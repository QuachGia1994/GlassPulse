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
    func testFullWindowInputStartsOutsideBoardAndReversesExactlyOnce() {
        let app = XCUIApplication()
        app.launchArguments = ["-glassPulse.selectedMode", "classic"]
        app.launch()

        let splash = element(in: app, identifier: "launch.splash")
        let board = element(in: app, identifier: "game.board")
        let inputSurface = element(in: app, identifier: "game.input.surface")
        assertDoesNotExist(splash, timeout: 5)
        assertExists(board, timeout: 2)
        assertExists(inputSurface, timeout: 2)

        let inputFrame = inputSurface.frame
        let windowFrame = app.windows.firstMatch.frame
        XCTAssertLessThanOrEqual(inputFrame.minX, windowFrame.minX + 1)
        XCTAssertLessThanOrEqual(inputFrame.minY, windowFrame.minY + 1)
        XCTAssertGreaterThanOrEqual(inputFrame.maxX, windowFrame.maxX - 1)
        XCTAssertGreaterThanOrEqual(inputFrame.maxY, windowFrame.maxY - 1)

        let outsidePoint = outsideBoardCoordinate(surface: inputSurface, board: board)
        let initialDirection = inputSurface.value as? String
        outsidePoint.tap()
        let pauseButton = app.buttons["game.pause"]
        assertExists(pauseButton, timeout: 2)
        let startedDirection = inputSurface.value as? String
        XCTAssertEqual(startedDirection, initialDirection)

        outsidePoint.tap()
        waitForValueChange(inputSurface, from: startedDirection)
        let reversedDirection = inputSurface.value as? String
        XCTAssertNotEqual(reversedDirection, startedDirection)
    }

    @MainActor
    func testPauseHasSingleResumeActionAndBoardStaysPaused() {
        let app = XCUIApplication()
        app.launchArguments = ["-glassPulse.selectedMode", "classic"]
        app.launch()

        let board = element(in: app, identifier: "game.board")
        let inputSurface = element(in: app, identifier: "game.input.surface")
        let splash = element(in: app, identifier: "launch.splash")
        assertExists(board, timeout: 5)
        assertExists(inputSurface, timeout: 5)
        assertDoesNotExist(splash, timeout: 5)
        inputSurface.tap()

        let pauseButton = app.buttons["game.pause"]
        assertExists(pauseButton, timeout: 2)
        let directionBeforePause = inputSurface.value as? String
        pauseButton.tap()
        let directionAfterPause = inputSurface.value as? String
        XCTAssertEqual(directionAfterPause, directionBeforePause)

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
        let directionWhilePaused = inputSurface.value as? String
        XCTAssertEqual(directionWhilePaused, directionBeforePause)

        resumeButton.tap()
        assertDoesNotExist(resumeButton, timeout: 2)
        let directionAfterResume = inputSurface.value as? String
        XCTAssertEqual(directionAfterResume, directionBeforePause)

        let themesButton = app.buttons["game.themes"]
        assertExists(themesButton, timeout: 2)
        themesButton.tap()
        let themeClose = app.buttons["theme.close"]
        assertExists(themeClose, timeout: 2)
        let directionAfterFooterTap = inputSurface.value as? String
        XCTAssertEqual(directionAfterFooterTap, directionBeforePause)
        themeClose.tap()
    }

    @MainActor
    func testGameOverBackgroundIsInertAndRetryStartsFreshRunAtAccessibilityXXL() {
        let app = XCUIApplication()
        app.launchArguments = [
            "--ui-testing-game-over",
            "-glassPulse.totalShards",
            "0",
            "-UIPreferredContentSizeCategoryName",
            "UICTContentSizeCategoryAccessibilityXXLarge"
        ]
        app.launch()

        let splash = element(in: app, identifier: "launch.splash")
        assertDoesNotExist(splash, timeout: 5)
        let inputSurface = element(in: app, identifier: "game.input.surface")
        let board = element(in: app, identifier: "game.board")
        let retry = app.buttons["game.retry"]
        let chooseMode = app.buttons["game.chooseMode"]
        let shards = element(in: app, identifier: "game.metric.shards")
        assertExists(inputSurface, timeout: 2)
        assertExists(board, timeout: 2)
        assertExists(retry, timeout: 2)
        assertExists(chooseMode, timeout: 2)
        assertExists(shards, timeout: 2)
        let initialShardValue = shards.value as? String
        XCTAssertEqual(initialShardValue, "1")
        let retryCount = app.buttons.matching(identifier: "game.retry").count
        let chooseModeCount = app.buttons.matching(identifier: "game.chooseMode").count
        let retryIsHittable = retry.isHittable
        let chooseModeIsHittable = chooseMode.isHittable
        XCTAssertEqual(retryCount, 1)
        XCTAssertEqual(chooseModeCount, 1)
        XCTAssertTrue(retryIsHittable)
        XCTAssertTrue(chooseModeIsHittable)

        outsideBoardCoordinate(surface: inputSurface, board: board).tap()
        let retryStillExists = retry.exists
        let pauseExistsAfterBackgroundTap = app.buttons["game.pause"].exists
        let shardsAfterBackgroundTap = shards.value as? String
        XCTAssertTrue(retryStillExists)
        XCTAssertFalse(pauseExistsAfterBackgroundTap)
        XCTAssertEqual(shardsAfterBackgroundTap, "1")

        retry.tap()
        assertDoesNotExist(retry, timeout: 2)
        let pause = app.buttons["game.pause"]
        assertExists(pause, timeout: 2)
        let shardsAfterRetry = shards.value as? String
        XCTAssertEqual(shardsAfterRetry, "1")
        let currentMode = element(in: app, identifier: "game.mode.current")
        let currentModeLabel = currentMode.label
        XCTAssertEqual(currentModeLabel, "Classic")
    }

    @MainActor
    func testGameOverChooseModeHandlesSameModeAsFreshStart() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing-game-over"]
        app.launch()

        let splash = element(in: app, identifier: "launch.splash")
        assertDoesNotExist(splash, timeout: 5)
        let chooseMode = app.buttons["game.chooseMode"]
        assertExists(chooseMode, timeout: 2)
        chooseMode.tap()

        let modeClose = app.buttons["mode.close"]
        assertExists(modeClose, timeout: 2)
        modeClose.tap()
        let retryAfterClosingPicker = app.buttons["game.retry"]
        assertExists(retryAfterClosingPicker, timeout: 2)

        chooseMode.tap()
        let classic = element(in: app, identifier: "mode.classic")
        assertExists(classic, timeout: 2)
        classic.tap()

        let retry = app.buttons["game.retry"]
        assertDoesNotExist(retry, timeout: 2)
        let pause = app.buttons["game.pause"]
        let pauseBeforeStart = pause.exists
        XCTAssertFalse(pauseBeforeStart)
        let currentMode = element(in: app, identifier: "game.mode.current")
        let currentModeLabel = currentMode.label
        XCTAssertEqual(currentModeLabel, "Classic")

        let inputSurface = element(in: app, identifier: "game.input.surface")
        assertExists(inputSurface, timeout: 2)
        inputSurface.tap()
        assertExists(pause, timeout: 5)
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
            let inputSurface = element(in: app, identifier: "game.input.surface")
            assertExists(board, timeout: 2, message: modeID)
            assertExists(inputSurface, timeout: 2, message: modeID)
            inputSurface.tap()
            let pauseButton = app.buttons["game.pause"]
            assertExists(pauseButton, timeout: 2, message: modeID)
            app.terminate()
        }
    }

    @MainActor
    private func outsideBoardCoordinate(
        surface: XCUIElement,
        board: XCUIElement
    ) -> XCUICoordinate {
        let surfaceFrame = surface.frame
        let boardFrame = board.frame
        let topGap = max(1, boardFrame.minY - surfaceFrame.minY)
        let normalizedY = min(0.22, max(0.04, topGap / surfaceFrame.height * 0.5))
        return surface.coordinate(
            withNormalizedOffset: CGVector(dx: 0.5, dy: normalizedY)
        )
    }

    @MainActor
    private func waitForValueChange(_ element: XCUIElement, from oldValue: String?) {
        let predicate = NSPredicate(format: "value != %@", oldValue ?? "")
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        let result = XCTWaiter.wait(for: [expectation], timeout: 2)
        XCTAssertEqual(result, .completed)
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
