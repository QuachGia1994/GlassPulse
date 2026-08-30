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

        settings.updateMusicEnabled(false)
        settings.updateSoundEnabled(false)
        settings.updateHapticsEnabled(false)
        settings.updateReduceMotionEnabled(true)
        settings.updateHighContrastEnabled(true)
        settings.updateLanguage(AppLanguage.VIETNAMESE)

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

        settings.updateMusicEnabled(false)
        assertFalse(settings.musicEnabled)
        assertTrue(settings.soundEnabled)
        assertTrue(settings.hapticsEnabled)

        settings.updateSoundEnabled(false)
        assertTrue(settings.hapticsEnabled)

        settings.updateHapticsEnabled(false)
        assertFalse(settings.soundEnabled)
        assertFalse(settings.musicEnabled)
    }
}
