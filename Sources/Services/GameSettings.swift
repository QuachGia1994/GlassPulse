import Foundation
import Observation
import UIKit

enum AppLanguage: String, CaseIterable, Identifiable, Sendable {
    case system
    case english = "en"
    case vietnamese = "vi"
    case japanese = "ja"
    case simplifiedChinese = "zh-Hans"

    var id: String { rawValue }

    var locale: Locale? {
        switch self {
        case .system: nil
        case .english, .vietnamese, .japanese, .simplifiedChinese:
            Locale(identifier: rawValue)
        }
    }
}

/// Cross-platform settings source of truth. Persisted through UserDefaults and
/// observed by the sensory, music and presentation layers.
@MainActor
@Observable
final class GameSettings {
    private enum Key {
        static let musicEnabled = "glassPulse.settings.musicEnabled"
        static let soundEnabled = "glassPulse.settings.soundEnabled"
        static let hapticsEnabled = "glassPulse.settings.hapticsEnabled"
        static let reduceMotionEnabled = "glassPulse.settings.reduceMotionEnabled"
        static let reduceMotionInitialized = "glassPulse.settings.reduceMotionInitialized"
        static let highContrastEnabled = "glassPulse.settings.highContrastEnabled"
        static let language = "glassPulse.settings.language"
    }

    private let defaults: UserDefaults

    private(set) var musicEnabled: Bool
    private(set) var soundEnabled: Bool
    private(set) var hapticsEnabled: Bool
    private(set) var reduceMotionEnabled: Bool
    private(set) var highContrastEnabled: Bool
    private(set) var language: AppLanguage

    private(set) var lastStorageError: String?

    init(
        defaults: UserDefaults = .standard,
        systemReduceMotion: Bool? = nil
    ) {
        self.defaults = defaults
        let stored = { key in defaults.object(forKey: key) as? Bool }
        musicEnabled = stored(Key.musicEnabled) ?? true
        soundEnabled = stored(Key.soundEnabled) ?? true
        hapticsEnabled = stored(Key.hapticsEnabled) ?? true
        highContrastEnabled = stored(Key.highContrastEnabled) ?? false
        language = defaults.string(forKey: Key.language)
            .flatMap(AppLanguage.init(rawValue:)) ?? .system

        let seeded = defaults.bool(forKey: Key.reduceMotionInitialized)
        if seeded {
            reduceMotionEnabled = stored(Key.reduceMotionEnabled) ?? false
        } else {
            let systemValue = systemReduceMotion ?? UIAccessibility.isReduceMotionEnabled
            reduceMotionEnabled = systemValue
            defaults.set(true, forKey: Key.reduceMotionInitialized)
            defaults.set(systemValue, forKey: Key.reduceMotionEnabled)
        }
    }

    func setMusicEnabled(_ enabled: Bool) {
        musicEnabled = enabled
        persist(enabled, forKey: Key.musicEnabled)
    }

    func setSoundEnabled(_ enabled: Bool) {
        soundEnabled = enabled
        persist(enabled, forKey: Key.soundEnabled)
    }

    func setHapticsEnabled(_ enabled: Bool) {
        hapticsEnabled = enabled
        persist(enabled, forKey: Key.hapticsEnabled)
    }

    func setReduceMotionEnabled(_ enabled: Bool) {
        reduceMotionEnabled = enabled
        persist(enabled, forKey: Key.reduceMotionEnabled)
    }

    func setHighContrastEnabled(_ enabled: Bool) {
        highContrastEnabled = enabled
        persist(enabled, forKey: Key.highContrastEnabled)
    }

    func setLanguage(_ newLanguage: AppLanguage) {
        language = newLanguage
        persist(newLanguage.rawValue, forKey: Key.language)
    }

    var resolvedLocale: Locale? {
        language.locale
    }

    private func persist(_ value: Bool, forKey key: String) {
        defaults.set(value, forKey: key)
        verifyStoredBool(value, forKey: key)
    }

    private func persist(_ value: String, forKey key: String) {
        defaults.set(value, forKey: key)
        verifyStoredString(value, forKey: key)
    }

    private func verifyStoredBool(_ expected: Bool, forKey key: String) {
        guard defaults.object(forKey: key) != nil else {
            lastStorageError = "Failed to persist \(key)"
            return
        }
        lastStorageError = nil
    }

    private func verifyStoredString(_ expected: String, forKey key: String) {
        guard defaults.string(forKey: key) == expected else {
            lastStorageError = "Failed to persist \(key)"
            return
        }
        lastStorageError = nil
    }
}
