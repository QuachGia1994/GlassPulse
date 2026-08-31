# Changelog

All notable changes to Glass Pulse are recorded here.

## [Unreleased]

### Added
- Added a cross-platform Settings surface on both platforms with persisted Background Music, Sound Effects, Haptics, Reduce Motion, High Contrast and in-app Language (System/EN/VI/JA/zh-Hans), exposed through a localized glass sheet behind a trailing footer gear (`settings.open`).
- Added one licensed background-music loop on both platforms derived from a single pinned CC0 master (`Formant 1` by Benjamin Marzinski, `benmarz/minimum_game` @ `c1343613`), with a machine-readable provenance/checksum manifest (`Media/Music/PROVENANCE.json`), Android OGG and iOS AAC encodes under 0.4 MiB each, and CI checksum assertions.
- Added an Android edge-layer sensory stack: capability-aware `VibratorManager`/`Vibrator` haptics with primitive/amplitude/basic fallbacks, throttled Precision proximity pulses, Battery Saver degradation, cached static-mode `AudioTrack` procedural tones mirroring the iOS frequencies/envelopes, and a `USAGE_GAME` `MediaPlayer` music controller with audio-focus duck/loss/resume handling.
- Added official Android per-app language switching: `AppCompatActivity` + `AppCompatDelegate` backport for API 26-32, framework `localeConfig` sync on Android 13+, and two-way synchronization between the in-app picker and system per-app language settings.
- Added iOS `GameSettings` (`@MainActor @Observable`, UserDefaults-persisted with read-back verification), a looping `MusicEngine` with interruption handling, and Reduce Motion/High Contrast presentation that changes real rendering (static ring, stronger ring/border contrast, non-color ball outline and gem cues).
- Added settings defaults/persistence, sensory exactly-once/zero-call-disabled, proximity floor/throttle, locale mapping, music provenance checksum and locale-key-parity unit tests, plus iOS UI tests for settings open/close isolation, toggle accessibility values and language switching.
- Added a playable native Android/Compose mirror with the five iOS modes, deterministic Kotlin engine, full-screen input, Canvas renderer, pause/retry/mode flow, four themes, local progression and Beta Full Access.
- Added Classic, Rush 60, Precision Pulse, Wave Survival and deterministic Daily Challenge through one `GameEngine` and the original tap-to-reverse control.
- Added persistent mode selection, completion-based Daily streak, local Daily best and a non-farmable first-clear reward with migration from the old launch streak.
- Added Precision-only adaptive Core Haptics with capability fallback, throttled proximity parameters, cached procedural audio buffers and interruption/reset handling.
- Added native `SubscriptionStoreView` presentation while retaining verified StoreKit entitlement and `Transaction.updates` handling.
- Added a WidgetKit/ActivityKit extension for local Daily/Rush Lock Screen and Dynamic Island status.
- Added Debug/Beta render signposts, Canvas p50/p95/p99 CPU sampling and a `--spritekit-benchmark` SpriteView/SKShapeNode benchmark path.
- Added deterministic mode/DST/access tests, 10,000-seed spawn-safety coverage and UI smoke coverage for all modes.

### Changed
- Replaced the non-persisted iOS Mode-picker sound/haptic toggles with the persisted Settings sheet; `SensoryEngine` now mirrors the settings source of truth instead of owning duplicate toggle state.
- Rebuilt the Android launcher adaptive/round/monochrome icon artwork from the iOS `GlassPulseLogo` oracle (dark circular core, cyan/purple/orange sweep ring, pulse waveform, orange orbit ball) inside the adaptive safe zone.
- Kept Canvas as the shipping renderer until real-device benchmarks justify a renderer change; no 120 FPS or power claim is inferred from preferred frame-rate configuration.
- Changed Daily streak semantics from app launch to successful Daily completion; Daily Classic/Precision variants now have a finite 60-second completion window.
- Changed Plus access to Classic + Daily free and Rush/Precision/Wave premium in production; unsigned Beta Full Access still opens all test content without persisting purchases.
- Shortened the startup splash, removed its artificial spinner and added Reduce Motion handling.
- Made the main board layout safe-area aware, added a prominent Mode entry and reduced unused vertical space.
- Reworked Theme selection for compact navigation, Dynamic Type wrapping and a readable selected-state chip.
- Aligned Android gameplay chrome with the iOS visual hierarchy: centered board rhythm, theme-driven glass surfaces, compact status actions, filled footer controls, anchored sheet headers and a custom Beta access dialog.
- CI now records Xcode build timing and enforces a strict 25 MiB ceiling for the compressed IPA, uncompressed app and each extension.

### Fixed
- Fixed iOS CI regressions by preserving the Settings sheet across live locale changes, validating compiled locale bundles instead of expecting the app to ship raw `xcstrings`, and making the Game Over retry UI harness collision-free.
- Fixed an Android cold-launch crash on devices with vibration amplitude control by keeping generated proximity amplitudes in the valid integer range.
- Fixed Android lint by gating the thud haptic primitive at API 31 while preserving API 30 click support, and by wiring localized Settings descriptions into Compose accessibility semantics.
- Fixed paused gameplay to expose one primary Resume action while paused board taps remain inert.
- Fixed App Icon packaging by placing the asset catalog in the XcodeGen resource build phase and added archive checks for `Assets.car`, `CFBundleIcons` and compiled AppIcon metadata.
- Removed the splash logo offscreen drawing group implicated in the device compositing square while keeping device confirmation as a visual gate.
- Kept intentionally pinned Android API 36 toolchain advisories out of fatal source-quality lint and retained full lint reports from every Android CI run.
- Fixed Android backup policy for both API 26–30 (`fullBackupContent`) and API 31+ (`dataExtractionRules`), plus release resource shrinking, adaptive icon qualifiers and monochrome launcher layers reported by strict lint.
