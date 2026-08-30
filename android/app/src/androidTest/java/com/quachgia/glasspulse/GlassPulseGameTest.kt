package com.quachgia.glasspulse

import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.junit4.createAndroidComposeRule
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.performClick
import androidx.test.ext.junit.runners.AndroidJUnit4
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class GlassPulseGameTest {
    @get:Rule
    val composeRule = createAndroidComposeRule<MainActivity>()

    @Test
    fun playableGameIsTheLaunchDestination() {
        composeRule.onNodeWithTag("game.screen").assertIsDisplayed()
        composeRule.onNodeWithTag("game.input.surface").assertIsDisplayed()
        composeRule.onNodeWithTag("game.board").assertIsDisplayed()
        composeRule.onNodeWithTag("game.modes").assertIsDisplayed()
    }

    @Test
    fun fullScreenInputStartsAndPauseResumeWorks() {
        composeRule.onNodeWithTag("game.input.surface").performClick()
        composeRule.onNodeWithTag("game.pause").assertIsDisplayed().performClick()
        composeRule.onNodeWithTag("game.resume").assertIsDisplayed().performClick()
        composeRule.onNodeWithTag("game.pause").assertIsDisplayed()
    }

    @Test
    fun betaModePickerContainsAllModes() {
        composeRule.onNodeWithTag("game.modes").performClick()
        composeRule.onNodeWithTag("mode.classic").assertExists()
        composeRule.onNodeWithTag("mode.rush_60").assertExists()
        composeRule.onNodeWithTag("mode.precision_pulse").assertExists()
        composeRule.onNodeWithTag("mode.wave_survival").assertExists()
        composeRule.onNodeWithTag("mode.daily_challenge").assertExists()
    }
}
