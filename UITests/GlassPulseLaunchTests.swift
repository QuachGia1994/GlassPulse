import XCTest

final class GlassPulseLaunchTests: XCTestCase {
    func testGameBoardAppearsOnLaunch() {
        let app = XCUIApplication()
        app.launch()

        let board = app.descendants(matching: .any)
            .matching(identifier: "game.board")
            .firstMatch
        XCTAssertTrue(board.waitForExistence(timeout: 5))
    }

    func testPauseAndResumeDuringPlay() {
        let app = XCUIApplication()
        app.launch()

        let board = app.descendants(matching: .any)
            .matching(identifier: "game.board")
            .firstMatch
        XCTAssertTrue(board.waitForExistence(timeout: 5))
        expectation(
            for: NSPredicate(format: "hittable == true"),
            evaluatedWith: board
        )
        waitForExpectations(timeout: 5)
        board.tap()

        let pauseButton = app.buttons["game.pause"]
        XCTAssertTrue(pauseButton.waitForExistence(timeout: 2))
        pauseButton.tap()
        XCTAssertTrue(app.staticTexts["Đã tạm dừng"].waitForExistence(timeout: 2))

        pauseButton.tap()
        XCTAssertTrue(
            app.staticTexts["Đã tạm dừng"]
                .waitForNonExistence(timeout: 2)
        )
    }
}
