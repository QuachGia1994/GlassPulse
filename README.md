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

## Cài lên máy

Mỗi run CI thành công tạo artifact `GlassPulse-unsigned-IPA-Xcode27` chứa `GlassPulse.ipa`. Đây là IPA **unsigned**, không thể cài trực tiếp từ Files: AltStore hoặc SideStore sẽ ký lại IPA bằng Apple Account trước khi cài.

### AltStore trên Windows

1. Cài [AltServer và AltStore theo hướng dẫn Windows](https://faq.altstore.io/altstore-classic/how-to-install-altstore-windows).
2. Giữ AltServer chạy trên PC và để PC cùng mạng Wi-Fi với iPhone.
3. Tải artifact từ trang **Actions > iOS CI**, giải nén, rồi mở `GlassPulse.ipa` bằng AltStore.
4. App ký bằng Apple Account miễn phí hết hạn sau 7 ngày. AltStore có thể tự refresh khi AltServer đang chạy và hai thiết bị vẫn cùng mạng; mở AltStore để kiểm tra thời hạn trước khi app hết hạn.

### SideStore

1. SideStore chỉ cần máy tính trong lần cài ban đầu: chuẩn bị [iloader và LocalDevVPN](https://docs.sidestore.io/docs/installation/prerequisites), sau đó [cài SideStore bằng iloader](https://docs.sidestore.io/docs/installation/install).
2. Sau khi setup, bật LocalDevVPN để cài/refresh `GlassPulse.ipa` ngay trên iPhone; không cần PC cho các lần refresh thông thường.
3. Tài liệu SideStore hiện liệt kê iOS 26.x, nhưng đã có báo cáo lỗi refresh trên [iOS 26.4](https://github.com/SideStore/SideStore/issues/1222) và [iOS 26.4.1](https://github.com/SideStore/SideStore/issues/1226). Hãy kiểm tra đúng phiên bản iOS, release và issue mới nhất của SideStore trước khi chọn cách này.

### Giới hạn tài khoản miễn phí

Theo [SideStore FAQ](https://docs.sidestore.io/docs/faq), Apple Account miễn phí chỉ được kích hoạt tối đa 3 app sideload cùng lúc (tính cả AltStore hoặc SideStore), tối đa 10 App ID khác nhau trong 7 ngày, và mỗi app cần được ký lại sau 7 ngày.

TrollStore không phải lựa chọn cho thiết bị mới: dự án chỉ hỗ trợ đến iOS 17.0 và ghi rõ iOS 17.0.1+ sẽ không được hỗ trợ nếu không xuất hiện lỗi CoreTrust mới. Vì vậy [TrollStore](https://github.com/opa334/TrollStore) không dùng được trên iOS 18/26/27.

## Structure

- `Sources/Domain`: deterministic game rules, state, update loop, and Canvas rendering
- `Sources/Services`: haptic/audio feedback, local player profile, and StoreKit 2 entitlements
- `Sources/Design`: theme palettes and pulse variants
- `Sources/Views`: game, theme gallery, and Plus surfaces
- `Tests`: game-rule, persistence, and product-identity tests
- `docs`: current product, gameplay, architecture, and build references
