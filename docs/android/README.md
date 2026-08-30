# Glass Pulse Android scaffold

> updated 2026-08-30 · Stage 1

The Android mirror lives under `android/` and is native Kotlin + Jetpack Compose. Stage 1 is scaffold-only: it establishes branding, localization, accessibility, build flavors, tests, and CI without porting gameplay or Android platform integrations.

## Toolchain

- Android Gradle Plugin 9.3.2
- Gradle 9.5.0
- Kotlin 2.4.10
- Java 17
- compileSdk / targetSdk 36
- minSdk 26
- Compose UI 1.11.4
- Material 3 1.4.0
- Activity Compose 1.13.0
- Core SplashScreen 1.2.0

## Build variants

- `productionDebug`: application ID `com.quachgia.glasspulse`, `BuildConfig.BETA_FULL_ACCESS=false`.
- `betaDebug`: application ID `com.quachgia.glasspulse.beta`, `BuildConfig.BETA_FULL_ACCESS=true`, Android debug signing.

Production access is never inferred from APK signature, package source, package name, or device state. The compile-time BuildConfig field is the only Stage 1 beta boundary.

## Stage 1 UI

The app launches through AndroidX SplashScreen into a dark Material 3 Compose shell with a procedural Glass Pulse mark. Startup adds no custom transition or artificial delay, so reduced-motion users are not forced through animation. EN, VI, JA, and zh-rCN resource sets contain the same Stage 1 keys.

This stage does not contain the game engine, Canvas gameplay renderer, Billing, DataStore, audio, haptics, notifications, widgets, or Play Games Services.

## CI artifact

Android CI runs lint, production/beta JVM unit tests, compiles the beta instrumentation smoke test, and assembles `betaDebug`. The package job verifies Android debug signing with `apksigner`, enforces an APK size below 25 MiB, prints SHA-256, renames the file to `GlassPulse-beta-debug.apk`, and uploads artifact `GlassPulse-android-beta-apk`.

Physical Android installation is not verified in Stage 1; `runtime_verified` remains false.
