package com.quachgia.glasspulse

import android.content.Context
import android.content.SharedPreferences
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.core.content.edit

enum class AppLanguage(val tag: String?) {
    SYSTEM(null),
    ENGLISH("en"),
    VIETNAMESE("vi"),
    JAPANESE("ja"),
    SIMPLIFIED_CHINESE("zh-CN");

    companion object {
        fun fromTag(tag: String?): AppLanguage = entries.firstOrNull { it.tag == tag } ?: SYSTEM
    }
}

fun systemReduceMotion(context: Context): Boolean =
    android.provider.Settings.Global.getFloat(
        context.contentResolver,
        android.provider.Settings.Global.ANIMATOR_DURATION_SCALE,
        1f
    ) == 0f

interface KeyValueStore {
    fun bool(key: String, fallback: Boolean): Boolean
    fun putBool(key: String, value: Boolean)
    fun string(key: String): String?
    fun putString(key: String, value: String)
}

class SharedPreferencesStore(
    private val preferences: SharedPreferences
) : KeyValueStore {
    override fun bool(key: String, fallback: Boolean): Boolean =
        preferences.getBoolean(key, fallback)

    override fun putBool(key: String, value: Boolean) {
        preferences.edit { putBoolean(key, value) }
    }

    override fun string(key: String): String? = preferences.getString(key, null)

    override fun putString(key: String, value: String) {
        preferences.edit { putString(key, value) }
    }

    companion object {
        fun fromContext(context: Context): SharedPreferencesStore =
            SharedPreferencesStore(
                context.getSharedPreferences("glass_pulse_settings", Context.MODE_PRIVATE)
            )
    }
}

class InMemoryKeyValueStore : KeyValueStore {
    private val values = mutableMapOf<String, Any>()

    override fun bool(key: String, fallback: Boolean): Boolean = values[key] as? Boolean ?: fallback

    override fun putBool(key: String, value: Boolean) {
        values[key] = value
    }

    override fun string(key: String): String? = values[key] as? String

    override fun putString(key: String, value: String) {
        values[key] = value
    }
}

/**
 * Cross-platform settings source of truth. One store per platform; views and
 * the sensory/music layers observe it. Profile data (score, shards, mode,
 * theme, Daily) stays in GameProfile's own storage and is untouched here.
 */
class GameSettingsStore(private val store: KeyValueStore) {
    private enum class Key(val id: String) {
        MUSIC_ENABLED("settings.music_enabled"),
        SOUND_ENABLED("settings.sound_enabled"),
        HAPTICS_ENABLED("settings.haptics_enabled"),
        REDUCE_MOTION_ENABLED("settings.reduce_motion_enabled"),
        REDUCE_MOTION_INITIALIZED("settings.reduce_motion_initialized"),
        HIGH_CONTRAST_ENABLED("settings.high_contrast_enabled"),
        LANGUAGE("settings.language")
    }

    var musicEnabled: Boolean by mutableStateOf(store.bool(Key.MUSIC_ENABLED.id, true))
        private set
    var soundEnabled: Boolean by mutableStateOf(store.bool(Key.SOUND_ENABLED.id, true))
        private set
    var hapticsEnabled: Boolean by mutableStateOf(store.bool(Key.HAPTICS_ENABLED.id, true))
        private set
    var reduceMotionEnabled: Boolean by mutableStateOf(
        store.bool(Key.REDUCE_MOTION_ENABLED.id, false)
    )
        private set
    var highContrastEnabled: Boolean by mutableStateOf(
        store.bool(Key.HIGH_CONTRAST_ENABLED.id, false)
    )
        private set
    var language: AppLanguage by mutableStateOf(AppLanguage.fromTag(store.string(Key.LANGUAGE.id)))
        private set

    val reduceMotionInitialized: Boolean
        get() = store.bool(Key.REDUCE_MOTION_INITIALIZED.id, false)

    fun updateMusicEnabled(enabled: Boolean) {
        musicEnabled = enabled
        store.putBool(Key.MUSIC_ENABLED.id, enabled)
    }

    fun updateSoundEnabled(enabled: Boolean) {
        soundEnabled = enabled
        store.putBool(Key.SOUND_ENABLED.id, enabled)
    }

    fun updateHapticsEnabled(enabled: Boolean) {
        hapticsEnabled = enabled
        store.putBool(Key.HAPTICS_ENABLED.id, enabled)
    }

    fun updateReduceMotionEnabled(enabled: Boolean) {
        reduceMotionEnabled = enabled
        store.putBool(Key.REDUCE_MOTION_ENABLED.id, enabled)
        store.putBool(Key.REDUCE_MOTION_INITIALIZED.id, true)
    }

    fun updateHighContrastEnabled(enabled: Boolean) {
        highContrastEnabled = enabled
        store.putBool(Key.HIGH_CONTRAST_ENABLED.id, enabled)
    }

    fun updateLanguage(language: AppLanguage) {
        this.language = language
        store.putString(Key.LANGUAGE.id, language.tag ?: "")
    }

    companion object {
        fun fromContext(context: Context): GameSettingsStore =
            GameSettingsStore(SharedPreferencesStore.fromContext(context))
    }
}
