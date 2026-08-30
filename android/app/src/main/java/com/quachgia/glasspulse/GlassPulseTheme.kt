package com.quachgia.glasspulse

import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.res.colorResource

@Composable
fun GlassPulseTheme(content: @Composable () -> Unit) {
    val colors = darkColorScheme(
        primary = colorResource(R.color.glass_accent),
        background = colorResource(R.color.glass_background),
        surface = colorResource(R.color.glass_surface),
        onPrimary = colorResource(R.color.glass_background),
        onBackground = colorResource(R.color.glass_on_background),
        onSurface = colorResource(R.color.glass_on_background)
    )
    MaterialTheme(
        colorScheme = colors,
        content = content
    )
}
