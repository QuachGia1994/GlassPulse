import XCTest
@testable import GlassPulse

final class GameActivityConcurrencyTests: XCTestCase {
    func testActivityPayloadTypesAreSendable() {
        requireSendable(GlassPulseActivityAttributes.self)
        requireSendable(GlassPulseActivityAttributes.ContentState.self)
    }

    private func requireSendable<T: Sendable>(_ type: T.Type) {}
}
