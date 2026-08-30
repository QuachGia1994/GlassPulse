package com.quachgia.glasspulse

import kotlin.math.max

enum class ImpactKind { REVERSE, COLLECT, COLLISION }

enum class ToneKind { REVERSE, COLLECT, COLLISION }

interface HapticSink {
    fun impact(kind: ImpactKind)
    fun proximityPulse(intensity: Float, sharpness: Float)
    fun stopContinuous()
}

interface SfxSink {
    fun tone(kind: ToneKind)
}

interface SensoryClient {
    fun reversed()
    fun collected()
    fun collided()
    fun proximity(value: Double, pulseActive: Boolean)
    fun stoppedContinuous()
}

/**
 * Routes gameplay sensory events to the haptic and audio sinks under the
 * settings contract. Pure Kotlin so disabled-settings and exactly-once
 * behavior is unit-testable without Android framework classes.
 */
class SensoryDispatcher(
    private val settings: GameSettingsStore,
    private val haptics: HapticSink,
    private val sfx: SfxSink
) : SensoryClient {
    override fun reversed() {
        if (settings.hapticsEnabled) haptics.impact(ImpactKind.REVERSE)
        if (settings.soundEnabled) sfx.tone(ToneKind.REVERSE)
    }

    override fun collected() {
        if (settings.hapticsEnabled) haptics.impact(ImpactKind.COLLECT)
        if (settings.soundEnabled) sfx.tone(ToneKind.COLLECT)
    }

    override fun collided() {
        if (settings.hapticsEnabled) haptics.impact(ImpactKind.COLLISION)
        if (settings.soundEnabled) sfx.tone(ToneKind.COLLISION)
    }

    override fun proximity(value: Double, pulseActive: Boolean) {
        if (!settings.hapticsEnabled) return
        val clamped = value.coerceIn(0.0, 1.0)
        if (clamped < PROXIMITY_FLOOR) {
            haptics.stopContinuous()
            return
        }
        val intensity = ((0.18 + 0.72 * clamped) * if (pulseActive) 1f else 0.42f).toFloat()
        val sharpness = (-0.45 + 0.90 * clamped).toFloat()
        haptics.proximityPulse(intensity, sharpness)
    }

    override fun stoppedContinuous() {
        haptics.stopContinuous()
    }

    companion object {
        const val PROXIMITY_FLOOR = 0.15
    }
}

/**
 * Translates engine snapshot diffs into exactly-once sensory events. Mirrors
 * the iOS engine's sensory call sites without touching the pure engine.
 */
class SensoryEventDetector(private val client: SensoryClient) {
    private var lastDirection = 1.0
    private var lastCollectionSerial = 0
    private var lastState: GameState? = null

    fun onSnapshot(snapshot: GameSnapshot) {
        val state = snapshot.state
        if (lastState == GameState.PLAYING && state == GameState.OVER) {
            client.stoppedContinuous()
            if (snapshot.runOutcome == GameRunOutcome.COLLISION) {
                client.collided()
            }
        }
        if (lastState == GameState.PLAYING && state == GameState.PAUSED) {
            client.stoppedContinuous()
        }
        if (state == GameState.PLAYING) {
            if (snapshot.collectionSerial != lastCollectionSerial) {
                client.collected()
            }
            if (lastState != null && snapshot.direction != lastDirection) {
                client.reversed()
            }
            updateProximity(snapshot)
        }
        lastDirection = snapshot.direction
        lastCollectionSerial = snapshot.collectionSerial
        lastState = state
    }

    fun reset(snapshot: GameSnapshot) {
        lastDirection = snapshot.direction
        lastCollectionSerial = snapshot.collectionSerial
        lastState = snapshot.state
    }

    private fun updateProximity(snapshot: GameSnapshot) {
        if (snapshot.session.effectiveModeId != GameModeId.PRECISION_PULSE) {
            client.stoppedContinuous()
            return
        }
        val distance = AngleMath.distance(snapshot.ballAngle, snapshot.gem.angle)
        client.proximity(max(0.0, 1.0 - distance / PROXIMITY_RANGE), snapshot.pulseIsActive)
    }

    companion object {
        const val PROXIMITY_RANGE = 0.90
    }
}
