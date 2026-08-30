# Glass Pulse

Glass Pulse is a one-touch SwiftUI orbit game. One controlled ball moves automatically on one ring; every gameplay mode keeps the same tap-to-reverse control and deterministic simulation engine.

## Requirements

- Xcode 27 with the Swift 6.4 compiler
- Swift 6 language mode (`SWIFT_VERSION = 6.0`)
- iOS 18 or newer
- XcodeGen

## Build

```bash
brew install xcodegen
xcodegen generate
open GlassPulse.xcodeproj
```

The generated `GlassPulse` scheme attaches `Resources/StoreKit.storekit` for local weekly/monthly Plus testing. Strict Concurrency and warnings-as-errors are enabled for the project.

## Modes

- **Classic**: original endless rules and regression oracle.
- **Rush 60**: fixed 60-second run with capped combo scoring.
- **Precision Pulse**: gem collection only succeeds during the visible pulse window; adaptive haptics are limited to this mode.
- **Wave Survival**: deterministic timed waves with one ball and safe hazard insertion.
- **Daily Challenge**: versioned calendar-day seed rotating the same one-ball rule sets; Classic/Precision Daily variants use a finite 60-second completion window. Daily streak and first-clear reward require a completed run.

Production access is Classic + Daily for free users and Rush/Precision/Wave for verified Plus subscribers. The unsigned CI Beta build opens every mode/theme without storing a fake purchase.

## Controls

- Tap anywhere on the gameplay surface to start; each later gameplay tap reverses direction exactly once. The empty space around the square board is interactive too.
- Explicit controls sit above the gameplay surface and consume their own taps. Pause uses one 44-point control; paused/background taps do nothing and Resume resets the frame clock.
- After game over/completion, background taps stay inert. Retry starts a fresh run in the same mode; Choose Mode opens the picker and returns the selected mode to `.start`.
- Daily Retry preserves the same day/version seed and cannot farm the first-clear reward; standard Retry creates a fresh valid session.
- Opening Theme/Plus or backgrounding the app pauses an active run. Mode changes remain disabled during an active or paused run.

## Tests

```bash
xcodebuild -project GlassPulse.xcodeproj -scheme GlassPulse -destination "platform=iOS Simulator,name=iPhone 17 Pro" test
```

CI selects an available iPhone simulator, runs the standard non-Beta build and tests, then creates the separate unsigned Beta archive. Unit coverage includes Classic regression, mode rules, inert paused/over taps, clean replay session semantics, Daily rollover/DST/reward behavior, subscription access, and a 10,000-seed spawn-safety stress pass. UI coverage includes full-window outside-board input, single reversal semantics, pause/control tap isolation, deterministic game-over Retry/Choose Mode flows, accessibility-sized game-over/theme actions and starting every mode through Debug-only harnesses.

## Renderer benchmark

Canvas remains the shipping renderer. Debug/Beta builds record `SimulationUpdate` and `CanvasFrame` `OSSignposter` intervals and log Canvas CPU p50/p95/p99 every 240 measured frames.

A SpriteKit `SpriteView` + `SKShapeNode` spike can be enabled only in Debug/Beta with the launch argument:

```text
--spritekit-benchmark
```

The spike consumes the same read-only simulation snapshot and requests 120 preferred frames per second for comparison. This is not evidence of 120 FPS or lower power. Do not switch the shipping renderer or add `CADisableMinimumFrameDurationOnPhone` until Instruments/device measurements show a benefit on both a 60 Hz iPhone and a ProMotion iPhone.

## Unsigned Beta IPA

Each successful `iOS CI` run uploads `GlassPulse-unsigned-IPA-Xcode27`, containing `GlassPulse.ipa`. The unsigned archive alone receives `GLASS_PULSE_BETA`; normal simulator/production builds continue to require verified StoreKit entitlement.

CI verifies before upload:

- compiled `Assets.car`, `CFBundleIcons`, and `AppIcon` archive metadata;
- embedded `GlassPulseWidgetExtension.appex`;
- SHA-256 of the IPA;
- compressed IPA size, uncompressed `GlassPulse.app` size, and every `.appex` size, each strictly below 25 MiB.

### Live Activity and sideload entitlements

The archive contains a WidgetKit/ActivityKit extension for active Daily/Rush runs. It shows mode, score, Rush time, Daily streak and **Local best** only. No backend/Game Center means no global-rank claim.

No App Group entitlement is required by the current implementation because Live Activity state is supplied directly through ActivityKit. AltStore/SideStore re-signing can consume an additional App ID for the extension and may strip or fail to provision optional extension capabilities depending on the Apple Account and signer. If that happens, the main game remains the required artifact; Lock Screen/Dynamic Island behavior is a device/provisioning verification gate, not a CI claim.

### AltStore / SideStore

Download the artifact from **Actions > iOS CI**, extract `GlassPulse.ipa`, then re-sign/install it with AltStore or SideStore. Free Apple Accounts generally require periodic re-signing and have App ID/app-count limits; an embedded extension may consume additional provisioning capacity. Check the current signer documentation for the exact account limits before installation.

## Structure

- `Sources/Domain`: deterministic simulation, mode/session rules and Canvas rendering.
- `Sources/Rendering`: render diagnostics and the feature-flagged SpriteKit benchmark spike.
- `Sources/Services`: player persistence, StoreKit entitlement, sensory feedback and Live Activity control.
- `Sources/Views`: game, mode, theme and Plus presentation.
- `Shared/Activity`: ActivityKit attributes shared by app and extension.
- `WidgetExtension`: Lock Screen/Dynamic Island Live Activity UI.
- `Tests` / `UITests`: deterministic rule and UI regression coverage.
- `docs`: product, gameplay, architecture and build source-of-truth documentation.
