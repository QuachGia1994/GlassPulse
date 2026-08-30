import Foundation
import Observation

@MainActor
@Observable
final class GameEngine {
    let economy: GameEconomy

    private(set) var score = 0
    private(set) var state: GameState = .start
    private(set) var ballAngle = -Double.pi / 2
    private(set) var direction = 1.0
    private(set) var obstacles: [Obstacle] = []
    private(set) var gem = Gem(angle: 0)
    private(set) var gemBurst: BurstEffect?
    private(set) var collisionEffect: CollisionEffect?

    @ObservationIgnored private var random: SplitMix64
    @ObservationIgnored private var sensory: SensoryClient
    @ObservationIgnored private var lastUpdate: Date?
    @ObservationIgnored private let initialScenario: GameScenario?
    private let ballSpeed = 1.6

    init(
        seed: UInt64 = UInt64.random(in: UInt64.min...UInt64.max),
        sensory: SensoryClient = .silent,
        economy: GameEconomy = .standard,
        scenario: GameScenario? = nil
    ) {
        random = SplitMix64(seed: seed)
        self.sensory = sensory
        self.economy = economy
        initialScenario = scenario
        reset()
    }

    var statusText: String {
        switch state {
        case .start: "Chạm để bắt đầu"
        case .playing: ""
        case .paused: "Đã tạm dừng"
        case .over: "Thua rồi. Chạm để chơi lại"
        }
    }

    var rewardForCurrentRun: Int {
        economy.reward(for: score)
    }

    func connectSensory(_ sensory: SensoryClient) {
        self.sensory = sensory
    }

    func handleTap(now: Date = .now) {
        switch state {
        case .start:
            startPlaying(at: now)
        case .playing:
            direction *= -1
            sensory.reversed()
        case .paused:
            return
        case .over:
            reset()
            startPlaying(at: now)
        }
    }

    func pause() {
        guard state == .playing else { return }
        state = .paused
        lastUpdate = nil
    }

    func resume(at now: Date = .now) {
        guard state == .paused else { return }
        state = .playing
        lastUpdate = now
    }

    func advance(to now: Date) {
        guard state != .paused else { return }
        expireEffects(at: now)
        guard state == .playing else { return }
        defer { lastUpdate = now }
        guard let lastUpdate else { return }

        let elapsed = now.timeIntervalSince(lastUpdate)
        let deltaTime = min(max(elapsed, 0), 0.05)
        guard deltaTime > 0 else { return }

        moveBodies(deltaTime: deltaTime)
        guard !hasCollision else {
            endRun(at: now)
            return
        }
        collectGemIfNeeded(at: now)
    }

    private func startPlaying(at now: Date) {
        state = .playing
        lastUpdate = now
    }

    private func reset() {
        score = 0
        state = .start
        gemBurst = nil
        collisionEffect = nil
        lastUpdate = nil

        guard let initialScenario else {
            resetRandomScenario()
            return
        }
        ballAngle = AngleMath.normalized(initialScenario.ballAngle)
        direction = initialScenario.direction >= 0 ? 1 : -1
        obstacles = initialScenario.obstacles
        gem = initialScenario.gem
    }

    private func resetRandomScenario() {
        ballAngle = -Double.pi / 2
        direction = 1
        obstacles = []
        let initialObstacle = Obstacle(
            angle: safeObstacleAngle(width: 0.50),
            width: 0.50,
            speed: 0.90
        )
        obstacles = [initialObstacle]
        spawnGem()
    }

    private func moveBodies(deltaTime: TimeInterval) {
        ballAngle = AngleMath.normalized(ballAngle + direction * ballSpeed * deltaTime)
        for index in obstacles.indices {
            obstacles[index].angle = AngleMath.normalized(
                obstacles[index].angle + obstacles[index].speed * deltaTime
            )
        }
    }

    private var hasCollision: Bool {
        obstacles.contains {
            AngleMath.distance(ballAngle, $0.angle) < $0.width / 2
        }
    }

    private func collectGemIfNeeded(at now: Date) {
        guard AngleMath.distance(ballAngle, gem.angle) < economy.gemCollectionRadius else { return }
        let collectedAngle = gem.angle
        score += economy.pointsPerGem
        gemBurst = BurstEffect(angle: collectedAngle, startedAt: now)
        sensory.collected()
        applyDifficultyChange()
        spawnGem()
    }

    private func applyDifficultyChange() {
        guard let change = economy.difficultyChange(
            score: score,
            obstacleCount: obstacles.count
        ) else { return }

        switch change {
        case .addObstacle:
            addObstacle()
        case .increaseObstacleSpeed(let multiplier):
            for index in obstacles.indices {
                obstacles[index].speed *= multiplier
            }
        }
    }

    private func addObstacle() {
        let width = 0.45
        obstacles.append(
            Obstacle(
                angle: safeObstacleAngle(width: width),
                width: width,
                speed: Double.random(in: 0.70...1.30, using: &random)
            )
        )
    }

    private func endRun(at now: Date) {
        state = .over
        collisionEffect = CollisionEffect(angle: ballAngle, startedAt: now)
        sensory.collided()
    }

    private func spawnGem() {
        for _ in 0..<64 {
            let candidate = randomAngle()
            guard !isNearObstacle(candidate, margin: economy.gemObstacleMargin) else { continue }
            gem = Gem(angle: candidate)
            return
        }
        gem = Gem(angle: safestGemAngle())
    }

    private func safeObstacleAngle(width: Double) -> Double {
        for _ in 0..<64 {
            let candidate = randomAngle()
            guard AngleMath.distance(candidate, ballAngle) > width / 2 + 0.80 else { continue }
            let overlapsObstacle = obstacles.contains {
                AngleMath.distance(candidate, $0.angle) < (width + $0.width) / 2 + 0.25
            }
            guard !overlapsObstacle else { continue }
            return candidate
        }
        return AngleMath.normalized(ballAngle + .pi)
    }

    private func isNearObstacle(_ angle: Double, margin: Double) -> Bool {
        obstacles.contains {
            AngleMath.distance($0.angle, angle) < $0.width / 2 + margin
        }
    }

    private func safestGemAngle() -> Double {
        let candidates = (0..<72).map {
            Double($0) / 72 * AngleMath.fullTurn
        }
        return candidates.max {
            minimumObstacleClearance(at: $0) < minimumObstacleClearance(at: $1)
        } ?? 0
    }

    private func minimumObstacleClearance(at angle: Double) -> Double {
        obstacles.map {
            AngleMath.distance($0.angle, angle) - $0.width / 2
        }.min() ?? .pi
    }

    private func randomAngle() -> Double {
        Double.random(in: 0..<AngleMath.fullTurn, using: &random)
    }

    private func expireEffects(at now: Date) {
        if let gemBurst, now.timeIntervalSince(gemBurst.startedAt) > 0.42 {
            self.gemBurst = nil
        }
        if let collisionEffect, now.timeIntervalSince(collisionEffect.startedAt) > 0.65 {
            self.collisionEffect = nil
        }
    }
}
