# Glass Pulse product

> updated 2026-08-30 · pre-release

## Positioning

Glass Pulse is a focused reflex game built around one recognizable rule: one automatically moving ball, one circular orbit and one tap that reverses direction. Replay variety comes from deterministic rule variants rather than extra controls or duplicated game systems.

## Retention

- Classic provides the endless high-score loop.
- Daily Challenge provides a reproducible calendar-day target, local best and completion streak.
- Rush, Precision and Wave provide short rule variants while preserving the same motor skill.
- Shards and themes add lightweight progression without changing collision fairness.

No backend or Game Center exists today, so Daily surfaces say **Local best** and never imply a global leaderboard.

## Monetization

- Free production: Classic + Daily Challenge.
- Plus weekly/monthly: Rush 60, Precision Pulse, Wave Survival and Prism Plus theme.
- Purchase presentation uses StoreKit's native subscription UI; verified entitlement remains authoritative.
- Production price/localization/review status remains an App Store Connect decision; `Resources/StoreKit.storekit` contains local test configuration only.
- Unsigned CI artifacts use compile-time Beta Full Access for device testing. Beta does not persist a purchase and cannot unlock production builds.

## Platform surfaces

Daily/Rush can start a local Live Activity containing mode, score, Rush time, Daily streak and Local best. Dynamic Island and Lock Screen support are optional platform surfaces: failure to provision an extension during unsigned re-signing must not block the core game.

## Evidence gates

Renderer migration is evidence-driven. Canvas remains shipping until the feature-flagged SpriteKit benchmark beats it on real 60 Hz and ProMotion devices for p95 frame work and power. `preferredFramesPerSecond: 120` is not a product claim.

No dark patterns: renewal is disclosed by the standard StoreKit surface, restore remains available in production and cancellation stays in App Store subscription controls.
