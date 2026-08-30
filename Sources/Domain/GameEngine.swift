import Foundation
import Observation

@MainActor
@Observable
final class GameEngine {
    let economy: GameEconomy
    let session: GameSessionContext
    let rules: GameModeRules

    private(set) var score = 0
    private(set) var combo = 1
    private(set) var state: GameState = .start
    private(set) var runOutcome: GameRunOutcome?
    private(set) var sessionElapsed: TimeInterval = 0
    private(set) var currentWave = 1
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
    @ObservationIgnored private var wasInGemRange = false
    private let ballSpeed = 1.6

    init(
        seed: UInt64 = UInt64.random(in: UInt64.min...UInt64.max),
        sensory: SensoryClient = .silent,
        economy: GameEconomy = .standard,
        scenario: GameScenario? = nil,
        session: GameSessionContext? = nil
    ) {
        let resolvedSession = session ?? .standard(modeID: .classic, seed: seed)
        random = SplitMix64(seed: resolvedSession.seed)
        self.sensory = sensory
        self.economy = economy
        self.session = resolvedSession
        rules = resolvedSession.rules
        initialScenario = scenario
        reset()
    }

    var modeID: GameModeID { session.modeID }

    var effectiveModeID: GameModeID { session.effectiveModeID }

    var remainingTime: TimeInterval? {
        rules.sessionDuration.map { max(0, $0 - sessionElapsed) }
    }

    var pulseIsActive: Bool {
        guard let cycle = rules.pulseCycleDuration,
              let active = rules.pulseActiveDuration,
              cycle > 0 else { return true }
        return sessionElapsed.truncatingRemainder(dividingBy: cycle) < active
    }

    var statusText: String {
        switch state {
        case .start: "Chạm để bắt đầu"
        case .playing: ""
        case .paused: "Đã tạm dừng"
        case .over:
            runOutcome == .completed ? "Hoàn thành" : "Thua rồi. Chạm để chơi lại"
        }
    }

    var rewardForCurrentRun: Int {
        let baseReward = economy.reward(for: score)
        guard effectiveModeID == .waveSurvival else { return baseReward }
        let waveReward = runOutcome == .completed ? currentWave * 2 : max(0, currentWave - 1)
        return baseReward + waveReward
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
        sensory.stoppedContinuous()
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

        let elapsed = max(now.timeIntervalSince(lastUpdate), 0)
        guard elapsed > 0 else { return }
        sessionElapsed += elapsed
        if shouldCompleteTimedRun {
            completeRun()
            return
        }
        updateWaveIfNeeded()
        guard state == .playing else { return }

        let deltaTime = min(elapsed, 0.05)
        moveBodies(deltaTime: deltaTime)
        guard !hasCollision else {
            endRun(at: now)
            return
        }
        collectGemIfNeeded(at: now)
        updatePrecisionFeedback()
    }

    private var shouldCompleteTimedRun: Bool {
        guard let duration = rules.sessionDuration else { return false }
        return sessionElapsed >= duration
    }

    private func startPlaying(at now: Date) {
        state = .playing
        lastUpdate = now
    }

    private func reset() {
        score = 0
        combo = 1
        state = .start
        runOutcome = nil
        sessionElapsed = 0
        currentWave = 1
        wasInGemRange = false
        gemBurst = nil
        collisionEffect = nil
        lastUpdate = nil
        sensory.stoppedContinuous()

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
        let inRange = AngleMath.distance(ballAngle, gem.angle) < economy.gemCollectionRadius
        guard inRange else {
            wasInGemRange = false
            return
        }
        guard !wasInGemRange else { return }
        wasInGemRange = true
        guard effectiveModeID != .precisionPulse || pulseIsActive else {
            combo = 1
            return
        }
        collectGem(at: now)
    }

    private func collectGem(at now: Date) {
        let collectedAngle = gem.angle
        score += scoreIncrement
        combo = min(combo + 1, rules.comboCap)
        gemBurst = BurstEffect(angle: collectedAngle, startedAt: now)
        sensory.collected()
        applyDifficultyChange()
        spawnGem()
        wasInGemRange = false
    }

    private var scoreIncrement: Int {
        let multiplier = effectiveModeID == .rush60 || effectiveModeID == .precisionPulse ? combo : 1
        return economy.pointsPerGem * multiplier
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
            scaleObstacleSpeed(by: multiplier)
        }
    }

    private func updateWaveIfNeeded() {
        guard effectiveModeID == .waveSurvival,
              let waveDuration = rules.waveDuration,
              let finalWave = rules.finalWave else { return }
        if sessionElapsed >= waveDuration * Double(finalWave) {
            currentWave = finalWave
            completeRun()
            return
        }
        let targetWave = min(finalWave, Int(sessionElapsed / waveDuration) + 1)
        while currentWave < targetWave {
            currentWave += 1
            advanceWaveHazards()
        }
    }

    private func advanceWaveHazards() {
        guard obstacles.count < economy.obstacleLimit else {
            scaleObstacleSpeed(by: 1.06)
            return
        }
        addObstacle()
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

    private func scaleObstacleSpeed(by multiplier: Double) {
        for index in obstacles.indices {
            obstacles[index].speed *= multiplier
        }
    }

    private func endRun(at now: Date) {
        state = .over
        runOutcome = .collision
        collisionEffect = CollisionEffect(angle: ballAngle, startedAt: now)
        sensory.stoppedContinuous()
        sensory.collided()
    }

    private func completeRun() {
        state = .over
        runOutcome = .completed
        sensory.stoppedContinuous()
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

    private func updatePrecisionFeedback() {
        guard effectiveModeID == .precisionPulse else {
            sensory.stoppedContinuous()
            return
        }
        let distance = AngleMath.distance(ballAngle, gem.angle)
        let proximity = max(0, 1 - distance / 0.90)
        sensory.proximity(proximity, pulseIsActive)
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
