# Glass Pulse

Glass Pulse is a one-touch SwiftUI orbit game. The ball moves at constant speed around a breathing glass ring; each tap reverses direction while rotating obstacle arcs and collectible gems share the orbit.

## Requirements

- Xcode 27 with the Swift 6.4 toolchain
- iOS 18 or newer
- XcodeGen

## Build

```bash
brew install xcodegen
xcodegen generate
open GlassPulse.xcodeproj
```

Run the GlassPulse scheme on an iPhone simulator. The scheme attaches `Resources/StoreKit.storekit` for local weekly and monthly Plus testing.

## Tests

```bash
xcodebuild -project GlassPulse.xcodeproj -scheme GlassPulse -destination "platform=iOS Simulator,name=iPhone 17 Pro" test
```

The repository CI selects an available iPhone simulator instead of depending on one fixed device name.

## Structure

- `Sources/Domain`: deterministic game rules, state, update loop, and Canvas rendering
- `Sources/Services`: haptic/audio feedback, local player profile, and StoreKit 2 entitlements
- `Sources/Design`: theme palettes and pulse variants
- `Sources/Views`: game, theme gallery, and Plus surfaces
- `Tests`: game-rule, persistence, and product-identity tests
- `docs`: current product, gameplay, architecture, and build references
