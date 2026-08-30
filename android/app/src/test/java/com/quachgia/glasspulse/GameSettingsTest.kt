package com.quachgia.glasspulse

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class GameSettingsTest {
    private fun newStore(): GameSettingsStore = GameSettingsStore(InMemoryKeyValueStore())

    @Test
    fun freshInstallDefaultsMatchCrossPlatformContract() {
        val settings = newStore()

        assertTrue(settings.musicEnabled)
        assertTrue(settings.soundEnabled)
        assertTrue(settings.hapticsEnabled)
        assertFalse(settings.highContrastEnabled)
        assertFalse(settings.reduceMotionEnabled)
        assertEquals(AppLanguage.SYSTEM, settings.language)
    }

    @Test
    fun settingsPersistAcrossInstances() {
        val store = InMemoryKeyValueStore()
        val settings = GameSettingsStore(store)

        settings.setMusicEnabled(false)
        settings.setSoundEnabled(false)
        settings.setHapticsEnabled(false)
        settings.setReduceMotionEnabled(true)
        settings.setHighContrastEnabled(true)
        settings.setLanguage(AppLanguage.VIETNAMESE)

        val reloaded = GameSettingsStore(store)
        assertFalse(reloaded.musicEnabled)
        assertFalse(reloaded.soundEnabled)
        assertFalse(reloaded.hapticsEnabled)
        assertTrue(reloaded.reduceMotionEnabled)
        assertTrue(reloaded.highContrastEnabled)
        assertEquals(AppLanguage.VIETNAMESE, reloaded.language)
        assertTrue(reloaded.reduceMotionInitialized)
    }

    @Test
    fun languageTagMappingCoversAllSupportedLanguages() {
        assertEquals(AppLanguage.ENGLISH, AppLanguage.fromTag("en"))
        assertEquals(AppLanguage.VIETNAMESE, AppLanguage.fromTag("vi"))
        assertEquals(AppLanguage.JAPANESE, AppLanguage.fromTag("ja"))
        assertEquals(AppLanguage.SIMPLIFIED_CHINESE, AppLanguage.fromTag("zh-CN"))
        assertEquals(AppLanguage.SYSTEM, AppLanguage.fromTag(null))
        assertEquals(AppLanguage.SYSTEM, AppLanguage.fromTag("fr"))
    }

    @Test
    fun flagsAreIndependent() {
        val settings = newStore()

        settings.setMusicEnabled(false)
        assertFalse(settings.musicEnabled)
        assertTrue(settings.soundEnabled)
        assertTrue(settings.hapticsEnabled)

        settings.setSoundEnabled(false)
        assertTrue(settings.hapticsEnabled)

        settings.setHapticsEnabled(false)
        assertFalse(settings.soundEnabled)
        assertFalse(settings.musicEnabled)
    }
}
