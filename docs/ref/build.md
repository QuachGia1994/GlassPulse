# Build and verify

## Generate

```bash
brew install xcodegen
xcodegen generate
xcodebuild -list -project GlassPulse.xcodeproj
```

## Build simulator

```bash
xcodebuild -project GlassPulse.xcodeproj -scheme GlassPulse -configuration Debug -sdk iphonesimulator -destination "generic/platform=iOS Simulator" CODE_SIGNING_ALLOWED=NO build
```

## Test

```bash
xcodebuild -project GlassPulse.xcodeproj -scheme GlassPulse -configuration Debug -destination "platform=iOS Simulator,name=iPhone 17 Pro" CODE_SIGNING_ALLOWED=NO test
```

If the named simulator is unavailable, use `xcrun simctl list devices available` and select any available iPhone identifier. CI performs this selection automatically.

## StoreKit

The generated GlassPulse scheme uses `Resources/StoreKit.storekit`. Local products are subscriptions only:

- `com.quachgia.glasspulse.plus.weekly`
- `com.quachgia.glasspulse.plus.monthly`

App Store Connect remains the production source of truth for availability, price, localization, and review status.
