import XCTest
@testable import GlassPulse

final class GameEngineTests: XCTestCase {
    @MainActor
    func testFirstTapStartsAndSecondTapReversesDirection() {
        let engine = GameEngine(seed: 1, scenario: safeScenario)
        let now = Date(timeIntervalSinceReferenceDate: 100)

        engine.handleTap(now: now)
        XCTAssertEqual(engine.state, .playing)
        XCTAssertEqual(engine.direction, 1)

        engine.handleTap(now: now)
        XCTAssertEqual(engine.direction, -1)
    }

    @MainActor
    func testGemCollectionAddsOnePoint() {
        let scenario = GameScenario(
            ballAngle: 0,
            direction: 1,
            obstacles: [Obstacle(angle: .pi, width: 0.5, speed: 0)],
            gem: Gem(angle: 0.16)
        )
        let engine = GameEngine(seed: 2, scenario: scenario)
        let start = Date(timeIntervalSinceReferenceDate: 200)

        engine.handleTap(now: start)
        engine.advance(to: start.addingTimeInterval(0.10))

        XCTAssertEqual(engine.score, 1)
        XCTAssertNotNil(engine.gemBurst)
        XCTAssertEqual(engine.state, .playing)
    }

    @MainActor
    func testObstacleCollisionEndsRun() {
        let scenario = GameScenario(
            ballAngle: 0,
            direction: 1,
            obstacles: [Obstacle(angle: 0.05, width: 0.5, speed: 0)],
            gem: Gem(angle: .pi)
        )
        let engine = GameEngine(seed: 3, scenario: scenario)
        let start = Date(timeIntervalSinceReferenceDate: 300)

        engine.handleTap(now: start)
        engine.advance(to: start.addingTimeInterval(0.01))

        XCTAssertEqual(engine.state, .over)
        XCTAssertNotNil(engine.collisionEffect)
    }

    @MainActor
    func testFrameDeltaIsClampedAfterLongPause() {
        let engine = GameEngine(seed: 4, scenario: safeScenario)
        let start = Date(timeIntervalSinceReferenceDate: 400)

        engine.handleTap(now: start)
        engine.advance(to: start.addingTimeInterval(1))

        XCTAssertEqual(engine.ballAngle, 0.08, accuracy: 0.000_001)
    }

    func testDifficultyChangesOnlyEveryThreePoints() {
        let economy = GameEconomy.standard

        XCTAssertNil(economy.difficultyChange(score: 1, obstacleCount: 1))
        XCTAssertEqual(economy.difficultyChange(score: 3, obstacleCount: 1), .addObstacle)
        XCTAssertEqual(economy.difficultyChange(score: 6, obstacleCount: 2), .addObstacle)
        XCTAssertEqual(
            economy.difficultyChange(score: 9, obstacleCount: 3),
            .increaseObstacleSpeed(multiplier: 1.04)
        )
    }

    func testAngularDistanceWrapsAcrossFullTurn() {
        let distance = AngleMath.distance(0.04, AngleMath.fullTurn - 0.04)
        XCTAssertEqual(distance, 0.08, accuracy: 0.000_001)
    }

    @MainActor
    func testSpawnedGemAvoidsEveryObstacleMargin() {
        for seed in 0..<100 {
            let engine = GameEngine(seed: UInt64(seed))
            for obstacle in engine.obstacles {
                let clearance = obstacle.width / 2 + engine.economy.gemObstacleMargin
                XCTAssertGreaterThanOrEqual(
                    AngleMath.distance(engine.gem.angle, obstacle.angle),
                    clearance
                )
            }
        }
    }

    private var safeScenario: GameScenario {
        GameScenario(
            ballAngle: 0,
            direction: 1,
            obstacles: [Obstacle(angle: .pi, width: 0.5, speed: 0)],
            gem: Gem(angle: .pi / 2)
        )
    }
}
