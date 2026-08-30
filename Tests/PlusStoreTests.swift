import XCTest
@testable import GlassPulse

final class PlusStoreTests: XCTestCase {
    func testPlusContainsWeeklyAndMonthlySubscriptionIDs() {
        XCTAssertEqual(
            PlusStore.productIDs,
            [
                "com.quachgia.glasspulse.plus.weekly",
                "com.quachgia.glasspulse.plus.monthly"
            ]
        )
    }

    func testProductIDResolvesToPlan() {
        XCTAssertEqual(
            PlusPlan(productID: "com.quachgia.glasspulse.plus.monthly"),
            .monthly
        )
        XCTAssertNil(PlusPlan(productID: "com.quachgia.glasspulse.plus.lifetime"))
    }

    func testPrismThemeIsPlusExclusive() {
        XCTAssertEqual(PulseTheme.prismPlus.unlock, .plus)
    }
}
