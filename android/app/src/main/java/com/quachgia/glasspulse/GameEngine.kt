package com.quachgia.glasspulse

import kotlin.math.max
import kotlin.math.min

class GameEngine(
    val session: GameSessionContext = GameSessionContext.standard(GameModeId.CLASSIC),
    val economy: GameEconomy = GameEconomy(),
    private val initialScenario: GameScenario? = null
) {
    val rules = session.rules

    var score = 0
        private set
    var combo = 1
        private set
    var state = GameState.START
        private set
    var runOutcome: GameRunOutcome? = null
        private set
    var sessionElapsedSeconds = 0.0
        private set
    var currentWave = 1
        private set
    var ballAngle = -Math.PI / 2
        private set
    var direction = 1.0
        private set
    var obstacles = mutableListOf<Obstacle>()
        private set
    var gem = Gem(0.0)
        private set
    var gemBurst: BurstEffect? = null
        private set
    var collisionEffect: CollisionEffect? = null
        private set
    var collectionSerial = 0
        private set

    private val random = SplitMix64(session.seed)
    private var lastUpdateNanos: Long? = null
    private var wasInGemRange = false
    private val ballSpeed = 1.6

    init {
        reset()
    }

    val remainingTimeSeconds: Double?
        get() = rules.sessionDurationSeconds?.let {
            max(0.0, it - sessionElapsedSeconds)
        }

    val pulseIsActive: Boolean
        get() {
            val cycle = rules.pulseCycleSeconds ?: return true
            val active = rules.pulseActiveSeconds ?: return true
            if (cycle <= 0) return true
            return sessionElapsedSeconds % cycle < active
        }

    val rewardForCurrentRun: Int
        get() {
            val baseReward = economy.reward(score)
            if (session.effectiveModeId != GameModeId.WAVE_SURVIVAL) return baseReward
            val waveReward = if (runOutcome == GameRunOutcome.COMPLETED) {
                currentWave * 2
            } else {
                max(0, currentWave - 1)
            }
            return baseReward + waveReward
        }

    fun handleTap(nowNanos: Long = System.nanoTime()) {
        when (state) {
            GameState.START -> startPlaying(nowNanos)
            GameState.PLAYING -> direction *= -1
            GameState.PAUSED, GameState.OVER -> Unit
        }
    }

    fun pause() {
        if (state != GameState.PLAYING) return
        state = GameState.PAUSED
        lastUpdateNanos = null
    }

    fun resume(nowNanos: Long = System.nanoTime()) {
        if (state != GameState.PAUSED) return
        state = GameState.PLAYING
        lastUpdateNanos = nowNanos
    }

    fun advance(nowNanos: Long) {
        expireEffects(nowNanos)
        if (state != GameState.PLAYING) return
        val previous = lastUpdateNanos ?: return
        lastUpdateNanos = nowNanos
        val elapsed = max(0.0, (nowNanos - previous) / NANOS_PER_SECOND)
        if (elapsed <= 0) return

        sessionElapsedSeconds += elapsed
        if (shouldCompleteTimedRun()) {
            completeRun()
            return
        }
        updateWaveIfNeeded()
        if (state != GameState.PLAYING) return
        moveBodies(min(elapsed, 0.05))
        if (hasCollision()) {
            endRun(nowNanos)
            return
        }
        collectGemIfNeeded(nowNanos)
    }

    fun snapshot(): GameSnapshot = GameSnapshot(
        session = session,
        rules = rules,
        state = state,
        runOutcome = runOutcome,
        score = score,
        combo = combo,
        sessionElapsedSeconds = sessionElapsedSeconds,
        currentWave = currentWave,
        ballAngle = ballAngle,
        direction = direction,
        obstacles = obstacles.map { it.copy() },
        gem = gem,
        gemBurst = gemBurst,
        collisionEffect = collisionEffect,
        remainingTimeSeconds = remainingTimeSeconds,
        pulseIsActive = pulseIsActive,
        rewardForCurrentRun = rewardForCurrentRun,
        collectionSerial = collectionSerial
    )

    private fun startPlaying(nowNanos: Long) {
        state = GameState.PLAYING
        lastUpdateNanos = nowNanos
    }

    private fun reset() {
        resetRunState()
        val scenario = initialScenario
        if (scenario == null) {
            resetRandomScenario()
            return
        }
        ballAngle = AngleMath.normalized(scenario.ballAngle)
        direction = if (scenario.direction >= 0) 1.0 else -1.0
        obstacles = scenario.obstacles.map { it.copy() }.toMutableList()
        gem = scenario.gem
    }

    private fun resetRunState() {
        score = 0
        combo = 1
        state = GameState.START
        runOutcome = null
        sessionElapsedSeconds = 0.0
        currentWave = 1
        wasInGemRange = false
        gemBurst = null
        collisionEffect = null
        collectionSerial = 0
        lastUpdateNanos = null
    }

    private fun resetRandomScenario() {
        ballAngle = -Math.PI / 2
        direction = 1.0
        obstacles.clear()
        obstacles += Obstacle(
            angle = safeObstacleAngle(0.50),
            width = 0.50,
            speed = 0.90
        )
        spawnGem()
    }

    private fun shouldCompleteTimedRun(): Boolean {
        val duration = rules.sessionDurationSeconds ?: return false
        return sessionElapsedSeconds >= duration
    }

    private fun moveBodies(deltaSeconds: Double) {
        ballAngle = AngleMath.normalized(ballAngle + direction * ballSpeed * deltaSeconds)
        obstacles.forEach { obstacle ->
            obstacle.angle = AngleMath.normalized(
                obstacle.angle + obstacle.speed * deltaSeconds
            )
        }
    }

    private fun hasCollision(): Boolean = obstacles.any { obstacle ->
        AngleMath.distance(ballAngle, obstacle.angle) < obstacle.width / 2
    }

    private fun collectGemIfNeeded(nowNanos: Long) {
        val inRange = AngleMath.distance(ballAngle, gem.angle) < economy.gemCollectionRadius
        if (!inRange) {
            wasInGemRange = false
            return
        }
        if (wasInGemRange) return
        wasInGemRange = true
        if (session.effectiveModeId == GameModeId.PRECISION_PULSE && !pulseIsActive) {
            combo = 1
            return
        }
        collectGem(nowNanos)
    }

    private fun collectGem(nowNanos: Long) {
        val collectedAngle = gem.angle
        score += scoreIncrement()
        combo = min(combo + 1, rules.comboCap)
        gemBurst = BurstEffect(collectedAngle, nowNanos)
        collectionSerial += 1
        applyDifficultyChange()
        spawnGem()
        wasInGemRange = false
    }

    private fun scoreIncrement(): Int {
        val comboMode = session.effectiveModeId == GameModeId.RUSH_60 ||
            session.effectiveModeId == GameModeId.PRECISION_PULSE
        return economy.pointsPerGem * if (comboMode) combo else 1
    }

    private fun applyDifficultyChange() {
        when (val change = economy.difficultyChange(score, obstacles.size)) {
            DifficultyChange.AddObstacle -> addObstacle()
            is DifficultyChange.IncreaseSpeed -> scaleObstacleSpeed(change.multiplier)
            null -> Unit
        }
    }

    private fun updateWaveIfNeeded() {
        if (session.effectiveModeId != GameModeId.WAVE_SURVIVAL) return
        val duration = rules.waveDurationSeconds ?: return
        val finalWave = rules.finalWave ?: return
        if (sessionElapsedSeconds >= duration * finalWave) {
            currentWave = finalWave
            completeRun()
            return
        }
        val target = min(finalWave, (sessionElapsedSeconds / duration).toInt() + 1)
        while (currentWave < target) {
            currentWave += 1
            advanceWaveHazards()
        }
    }

    private fun advanceWaveHazards() {
        if (obstacles.size < economy.obstacleLimit) {
            addObstacle()
            return
        }
        scaleObstacleSpeed(1.06)
    }

    private fun addObstacle() {
        val width = 0.45
        obstacles += Obstacle(
            angle = safeObstacleAngle(width),
            width = width,
            speed = random.nextDouble(0.70, 1.30)
        )
    }

    private fun scaleObstacleSpeed(multiplier: Double) {
        obstacles.forEach { it.speed *= multiplier }
    }

    private fun endRun(nowNanos: Long) {
        state = GameState.OVER
        runOutcome = GameRunOutcome.COLLISION
        collisionEffect = CollisionEffect(ballAngle, nowNanos)
    }

    private fun completeRun() {
        state = GameState.OVER
        runOutcome = GameRunOutcome.COMPLETED
    }

    private fun spawnGem() {
        repeat(64) {
            val candidate = randomAngle()
            if (!isNearObstacle(candidate, economy.gemObstacleMargin)) {
                gem = Gem(candidate)
                return
            }
        }
        gem = Gem(safestGemAngle())
    }

    private fun safeObstacleAngle(width: Double): Double {
        repeat(64) {
            val candidate = randomAngle()
            if (AngleMath.distance(candidate, ballAngle) <= width / 2 + 0.80) return@repeat
            val overlaps = obstacles.any { obstacle ->
                AngleMath.distance(candidate, obstacle.angle) <
                    (width + obstacle.width) / 2 + 0.25
            }
            if (!overlaps) return candidate
        }
        return AngleMath.normalized(ballAngle + Math.PI)
    }

    private fun isNearObstacle(angle: Double, margin: Double): Boolean =
        obstacles.any { obstacle ->
            AngleMath.distance(obstacle.angle, angle) < obstacle.width / 2 + margin
        }

    private fun safestGemAngle(): Double {
        return (0 until 72)
            .map { it.toDouble() / 72 * AngleMath.FULL_TURN }
            .maxByOrNull(::minimumObstacleClearance)
            ?: 0.0
    }

    private fun minimumObstacleClearance(angle: Double): Double =
        obstacles.minOfOrNull { obstacle ->
            AngleMath.distance(obstacle.angle, angle) - obstacle.width / 2
        } ?: Math.PI

    private fun randomAngle(): Double = random.nextDouble(0.0, AngleMath.FULL_TURN)

    private fun expireEffects(nowNanos: Long) {
        val burst = gemBurst
        if (burst != null && nowNanos - burst.startedAtNanos > GEM_BURST_NANOS) {
            gemBurst = null
        }
        val collision = collisionEffect
        if (collision != null && nowNanos - collision.startedAtNanos > COLLISION_NANOS) {
            collisionEffect = null
        }
    }

    private companion object {
        const val NANOS_PER_SECOND = 1_000_000_000.0
        const val GEM_BURST_NANOS = 420_000_000L
        const val COLLISION_NANOS = 650_000_000L
    }
}
