package com.quachgia.glasspulse

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.core.splashscreen.SplashScreen.Companion.installSplashScreen

class MainActivity : ComponentActivity() {
    private lateinit var gameController: GameController

    override fun onCreate(savedInstanceState: Bundle?) {
        installSplashScreen()
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        gameController = GameController(
            context = applicationContext,
            betaFullAccess = BuildConfig.BETA_FULL_ACCESS
        )
        setContent {
            GlassPulseTheme {
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
