import XCTest
@testable import GlassPulse

final class PlayerProfileTests: XCTestCase {
    @MainActor
    func testLegacyLaunchStreakResetsDuringCompletionMigration() throws {
        let suiteName = "glassPulse.tests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set(42, forKey: "glassPulse.dailyStreak")
        defaults.set(Date.now, forKey: "glassPulse.lastPlayedDate")

        let profile = PlayerProfile(defaults: defaults)

        XCTAssertEqual(profile.dailyStreak, 0)
        XCTAssertNil(profile.lastDailyCompletionKey)
    }

    @MainActor
    func testDailyCompletionStreakUsesCalendarDaysAcrossDST() throws {
        let suiteName = "glassPulse.tests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let profile = PlayerProfile(defaults: defaults)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(identifier: "America/Los_Angeles"))
        let firstDate = try XCTUnwrap(
            calendar.date(from: DateComponents(year: 2026, month: 3, day: 8, hour: 12))
        )
        let secondDate = try XCTUnwrap(calendar.date(byAdding: .day, value: 1, to: firstDate))
        let firstKey = DailyChallenge.key(for: firstDate, calendar: calendar)
        let secondKey = DailyChallenge.key(for: secondDate, calendar: calendar)

        profile.recordDailyCompletion(
            dayKey: firstKey,
            date: firstDate,
            score: 4,
            firstClearBonus: 10,
            calendar: calendar
        )
        profile.recordDailyCompletion(
            dayKey: secondKey,
            date: secondDate,
            score: 6,
            firstClearBonus: 10,
            calendar: calendar
        )

        XCTAssertEqual(profile.dailyStreak, 2)
        XCTAssertEqual(profile.dailyBestScore, 6)
    }

    @MainActor
    func testDailyFirstClearBonusCannotBeFarmed() throws {
        let suiteName = "glassPulse.tests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let profile = PlayerProfile(defaults: defaults)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(secondsFromGMT: 0))
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let dayKey = DailyChallenge.key(for: date, calendar: calendar)

        let firstBonus = profile.recordDailyCompletion(
            dayKey: dayKey,
            date: date,
            score: 3,
            firstClearBonus: 10,
            calendar: calendar
        )
        let secondBonus = profile.recordDailyCompletion(
            dayKey: dayKey,
            date: date,
            score: 8,
            firstClearBonus: 10,
            calendar: calendar
        )

        XCTAssertEqual(firstBonus, 10)
        XCTAssertEqual(secondBonus, 0)
        XCTAssertEqual(profile.totalShards, 10)
        XCTAssertEqual(profile.dailyBestScore, 8)
        XCTAssertEqual(profile.dailyStreak, 1)
    }

    @MainActor
    func testDailyBestLookupDoesNotLeakPreviousDay() throws {
        let suiteName = "glassPulse.tests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let profile = PlayerProfile(defaults: defaults)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(secondsFromGMT: 0))
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let dayKey = DailyChallenge.key(for: date, calendar: calendar)
        let nextDate = try XCTUnwrap(calendar.date(byAdding: .day, value: 1, to: date))
        let nextKey = DailyChallenge.key(for: nextDate, calendar: calendar)

        profile.recordDailyCompletion(
            dayKey: dayKey,
            date: date,
            score: 12,
            firstClearBonus: 10,
            calendar: calendar
        )

        XCTAssertEqual(profile.dailyBest(for: dayKey), 12)
        XCTAssertEqual(profile.dailyBest(for: nextKey), 0)
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
    func testProductionModeAccessLocksPremiumModes() throws {
        let suiteName = "glassPulse.tests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let profile = PlayerProfile(defaults: defaults)
        let freeAccess = FeatureAccess(
            isBetaFullAccess: false,
            hasActivePlusSubscription: false
        )

        guard case .failure(.modePlusRequired) = profile.select(mode: .rush60, access: freeAccess) else {
            return XCTFail("Expected Rush 60 to require Plus in production.")
        }
        XCTAssertEqual(profile.activeMode(access: freeAccess), .classic)

        guard case .success = profile.select(mode: .dailyChallenge, access: freeAccess) else {
            return XCTFail("Expected Daily Challenge to remain free.")
        }
        XCTAssertEqual(profile.activeMode(access: freeAccess), .dailyChallenge)
    }

    @MainActor
    func testBetaAccessSelectsPremiumModeAndThemesWithoutSpending() throws {
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

        guard case .success = profile.select(mode: .waveSurvival, access: access) else {
            return XCTFail("Expected beta access to unlock Wave Survival.")
        }
        XCTAssertEqual(profile.activeMode(access: access), .waveSurvival)
        XCTAssertEqual(profile.totalShards, 0)
    }
}
