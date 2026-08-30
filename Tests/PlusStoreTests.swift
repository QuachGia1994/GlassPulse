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
        XCTAssertTrue(freeAccess.canUse(.classic))
        XCTAssertTrue(freeAccess.canUse(.dailyChallenge))
        XCTAssertFalse(freeAccess.canUse(.rush60))
        XCTAssertTrue(subscribedAccess.canUse(.rush60))
    }

    func testSubscriptionGroupIdentityMatchesStoreKitConfiguration() {
        XCTAssertEqual(
            PlusStore.subscriptionGroupID,
            "5A15D10B-9197-4D8A-A026-77A5ECCE01A1"
        )
    }

    func testRevokedOrExpiredSubscriptionsAreInactive() {
        let now = Date(timeIntervalSinceReferenceDate: 2_000)
        XCTAssertFalse(
            SubscriptionEntitlementPolicy.isActive(
                revocationDate: now,
                expirationDate: now.addingTimeInterval(100),
                now: now
            )
        )
        XCTAssertFalse(
            SubscriptionEntitlementPolicy.isActive(
                revocationDate: nil,
                expirationDate: now.addingTimeInterval(-1),
                now: now
            )
        )
        XCTAssertTrue(
            SubscriptionEntitlementPolicy.isActive(
                revocationDate: nil,
                expirationDate: now.addingTimeInterval(100),
                now: now
            )
        )
    }
}
