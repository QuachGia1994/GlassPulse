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

    @MainActor
    func testPauseStopsMotionAndResumeRestartsFromCurrentTime() {
        let engine = GameEngine(seed: 5, scenario: safeScenario)
        let start = Date(timeIntervalSinceReferenceDate: 500)

        engine.handleTap(now: start)
        engine.advance(to: start.addingTimeInterval(0.10))
        let angleBeforePause = engine.ballAngle

        engine.pause()
        engine.advance(to: start.addingTimeInterval(10))
        XCTAssertEqual(engine.state, .paused)
        XCTAssertEqual(engine.ballAngle, angleBeforePause, accuracy: 0.000_001)

        engine.resume(at: start.addingTimeInterval(10))
        engine.advance(to: start.addingTimeInterval(10.10))
        XCTAssertEqual(engine.state, .playing)
        XCTAssertEqual(engine.ballAngle, angleBeforePause + 0.08, accuracy: 0.000_001)
    }

    @MainActor
    func testGameTapDoesNotReverseDirectionWhilePaused() {
        let engine = GameEngine(seed: 6, scenario: safeScenario)
        let start = Date(timeIntervalSinceReferenceDate: 600)

        engine.handleTap(now: start)
        engine.pause()
        engine.handleTap(now: start.addingTimeInterval(1))

        XCTAssertEqual(engine.state, .paused)
        XCTAssertEqual(engine.direction, 1)
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

    @MainActor
    func testRushCompletesAtSixtySecondsWithoutPhysicsJump() {
        let session = GameSessionContext.standard(modeID: .rush60, seed: 21)
        let engine = GameEngine(scenario: safeScenario, session: session)
        let start = Date(timeIntervalSinceReferenceDate: 700)

        engine.handleTap(now: start)
        engine.advance(to: start.addingTimeInterval(60))

        XCTAssertEqual(engine.state, .over)
        XCTAssertEqual(engine.runOutcome, .completed)
        XCTAssertEqual(engine.remainingTime, 0)
        XCTAssertEqual(engine.ballAngle, 0, accuracy: 0.000_001)
    }

    @MainActor
    func testRushComboRaisesDeterministicScore() {
        let economy = GameEconomy(
            pointsPerGem: 1,
            difficultyInterval: 1_000,
            obstacleLimit: 3,
            obstacleSpeedMultiplier: 1.04,
            gemCollectionRadius: 10,
            gemObstacleMargin: 0.60
        )
        let session = GameSessionContext.standard(modeID: .rush60, seed: 22)
        let engine = GameEngine(economy: economy, scenario: safeScenario, session: session)
        let start = Date(timeIntervalSinceReferenceDate: 800)

        engine.handleTap(now: start)
        engine.advance(to: start.addingTimeInterval(0.1))
        engine.advance(to: start.addingTimeInterval(0.2))

        XCTAssertEqual(engine.score, 3)
        XCTAssertEqual(engine.combo, 3)
    }

    @MainActor
    func testPrecisionRejectsInactivePulseWithoutAwarding() {
        let scenario = GameScenario(
            ballAngle: 0,
            direction: 1,
            obstacles: [Obstacle(angle: .pi, width: 0.5, speed: 0)],
            gem: Gem(angle: 0.16)
        )
        let session = GameSessionContext.standard(modeID: .precisionPulse, seed: 23)
        let engine = GameEngine(scenario: scenario, session: session)
        let start = Date(timeIntervalSinceReferenceDate: 900)

        engine.handleTap(now: start)
        engine.advance(to: start.addingTimeInterval(0.8))

        XCTAssertFalse(engine.pulseIsActive)
        XCTAssertEqual(engine.score, 0)
        XCTAssertEqual(engine.combo, 1)
    }

    @MainActor
    func testWaveTransitionAddsHazardWithBallClearance() {
        let session = GameSessionContext.standard(modeID: .waveSurvival, seed: 24)
        let engine = GameEngine(scenario: safeScenario, session: session)
        let start = Date(timeIntervalSinceReferenceDate: 1_000)

        engine.handleTap(now: start)
        engine.advance(to: start.addingTimeInterval(8.1))

        XCTAssertEqual(engine.currentWave, 2)
        XCTAssertEqual(engine.obstacles.count, 2)
        let added = engine.obstacles[1]
        XCTAssertGreaterThanOrEqual(
            AngleMath.distance(added.angle, 0),
            added.width / 2 + 0.80
        )
    }

    @MainActor
    func testWaveFinalBoundaryCompletesRun() {
        let session = GameSessionContext.standard(modeID: .waveSurvival, seed: 25)
        let engine = GameEngine(scenario: safeScenario, session: session)
        let start = Date(timeIntervalSinceReferenceDate: 1_100)

        engine.handleTap(now: start)
        engine.advance(to: start.addingTimeInterval(40))

        XCTAssertEqual(engine.currentWave, 5)
        XCTAssertEqual(engine.runOutcome, .completed)
        XCTAssertEqual(engine.state, .over)
    }

    func testDailyContextIsStableForCalendarDayAndVersion() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(identifier: "America/Los_Angeles"))
        let date = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 3, day: 8, hour: 1)))
        let sameDay = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 3, day: 8, hour: 18)))
        let nextDay = try XCTUnwrap(calendar.date(byAdding: .day, value: 1, to: date))

        let first = GameSessionContext.daily(date: date, calendar: calendar)
        let second = GameSessionContext.daily(date: sameDay, calendar: calendar)
        let next = GameSessionContext.daily(date: nextDay, calendar: calendar)

        XCTAssertEqual(first, second)
        XCTAssertNotEqual(first.dailyKey, next.dailyKey)
        XCTAssertNotEqual(first.seed, next.seed)
    }

    func testDailyClassicAndPrecisionHaveFiniteCompletionWindow() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(secondsFromGMT: 0))
        var checkedCount = 0

        for dayOffset in 0..<64 {
            let date = Date(timeIntervalSince1970: 1_700_000_000 + Double(dayOffset * 86_400))
            let session = GameSessionContext.daily(date: date, calendar: calendar)
            guard session.effectiveModeID == .classic || session.effectiveModeID == .precisionPulse else {
                continue
            }
            checkedCount += 1
            XCTAssertEqual(session.rules.sessionDuration, 60)
        }
        XCTAssertGreaterThan(checkedCount, 0)
    }

    @MainActor
    func testTenThousandSeededInitialScenariosRemainSafe() {
        for seed in 0..<10_000 {
            let engine = GameEngine(seed: UInt64(seed))
            for obstacle in engine.obstacles {
                XCTAssertGreaterThanOrEqual(
                    AngleMath.distance(engine.gem.angle, obstacle.angle),
                    obstacle.width / 2 + engine.economy.gemObstacleMargin
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
