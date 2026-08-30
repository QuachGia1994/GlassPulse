package com.quachgia.glasspulse

import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.junit4.createAndroidComposeRule
import androidx.compose.ui.test.onNodeWithTag
import androidx.test.ext.junit.runners.AndroidJUnit4
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class AndroidBetaShellTest {
    @get:Rule
    val composeRule = createAndroidComposeRule<MainActivity>()

    @Test
    fun brandedShellAndAccessChannelAreVisible() {
        composeRule.onNodeWithTag("android.shell").assertIsDisplayed()
        composeRule.onNodeWithTag("android.logo").assertIsDisplayed()
        composeRule.onNodeWithTag("android.access.value").assertIsDisplayed()
        composeRule.onNodeWithTag("android.scope.button").assertIsDisplayed()
    }
}
