import XCTest
@testable import GlassPulse

final class PlayerProfileTests: XCTestCase {
    @MainActor
    func testDailyStreakAdvancesOncePerConsecutiveDay() throws {
        let suiteName = "glassPulse.tests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let profile = PlayerProfile(defaults: defaults)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(secondsFromGMT: 0))
        let day = Date(timeIntervalSince1970: 1_700_000_000)

        profile.registerDailyPlay(now: day, calendar: calendar)
        profile.registerDailyPlay(now: day, calendar: calendar)
        XCTAssertEqual(profile.dailyStreak, 1)

        let nextDay = try XCTUnwrap(calendar.date(byAdding: .day, value: 1, to: day))
        profile.registerDailyPlay(now: nextDay, calendar: calendar)
        XCTAssertEqual(profile.dailyStreak, 2)
    }

    @MainActor
    func testRunRewardUnlocksAndSelectsShardTheme() throws {
        let suiteName = "glassPulse.tests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let profile = PlayerProfile(defaults: defaults)

        profile.recordRun(score: 20, reward: 20)
        let access = FeatureAccess(
            isBetaFullAccess: false,
            hasActivePlusSubscription: false
        )
        let result = profile.select(.ember, access: access)

        guard case .success = result else {
            return XCTFail("Expected Ember to unlock with 20 shards.")
        }
        XCTAssertEqual(profile.totalShards, 2)
        XCTAssertEqual(profile.activeTheme(access: access), .ember)
        XCTAssertEqual(profile.bestScore, 20)
    }

    @MainActor
    func testPlusThemeRequiresActiveEntitlement() throws {
        let suiteName = "glassPulse.tests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let profile = PlayerProfile(defaults: defaults)

        let access = FeatureAccess(
            isBetaFullAccess: false,
            hasActivePlusSubscription: false
        )
        let result = profile.select(.prismPlus, access: access)

        guard case .failure(.plusRequired) = result else {
            return XCTFail("Expected Prism Plus to require an entitlement.")
        }
        XCTAssertEqual(profile.activeTheme(access: access), .clarity)
    }

    @MainActor
    func testBetaAccessSelectsShardAndPlusThemesWithoutSpending() throws {
        let suiteName = "glassPulse.tests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let profile = PlayerProfile(defaults: defaults)
        let access = FeatureAccess(
            isBetaFullAccess: true,
            hasActivePlusSubscription: false
        )

        guard case .success = profile.select(.aurora, access: access) else {
            return XCTFail("Expected beta access to unlock Aurora.")
        }
        XCTAssertEqual(profile.totalShards, 0)
        XCTAssertEqual(profile.activeTheme(access: access), .aurora)

        guard case .success = profile.select(.prismPlus, access: access) else {
            return XCTFail("Expected beta access to unlock Prism Plus.")
        }
        XCTAssertEqual(profile.activeTheme(access: access), .prismPlus)
    }
}
