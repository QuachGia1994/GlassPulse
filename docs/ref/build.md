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

## Unsigned Beta IPA

The `unsigned-ipa` CI job archives for `generic/platform=iOS` with code signing disabled and adds `GLASS_PULSE_BETA` to `SWIFT_ACTIVE_COMPILATION_CONDITIONS`. That artifact opens every theme/pulse for sideload testing; simulator and normal production builds do not receive the flag and continue to use verified StoreKit entitlement state.

The job packages `.build/GlassPulse.xcarchive/Products/Applications/GlassPulse.app` as `Payload/GlassPulse.app`, then uploads `GlassPulse.ipa` in the `GlassPulse-unsigned-IPA-Xcode27` artifact.

## StoreKit

The generated GlassPulse scheme uses `Resources/StoreKit.storekit`. Local products are subscriptions only:

- `com.quachgia.glasspulse.plus.weekly`
- `com.quachgia.glasspulse.plus.monthly`

App Store Connect remains the production source of truth for availability, price, localization, and review status.
