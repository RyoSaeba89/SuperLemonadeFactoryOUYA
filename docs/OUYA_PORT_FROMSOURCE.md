# Super Lemonade Factory — OUYA port (built from source)

This documents how the OUYA build of *Super Lemonade Factory* is produced **from the
original ActionScript-3 source** (this fork), rather than by binary-patching the official
store APK. Three problems had to be solved to make a source build behave like the working
store build: a **white-screen crash**, **controller input never arriving**, and the
**in-app-purchase / level locking**.

The game is an Adobe AIR / ActionScript-3 (flixel) title. The controller layer is the pure
AS3 `io.arkeus.ouya` library built on `flash.ui.GameInput` (no native extension).

## Build

Requirements on the build machine:

- **Adobe AIR SDK 3.8** at `C:\air38c` (`mxmlc` + `adt`). The captive runtime it bundles
  (`libCore.so`) is byte-for-byte the one shipped in the 2014 store APK, so `GameInput`
  behaves exactly as it did on the original release. **Do not build with a newer AIR SDK**
  (e.g. AIR 32): its runtime no longer enumerates the legacy OUYA pad on Android 4.1.
- **JDK 8** at `C:\Program Files\Java\jdk-1.8` (adt's APK signer needs it; JDK 9+ blocks
  `sun.security.x509`).

```powershell
powershell -ExecutionPolicy Bypass -File build_ouya_air38.ps1
```

This compiles `src/SLF.as` to `bin/SLFforOuya.swf` (mxmlc) and packages a captive-runtime,
armv7 APK (adt). No native extension (ANE) is packaged.

## 1. White screen on boot

Several game states call, every frame:

```actionscript
FlxG.ouyaController.o.reset();   // and .u / .y / .a, etc.
```

`FlxG.ouyaController` starts `null` and is only assigned once a controller is "ready". If it
is still `null`, the unguarded `null.o.reset()` throws `TypeError #1009` inside `update()`
**every frame**, before `draw()` runs — the render loop dies and the screen stays blank
(audio keeps playing because it starts in `create()`).

**Fix (two parts):**

1. `org.flixel.FlxG` declares the field with a safe non-null placeholder:
   ```actionscript
   public static var ouyaController:OuyaController = new OuyaController(null);
   ```
   `ControllerInput.initialize()` also installs the placeholder defensively if it is null.
2. `io.arkeus.ouya.controller.OuyaController.bindControls()` tolerates a `null` device (the
   placeholder passes `null`): the control-binding loop is wrapped in `if (device != null)`,
   so an empty control map binds every control to a null `GameInputControl`, which
   `GameControl` treats as a safe no-op.

Once the placeholder exists, the render loop survives and the real pad swaps it in later.

## 2. Controller input never arrives (the real blocker for a source build)

Symptom: the game renders, but the OUYA pad does nothing — at most the `O` and `A` buttons
register (they arrive as keyboard events; the d-pad / `U` / `Y` do not map to any key).

Root cause: the `io.arkeus.ouya` library and the AIR runtime are identical to the working
store build, but **`ControllerInput.initialize()` was never being called**, so `GameInput`
was never created. The store build initializes it from the flixel `[Frame]` preloader
(`FlxPreloader`); in an **AIR** build that preloader frame does not execute the same way
(AIR has no progressive-download phase), so the call was lost.

Simply moving the call into the first game state is **not enough**: on OUYA firmware,
`GameInput`'s `DEVICE_ADDED` event only fires for a pad that connects *after* the `GameInput`
object exists. A controller that is already on at launch (the normal case) is never reported
if `GameInput` is created late — `GameInput.getDeviceAt()` keeps returning `null` even though
`GameInput.numDevices == 1`.

**Fix:** create `GameInput` as early as possible — in the `SLF` (FlxGame) **constructor**,
the app entry point, before the controller finishes enumerating:

```actionscript
public function SLF() {
    ControllerInput.initialize(null);   // earliest possible; stage not needed for GameInput
    ...
    super(640, 360, PCIntroState, 3, 60, 30);
    ...
}
```

`ControllerInput.initialize()` is idempotent and tolerates a `null` stage. It does two
independent steps: (1) create `GameInput` + device listeners (must be early — from the `SLF`
constructor); (2) attach the per-frame listeners, which needs a valid stage and is completed
from `PCIntroState.create()`. With `GameInput` alive this early, `DEVICE_ADDED` fires for the
already-connected OUYA pad and the existing `hasReadyController()` / `getReadyController()`
logic attaches it. Button mapping (`io.arkeus.ouya.controller.OuyaController`) is unchanged.

### 2b. Button "pressed" edge / air double jump

`ButtonControl.pressed` is an edge detected against `ControllerInput.now`/`previous`, which
the library advanced from the stage `ENTER_FRAME` (render rate). On a slow OUYA the render
rate drops far below the 60 Hz game-logic rate, so `now`/`previous` lagged and `pressed`
stayed `true` for many logic frames. That made a *held* first jump auto-trigger Liselot's air
double jump (which gates on `o.pressed && jumpCounter == 1 && timeOffGround > 0.1`) instead of
requiring a real second press. Fix: advance `now`/`previous` once per **game-logic** frame in
`FlxG.updateInput()` (not from `ENTER_FRAME`), so `pressed` is a clean one-frame edge
regardless of render fps. The `io.arkeus.ouya` control classes are otherwise unchanged.

## 3. In-app purchase and level locking

The game shipped as a demo unlocked by an OUYA in-app purchase via the
`com.gaslightgames.AIROUYAIAPANE` native extension. This fork ships the **full game,
unlocked, with no purchase and no ANE**.

- **`Registry.DEMO = false`** (set in the `SLF` constructor, and the default in `Registry`).
  With `DEMO == false` the main menu shows "FULL GAME UNLOCKED", the "BUY GAME" button is not
  added, and the purchase prompt path is unreachable.
- **No ANE is packaged** and `application.xml` declares no `<extensions>`. The purchase flow
  (`PCMenuState.buy()` → `AIROUYAIAPANE.getInstance()` → `ExtensionContext.createExtensionContext()`)
  would create a null context and crash if ever reached, so `buy()` early-returns to normal
  play when `!Registry.DEMO` as a hard guard.
- **All levels accessible from launch.** Level selection is gated by per-level "complete"
  flags loaded from the save (`warehouseLevelsComplete` / `factoryLevelsComplete` /
  `mgmtLevelsComplete` and their hardcore variants); a fresh save only unlocks levels 1–2 and
  the rest unlock by progression. The reused "Purchase the game…" speech bubble shown for a
  locked level is misleading — the lock is progression, not purchase. `PCLevelSelectState`
  force-unlocks every slot (indices 1..12) of the in-memory selection arrays right after
  loading them, so all of levels 1–12 (normal and hardcore) are playable immediately.

## Device / install

```bash
adb install -r SuperLemonadeFactory-OUYA.apk
adb shell am start -n air.com.initialsgames.SLF/.AppEntry
```

App id `air.com.initialsgames.SLF`, launch activity `.AppEntry`. Verified on real OUYA
hardware (Android 4.1.2 / API 16): renders, controller works from a cold launch, and all
levels are selectable. Note: `screencap` is useless for AIR direct-mode rendering — verify on
the TV.
