package com.quachgia.glasspulse

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

private class RecordingHapticSink : HapticSink {
    val impacts = mutableListOf<ImpactKind>()
    val pulses = mutableListOf<Pair<Float, Float>>()
    var stopCount = 0

    override fun impact(kind: ImpactKind) {
        impacts += kind
    }

    override fun proximityPulse(intensity: Float, sharpness: Float) {
        pulses += intensity to sharpness
    }

    override fun stopContinuous() {
        stopCount += 1
    }
}

private class RecordingSfxSink : SfxSink {
    val tones = mutableListOf<ToneKind>()

    override fun tone(kind: ToneKind) {
        tones += kind
    }
}

private fun snapshot(
    state: GameState,
    direction: Double = 1.0,
    collectionSerial: Int = 0,
    runOutcome: GameRunOutcome? = null,
    effectiveModeId: GameModeId = GameModeId.CLASSIC,
    ballAngle: Double = 0.0,
    gemAngle: Double = 1.0,
    pulseIsActive: Boolean = true
): GameSnapshot = GameSnapshot(
    session = GameSessionContext(
        modeId = effectiveModeId,
        effectiveModeId = effectiveModeId,
        seed = 1uL,
        rulesetVersion = 1,
        dailyKey = null
    ),
    rules = GameModeRules.forMode(effectiveModeId),
    state = state,
    runOutcome = runOutcome,
    score = 0,
    combo = 1,
    sessionElapsedSeconds = 0.0,
    currentWave = 1,
    ballAngle = ballAngle,
    direction = direction,
    obstacles = emptyList(),
    gem = Gem(gemAngle),
    gemBurst = null,
    collisionEffect = null,
    remainingTimeSeconds = null,
    pulseIsActive = pulseIsActive,
    rewardForCurrentRun = 0,
    collectionSerial = collectionSerial
)

class SensoryMappingTest {
    private fun newDispatcher(
        settings: GameSettingsStore = GameSettingsStore(InMemoryKeyValueStore())
    ): Pair<SensoryDispatcher, Pair<RecordingHapticSink, RecordingSfxSink>> {
        val haptics = RecordingHapticSink()
        val sfx = RecordingSfxSink()
        return SensoryDispatcher(settings, haptics, sfx) to (haptics to sfx)
    }

    @Test
    fun reversalMapsExactlyOncePerDirectionChange() {
        val (detector, client) = newDetectorWithRecorder()
        detector.onSnapshot(snapshot(GameState.PLAYING, direction = 1.0))
        detector.onSnapshot(snapshot(GameState.PLAYING, direction = -1.0))
        detector.onSnapshot(snapshot(GameState.PLAYING, direction = -1.0))
        detector.onSnapshot(snapshot(GameState.PLAYING, direction = 1.0))

        assertEquals(2, client.reversedCount)
    }

    @Test
    fun collectionMapsExactlyOncePerSerialIncrement() {
        val (detector, client) = newDetectorWithRecorder()
        detector.onSnapshot(snapshot(GameState.PLAYING, collectionSerial = 0))
        detector.onSnapshot(snapshot(GameState.PLAYING, collectionSerial = 1))
        detector.onSnapshot(snapshot(GameState.PLAYING, collectionSerial = 1))
        detector.onSnapshot(snapshot(GameState.PLAYING, collectionSerial = 2))

        assertEquals(2, client.collectedCount)
    }

    @Test
    fun collisionMapsOnceAndStopsContinuous() {
        val (detector, client) = newDetectorWithRecorder()
        detector.onSnapshot(snapshot(GameState.PLAYING))
        detector.onSnapshot(
            snapshot(
                GameState.OVER,
                runOutcome = GameRunOutcome.COLLISION
            )
        )

        assertEquals(1, client.collidedCount)
        assertTrue(client.stoppedContinuousCount >= 1)
    }

    @Test
    fun completedRunStopsContinuousWithoutCollision() {
        val (detector, client) = newDetectorWithRecorder()
        detector.onSnapshot(snapshot(GameState.PLAYING))
        detector.onSnapshot(
            snapshot(
                GameState.OVER,
                runOutcome = GameRunOutcome.COMPLETED
            )
        )

        assertEquals(0, client.collidedCount)
        assertTrue(client.stoppedContinuousCount >= 1)
    }

    @Test
    fun pauseStopsContinuousWithoutCollision() {
        val (detector, client) = newDetectorWithRecorder()
        detector.onSnapshot(snapshot(GameState.PLAYING))
        detector.onSnapshot(snapshot(GameState.PAUSED))

        assertEquals(0, client.collidedCount)
        assertTrue(client.stoppedContinuousCount >= 1)
    }

    @Test
    fun detectorResetPreventsSpuriousReversalAfterRetry() {
        val (detector, client) = newDetectorWithRecorder()
        detector.onSnapshot(snapshot(GameState.PLAYING, direction = -1.0))
        detector.onSnapshot(snapshot(GameState.OVER, direction = -1.0, runOutcome = GameRunOutcome.COLLISION))
        detector.reset(snapshot(GameState.START, direction = 1.0))
        detector.onSnapshot(snapshot(GameState.PLAYING, direction = 1.0))

        assertEquals(0, client.reversedCount)
    }

    @Test
    fun disabledSettingsProduceZeroSinkCalls() {
        val settings = GameSettingsStore(InMemoryKeyValueStore())
        settings.updateHapticsEnabled(false)
        settings.updateSoundEnabled(false)
        val (dispatcher, sinks) = newDispatcher(settings)

        dispatcher.reversed()
        dispatcher.collected()
        dispatcher.collided()

        val (haptics, sfx) = sinks
        assertEquals(0, haptics.impacts.size)
        assertEquals(0, sfx.tones.size)
    }

    @Test
    fun hapticsAndSfxAreGatedIndependently() {
        val settings = GameSettingsStore(InMemoryKeyValueStore())
        settings.updateHapticsEnabled(false)
        val (dispatcher, sinks) = newDispatcher(settings)

        dispatcher.reversed()

        val (haptics, sfx) = sinks
        assertEquals(0, haptics.impacts.size)
        assertEquals(listOf(ToneKind.REVERSE), sfx.tones)
    }

    @Test
    fun proximityBelowFloorStopsInsteadOfPulsing() {
        val settings = GameSettingsStore(InMemoryKeyValueStore())
        val haptics = RecordingHapticSink()
        val sfx = RecordingSfxSink()
        val dispatcher = SensoryDispatcher(settings, haptics, sfx)

        dispatcher.proximity(0.10, pulseActive = true)
        assertEquals(1, haptics.stopCount)
        assertEquals(0, haptics.pulses.size)

        dispatcher.proximity(SensoryDispatcher.PROXIMITY_FLOOR, pulseActive = true)
        assertEquals(1, haptics.pulses.size)
    }

    @Test
    fun proximityScalesIntensityWithPulseWindow() {
        val settings = GameSettingsStore(InMemoryKeyValueStore())
        val haptics = RecordingHapticSink()
        val sfx = RecordingSfxSink()
        val dispatcher = SensoryDispatcher(settings, haptics, sfx)

        dispatcher.proximity(1.0, pulseActive = true)
        dispatcher.proximity(1.0, pulseActive = false)

        val (activeIntensity, _) = haptics.pulses[0]
        val (inactiveIntensity, _) = haptics.pulses[1]
        assertTrue(activeIntensity > inactiveIntensity)
    }

    @Test
    fun nonPrecisionModeStopsContinuousFeedback() {
        val (detector, client) = newDetectorWithRecorder()
        detector.onSnapshot(
            snapshot(
                GameState.PLAYING,
                effectiveModeId = GameModeId.CLASSIC
            )
        )

        assertTrue(client.stoppedContinuousCount >= 1)
        assertEquals(0, client.proximityCount)
    }

    @Test
    fun precisionModeEmitsProximityFromGemDistance() {
        val (detector, client) = newDetectorWithRecorder()
        detector.onSnapshot(
            snapshot(
                GameState.PLAYING,
                effectiveModeId = GameModeId.PRECISION_PULSE,
                ballAngle = 0.0,
                gemAngle = 0.90 * SensoryEventDetector.PROXIMITY_RANGE
            )
        )

        assertEquals(1, client.proximityCount)
        assertEquals(0.10, client.lastProximity!!, 0.0001)
    }

    private fun newDetectorWithRecorder(): Pair<SensoryEventDetector, RecordingSensoryClient> {
        val recorder = RecordingSensoryClient()
        return SensoryEventDetector(recorder) to recorder
    }
}

private class RecordingSensoryClient : SensoryClient {
    var reversedCount = 0
    var collectedCount = 0
    var collidedCount = 0
    var proximityCount = 0
    var lastProximity: Double? = null
    var stoppedContinuousCount = 0

    override fun reversed() {
        reversedCount += 1
    }

    override fun collected() {
        collectedCount += 1
    }

    override fun collided() {
        collidedCount += 1
    }

    override fun proximity(value: Double, pulseActive: Boolean) {
        proximityCount += 1
        lastProximity = value
    }

    override fun stoppedContinuous() {
        stoppedContinuousCount += 1
    }
}
