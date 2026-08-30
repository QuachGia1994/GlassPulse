import CoreGraphics
import Foundation
import XCTest

final class GlassPulseLaunchTests: XCTestCase {
    @MainActor
    func testGameBoardAppearsAfterSplashDismisses() {
        let app = XCUIApplication()
        app.launch()

        let board = element(in: app, identifier: "game.board")
        let splash = element(in: app, identifier: "launch.splash")
        assertExists(board, timeout: 5)
        assertDoesNotExist(splash, timeout: 5)
    }

    @MainActor
    func testPauseHasSingleResumeActionAndBoardStaysPaused() {
        let app = XCUIApplication()
        app.launch()

        let board = element(in: app, identifier: "game.board")
        let splash = element(in: app, identifier: "launch.splash")
        assertExists(board, timeout: 5)
        assertDoesNotExist(splash, timeout: 5)
        board.tap()

        let pauseButton = app.buttons["game.pause"]
        assertExists(pauseButton, timeout: 2)
        pauseButton.tap()

        let resumeButton = app.buttons["game.resume"]
        assertExists(resumeButton, timeout: 2)
        let pauseExistsWhilePaused = pauseButton.exists
        XCTAssertFalse(pauseExistsWhilePaused)

        let safeBoardPoint = board.coordinate(
            withNormalizedOffset: CGVector(dx: 0.15, dy: 0.85)
        )
        safeBoardPoint.tap()
        let resumeStillExists = resumeButton.exists
        XCTAssertTrue(resumeStillExists)

        resumeButton.tap()
        assertDoesNotExist(resumeButton, timeout: 2)
    }

    @MainActor
    func testThemeSheetShowsReadableSelectedStateAndCloseTarget() {
        let app = XCUIApplication()
        app.launchArguments += [
            "-glassPulse.selectedTheme",
            "clarity",
            "-UIPreferredContentSizeCategoryName",
            "UICTContentSizeCategoryAccessibilityXXLarge"
        ]
        app.launch()

        let splash = element(in: app, identifier: "launch.splash")
        assertDoesNotExist(splash, timeout: 5)
        let board = element(in: app, identifier: "game.board")
        assertExists(board, timeout: 2)

        let boardFrame = board.frame
        let windowFrame = app.windows.firstMatch.frame
        XCTAssertEqual(boardFrame.width, boardFrame.height, accuracy: 1)
        XCTAssertGreaterThanOrEqual(boardFrame.minX, windowFrame.minX)
        XCTAssertGreaterThanOrEqual(boardFrame.minY, windowFrame.minY)
        XCTAssertLessThanOrEqual(boardFrame.maxX, windowFrame.maxX)
        XCTAssertLessThanOrEqual(boardFrame.maxY, windowFrame.maxY)

        let themesButton = app.buttons["game.themes"]
        assertExists(themesButton, timeout: 2)
        themesButton.tap()

        let selected = element(in: app, identifier: "theme.selected")
        let selectedCard = element(in: app, identifier: "theme.card.clarity")
        let close = app.buttons["theme.close"]
        assertExists(selectedCard, timeout: 2)
        assertExists(selected, timeout: 2)
        assertExists(close, timeout: 2)
        let closeIsHittable = close.isHittable
        XCTAssertTrue(closeIsHittable)
    }

    @MainActor
    func testEveryModeCanBeSelectedAndStartedWithTestEntitlement() {
        let modeIDs = [
            "classic",
            "rush60",
            "precisionPulse",
            "waveSurvival",
            "dailyChallenge"
        ]

        for modeID in modeIDs {
            let app = XCUIApplication()
            app.launchArguments = ["--ui-testing-plus"]
            app.launch()

            let splash = element(in: app, identifier: "launch.splash")
            assertDoesNotExist(splash, timeout: 5, message: modeID)
            let modesButton = app.buttons["game.modes"]
            assertExists(modesButton, timeout: 2, message: modeID)
            modesButton.tap()

            let modeButton = element(in: app, identifier: "mode.\(modeID)")
            assertExists(modeButton, timeout: 2, message: modeID)
            modeButton.tap()

            let board = element(in: app, identifier: "game.board")
            assertExists(board, timeout: 2, message: modeID)
            board.tap()
            let pauseButton = app.buttons["game.pause"]
            assertExists(pauseButton, timeout: 2, message: modeID)
            app.terminate()
        }
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
