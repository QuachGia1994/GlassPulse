# Build and verify

## Generate

```bash
brew install xcodegen
xcodegen generate
xcodebuild -list -project GlassPulse.xcodeproj
```

Required project settings are Xcode 27 / Swift 6.4 compiler, `SWIFT_VERSION = 6.0`, complete Strict Concurrency and warnings-as-errors.

## Build simulator

```bash
xcodebuild -project GlassPulse.xcodeproj -scheme GlassPulse -configuration Debug -sdk iphonesimulator -destination "generic/platform=iOS Simulator" -showBuildTimingSummary CODE_SIGNING_ALLOWED=NO build
```

## Test

```bash
xcodebuild -project GlassPulse.xcodeproj -scheme GlassPulse -configuration Debug -destination "platform=iOS Simulator,name=iPhone 17 Pro" CODE_SIGNING_ALLOWED=NO test
```

If that simulator name is unavailable, select an available iPhone UDID from `xcrun simctl list devices available`. CI performs this dynamically.

## Renderer benchmark

Shipping builds use Canvas. Debug/Beta builds expose the SpriteKit benchmark launch argument:

```text
--spritekit-benchmark
```

Without it, Canvas remains active. With it, the same simulation snapshot feeds a `SpriteView`/`SKShapeNode` scene requesting 120 preferred FPS. Debug/Beta Canvas runs emit `SimulationUpdate` and `CanvasFrame` signposts and p50/p95/p99 CPU summaries.

Device benchmark protocol:

1. Run the same seeded stress scene on one 60 Hz iPhone and one ProMotion iPhone.
2. Capture `CanvasFrame` / `SimulationUpdate` signposts, dropped frames, CPU/GPU and Power Profiler.
3. Repeat with `--spritekit-benchmark`.
4. Adopt SpriteKit only if p95/device power evidence improves without gameplay regressions. Until then Canvas remains shipping and `CADisableMinimumFrameDurationOnPhone` stays absent.

Simulator timing is useful for build/test correctness but is not evidence for 120 FPS or power.

## Unsigned Beta IPA

The `unsigned-ipa` job archives `generic/platform=iOS` with code signing disabled and adds `GLASS_PULSE_BETA` only to that archive command. Normal build/test and production builds do not receive the flag.

Archive verification requires:

- `GlassPulse.app/Assets.car` exists;
- `Info.plist` contains `CFBundleIcons` and AppIcon metadata;
- `assetutil` finds AppIcon in compiled assets;
- `PlugIns/GlassPulseWidgetExtension.appex` exists;
- SHA-256 is printed for `.build/GlassPulse.ipa`.

The job then enforces a strict `<25 MiB` limit independently for:

- compressed `GlassPulse.ipa`;
- uncompressed `GlassPulse.app` tree;
- every embedded `.appex` tree.

The uploaded artifact remains `GlassPulse-unsigned-IPA-Xcode27`.

## Live Activity / Widget extension

The archive embeds `GlassPulseWidgetExtension` for Daily/Rush Live Activities. Dynamic content is supplied through ActivityKit and currently needs no App Group. Lock Screen/Dynamic Island output uses local score/streak/best data only.

Unsigned re-signing is outside CI's entitlement authority. AltStore/SideStore can require an additional App ID for the extension and may strip or fail optional extension provisioning. A successful unsigned archive proves packaging, not real-device Dynamic Island/Lock Screen behavior.

## StoreKit

The generated scheme uses `Resources/StoreKit.storekit` with one subscription group and two products:

- `com.quachgia.glasspulse.plus.weekly`
- `com.quachgia.glasspulse.plus.monthly`

`SubscriptionStoreView` presents purchases. `PlusStore` remains the entitlement source of truth through verified `Transaction.currentEntitlements` and `Transaction.updates`; restore uses `AppStore.sync()`.

## CI evidence boundary

A green Xcode 27 run proves project generation, warnings-as-errors build, simulator tests, unsigned archive, App Icon/extension packaging and size gates. It does not prove device FPS/power, Core Haptics feel, Dynamic Island appearance, sideload provisioning or crash-free rate.
