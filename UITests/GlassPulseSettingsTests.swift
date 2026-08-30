import CoreGraphics
import Foundation
import XCTest

final class GlassPulseSettingsTests: XCTestCase {
    @MainActor
    func testSettingsSheetOpensAndClosesWithoutGameplayLeakage() {
        let app = XCUIApplication()
        app.launchArguments = ["-glassPulse.selectedMode", "classic"]
        app.launch()

        let board = element(in: app, identifier: "game.board")
        let inputSurface = element(in: app, identifier: "game.input.surface")
        assertExists(board, timeout: 5)
        assertExists(inputSurface, timeout: 5)
        assertDoesNotExist(element(in: app, identifier: "launch.splash"), timeout: 5)

        let directionBefore = inputSurface.value as? String
        let gear = app.buttons["settings.open"]
        assertExists(gear, timeout: 2)
        gear.tap()

        let sheet = element(in: app, identifier: "settings.sheet")
        assertExists(sheet, timeout: 3)
        let directionWhileSheetOpen = inputSurface.value as? String
        XCTAssertEqual(directionWhileSheetOpen, directionBefore)

        let close = app.buttons["settings.close"]
        assertExists(close, timeout: 2)
        close.tap()
        assertDoesNotExist(sheet, timeout: 3)

        let directionAfterClose = inputSurface.value as? String
        XCTAssertEqual(directionAfterClose, directionBefore)
        XCTAssertFalse(app.buttons["game.pause"].exists)
    }

    @MainActor
    func testSettingsTogglesExposeStableAccessibilityValues() {
        let app = XCUIApplication()
        app.launch()
        assertDoesNotExist(element(in: app, identifier: "launch.splash"), timeout: 5)

        openSettings(app)

        let music = app.switches["settings.music"]
        assertExists(music, timeout: 2)
        let musicBefore = music.value as? String
        music.tap()
        let musicAfter = music.value as? String
        XCTAssertNotEqual(musicAfter, musicBefore)

        let sfx = app.switches["settings.sfx"]
        assertExists(sfx, timeout: 2)
        let sfxBefore = sfx.value as? String
        sfx.tap()
        let sfxAfter = sfx.value as? String
        XCTAssertNotEqual(sfxAfter, sfxBefore)

        let haptics = app.switches["settings.haptics"]
        assertExists(haptics, timeout: 2)
        let hapticsBefore = haptics.value as? String
        haptics.tap()
        let hapticsAfter = haptics.value as? String
        XCTAssertNotEqual(hapticsAfter, hapticsBefore)

        let reduceMotion = app.switches["settings.reduceMotion"]
        assertExists(reduceMotion, timeout: 2)
        let reduceMotionBefore = reduceMotion.value as? String
        reduceMotion.tap()
        let reduceMotionAfter = reduceMotion.value as? String
        XCTAssertNotEqual(reduceMotionAfter, reduceMotionBefore)

        let highContrast = app.switches["settings.highContrast"]
        assertExists(highContrast, timeout: 2)
        let highContrastBefore = highContrast.value as? String
        highContrast.tap()
        let highContrastAfter = highContrast.value as? String
        XCTAssertNotEqual(highContrastAfter, highContrastBefore)
    }

    @MainActor
    func testLanguageSwitchChangesRepresentativeTitleAndReturnsToSystem() {
        let app = XCUIApplication()
        app.launch()
        assertDoesNotExist(element(in: app, identifier: "launch.splash"), timeout: 5)

        openSettings(app)

        let languagePicker = app.buttons["settings.language"]
        assertExists(languagePicker, timeout: 2)
        languagePicker.tap()

        let japanese = app.buttons["日本語"]
        assertExists(japanese, timeout: 2)
        japanese.tap()

        let japaneseTitle = app.navigationBars.staticTexts["設定"]
        assertExists(japaneseTitle, timeout: 3)

        languagePicker.tap()
        let system = app.buttons["システムに従う"]
        assertExists(system, timeout: 2)
        system.tap()

        let englishTitle = app.navigationBars.staticTexts["Settings"]
        assertExists(englishTitle, timeout: 3)
    }

    @MainActor
    private func openSettings(_ app: XCUIApplication) {
        let gear = app.buttons["settings.open"]
        assertExists(gear, timeout: 2)
        gear.tap()
        assertExists(element(in: app, identifier: "settings.sheet"), timeout: 3)
    }

    @MainActor
    private func element(in app: XCUIApplication, identifier: String) -> XCUIElement {
        app.descendants(matching: .any)
            .matching(identifier: identifier)
            .firstMatch
    }

    @MainActor
    private func assertExists(
        _ element: XCUIElement,
        timeout: TimeInterval,
        message: String = "",
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let exists = element.waitForExistence(timeout: timeout)
        XCTAssertTrue(exists, message, file: file, line: line)
    }

    @MainActor
    private func assertDoesNotExist(
        _ element: XCUIElement,
        timeout: TimeInterval,
        message: String = "",
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let disappeared = element.waitForNonExistence(timeout: timeout)
        XCTAssertTrue(disappeared, message, file: file, line: line)
    }
}
