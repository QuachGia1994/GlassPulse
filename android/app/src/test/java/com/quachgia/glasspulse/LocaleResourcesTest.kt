package com.quachgia.glasspulse

import java.nio.charset.StandardCharsets
import java.nio.file.Files
import java.nio.file.Path
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class LocaleResourcesTest {
    @Test
    fun everyRequiredLocaleContainsTheDefaultStringKeys() {
        val resources = locateResources()
        val defaultKeys = stringKeys(resources.resolve("values/strings.xml"))
        val localeDirectories = listOf("values-vi", "values-ja", "values-zh-rCN")

        assertTrue(defaultKeys.isNotEmpty())
        localeDirectories.forEach { directory ->
            val localizedKeys = stringKeys(resources.resolve("$directory/strings.xml"))
            assertEquals("Missing or extra keys in $directory", defaultKeys, localizedKeys)
        }
    }

    private fun locateResources(): Path {
        val working = Path.of(System.getProperty("user.dir")).toAbsolutePath().normalize()
        val candidates = listOf(
            working.resolve("android/app/src/main/res"),
            working.resolve("app/src/main/res"),
            working.resolve("src/main/res")
        )
        return candidates.firstOrNull(Files::isDirectory)
            ?: error("Android resource directory not found from $working")
    }

    private fun stringKeys(file: Path): Set<String> {
        val text = String(Files.readAllBytes(file), StandardCharsets.UTF_8)
        val namePattern = Regex("<string\\s+name=\"([^\"]+)\"")
        return namePattern.findAll(text).map { it.groupValues[1] }.toSet()
    }
}
