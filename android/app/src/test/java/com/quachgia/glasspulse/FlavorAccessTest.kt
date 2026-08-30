package com.quachgia.glasspulse

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Assert.fail
import org.junit.Test

class FlavorAccessTest {
    @Test
    fun compileTimeBetaBoundaryMatchesFlavorContract() {
        when (BuildConfig.FLAVOR) {
            "production" -> {
                assertFalse(BuildConfig.BETA_FULL_ACCESS)
                assertEquals("com.quachgia.glasspulse", BuildConfig.APPLICATION_ID)
            }
            "beta" -> {
                assertTrue(BuildConfig.BETA_FULL_ACCESS)
                assertEquals("com.quachgia.glasspulse.beta", BuildConfig.APPLICATION_ID)
            }
            else -> fail("Unexpected flavor: ${BuildConfig.FLAVOR}")
        }
    }
}
