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
}
