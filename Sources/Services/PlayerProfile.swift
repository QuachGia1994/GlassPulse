import Foundation
import Observation

enum PlayerProfileError: Error, Equatable, LocalizedError {
    case insufficientShards(required: Int, available: Int)
    case plusRequired
    case modePlusRequired

    var errorDescription: String? {
        switch self {
        case .insufficientShards(let required, let available):
            "Cần \(required) shard, hiện có \(available)."
        case .plusRequired:
            "Theme này chỉ dành cho Glass Pulse Plus."
        case .modePlusRequired:
            "Mode này chỉ dành cho Glass Pulse Plus."
        }
    }
}

@MainActor
@Observable
final class PlayerProfile {
    private enum Key {
        static let bestScore = "glassPulse.bestScore"
        static let legacyDailyStreak = "glassPulse.dailyStreak"
        static let legacyLastPlayedDate = "glassPulse.lastPlayedDate"
        static let dailyCompletionMigration = "glassPulse.dailyCompletionMigration.v1"
        static let dailyCompletionStreak = "glassPulse.dailyCompletionStreak"
        static let lastDailyCompletionKey = "glassPulse.lastDailyCompletionKey"
        static let dailyBestKey = "glassPulse.dailyBestKey"
        static let dailyBestScore = "glassPulse.dailyBestScore"
        static let dailyRewardKey = "glassPulse.dailyRewardKey"
        static let totalShards = "glassPulse.totalShards"
        static let selectedTheme = "glassPulse.selectedTheme"
        static let ownedThemes = "glassPulse.ownedThemes"
        static let selectedMode = "glassPulse.selectedMode"
    }

    @ObservationIgnored private let defaults: UserDefaults

    private(set) var bestScore: Int {
        didSet { defaults.set(bestScore, forKey: Key.bestScore) }
    }

    private(set) var dailyStreak: Int {
        didSet { defaults.set(dailyStreak, forKey: Key.dailyCompletionStreak) }
    }

    private(set) var lastDailyCompletionKey: String? {
        didSet { defaults.set(lastDailyCompletionKey, forKey: Key.lastDailyCompletionKey) }
    }

    private(set) var dailyBestKey: String? {
        didSet { defaults.set(dailyBestKey, forKey: Key.dailyBestKey) }
    }

    private(set) var dailyBestScore: Int {
        didSet { defaults.set(dailyBestScore, forKey: Key.dailyBestScore) }
    }

    private(set) var dailyRewardKey: String? {
        didSet { defaults.set(dailyRewardKey, forKey: Key.dailyRewardKey) }
    }

    private(set) var totalShards: Int {
        didSet { defaults.set(totalShards, forKey: Key.totalShards) }
    }

    private(set) var selectedThemeID: String {
        didSet { defaults.set(selectedThemeID, forKey: Key.selectedTheme) }
    }

    private(set) var ownedThemeIDs: Set<String> {
        didSet { defaults.set(ownedThemeIDs.sorted(), forKey: Key.ownedThemes) }
    }

    private(set) var selectedModeID: GameModeID {
        didSet { defaults.set(selectedModeID.rawValue, forKey: Key.selectedMode) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        bestScore = defaults.integer(forKey: Key.bestScore)
        totalShards = defaults.integer(forKey: Key.totalShards)
        selectedThemeID = defaults.string(forKey: Key.selectedTheme) ?? PulseTheme.clarity.id
        let storedThemes = Set(defaults.stringArray(forKey: Key.ownedThemes) ?? [])
        ownedThemeIDs = storedThemes.union([PulseTheme.clarity.id])
        selectedModeID = defaults.string(forKey: Key.selectedMode)
            .flatMap(GameModeID.init(rawValue:)) ?? .classic

        if defaults.bool(forKey: Key.dailyCompletionMigration) {
            dailyStreak = defaults.integer(forKey: Key.dailyCompletionStreak)
            lastDailyCompletionKey = defaults.string(forKey: Key.lastDailyCompletionKey)
            dailyBestKey = defaults.string(forKey: Key.dailyBestKey)
            dailyBestScore = defaults.integer(forKey: Key.dailyBestScore)
            dailyRewardKey = defaults.string(forKey: Key.dailyRewardKey)
        } else {
            dailyStreak = 0
            lastDailyCompletionKey = nil
            dailyBestKey = nil
            dailyBestScore = 0
            dailyRewardKey = nil
            defaults.set(true, forKey: Key.dailyCompletionMigration)
            defaults.removeObject(forKey: Key.legacyDailyStreak)
            defaults.removeObject(forKey: Key.legacyLastPlayedDate)
        }
    }

    func activeTheme(access: FeatureAccess) -> PulseTheme {
        guard let selected = PulseTheme(rawValue: selectedThemeID) else {
            return .clarity
        }
        guard canUse(selected, access: access) else { return .clarity }
        return selected
    }

    func activeMode(access: FeatureAccess) -> GameModeID {
        access.canUse(selectedModeID) ? selectedModeID : .classic
    }

    func canUse(_ theme: PulseTheme, access: FeatureAccess) -> Bool {
        guard !access.isBetaFullAccess else { return true }
        switch theme.unlock {
        case .free:
            return true
        case .shards:
            return ownedThemeIDs.contains(theme.id)
        case .plus:
            return access.hasPlus
        }
    }

    func select(
        _ theme: PulseTheme,
        access: FeatureAccess
    ) -> Result<Void, PlayerProfileError> {
        guard !access.isBetaFullAccess else {
            selectedThemeID = theme.id
            return .success(())
        }
        switch theme.unlock {
        case .free:
            selectedThemeID = theme.id
            return .success(())
        case .plus:
            guard access.hasPlus else { return .failure(.plusRequired) }
            selectedThemeID = theme.id
            return .success(())
        case .shards(let price):
            return purchaseAndSelect(theme, price: price)
        }
    }

    func select(
        mode modeID: GameModeID,
        access: FeatureAccess
    ) -> Result<Void, PlayerProfileError> {
        guard access.canUse(modeID) else { return .failure(.modePlusRequired) }
        selectedModeID = modeID
        return .success(())
    }

    func recordRun(score: Int, reward: Int) {
        bestScore = max(bestScore, score)
        totalShards += max(0, reward)
    }

    func dailyBest(for dayKey: String?) -> Int {
        guard let dayKey, dailyBestKey == dayKey else { return 0 }
        return dailyBestScore
    }

    @discardableResult
    func recordDailyCompletion(
        dayKey: String,
        date: Date,
        score: Int,
        firstClearBonus: Int,
        calendar: Calendar
    ) -> Int {
        refreshDailyBest(dayKey: dayKey, score: score)
        advanceDailyStreak(dayKey: dayKey, date: date, calendar: calendar)
        guard dailyRewardKey != dayKey else { return 0 }
        dailyRewardKey = dayKey
        let bonus = max(0, firstClearBonus)
        totalShards += bonus
        return bonus
    }

    private func refreshDailyBest(dayKey: String, score: Int) {
        if dailyBestKey != dayKey {
            dailyBestKey = dayKey
            dailyBestScore = max(0, score)
            return
        }
        dailyBestScore = max(dailyBestScore, score)
    }

    private func advanceDailyStreak(
        dayKey: String,
        date: Date,
        calendar: Calendar
    ) {
        guard lastDailyCompletionKey != dayKey else { return }
        let yesterday = calendar.date(byAdding: .day, value: -1, to: date)
            .map { DailyChallenge.key(for: $0, calendar: calendar) }
        dailyStreak = lastDailyCompletionKey == yesterday ? max(1, dailyStreak + 1) : 1
        lastDailyCompletionKey = dayKey
    }

    private func purchaseAndSelect(
        _ theme: PulseTheme,
        price: Int
    ) -> Result<Void, PlayerProfileError> {
        if ownedThemeIDs.contains(theme.id) {
            selectedThemeID = theme.id
            return .success(())
        }
        guard totalShards >= price else {
            return .failure(.insufficientShards(required: price, available: totalShards))
        }
        totalShards -= price
        ownedThemeIDs.insert(theme.id)
        selectedThemeID = theme.id
        return .success(())
    }
}
