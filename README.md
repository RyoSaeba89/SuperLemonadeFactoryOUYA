# Super Lemonade Factory — OUYA (source build)

A fork of [initials/SuperLemonadeFactoryOUYA](https://github.com/initials/SuperLemonadeFactoryOUYA)
that **builds the OUYA version from the original ActionScript-3 source** and makes it run on
current OUYA firmware, shipping the **full game unlocked**.

It renders, the OUYA controller works from a cold launch, and all levels are accessible — built
straight from `src/`, not by binary-patching a store APK.

## What was changed

The original source compiled, but a source build did not behave like the 2014 store release.
Three issues were fixed (details in [`docs/OUYA_PORT_FROMSOURCE.md`](docs/OUYA_PORT_FROMSOURCE.md)):

1. **White screen on boot** — a per-frame `FlxG.ouyaController.o.reset()` on a `null`
   controller threw every frame and killed the render loop. Fixed with a safe non-null
   placeholder controller and a `null`-device guard in `OuyaController.bindControls()`.
2. **Controller input never arrived** — `flash.ui.GameInput` has to be created *very early*
   (the flixel `[Frame]` preloader that normally does it does not run in an AIR build, and on
   OUYA firmware `DEVICE_ADDED` only fires for a pad that connects *after* `GameInput` exists).
   Fixed by initializing the controller library in the `SLF` constructor — the app entry point.
3. **In-app purchase / level locking** — the game ships fully unlocked (`Registry.DEMO = false`,
   no native IAP extension packaged), the purchase path is hard-guarded, and all 12 levels are
   unlocked from launch (the original "buy to unlock levels 3–12" was progression gating reusing
   a misleading purchase string, not a real IAP check).

## Building

Requires **Adobe AIR SDK 3.8** (its captive runtime is the same one the original store APK
shipped — a newer AIR SDK's `GameInput` no longer sees the legacy OUYA pad) and **JDK 8**.

```powershell
powershell -ExecutionPolicy Bypass -File build_ouya_air38.ps1
```

Produces a captive-runtime armv7 APK in `dist/`. Install with
`adb install -r dist/SuperLemonadeFactory-OUYA.apk`.

## License & credits

*Super Lemonade Factory* by **initials (Paul Greasley)** — see upstream. This fork keeps the
upstream **GPL-3.0** license. All game assets and original code belong to their author; this
fork only adds the OUYA build fixes described above.
