import Foundation
import Observation

enum PlayerProfileError: Error, Equatable, LocalizedError {
    case insufficientShards(required: Int, available: Int)
    case plusRequired

    var errorDescription: String? {
        switch self {
        case .insufficientShards(let required, let available):
            "Cần \(required) shard, hiện có \(available)."
        case .plusRequired:
            "Theme này chỉ dành cho Glass Pulse Plus."
        }
    }
}

@MainActor
@Observable
final class PlayerProfile {
    private enum Key {
        static let bestScore = "glassPulse.bestScore"
        static let dailyStreak = "glassPulse.dailyStreak"
        static let lastPlayedDate = "glassPulse.lastPlayedDate"
        static let totalShards = "glassPulse.totalShards"
        static let selectedTheme = "glassPulse.selectedTheme"
        static let ownedThemes = "glassPulse.ownedThemes"
    }

    @ObservationIgnored private let defaults: UserDefaults

    private(set) var bestScore: Int {
        didSet { defaults.set(bestScore, forKey: Key.bestScore) }
    }

    private(set) var dailyStreak: Int {
        didSet { defaults.set(dailyStreak, forKey: Key.dailyStreak) }
    }

    private(set) var lastPlayedDate: Date? {
        didSet { defaults.set(lastPlayedDate, forKey: Key.lastPlayedDate) }
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

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        bestScore = defaults.integer(forKey: Key.bestScore)
        dailyStreak = defaults.integer(forKey: Key.dailyStreak)
        lastPlayedDate = defaults.object(forKey: Key.lastPlayedDate) as? Date
        totalShards = defaults.integer(forKey: Key.totalShards)
        selectedThemeID = defaults.string(forKey: Key.selectedTheme) ?? PulseTheme.clarity.id
        let storedThemes = Set(defaults.stringArray(forKey: Key.ownedThemes) ?? [])
        ownedThemeIDs = storedThemes.union([PulseTheme.clarity.id])
    }

    func activeTheme(access: FeatureAccess) -> PulseTheme {
        guard let selected = PulseTheme(rawValue: selectedThemeID) else {
            return .clarity
        }
        guard canUse(selected, access: access) else { return .clarity }
        return selected
    }

    func canUse(_ theme: PulseTheme, access: FeatureAccess) -> Bool {
        guard !access.isBetaFullAccess else { return true }
        switch theme.unlock {
        case .free:
            true
        case .shards:
            ownedThemeIDs.contains(theme.id)
        case .plus:
            access.hasPlus
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

    func registerDailyPlay(now: Date = .now, calendar: Calendar = .current) {
        let today = calendar.startOfDay(for: now)
        guard let lastPlayedDate else {
            dailyStreak = 1
            self.lastPlayedDate = today
            return
        }

        let previousDay = calendar.startOfDay(for: lastPlayedDate)
        guard previousDay != today else { return }
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)
        dailyStreak = previousDay == yesterday ? max(1, dailyStreak + 1) : 1
        self.lastPlayedDate = today
    }

    func recordRun(score: Int, reward: Int) {
        bestScore = max(bestScore, score)
        totalShards += max(0, reward)
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
