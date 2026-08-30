package com.quachgia.glasspulse

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.SystemBarStyle
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.core.splashscreen.SplashScreen.Companion.installSplashScreen

class MainActivity : ComponentActivity() {
    private lateinit var gameController: GameController

    override fun onCreate(savedInstanceState: Bundle?) {
        installSplashScreen()
        super.onCreate(savedInstanceState)
        val systemBarScrim = android.graphics.Color.rgb(2, 4, 15)
        enableEdgeToEdge(
            statusBarStyle = SystemBarStyle.dark(systemBarScrim),
            navigationBarStyle = SystemBarStyle.dark(systemBarScrim)
        )
        gameController = GameController(
            context = applicationContext,
            betaFullAccess = BuildConfig.BETA_FULL_ACCESS
        )
        setContent {
            val palette = gameController.uiState.activeThemeId.palette()
            GlassPulseTheme(palette = palette) {
                GlassPulseGame(controller = gameController)
            }
        }
    }

    override fun onPause() {
        if (::gameController.isInitialized) {
            gameController.pauseForBackground()
        }
        super.onPause()
    }
}
