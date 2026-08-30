import XCTest

final class GlassPulseLaunchTests: XCTestCase {
    func testGameBoardAppearsAfterSplashDismisses() {
        let app = XCUIApplication()
        app.launch()

        let board = element(in: app, identifier: "game.board")
        let splash = element(in: app, identifier: "launch.splash")
        XCTAssertTrue(board.waitForExistence(timeout: 5))
        XCTAssertTrue(splash.waitForNonExistence(timeout: 5))
    }

    func testPauseHasSingleResumeActionAndBoardStaysPaused() {
        let app = XCUIApplication()
        app.launch()

        let board = element(in: app, identifier: "game.board")
        let splash = element(in: app, identifier: "launch.splash")
        XCTAssertTrue(board.waitForExistence(timeout: 5))
        XCTAssertTrue(splash.waitForNonExistence(timeout: 5))
        board.tap()

        let pauseButton = app.buttons["game.pause"]
        XCTAssertTrue(pauseButton.waitForExistence(timeout: 2))
        pauseButton.tap()

        let resumeButton = app.buttons["game.resume"]
        XCTAssertTrue(resumeButton.waitForExistence(timeout: 2))
        XCTAssertFalse(pauseButton.exists)
        board.tap()
        XCTAssertTrue(resumeButton.exists)

        resumeButton.tap()
        XCTAssertTrue(resumeButton.waitForNonExistence(timeout: 2))
        XCTAssertTrue(pauseButton.waitForExistence(timeout: 2))
    }

    func testThemeSheetShowsReadableSelectedStateAndCloseTarget() {
        let app = XCUIApplication()
        app.launchArguments += [
            "-UIPreferredContentSizeCategoryName",
            "UICTContentSizeCategoryAccessibilityXXLarge"
        ]
        app.launch()

        let splash = element(in: app, identifier: "launch.splash")
        XCTAssertTrue(splash.waitForNonExistence(timeout: 5))
        let board = element(in: app, identifier: "game.board")
        XCTAssertTrue(board.waitForExistence(timeout: 2))
        XCTAssertEqual(board.frame.width, board.frame.height, accuracy: 1)
        let windowFrame = app.windows.firstMatch.frame
        XCTAssertGreaterThanOrEqual(board.frame.minX, windowFrame.minX)
        XCTAssertGreaterThanOrEqual(board.frame.minY, windowFrame.minY)
        XCTAssertLessThanOrEqual(board.frame.maxX, windowFrame.maxX)
        XCTAssertLessThanOrEqual(board.frame.maxY, windowFrame.maxY)

        let themesButton = app.buttons["game.themes"]
        XCTAssertTrue(themesButton.waitForExistence(timeout: 2))
        themesButton.tap()

        let selected = element(in: app, identifier: "theme.selected")
        let close = app.buttons["theme.close"]
        XCTAssertTrue(selected.waitForExistence(timeout: 2))
        XCTAssertTrue(close.waitForExistence(timeout: 2))
        XCTAssertTrue(close.isHittable)
    }

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
            XCTAssertTrue(splash.waitForNonExistence(timeout: 5), modeID)
            let modesButton = app.buttons["game.modes"]
            XCTAssertTrue(modesButton.waitForExistence(timeout: 2), modeID)
            modesButton.tap()

            let modeButton = element(in: app, identifier: "mode.\(modeID)")
            XCTAssertTrue(modeButton.waitForExistence(timeout: 2), modeID)
            modeButton.tap()

            let board = element(in: app, identifier: "game.board")
            XCTAssertTrue(board.waitForExistence(timeout: 2), modeID)
            board.tap()
            XCTAssertTrue(app.buttons["game.pause"].waitForExistence(timeout: 2), modeID)
            app.terminate()
        }
    }

    private func element(in app: XCUIApplication, identifier: String) -> XCUIElement {
        app.descendants(matching: .any)
            .matching(identifier: identifier)
            .firstMatch
    }
}
