package com.quachgia.glasspulse

import java.time.LocalDate
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class GameEngineTest {
    @Test
    fun startAndPlayingTapsFollowSingleReversalContract() {
        val engine = GameEngine(
            session = GameSessionContext.standard(GameModeId.CLASSIC, 17uL)
        )
        val start = 1_000_000_000L

        engine.handleTap(start)
        assertEquals(GameState.PLAYING, engine.state)
        assertEquals(1.0, engine.direction, 0.0)

        engine.handleTap(start + 1)
        assertEquals(-1.0, engine.direction, 0.0)
    }

    @Test
    fun pausedAndGameOverTapsAreInert() {
        val scenario = GameScenario(
            ballAngle = 0.0,
            direction = 1.0,
            obstacles = listOf(Obstacle(angle = 0.08, width = 0.14, speed = 0.0)),
            gem = Gem(Math.PI)
        )
        val engine = GameEngine(
            session = GameSessionContext.standard(GameModeId.CLASSIC, 91uL),
            initialScenario = scenario
        )
        val start = 2_000_000_000L

        engine.handleTap(start)
        engine.pause()
        engine.handleTap(start + 1)
        assertEquals(GameState.PAUSED, engine.state)
        assertEquals(1.0, engine.direction, 0.0)

        engine.resume(start + 2)
        engine.advance(start + 102_000_000L)
        assertEquals(GameState.OVER, engine.state)
        assertEquals(GameRunOutcome.COLLISION, engine.runOutcome)

        engine.handleTap(start + 103_000_000L)
        assertEquals(GameState.OVER, engine.state)
        assertEquals(1.0, engine.direction, 0.0)
    }

    @Test
    fun rushCompletesAtSixtySeconds() {
        val scenario = GameScenario(
            ballAngle = 0.0,
            direction = 1.0,
            obstacles = emptyList(),
            gem = Gem(Math.PI)
        )
        val engine = GameEngine(
            session = GameSessionContext.standard(GameModeId.RUSH_60, 8uL),
            initialScenario = scenario
        )
        val start = 3_000_000_000L

        engine.handleTap(start)
        engine.advance(start + 60_000_000_000L)

        assertEquals(GameState.OVER, engine.state)
        assertEquals(GameRunOutcome.COMPLETED, engine.runOutcome)
        assertEquals(0.0, engine.remainingTimeSeconds ?: -1.0, 0.0)
    }

    @Test
    fun dailyContextIsDeterministicAndRetryKeepsIt() {
        val date = LocalDate.of(2026, 8, 30)
        val first = GameSessionContext.daily(date)
        val second = GameSessionContext.daily(date)
        val replay = first.replayContext(999uL)

        assertEquals(first, second)
        assertEquals(first, replay)
        assertNotEquals(first.seed, GameSessionContext.daily(date.plusDays(1)).seed)
    }

    @Test
    fun tenThousandSeedsStartWithSafeObstacleAndGemSpacing() {
        repeat(10_000) { seed ->
            val engine = GameEngine(
                session = GameSessionContext.standard(GameModeId.CLASSIC, seed.toULong())
            )
            val obstacle = engine.obstacles.single()
            val ballClearance = AngleMath.distance(engine.ballAngle, obstacle.angle)
            val gemClearance = AngleMath.distance(engine.gem.angle, obstacle.angle)

            assertTrue(ballClearance > obstacle.width / 2 + 0.80)
            assertTrue(gemClearance >= obstacle.width / 2 + engine.economy.gemObstacleMargin)
        }
    }
}
