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

    func testStandardBuildDoesNotEnableBetaAccess() {
        let access = FeatureAccess.current(
            hasActivePlusSubscription: false
        )

        XCTAssertFalse(access.isBetaFullAccess)
        XCTAssertFalse(access.hasPlus)
    }

    func testBetaAccessUnlocksPlusWithoutSubscription() {
        let access = FeatureAccess(
            isBetaFullAccess: true,
            hasActivePlusSubscription: false
        )

        XCTAssertTrue(access.hasPlus)
    }

    func testProductionAccessRequiresActiveSubscription() {
        let freeAccess = FeatureAccess(
            isBetaFullAccess: false,
            hasActivePlusSubscription: false
        )
        let subscribedAccess = FeatureAccess(
            isBetaFullAccess: false,
            hasActivePlusSubscription: true
        )

        XCTAssertFalse(freeAccess.hasPlus)
        XCTAssertTrue(subscribedAccess.hasPlus)
    }
}
