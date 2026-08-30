# Glass Pulse Android

> updated 2026-08-30 · playable native beta

The Android mirror lives under `android/` and is native Kotlin + Jetpack Compose. The launch destination is the game itself, not a scaffold screen.

## Toolchain

- Android Gradle Plugin 9.3.2
- Gradle 9.5.0
- Kotlin 2.4.10
- Java 17
- compileSdk / targetSdk 36
- minSdk 26
- Compose UI 1.11.4
- Material 3 1.4.0
- Activity Compose 1.12.4
- Core SplashScreen 1.2.0

## Playable parity scope

- One ball moves automatically on one orbit; one full-screen tap reverses direction exactly once.
- Compose Canvas draws the breathing ring, ball, rotating spike arcs, gem, glow, collection burst and collision flash.
- Classic, Rush 60, Precision Pulse, Wave Survival and deterministic Daily Challenge share one Kotlin `GameEngine`.
- Pause/background taps are inert; Resume resets the frame clock.
- Game Over exposes Retry and Choose Mode. Retry creates a fresh normal session while Daily preserves the same day/version context.
- Best score, shards, selected mode/theme, Daily best, first-clear reward and completion streak persist locally.
- Clarity, Ember, Aurora and Prism Plus palettes are drawn procedurally.
- EN, VI, JA and zh-rCN resource sets contain the same gameplay keys.

## Build variants

- `productionDebug`: application ID `com.quachgia.glasspulse`, `BuildConfig.BETA_FULL_ACCESS=false`.
- `betaDebug`: application ID `com.quachgia.glasspulse.beta`, `BuildConfig.BETA_FULL_ACCESS=true`, Android debug signing.

The beta flag opens all five modes and four themes without creating a fake purchase. Production access is never inferred from APK signing, package source or device state.

## Verification

Android CI runs strict lint, production/beta JVM tests, compiles the instrumentation suite and assembles `betaDebug`. Unit coverage includes the tap contract, paused/over inert behavior, timed completion, Daily determinism and 10,000 safe seeded starts. UI coverage asserts that the game is the launch destination, full-screen input starts play, pause/resume works and all five modes exist.

The package job verifies signing with `apksigner`, enforces an APK below 25 MiB, emits SHA-256 and uploads `GlassPulse-android-beta-apk` containing `GlassPulse-beta-debug.apk`.

Physical-device gameplay remains `runtime_verified: false` until the new APK is installed and exercised.
