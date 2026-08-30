package com.quachgia.glasspulse

import android.content.Context
import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioManager
import android.media.AudioTrack
import android.os.Build
import android.os.PowerManager
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import kotlin.math.PI
import kotlin.math.pow
import kotlin.math.roundToInt
import kotlin.math.sin

/**
 * Framework edge for haptics and procedural SFX. Capability-aware with
 * amplitude fallbacks so reverse/collect/collision stay perceptibly distinct.
 * The pure dispatcher in Sensory.kt owns gating; this class owns hardware.
 */
class AndroidHapticSink(context: Context) : HapticSink {
    private val vibrator: Vibrator = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
        val manager = context.getSystemService(VibratorManager::class.java)
        manager.defaultVibrator
    } else {
        @Suppress("DEPRECATION")
        context.getSystemService(Vibrator::class.java)
    }
    private val powerManager = context.getSystemService(PowerManager::class.java)
    private val primitivesSupported = Build.VERSION.SDK_INT >= Build.VERSION_CODES.R &&
        vibrator.areAllPrimitivesSupported(
            VibrationEffect.Composition.PRIMITIVE_CLICK,
            VibrationEffect.Composition.PRIMITIVE_THUD
        )
    private val hasAmplitudeControl = vibrator.hasAmplitudeControl()
    private var proximityActive = false
    private var lastProximityNanos = 0L
    private val proximityEffects: List<VibrationEffect> = buildProximityEffects()

    override fun impact(kind: ImpactKind) {
        if (!vibrator.hasVibrator()) return
        when (kind) {
            ImpactKind.REVERSE -> vibrate(lightEffect())
            ImpactKind.COLLECT -> vibrate(strongEffect())
            ImpactKind.COLLISION -> vibrate(errorEffect())
        }
    }

    override fun proximityPulse(intensity: Float, sharpness: Float) {
        if (!vibrator.hasVibrator()) return
        if (powerManager.isPowerSaveMode) return
        val now = System.nanoTime()
        if (now - lastProximityNanos < THROTTLE_NANOS) return
        lastProximityNanos = now
        val bucket = (intensity.coerceIn(0f, 1f) * (proximityEffects.size - 1)).roundToInt()
        vibrate(proximityEffects[bucket])
        proximityActive = true
    }

    override fun stopContinuous() {
        lastProximityNanos = 0L
        if (proximityActive) {
            proximityActive = false
            vibrator.cancel()
        }
    }

    private fun vibrate(effect: VibrationEffect) {
        vibrator.vibrate(effect)
    }

    private fun lightEffect(): VibrationEffect = when {
        Build.VERSION.SDK_INT >= Build.VERSION_CODES.R && primitivesSupported ->
            VibrationEffect.startComposition()
                .addPrimitive(VibrationEffect.Composition.PRIMITIVE_CLICK, 0.58f)
                .compose()
        hasAmplitudeControl -> VibrationEffect.createWaveform(LIGHT_TIMING, LIGHT_AMPLITUDES, -1)
        else -> VibrationEffect.createOneShot(24, VibrationEffect.DEFAULT_AMPLITUDE)
    }

    private fun strongEffect(): VibrationEffect = when {
        Build.VERSION.SDK_INT >= Build.VERSION_CODES.R && primitivesSupported ->
            VibrationEffect.startComposition()
                .addPrimitive(VibrationEffect.Composition.PRIMITIVE_THUD, 0.78f)
                .compose()
        hasAmplitudeControl -> VibrationEffect.createWaveform(STRONG_TIMING, STRONG_AMPLITUDES, -1)
        else -> VibrationEffect.createOneShot(48, VibrationEffect.DEFAULT_AMPLITUDE)
    }

    private fun errorEffect(): VibrationEffect = when {
        Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q ->
            VibrationEffect.createPredefined(VibrationEffect.EFFECT_DOUBLE_CLICK)
        hasAmplitudeControl -> VibrationEffect.createWaveform(ERROR_TIMING, ERROR_AMPLITUDES, -1)
        else -> VibrationEffect.createWaveform(ERROR_TIMING, null, -1)
    }

    private fun buildProximityEffects(): List<VibrationEffect> {
        if (!hasAmplitudeControl) {
            return List(PROXIMITY_BUCKETS) { VibrationEffect.createOneShot(12, 96) }
        }
        return List(PROXIMITY_BUCKETS) { index ->
            val amplitude = (64 + index * (255 - 64) / (PROXIMITY_BUCKETS - 1)).toByte().toInt()
            VibrationEffect.createWaveform(longArrayOf(0, 12), intArrayOf(0, amplitude), -1)
        }
    }

    private companion object {
        const val THROTTLE_NANOS = 1_000_000_000L / 25L
        const val PROXIMITY_BUCKETS = 8
        val LIGHT_TIMING = longArrayOf(0, 24)
        val LIGHT_AMPLITUDES = intArrayOf(0, 96)
        val STRONG_TIMING = longArrayOf(0, 48)
        val STRONG_AMPLITUDES = intArrayOf(0, 168)
        val ERROR_TIMING = longArrayOf(0, 40, 60, 40)
        val ERROR_AMPLITUDES = intArrayOf(0, 255, 0, 255)
    }
}

/**
 * Cached procedural event tones mirroring the iOS SensoryEngine frequencies,
 * durations and envelopes. One static-mode AudioTrack per tone, created once.
 */
class AndroidSfxSink : SfxSink {
    private val tracks: MutableMap<ToneKind, AudioTrack> = mutableMapOf()

    override fun tone(kind: ToneKind) {
        val track = tracks.getOrPut(kind) { createTrack(kind) }
        synchronized(track) {
            track.stop()
            track.reload()
            track.play()
        }
    }

    fun release() {
        tracks.values.forEach { it.release() }
        tracks.clear()
    }

    private fun createTrack(kind: ToneKind): AudioTrack {
        val event = when (kind) {
            ToneKind.REVERSE -> ToneEvent(310.0, 0.055, 0.035f)
            ToneKind.COLLECT -> ToneEvent(760.0, 0.110, 0.070f)
            ToneKind.COLLISION -> ToneEvent(118.0, 0.200, 0.060f)
        }
        val sampleRate = 44_100
        val frameCount = (sampleRate * event.durationSeconds).toInt()
        val pcm = ByteArray(frameCount * 2)
        for (frame in 0 until frameCount) {
            val progress = frame.toDouble() / (frameCount - 1).coerceAtLeast(1)
            val phase = 2.0 * PI * event.frequencyHz * frame / sampleRate
            val envelope = (progress / 0.08).coerceAtMost(1.0) * (1 - progress).pow(2)
            val sample = (sin(phase) * envelope * 0.20 * Short.MAX_VALUE).toInt().toShort()
            val offset = frame * 2
            pcm[offset] = (sample.toInt() and 0xFF).toByte()
            pcm[offset + 1] = ((sample.toInt() shr 8) and 0xFF).toByte()
        }
        val track = AudioTrack.Builder()
            .setAudioAttributes(
                AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_GAME)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                    .build()
            )
            .setAudioFormat(
                AudioFormat.Builder()
                    .setEncoding(AudioFormat.ENCODING_PCM_16BIT)
                    .setSampleRate(sampleRate)
                    .setChannelMask(AudioFormat.CHANNEL_OUT_MONO)
                    .build()
            )
            .setTransferMode(AudioTrack.MODE_STATIC)
            .setBufferSizeInBytes(pcm.size)
            .build()
        track.write(pcm, 0, pcm.size)
        track.setVolume(event.volume)
        return track
    }

    private data class ToneEvent(
        val frequencyHz: Double,
        val durationSeconds: Double,
        val volume: Float
    )
}
