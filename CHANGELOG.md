# Changelog

All notable changes to Glass Pulse are recorded here.

## [Unreleased]

### Added
- Added Classic, Rush 60, Precision Pulse, Wave Survival and deterministic Daily Challenge through one `GameEngine` and the original tap-to-reverse control.
- Added persistent mode selection, completion-based Daily streak, local Daily best and a non-farmable first-clear reward with migration from the old launch streak.
- Added Precision-only adaptive Core Haptics with capability fallback, throttled proximity parameters, cached procedural audio buffers and interruption/reset handling.
- Added native `SubscriptionStoreView` presentation while retaining verified StoreKit entitlement and `Transaction.updates` handling.
- Added a WidgetKit/ActivityKit extension for local Daily/Rush Lock Screen and Dynamic Island status.
- Added Debug/Beta render signposts, Canvas p50/p95/p99 CPU sampling and a `--spritekit-benchmark` SpriteView/SKShapeNode benchmark path.
- Added deterministic mode/DST/access tests, 10,000-seed spawn-safety coverage and UI smoke coverage for all modes.

### Changed
- Kept Canvas as the shipping renderer until real-device benchmarks justify a renderer change; no 120 FPS or power claim is inferred from preferred frame-rate configuration.
- Changed Daily streak semantics from app launch to successful Daily completion; Daily Classic/Precision variants now have a finite 60-second completion window.
- Changed Plus access to Classic + Daily free and Rush/Precision/Wave premium in production; unsigned Beta Full Access still opens all test content without persisting purchases.
- Shortened the startup splash, removed its artificial spinner and added Reduce Motion handling.
- Made the main board layout safe-area aware, added a prominent Mode entry and reduced unused vertical space.
- Reworked Theme selection for compact navigation, Dynamic Type wrapping and a readable selected-state chip.
- CI now records Xcode build timing and enforces a strict 25 MiB ceiling for the compressed IPA, uncompressed app and each extension.

### Fixed
- Fixed paused gameplay to expose one primary Resume action while paused board taps remain inert.
- Fixed App Icon packaging by placing the asset catalog in the XcodeGen resource build phase and added archive checks for `Assets.car`, `CFBundleIcons` and compiled AppIcon metadata.
- Removed the splash logo offscreen drawing group implicated in the device compositing square while keeping device confirmation as a visual gate.
