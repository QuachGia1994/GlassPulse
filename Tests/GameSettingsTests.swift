import XCTest
@testable import GlassPulse

@MainActor
final class GameSettingsTests: XCTestCase {
    private func makeDefaults() throws -> UserDefaults {
        let suiteName = "glassPulse.settings.tests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        addTeardownBlock { defaults.removePersistentDomain(forName: suiteName) }
        return defaults
    }

    func testFreshInstallDefaultsMatchCrossPlatformContract() throws {
        let defaults = try makeDefaults()
        let settings = GameSettings(defaults: defaults, systemReduceMotion: false)

        XCTAssertTrue(settings.musicEnabled)
        XCTAssertTrue(settings.soundEnabled)
        XCTAssertTrue(settings.hapticsEnabled)
        XCTAssertFalse(settings.highContrastEnabled)
        XCTAssertEqual(settings.language, .system)
        XCTAssertFalse(settings.reduceMotionEnabled)
        XCTAssertNil(settings.resolvedLocale)
        XCTAssertNil(settings.lastStorageError)
    }

    func testReduceMotionSeedsFromSystemOnFirstLaunchOnly() throws {
        let defaults = try makeDefaults()
        let first = GameSettings(defaults: defaults, systemReduceMotion: true)
        XCTAssertTrue(first.reduceMotionEnabled)

        let second = GameSettings(defaults: defaults, systemReduceMotion: false)
        XCTAssertTrue(second.reduceMotionEnabled)
    }

    func testSettingsPersistAcrossInstances() throws {
        let defaults = try makeDefaults()
        let settings = GameSettings(defaults: defaults, systemReduceMotion: false)
        settings.setMusicEnabled(false)
        settings.setSoundEnabled(false)
        settings.setHapticsEnabled(false)
        settings.setReduceMotionEnabled(true)
        settings.setHighContrastEnabled(true)
        settings.setLanguage(.vietnamese)

        let reloaded = GameSettings(defaults: defaults, systemReduceMotion: false)
        XCTAssertFalse(reloaded.musicEnabled)
        XCTAssertFalse(reloaded.soundEnabled)
        XCTAssertFalse(reloaded.hapticsEnabled)
        XCTAssertTrue(reloaded.reduceMotionEnabled)
        XCTAssertTrue(reloaded.highContrastEnabled)
        XCTAssertEqual(reloaded.language, .vietnamese)
        XCTAssertNil(reloaded.lastStorageError)
    }

    func testLocaleMappingCoversAllSupportedLanguages() {
        XCTAssertEqual(AppLanguage.english.locale, Locale(identifier: "en"))
        XCTAssertEqual(AppLanguage.vietnamese.locale, Locale(identifier: "vi"))
        XCTAssertEqual(AppLanguage.japanese.locale, Locale(identifier: "ja"))
        XCTAssertEqual(AppLanguage.simplifiedChinese.locale, Locale(identifier: "zh-Hans"))
        XCTAssertNil(AppLanguage.system.locale)
    }

    func testSensoryEngineMirrorsSettingsWithoutDuplicatingState() throws {
        let defaults = try makeDefaults()
        let settings = GameSettings(defaults: defaults, systemReduceMotion: false)
        let sensory = SensoryEngine(settings: settings)

        XCTAssertTrue(sensory.soundEnabled)
        XCTAssertTrue(sensory.hapticsEnabled)

        settings.setSoundEnabled(false)
        settings.setHapticsEnabled(false)

        XCTAssertFalse(sensory.soundEnabled)
        XCTAssertFalse(sensory.hapticsEnabled)
    }

    func testEveryNewSettingsKeyIsPresentInAllFourLocales() throws {
        let required: Set<String> = [
            "settings.title", "settings.section.audio", "settings.section.feedback",
            "settings.section.display", "settings.section.language", "settings.section.credit",
            "settings.music.label", "settings.music.hint", "settings.sfx.label", "settings.sfx.hint",
            "settings.haptics.label", "settings.haptics.hint", "settings.reduceMotion.label",
            "settings.reduceMotion.hint", "settings.highContrast.label", "settings.highContrast.hint",
            "settings.language.label", "settings.language.hint", "settings.language.system",
            "settings.language.en", "settings.language.vi", "settings.language.ja",
            "settings.language.zhHans", "settings.music.credit", "settings.open.label",
            "settings.close.label"
        ]
        for locale in ["en", "vi", "ja", "zh-Hans"] {
            let bundle = try localizationBundle(for: locale)
            for key in required {
                let value = bundle.localizedString(
                    forKey: key,
                    value: "__MISSING__",
                    table: nil
                )
                XCTAssertNotEqual(value, "__MISSING__", "key \(key) missing locale \(locale)")
            }
        }
    }

    private func localizationBundle(for locale: String) throws -> Bundle {
        let path = try XCTUnwrap(
            Bundle.main.path(forResource: locale, ofType: "lproj"),
            "compiled locale \(locale) must ship with the app"
        )
        return try XCTUnwrap(Bundle(path: path))
    }
}
