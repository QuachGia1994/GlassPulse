package com.quachgia.glasspulse

import android.content.Context
import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.media.AudioManager
import android.media.MediaPlayer

/**
 * Bundled background-music loop (res/raw/bgm.ogg, one pinned master). Starts
 * only after the launch UI is ready, pauses on background/audio-focus loss,
 * ducks on transient loss and resumes only when enabled and previously playing.
 */
class MusicController(
    context: Context,
    private val settings: GameSettingsStore
) {
    private val appContext = context.applicationContext
    private val audioManager = context.getSystemService(AudioManager::class.java)
    private var player: MediaPlayer? = null
    private var focusRequest: AudioFocusRequest? = null
    private var wasPlayingBeforeLoss = false
    private var ducked = false
    private var released = false

    /** Called once the launch UI is ready; never double-starts across recreations. */
    fun startIfReady() {
        if (released || !settings.musicEnabled) return
        ensurePlayer()
        requestFocus()
        play()
    }

    fun pauseForBackground() {
        if (isPlaying()) {
            wasPlayingBeforeLoss = true
        }
        pause()
        abandonFocus()
    }

    fun resumeIfAppropriate() {
        if (released || !settings.musicEnabled) return
        if (wasPlayingBeforeLoss || isPlaying()) {
            wasPlayingBeforeLoss = false
            ensurePlayer()
            requestFocus()
            play()
        }
    }

    fun applySettings() {
        if (released) return
        if (settings.musicEnabled) {
            ensurePlayer()
            requestFocus()
            play()
        } else {
            wasPlayingBeforeLoss = false
            pause()
            abandonFocus()
        }
    }

    fun release() {
        released = true
        abandonFocus()
        player?.run {
            stop()
            release()
        }
        player = null
    }

    private fun ensurePlayer() {
        if (player != null) return
        player = MediaPlayer.create(appContext, R.raw.bgm)?.apply {
            isLooping = true
            setVolume(MUSIC_VOLUME, MUSIC_VOLUME)
        }
    }

    private fun play() {
        val mediaPlayer = player ?: return
        if (mediaPlayer.isPlaying) return
        mediaPlayer.start()
        setDucked(ducked)
    }

    private fun pause() {
        val mediaPlayer = player ?: return
        if (mediaPlayer.isPlaying) {
            mediaPlayer.pause()
        }
    }

    private fun isPlaying(): Boolean = player?.isPlaying == true

    private fun requestFocus() {
        if (focusRequest != null) return
        val request = AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN)
            .setAudioAttributes(
                AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_GAME)
                    .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                    .build()
            )
            .setOnAudioFocusChangeListener(::handleFocusChange)
            .setWillPauseWhenDucked(true)
            .build()
        focusRequest = request
        audioManager.requestAudioFocus(request)
    }

    private fun abandonFocus() {
        val request = focusRequest ?: return
        audioManager.abandonAudioFocusRequest(request)
        focusRequest = null
    }

    private fun handleFocusChange(change: Int) {
        when (change) {
            AudioManager.AUDIOFOCUS_LOSS -> {
                wasPlayingBeforeLoss = isPlaying()
                pause()
                abandonFocus()
            }
            AudioManager.AUDIOFOCUS_LOSS_TRANSIENT -> {
                wasPlayingBeforeLoss = isPlaying()
                pause()
            }
            AudioManager.AUDIOFOCUS_LOSS_TRANSIENT_CAN_DUCK -> {
                wasPlayingBeforeLoss = isPlaying()
                setDucked(true)
            }
            AudioManager.AUDIOFOCUS_GAIN -> {
                if (wasPlayingBeforeLoss && settings.musicEnabled) {
                    wasPlayingBeforeLoss = false
                    setDucked(false)
                    play()
                } else {
                    setDucked(false)
                }
            }
        }
    }

    private fun setDucked(duck: Boolean) {
        ducked = duck
        val volume = if (duck) DUCK_VOLUME else MUSIC_VOLUME
        player?.setVolume(volume, volume)
    }

    private companion object {
        const val MUSIC_VOLUME = 0.35f
        const val DUCK_VOLUME = 0.12f
    }
}
