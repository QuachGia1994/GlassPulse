package com.quachgia.glasspulse

import android.content.Context
import android.content.SharedPreferences
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.core.content.edit
import java.time.LocalDate
import kotlin.math.max

enum class PulseThemeId {
    CLARITY,
    EMBER,
    AURORA,
    PRISM_PLUS
}

data class PlayerSnapshot(
    val bestScore: Int,
    val dailyStreak: Int,
    val totalShards: Int,
    val selectedModeId: GameModeId,
    val selectedThemeId: PulseThemeId,
    val dailyBest: Int
)

data class GameUiState(
    val game: GameSnapshot,
    val player: PlayerSnapshot,
    val activeThemeId: PulseThemeId,
    val betaFullAccess: Boolean,
    val dailyBonus: Int,
    val frameTimeNanos: Long,
    val reduceMotion: Boolean,
    val highContrast: Boolean
)

class GameController(
    context: Context,
    private val betaFullAccess: Boolean,
    val settings: GameSettingsStore
) {
    private val profile = GameProfile(context)
    private var engine = GameEngine(sessionFor(profile.activeMode(betaFullAccess)))
    private var settledCurrentRun = false
    private var dailyBonus = 0
    private val music = MusicController(context, settings)
    private val sensoryDispatcher = SensoryDispatcher(
        settings = settings,
        haptics = AndroidHapticSink(context),
        sfx = AndroidSfxSink()
    )
    private val sensoryDetector = SensoryEventDetector(sensoryDispatcher)

    var uiState by mutableStateOf(buildUiState(System.nanoTime(), engine.snapshot()))
        private set

    fun onLaunchUiReady() {
        music.startIfReady()
    }

    fun resumeForeground() {
        music.resumeIfAppropriate()
    }

    fun applyMusicSettings() {
        music.applySettings()
    }

    fun releaseSensory() {
        music.release()
    }

    fun advance(frameTimeNanos: Long) {
        val previousState = engine.state
        engine.advance(frameTimeNanos)
        if (previousState != GameState.OVER && engine.state == GameState.OVER) {
            settleCurrentRun()
        }
        publish(frameTimeNanos)
    }

    fun handleSurfaceTap(nowNanos: Long = System.nanoTime()) {
        if (engine.state == GameState.PAUSED || engine.state == GameState.OVER) return
        engine.handleTap(nowNanos)
        publish(nowNanos)
    }

    fun pause() {
        engine.pause()
        publish(System.nanoTime())
    }

    fun resume(nowNanos: Long = System.nanoTime()) {
        engine.resume(nowNanos)
        publish(nowNanos)
    }

    fun retry(nowNanos: Long = System.nanoTime()) {
        if (engine.state != GameState.OVER) return
        replaceEngine(engine.session.replayContext())
        engine.handleTap(nowNanos)
        publish(nowNanos)
    }

    fun selectMode(modeId: GameModeId): Boolean {
        if (!canChangeMode() || !canUseMode(modeId)) return false
        profile.selectMode(modeId)
        replaceEngine(sessionFor(modeId))
        publish(System.nanoTime())
        return true
    }

    fun selectTheme(themeId: PulseThemeId): Boolean {
        val selected = profile.selectTheme(themeId, betaFullAccess)
        if (selected) publish(System.nanoTime())
        return selected
    }

    fun canUseMode(modeId: GameModeId): Boolean =
        !modeId.requiresPlus || betaFullAccess

    fun canUseTheme(themeId: PulseThemeId): Boolean =
        profile.canUseTheme(themeId, betaFullAccess)

    fun canChangeMode(): Boolean =
        engine.state == GameState.START || engine.state == GameState.OVER

    fun pauseForBackground() {
        if (engine.state == GameState.PLAYING) pause()
        music.pauseForBackground()
    }

    private fun replaceEngine(session: GameSessionContext) {
        engine = GameEngine(session)
        settledCurrentRun = false
        dailyBonus = 0
        sensoryDetector.reset(engine.snapshot())
    }

    private fun settleCurrentRun() {
        if (settledCurrentRun) return
        settledCurrentRun = true
        profile.recordRun(engine.score, engine.rewardForCurrentRun)
        dailyBonus = settleDailyIfNeeded()
    }

    private fun settleDailyIfNeeded(): Int {
        if (engine.session.modeId != GameModeId.DAILY_CHALLENGE) return 0
        if (engine.runOutcome != GameRunOutcome.COMPLETED) return 0
        val dayKey = engine.session.dailyKey ?: return 0
        return profile.recordDailyCompletion(
            dayKey = dayKey,
            score = engine.score,
            firstClearBonus = engine.rules.dailyFirstClearBonus
        )
    }

    private fun publish(frameTimeNanos: Long) {
        val snapshot = engine.snapshot()
        sensoryDetector.onSnapshot(snapshot)
        uiState = buildUiState(frameTimeNanos, snapshot)
    }

    private fun buildUiState(frameTimeNanos: Long, snapshot: GameSnapshot): GameUiState {
        return GameUiState(
            game = snapshot,
            player = profile.snapshot(snapshot.session.dailyKey),
            activeThemeId = profile.activeTheme(betaFullAccess),
            betaFullAccess = betaFullAccess,
            dailyBonus = dailyBonus,
            frameTimeNanos = frameTimeNanos,
            reduceMotion = settings.reduceMotionEnabled,
            highContrast = settings.highContrastEnabled
        )
    }

    private fun sessionFor(modeId: GameModeId): GameSessionContext =
        if (modeId == GameModeId.DAILY_CHALLENGE) {
            GameSessionContext.daily()
        } else {
            GameSessionContext.standard(modeId)
        }
}

private class GameProfile(context: Context) {
    private val preferences: SharedPreferences = context.getSharedPreferences(
        "glass_pulse_profile",
        Context.MODE_PRIVATE
    )

    private var bestScore = preferences.getInt(KEY_BEST_SCORE, 0)
    private var dailyStreak = preferences.getInt(KEY_DAILY_STREAK, 0)
    private var totalShards = preferences.getInt(KEY_TOTAL_SHARDS, 0)
    private var lastDailyKey = preferences.getString(KEY_LAST_DAILY, null)
    private var dailyBestKey = preferences.getString(KEY_DAILY_BEST_KEY, null)
    private var dailyBestScore = preferences.getInt(KEY_DAILY_BEST_SCORE, 0)
    private var dailyRewardKey = preferences.getString(KEY_DAILY_REWARD_KEY, null)
    private var selectedMode = enumPreference(KEY_SELECTED_MODE, GameModeId.CLASSIC)
    private var selectedTheme = enumPreference(KEY_SELECTED_THEME, PulseThemeId.CLARITY)
    private var ownedThemes = preferences
        .getStringSet(KEY_OWNED_THEMES, emptySet())
        .orEmpty()
        .toMutableSet()
        .apply { add(PulseThemeId.CLARITY.name) }

    fun snapshot(currentDailyKey: String?): PlayerSnapshot = PlayerSnapshot(
        bestScore = bestScore,
        dailyStreak = dailyStreak,
        totalShards = totalShards,
        selectedModeId = selectedMode,
        selectedThemeId = selectedTheme,
        dailyBest = if (dailyBestKey == currentDailyKey) dailyBestScore else 0
    )

    fun activeMode(betaFullAccess: Boolean): GameModeId {
        if (!selectedMode.requiresPlus || betaFullAccess) return selectedMode
        return GameModeId.CLASSIC
    }

    fun selectMode(modeId: GameModeId) {
        selectedMode = modeId
        preferences.edit { putString(KEY_SELECTED_MODE, modeId.name) }
    }

    fun activeTheme(betaFullAccess: Boolean): PulseThemeId {
        if (canUseTheme(selectedTheme, betaFullAccess)) return selectedTheme
        return PulseThemeId.CLARITY
    }

    fun canUseTheme(themeId: PulseThemeId, betaFullAccess: Boolean): Boolean {
        if (betaFullAccess || themeId == PulseThemeId.CLARITY) return true
        if (themeId == PulseThemeId.PRISM_PLUS) return false
        return ownedThemes.contains(themeId.name)
    }

    fun selectTheme(themeId: PulseThemeId, betaFullAccess: Boolean): Boolean {
        if (betaFullAccess || themeId == PulseThemeId.CLARITY) {
            persistSelectedTheme(themeId)
            return true
        }
        if (themeId == PulseThemeId.PRISM_PLUS) return false
        return purchaseTheme(themeId, themePrice(themeId))
    }

    fun recordRun(score: Int, reward: Int) {
        bestScore = max(bestScore, score)
        totalShards += max(0, reward)
        preferences.edit {
            putInt(KEY_BEST_SCORE, bestScore)
            putInt(KEY_TOTAL_SHARDS, totalShards)
        }
    }

    fun recordDailyCompletion(
        dayKey: String,
        score: Int,
        firstClearBonus: Int
    ): Int {
        updateDailyBest(dayKey, score)
        updateDailyStreak(dayKey)
        val bonus = if (dailyRewardKey == dayKey) 0 else max(0, firstClearBonus)
        if (bonus > 0) {
            dailyRewardKey = dayKey
            totalShards += bonus
        }
        persistDaily()
        return bonus
    }

    private fun purchaseTheme(themeId: PulseThemeId, price: Int): Boolean {
        if (!ownedThemes.contains(themeId.name)) {
            if (totalShards < price) return false
            totalShards -= price
            ownedThemes.add(themeId.name)
        }
        persistSelectedTheme(themeId)
        preferences.edit {
            putInt(KEY_TOTAL_SHARDS, totalShards)
            putStringSet(KEY_OWNED_THEMES, ownedThemes.toSet())
        }
        return true
    }

    private fun updateDailyBest(dayKey: String, score: Int) {
        if (dailyBestKey != dayKey) {
            dailyBestKey = dayKey
            dailyBestScore = max(0, score)
            return
        }
        dailyBestScore = max(dailyBestScore, score)
    }

    private fun updateDailyStreak(dayKey: String) {
        if (lastDailyKey == dayKey) return
        val currentDate = runCatching { LocalDate.parse(dayKey) }.getOrNull()
        val previousDate = lastDailyKey?.let { key ->
            runCatching { LocalDate.parse(key) }.getOrNull()
        }
        dailyStreak = if (currentDate != null && previousDate == currentDate.minusDays(1)) {
            max(1, dailyStreak + 1)
        } else {
            1
        }
        lastDailyKey = dayKey
    }

    private fun persistDaily() {
        preferences.edit {
            putInt(KEY_DAILY_STREAK, dailyStreak)
            putString(KEY_LAST_DAILY, lastDailyKey)
            putString(KEY_DAILY_BEST_KEY, dailyBestKey)
            putInt(KEY_DAILY_BEST_SCORE, dailyBestScore)
            putString(KEY_DAILY_REWARD_KEY, dailyRewardKey)
            putInt(KEY_TOTAL_SHARDS, totalShards)
        }
    }

    private fun persistSelectedTheme(themeId: PulseThemeId) {
        selectedTheme = themeId
        preferences.edit { putString(KEY_SELECTED_THEME, themeId.name) }
    }

    private fun themePrice(themeId: PulseThemeId): Int = when (themeId) {
        PulseThemeId.EMBER -> 18
        PulseThemeId.AURORA -> 45
        PulseThemeId.CLARITY, PulseThemeId.PRISM_PLUS -> 0
    }

    private inline fun <reified T : Enum<T>> enumPreference(key: String, fallback: T): T =
        preferences.getString(key, null)
            ?.let { stored -> enumValues<T>().firstOrNull { it.name == stored } }
            ?: fallback

    private companion object {
        const val KEY_BEST_SCORE = "best_score"
        const val KEY_DAILY_STREAK = "daily_streak"
        const val KEY_TOTAL_SHARDS = "total_shards"
        const val KEY_LAST_DAILY = "last_daily_key"
        const val KEY_DAILY_BEST_KEY = "daily_best_key"
        const val KEY_DAILY_BEST_SCORE = "daily_best_score"
        const val KEY_DAILY_REWARD_KEY = "daily_reward_key"
        const val KEY_SELECTED_MODE = "selected_mode"
        const val KEY_SELECTED_THEME = "selected_theme"
        const val KEY_OWNED_THEMES = "owned_themes"
    }
}
