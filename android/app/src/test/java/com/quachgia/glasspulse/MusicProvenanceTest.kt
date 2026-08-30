package com.quachgia.glasspulse

import java.io.File
import java.security.MessageDigest
import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.Assume.assumeTrue

class MusicProvenanceTest {
    private val repoRoot: File
        get() {
            var dir = File(System.getProperty("user.dir"))
            repeat(4) {
                if (File(dir, "Media/Music/PROVENANCE.json").exists()) return dir
                dir = dir.parentFile ?: dir
            }
            return dir
        }

    private fun provenanceFile(): File = File(repoRoot, "Media/Music/PROVENANCE.json")

    private fun sha256(file: File): String {
        val digest = MessageDigest.getInstance("SHA-256")
        file.inputStream().use { stream ->
            val buffer = ByteArray(64 * 1024)
            var read = stream.read(buffer)
            while (read >= 0) {
                digest.update(buffer, 0, read)
                read = stream.read(buffer)
            }
        }
        return digest.digest().joinToString("") { "%02x".format(it) }
    }

    @Test
    fun provenanceManifestParsesAndChecksumsMatchPackagedFiles() {
        val file = provenanceFile()
        assumeTrue("PROVENANCE.json not found from ${System.getProperty("user.dir")}", file.exists())

        val track = JSONObject(file.readText()).getJSONObject("track")

        assertEquals("Formant 1", track.getString("title"))
        val source = track.getJSONObject("source")
        assertEquals("CC0-1.0", source.getJSONObject("license").getString("type"))
        assertTrue(source.getString("commitSha").matches(Regex("[0-9a-f]{40}")))

        val master = track.getJSONObject("master")
        val masterFile = File(repoRoot, master.getString("path"))
        assertTrue(masterFile.exists())
        assertEquals(master.getString("sha256"), sha256(masterFile))

        val encodes = track.getJSONArray("encodes")
        assertEquals(2, encodes.length())
        for (index in 0 until encodes.length()) {
            val encode = encodes.getJSONObject(index)
            val encodeFile = File(repoRoot, encode.getString("path"))
            assertTrue("missing encode ${encode.getString("path")}", encodeFile.exists())
            assertEquals(
                encode.getString("sha256"),
                sha256(encodeFile)
            )
            val budgetBytes = (1.5 * 1024 * 1024).toLong()
            assertTrue(
                "${encode.getString("path")} exceeds the 1.5 MiB audio budget",
                encodeFile.length() < budgetBytes
            )
        }
    }
}
