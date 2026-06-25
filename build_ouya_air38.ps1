# Build Super Lemonade Factory for OUYA from source (full game, no IAP).
#
# Produces a captive-runtime, armv7 APK that runs on OUYA / Android 4.1 / API 16.
#
# MUST build with Adobe AIR SDK 3.8: its captive runtime (libCore.so) is the same one the
# 2014 store APK shipped, so flash.ui.GameInput enumerates the OUYA pad. A newer AIR SDK
# (e.g. AIR 32) bundles a runtime whose GameInput no longer sees the legacy OUYA controller.
#
# Requirements:
#   - Adobe AIR SDK 3.8           at  C:\air38c   (mxmlc + adt)
#   - JDK 8                       at  C:\Program Files\Java\jdk-1.8  (adt's signer needs it)
#
# Run from the project root:  powershell -ExecutionPolicy Bypass -File build_ouya_air38.ps1

$ErrorActionPreference = "Stop"
$AIR   = "C:\air38c"
$JDK8  = "C:\Program Files\Java\jdk-1.8"
$PROJ  = $PSScriptRoot
$CERT  = Join-Path $PROJ "cert\slf-ouya.p12"
$PASS  = "fd"
$APK   = Join-Path $PROJ "dist\SuperLemonadeFactory-OUYA.apk"

# adt/mxmlc launch plain `java` from PATH -> force JDK 8 to the front.
$env:JAVA_HOME = $JDK8
$env:PATH      = "$JDK8\bin;" + $env:PATH

New-Item -ItemType Directory -Force (Join-Path $PROJ "bin")  | Out-Null
New-Item -ItemType Directory -Force (Join-Path $PROJ "dist") | Out-Null

Write-Host "[1/3] Compiling SWF (mxmlc, airmobile)..."
& "$AIR\bin\mxmlc.bat" +configname=airmobile `
    -source-path (Join-Path $PROJ "src") `
    -output (Join-Path $PROJ "bin\SLFforOuya.swf") `
    -static-link-runtime-shared-libraries=true `
    -- (Join-Path $PROJ "src\SLF.as")
if ($LASTEXITCODE -ne 0) { throw "mxmlc failed ($LASTEXITCODE)" }

if (-not (Test-Path $CERT)) {
    Write-Host "[2/3] Creating self-signed certificate..."
    & "$AIR\bin\adt.bat" -certificate -validityPeriod 20 -cn "Super Lemonade Factory" 2048-RSA $CERT $PASS
    if ($LASTEXITCODE -ne 0) { throw "cert creation failed ($LASTEXITCODE)" }
} else {
    Write-Host "[2/3] Using existing certificate."
}

Write-Host "[3/3] Packaging captive-runtime armv7 APK (adt)..."
Set-Location $PROJ
& "$AIR\bin\adt.bat" -package -target apk-captive-runtime `
    -storetype pkcs12 -keystore $CERT -storepass $PASS `
    $APK application.xml -C bin . -C icons/android .
if ($LASTEXITCODE -ne 0) { throw "adt packaging failed ($LASTEXITCODE)" }

Write-Host ""
Write-Host ("DONE -> {0} ({1:N2} MB)" -f $APK, ((Get-Item $APK).Length / 1MB))
