package com.quachgia.glasspulse

import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color

data class PulsePalette(
    val backgroundTop: Color,
    val backgroundBottom: Color,
    val ring: Color,
    val ball: Color,
    val gem: Color,
    val hazard: Color,
    val glassSurface: Color,
    val pulseAmplitudeDp: Float,
    val pulseFrequency: Double
)

fun PulseThemeId.palette(): PulsePalette = when (this) {
    PulseThemeId.CLARITY -> PulsePalette(
        backgroundTop = Color(0xFF051A29),
        backgroundBottom = Color(0xFF02040F),
        ring = Color(0xFF5CE0FF),
        ball = Color(0xFF6BD1FF),
        gem = Color(0xFF6BFFB8),
        hazard = Color(0xFFFF4D6B),
        glassSurface = Color(0xB31B202A),
        pulseAmplitudeDp = 3.0f,
        pulseFrequency = 2.0
    )
    PulseThemeId.EMBER -> PulsePalette(
        backgroundTop = Color(0xFF300F0A),
        backgroundBottom = Color(0xFF0A0305),
        ring = Color(0xFFFF963D),
        ball = Color(0xFFFFC75C),
        gem = Color(0xFFFFEB7A),
        hazard = Color(0xFFFF2E2E),
        glassSurface = Color(0xB3262020),
        pulseAmplitudeDp = 3.8f,
        pulseFrequency = 2.35
    )
    PulseThemeId.AURORA -> PulsePalette(
        backgroundTop = Color(0xFF0A2621),
        backgroundBottom = Color(0xFF050714),
        ring = Color(0xFF6BFFC2),
        ball = Color(0xFFA8EBFF),
        gem = Color(0xFFD19EFF),
        hazard = Color(0xFFFF5294),
        glassSurface = Color(0xB31A2326),
        pulseAmplitudeDp = 4.4f,
        pulseFrequency = 1.75
    )
    PulseThemeId.PRISM_PLUS -> PulsePalette(
        backgroundTop = Color(0xFF21103D),
        backgroundBottom = Color(0xFF050517),
        ring = Color(0xFFBA8FFF),
        ball = Color(0xFF7AF0FF),
        gem = Color(0xFFFF94EB),
        hazard = Color(0xFFFF4775),
        glassSurface = Color(0xB3231F2E),
        pulseAmplitudeDp = 5.0f,
        pulseFrequency = 2.65
    )
}

@Composable
fun GlassPulseTheme(
    palette: PulsePalette = PulseThemeId.CLARITY.palette(),
    content: @Composable () -> Unit
) {
    val colors = darkColorScheme(
        primary = palette.ring,
        secondary = palette.gem,
        background = palette.backgroundBottom,
        surface = palette.backgroundTop.copy(alpha = 1f),
        surfaceVariant = palette.glassSurface.copy(alpha = 1f),
        onPrimary = palette.backgroundBottom,
        onSecondary = palette.backgroundBottom,
        onBackground = Color(0xFFF5F7FF),
        onSurface = Color(0xFFF5F7FF),
        onSurfaceVariant = Color(0xFFD8D6DE)
    )
    MaterialTheme(
        colorScheme = colors,
        content = content
    )
}
