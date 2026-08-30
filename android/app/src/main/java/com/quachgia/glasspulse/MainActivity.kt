package com.quachgia.glasspulse

import android.os.Bundle
import androidx.activity.SystemBarStyle
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.appcompat.app.AppCompatActivity
import androidx.appcompat.app.AppCompatDelegate
import androidx.core.os.LocaleListCompat
import androidx.core.splashscreen.SplashScreen.Companion.installSplashScreen

class MainActivity : AppCompatActivity() {
    private lateinit var gameController: GameController

    override fun onCreate(savedInstanceState: Bundle?) {
        installSplashScreen()
        super.onCreate(savedInstanceState)
        val systemBarScrim = android.graphics.Color.rgb(2, 4, 15)
        enableEdgeToEdge(
            statusBarStyle = SystemBarStyle.dark(systemBarScrim),
            navigationBarStyle = SystemBarStyle.dark(systemBarScrim)
        )
        val settings = GameSettingsStore.fromContext(applicationContext)
        seedReduceMotionFromSystem(settings)
        syncPerAppLocale(settings)
        gameController = GameController(
            context = applicationContext,
            betaFullAccess = BuildConfig.BETA_FULL_ACCESS,
            settings = settings
        )
        setContent {
            val palette = gameController.uiState.activeThemeId.palette()
            GlassPulseTheme(palette = palette) {
                GlassPulseGame(controller = gameController)
            }
        }
    }

    override fun onResume() {
        super.onResume()
        if (::gameController.isInitialized) {
            gameController.resumeForeground()
        }
    }

    override fun onPause() {
        if (::gameController.isInitialized) {
            gameController.pauseForBackground()
        }
        super.onPause()
    }

    override fun onDestroy() {
        if (::gameController.isInitialized) {
            gameController.releaseSensory()
        }
        super.onDestroy()
    }

    private fun seedReduceMotionFromSystem(settings: GameSettingsStore) {
        if (settings.reduceMotionInitialized) return
        settings.updateReduceMotionEnabled(systemReduceMotion(this))
    }

    /**
     * Keeps the in-app picker and the platform per-app locale store in sync in
     * both directions: a stored in-app choice applies through AppCompatDelegate
     * (API 26-32 backport, framework on 33+), and a system-side change is
     * adopted back into the settings store.
     */
    private fun syncPerAppLocale(settings: GameSettingsStore) {
        val activeLocales = AppCompatDelegate.getApplicationLocales()
        if (activeLocales.isEmpty) {
            settings.language.tag?.let { tag ->
                AppCompatDelegate.setApplicationLocales(LocaleListCompat.forLanguageTags(tag))
            }
            return
        }
        val activeTag = activeLocales[0]?.toLanguageTag()
        val activeLanguage = AppLanguage.fromTag(activeTag)
        if (activeLanguage != settings.language) {
            settings.updateLanguage(activeLanguage)
        }
    }
}
