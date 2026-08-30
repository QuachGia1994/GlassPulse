package com.quachgia.glasspulse

import java.time.LocalDate
import kotlin.math.abs
import kotlin.math.max
import kotlin.math.min
import kotlin.random.Random

enum class GameState {
    START,
    PLAYING,
    PAUSED,
    OVER
}

enum class GameRunOutcome {
    COLLISION,
    COMPLETED
}

enum class GameModeId(val requiresPlus: Boolean) {
    CLASSIC(false),
    RUSH_60(true),
    PRECISION_PULSE(true),
    WAVE_SURVIVAL(true),
    DAILY_CHALLENGE(false)
}

data class Obstacle(
    var angle: Double,
    val width: Double,
    var speed: Double
)

data class Gem(val angle: Double)

data class GameScenario(
    val ballAngle: Double,
    val direction: Double,
    val obstacles: List<Obstacle>,
    val gem: Gem
)

data class BurstEffect(
    val angle: Double,
    val startedAtNanos: Long
)

data class CollisionEffect(
    val angle: Double,
    val startedAtNanos: Long
)

sealed interface DifficultyChange {
    data object AddObstacle : DifficultyChange
    data class IncreaseSpeed(val multiplier: Double) : DifficultyChange
}

data class GameEconomy(
    val pointsPerGem: Int = 1,
    val difficultyInterval: Int = 3,
    val obstacleLimit: Int = 3,
    val obstacleSpeedMultiplier: Double = 1.04,
    val gemCollectionRadius: Double = 0.18,
    val gemObstacleMargin: Double = 0.60
) {
    fun difficultyChange(score: Int, obstacleCount: Int): DifficultyChange? {
        if (score <= 0 || score % difficultyInterval != 0) return null
        if (obstacleCount < obstacleLimit) return DifficultyChange.AddObstacle
        return DifficultyChange.IncreaseSpeed(obstacleSpeedMultiplier)
    }

    fun reward(score: Int): Int = max(0, score)
}

data class GameModeRules(
    val sessionDurationSeconds: Double?,
    val comboCap: Int,
    val pulseCycleSeconds: Double?,
    val pulseActiveSeconds: Double?,
    val waveDurationSeconds: Double?,
    val finalWave: Int?,
    val dailyFirstClearBonus: Int
) {
    companion object {
        fun forMode(modeId: GameModeId): GameModeRules = when (modeId) {
            GameModeId.CLASSIC -> GameModeRules(null, 1, null, null, null, null, 0)
            GameModeId.RUSH_60 -> GameModeRules(60.0, 5, null, null, null, null, 0)
            GameModeId.PRECISION_PULSE ->
                GameModeRules(null, 4, 1.60, 0.56, null, null, 0)
            GameModeId.WAVE_SURVIVAL ->
                GameModeRules(null, 1, null, null, 8.0, 5, 0)
            GameModeId.DAILY_CHALLENGE ->
                GameModeRules(null, 1, null, null, null, null, 10)
        }
    }
}

data class GameSessionContext(
    val modeId: GameModeId,
    val effectiveModeId: GameModeId,
    val seed: ULong,
    val rulesetVersion: Int,
    val dailyKey: String?
) {
    val rules: GameModeRules
        get() {
            val base = GameModeRules.forMode(effectiveModeId)
            if (modeId != GameModeId.DAILY_CHALLENGE) return base
            val duration = base.sessionDurationSeconds
                ?: if (base.waveDurationSeconds == null) 60.0 else null
            return base.copy(
                sessionDurationSeconds = duration,
                dailyFirstClearBonus = GameModeRules
                    .forMode(GameModeId.DAILY_CHALLENGE)
                    .dailyFirstClearBonus
            )
        }

    fun replayContext(seed: ULong = randomSessionSeed()): GameSessionContext {
        if (modeId == GameModeId.DAILY_CHALLENGE) return this
        return standard(modeId, seed)
    }

    companion object {
        const val DAILY_RULESET_VERSION = 1

        fun standard(
            modeId: GameModeId,
            seed: ULong = randomSessionSeed()
        ): GameSessionContext {
            if (modeId == GameModeId.DAILY_CHALLENGE) return daily()
            return GameSessionContext(modeId, modeId, seed, 1, null)
        }

        fun daily(date: LocalDate = LocalDate.now()): GameSessionContext {
            val key = date.toString()
            val seed = DailyChallenge.seed(key, DAILY_RULESET_VERSION)
            val effective = DailyChallenge.rotation[
                (seed % DailyChallenge.rotation.size.toULong()).toInt()
            ]
            return GameSessionContext(
                modeId = GameModeId.DAILY_CHALLENGE,
                effectiveModeId = effective,
                seed = seed,
                rulesetVersion = DAILY_RULESET_VERSION,
                dailyKey = key
            )
        }
    }
}

object DailyChallenge {
    val rotation = listOf(
        GameModeId.CLASSIC,
        GameModeId.RUSH_60,
        GameModeId.PRECISION_PULSE,
        GameModeId.WAVE_SURVIVAL
    )

    fun seed(key: String, rulesetVersion: Int): ULong {
        val payload = "glass-pulse-daily-v$rulesetVersion-$key"
        return payload.encodeToByteArray().fold(14_695_981_039_346_656_037uL) { hash, byte ->
            (hash xor byte.toUByte().toULong()) * 1_099_511_628_211uL
        }
    }
}

object AngleMath {
    const val FULL_TURN = 6.283185307179586

    fun normalized(angle: Double): Double {
        val remainder = angle % FULL_TURN
        return if (remainder >= 0) remainder else remainder + FULL_TURN
    }

    fun distance(first: Double, second: Double): Double {
        val difference = abs(normalized(first) - normalized(second))
        return min(difference, FULL_TURN - difference)
    }
}

class SplitMix64(seed: ULong) {
    private var state = seed

    fun nextULong(): ULong {
        state += 0x9E3779B97F4A7C15uL
        var value = state
        value = (value xor (value shr 30)) * 0xBF58476D1CE4E5B9uL
        value = (value xor (value shr 27)) * 0x94D049BB133111EBuL
        return value xor (value shr 31)
    }

    fun nextDouble(minimum: Double, maximum: Double): Double {
        val unit = (nextULong() shr 11).toLong().toDouble() / 9_007_199_254_740_992.0
        return minimum + (maximum - minimum) * unit
    }
}

data class GameSnapshot(
    val session: GameSessionContext,
    val rules: GameModeRules,
    val state: GameState,
    val runOutcome: GameRunOutcome?,
    val score: Int,
    val combo: Int,
    val sessionElapsedSeconds: Double,
    val currentWave: Int,
    val ballAngle: Double,
    val direction: Double,
    val obstacles: List<Obstacle>,
    val gem: Gem,
    val gemBurst: BurstEffect?,
    val collisionEffect: CollisionEffect?,
    val remainingTimeSeconds: Double?,
    val pulseIsActive: Boolean,
    val rewardForCurrentRun: Int,
    val collectionSerial: Int
)

internal fun randomSessionSeed(): ULong = Random.nextLong().toULong()
