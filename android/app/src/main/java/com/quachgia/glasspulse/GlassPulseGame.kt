package com.quachgia.glasspulse

import androidx.annotation.StringRes
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.RowScope
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.safeDrawing
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Surface
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.runtime.withFrameNanos
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.PathEffect
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.role
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.stateDescription
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.window.Dialog
import kotlin.math.ceil
import kotlin.math.cos
import kotlin.math.max
import kotlin.math.sin

@Composable
fun GlassPulseGame(controller: GameController) {
    val uiState = controller.uiState
    val palette = uiState.activeThemeId.palette()
    var showModes by remember { mutableStateOf(false) }
    var showThemes by remember { mutableStateOf(false) }
    var showAccess by remember { mutableStateOf(false) }
    var showSettings by remember { mutableStateOf(false) }

    LaunchedEffect(controller) {
        controller.onLaunchUiReady()
        while (true) {
            withFrameNanos { frameTimeNanos -> controller.advance(frameTimeNanos) }
        }
    }

    Scaffold(
        modifier = Modifier.testTag("game.screen"),
        containerColor = Color.Transparent,
        contentWindowInsets = WindowInsets.safeDrawing
    ) { innerPadding ->
        Box(
            modifier = Modifier
                .fillMaxSize()
                .background(
                    Brush.radialGradient(
                        listOf(palette.backgroundTop, palette.backgroundBottom)
                    )
                )
                .padding(innerPadding)
        ) {
            GameplayInputSurface(
                game = uiState.game,
                onTap = controller::handleSurfaceTap
            )
            GameChrome(
                uiState = uiState,
                controller = controller,
                palette = palette,
                onShowModes = { showModes = true },
                onShowThemes = {
                    controller.pause()
                    showThemes = true
                },
                onShowAccess = {
                    controller.pause()
                    showAccess = true
                },
                onShowSettings = {
                    controller.pause()
                    showSettings = true
                }
            )
        }
    }

    if (showModes) {
        ModePickerSheet(
            uiState = uiState,
            controller = controller,
            onDismiss = { showModes = false }
        )
    }
    if (showThemes) {
        ThemePickerSheet(
            uiState = uiState,
            controller = controller,
            onDismiss = { showThemes = false }
        )
    }
    if (showSettings) {
        SettingsSheet(
            controller = controller,
            onDismiss = { showSettings = false }
        )
    }
    if (showAccess) {
        AccessDialog(uiState.betaFullAccess, palette) { showAccess = false }
    }
}

@Composable
private fun GameplayInputSurface(
    game: GameSnapshot,
    onTap: () -> Unit
) {
    val interactionSource = remember { MutableInteractionSource() }
    val direction = stringResource(
        if (game.direction >= 0) {
            R.string.game_direction_clockwise
        } else {
            R.string.game_direction_counterclockwise
        }
    )
    val description = stringResource(R.string.game_input_label)
    Box(
        modifier = Modifier
            .fillMaxSize()
            .testTag("game.input.surface")
            .semantics {
                contentDescription = description
                stateDescription = direction
                role = Role.Button
            }
            .clickable(
                interactionSource = interactionSource,
                indication = null,
                role = Role.Button,
                onClick = onTap
            )
    )
}

@Composable
private fun GameChrome(
    uiState: GameUiState,
    controller: GameController,
    palette: PulsePalette,
    onShowModes: () -> Unit,
    onShowThemes: () -> Unit,
    onShowAccess: () -> Unit,
    onShowSettings: () -> Unit
) {
    BoxWithConstraints(
        modifier = Modifier
            .fillMaxSize()
            .padding(horizontal = 16.dp, vertical = 8.dp)
    ) {
        val fontScale = LocalDensity.current.fontScale
        val chromeBudget = if (fontScale > 1.5f) 260.dp else 178.dp
        val boardSide = minOf(maxWidth, maxHeight - chromeBudget)
            .coerceAtLeast(190.dp)

        Column(
            modifier = Modifier.fillMaxSize(),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            GameHeader(uiState, palette)
            Spacer(
                Modifier
                    .weight(1f)
                    .heightIn(min = 6.dp)
            )
            GameBoard(
                uiState = uiState,
                controller = controller,
                palette = palette,
                side = boardSide,
                onShowModes = onShowModes
            )
            Spacer(
                Modifier
                    .weight(1f)
                    .heightIn(min = 6.dp)
            )
            GameFooter(
                uiState = uiState,
                controller = controller,
                palette = palette,
                onShowModes = onShowModes,
                onShowThemes = onShowThemes,
                onShowAccess = onShowAccess,
                onShowSettings = onShowSettings
            )
        }
    }
}

@Composable
private fun GameHeader(
    uiState: GameUiState,
    palette: PulsePalette
) {
    val game = uiState.game
    Row(
        modifier = Modifier.fillMaxWidth(),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Column(modifier = Modifier.weight(1f)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(
                    text = stringResource(R.string.brand_name),
                    color = MaterialTheme.colorScheme.onBackground.copy(alpha = 0.62f),
                    fontSize = 12.sp,
                    fontWeight = FontWeight.SemiBold,
                    letterSpacing = 3.sp
                )
                if (uiState.betaFullAccess) {
                    Text(
                        text = stringResource(R.string.beta_badge),
                        modifier = Modifier.padding(start = 7.dp),
                        color = palette.ring,
                        fontSize = 8.sp,
                        fontWeight = FontWeight.Bold
                    )
                }
            }
            Text(
                text = stringResource(game.session.modeId.titleResource()),
                modifier = Modifier.testTag("game.mode.current"),
                color = palette.ring,
                fontSize = 13.sp,
                fontWeight = FontWeight.Medium
            )
            Text(
                text = game.score.toString(),
                color = MaterialTheme.colorScheme.onBackground,
                fontSize = 38.sp,
                fontWeight = FontWeight.SemiBold
            )
        }
        Metric(stringResource(R.string.metric_best), uiState.player.bestScore)
        Metric(stringResource(R.string.metric_streak), uiState.player.dailyStreak)
        Metric(stringResource(R.string.metric_shards), uiState.player.totalShards)
    }
}

@Composable
private fun Metric(label: String, value: Int) {
    Column(
        modifier = Modifier.padding(start = 13.dp),
        horizontalAlignment = Alignment.End
    ) {
        Text(
            text = value.toString(),
            color = MaterialTheme.colorScheme.onBackground,
            fontSize = 18.sp,
            fontWeight = FontWeight.SemiBold
        )
        Text(
            text = label,
            color = MaterialTheme.colorScheme.onBackground.copy(alpha = 0.56f),
            fontSize = 8.sp,
            fontWeight = FontWeight.Medium,
            letterSpacing = 1.sp
        )
    }
}

@Composable
private fun GameBoard(
    uiState: GameUiState,
    controller: GameController,
    palette: PulsePalette,
    side: Dp,
    onShowModes: () -> Unit
) {
    val game = uiState.game
    Box(
        modifier = Modifier
            .size(side)
            .clip(RoundedCornerShape(28.dp))
            .background(
                Brush.verticalGradient(
                    listOf(Color.White.copy(alpha = 0.045f), palette.glassSurface)
                )
            )
            .border(
                width = 1.dp,
                color = Color.White.copy(alpha = 0.14f),
                shape = RoundedCornerShape(28.dp)
            )
    ) {
        GameCanvas(uiState, palette)
        ModeHud(uiState, palette)
        StatusOverlay(
            uiState = uiState,
            controller = controller,
            palette = palette,
            onShowModes = onShowModes
        )
        if (game.state == GameState.PLAYING) {
            Surface(
                onClick = controller::pause,
                modifier = Modifier
                    .align(Alignment.TopEnd)
                    .padding(12.dp)
                    .size(46.dp)
                    .testTag("game.pause"),
                shape = CircleShape,
                color = palette.glassSurface.copy(alpha = 0.92f),
                contentColor = palette.ring,
                border = BorderStroke(1.dp, Color.White.copy(alpha = 0.15f)),
                shadowElevation = 6.dp
            ) {
                Box(
                    modifier = Modifier.fillMaxSize(),
                    contentAlignment = Alignment.Center
                ) {
                    Text(
                        stringResource(R.string.pause_symbol),
                        fontSize = 18.sp,
                        fontWeight = FontWeight.Bold
                    )
                }
            }
        }
    }
}

@Composable
private fun GameCanvas(
    uiState: GameUiState,
    palette: PulsePalette
) {
    val gameDescription = stringResource(
        R.string.game_board_description,
        uiState.game.score
    )
    Canvas(
        modifier = Modifier
            .fillMaxSize()
            .testTag("game.board")
            .semantics { contentDescription = gameDescription }
    ) {
        drawGlassPulse(
            game = uiState.game,
            palette = palette,
            frameTimeNanos = uiState.frameTimeNanos,
            reduceMotion = uiState.reduceMotion,
            highContrast = uiState.highContrast
        )
    }
}

@Composable
private fun StatusCard(
    palette: PulsePalette,
    modifier: Modifier = Modifier,
    content: @Composable () -> Unit
) {
    Surface(
        modifier = modifier.widthIn(max = 292.dp),
        shape = RoundedCornerShape(20.dp),
        color = palette.glassSurface.copy(alpha = 0.88f),
        contentColor = MaterialTheme.colorScheme.onSurface,
        border = BorderStroke(1.dp, Color.White.copy(alpha = 0.09f)),
        tonalElevation = 0.dp,
        shadowElevation = 10.dp,
        content = content
    )
}

@Composable
private fun StatusOverlay(
    uiState: GameUiState,
    controller: GameController,
    palette: PulsePalette,
    onShowModes: () -> Unit
) {
    Box(
        modifier = Modifier.fillMaxSize(),
        contentAlignment = Alignment.Center
    ) {
        when (uiState.game.state) {
            GameState.PLAYING -> Unit
            GameState.START -> StartCard(palette)
            GameState.PAUSED -> PausedCard(controller, palette)
            GameState.OVER -> GameOverCard(uiState, controller, palette, onShowModes)
        }
    }
}

@Composable
private fun StartCard(palette: PulsePalette) {
    StatusCard(palette) {
        Column(
            modifier = Modifier.padding(horizontal = 20.dp, vertical = 16.dp),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            Text(
                stringResource(R.string.game_mark_symbol),
                color = palette.ring,
                fontSize = 24.sp
            )
            Text(
                text = stringResource(R.string.game_status_start),
                textAlign = TextAlign.Center,
                fontWeight = FontWeight.SemiBold
            )
        }
    }
}

@Composable
private fun PausedCard(
    controller: GameController,
    palette: PulsePalette
) {
    StatusCard(palette) {
        Column(
            modifier = Modifier.padding(horizontal = 20.dp, vertical = 18.dp),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            Text(
                text = stringResource(R.string.game_status_paused),
                fontSize = 20.sp,
                fontWeight = FontWeight.Bold
            )
            Button(
                onClick = controller::resume,
                modifier = Modifier
                    .padding(top = 10.dp)
                    .height(44.dp)
                    .testTag("game.resume"),
                shape = RoundedCornerShape(14.dp),
                colors = ButtonDefaults.buttonColors(
                    containerColor = palette.ring,
                    contentColor = palette.backgroundBottom
                )
            ) {
                Text(
                    text = stringResource(R.string.action_resume),
                    fontWeight = FontWeight.SemiBold
                )
            }
        }
    }
}

@Composable
private fun GameOverCard(
    uiState: GameUiState,
    controller: GameController,
    palette: PulsePalette,
    onShowModes: () -> Unit
) {
    val completed = uiState.game.runOutcome == GameRunOutcome.COMPLETED
    StatusCard(palette) {
        Column(
            modifier = Modifier.padding(horizontal = 18.dp, vertical = 15.dp),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            Text(
                text = stringResource(R.string.game_mark_symbol),
                color = palette.ring,
                fontSize = 22.sp
            )
            Text(
                text = stringResource(
                    if (completed) R.string.game_status_completed else R.string.game_status_collision
                ),
                textAlign = TextAlign.Center,
                fontSize = 19.sp,
                fontWeight = FontWeight.Bold
            )
            GameReward(uiState, palette)
            GameOverActions(controller, palette, onShowModes)
        }
    }
}

@Composable
private fun GameReward(uiState: GameUiState, palette: PulsePalette) {
    Text(
        text = stringResource(R.string.game_reward, uiState.game.rewardForCurrentRun),
        modifier = Modifier.padding(top = 4.dp),
        color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.66f)
    )
    if (uiState.dailyBonus > 0) {
        Text(
            text = stringResource(R.string.game_daily_bonus, uiState.dailyBonus),
            color = palette.ring,
            fontWeight = FontWeight.SemiBold
        )
    }
}

@Composable
private fun GameOverActions(
    controller: GameController,
    palette: PulsePalette,
    onShowModes: () -> Unit
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(top = 10.dp),
        horizontalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        Button(
            onClick = controller::retry,
            modifier = Modifier
                .weight(1f)
                .height(44.dp)
                .testTag("game.retry"),
            shape = RoundedCornerShape(14.dp),
            colors = ButtonDefaults.buttonColors(
                containerColor = palette.ring,
                contentColor = palette.backgroundBottom
            ),
            contentPadding = PaddingValues(horizontal = 8.dp)
        ) {
            Text(stringResource(R.string.action_retry), maxLines = 1)
        }
        OutlinedButton(
            onClick = onShowModes,
            modifier = Modifier
                .weight(1f)
                .height(44.dp)
                .testTag("game.chooseMode"),
            shape = RoundedCornerShape(14.dp),
            border = BorderStroke(1.dp, Color.White.copy(alpha = 0.18f)),
            colors = ButtonDefaults.outlinedButtonColors(
                containerColor = palette.glassSurface.copy(alpha = 0.8f),
                contentColor = MaterialTheme.colorScheme.onSurface
            ),
            contentPadding = PaddingValues(horizontal = 8.dp)
        ) {
            Text(stringResource(R.string.action_choose_mode), maxLines = 1)
        }
    }
}

@Composable
private fun ModeHud(
    uiState: GameUiState,
    palette: PulsePalette
) {
    val game = uiState.game
    if (game.state == GameState.START) return
    Column(
        modifier = Modifier.padding(12.dp),
        verticalArrangement = Arrangement.spacedBy(5.dp)
    ) {
        if (game.session.modeId == GameModeId.DAILY_CHALLENGE) {
            HudPill(
                stringResource(R.string.hud_today),
                stringResource(game.session.effectiveModeId.titleResource()),
                palette
            )
            HudPill(
                stringResource(R.string.hud_local_best),
                uiState.player.dailyBest.toString(),
                palette
            )
        }
        game.remainingTimeSeconds?.let { remaining ->
            HudPill(
                stringResource(R.string.hud_remaining),
                stringResource(R.string.seconds_short, ceil(remaining).toInt()),
                palette
            )
        }
        if (game.session.effectiveModeId == GameModeId.RUSH_60 ||
            game.session.effectiveModeId == GameModeId.PRECISION_PULSE
        ) {
            HudPill(
                stringResource(R.string.hud_combo),
                stringResource(R.string.combo_value, game.combo),
                palette
            )
        }
        if (game.session.effectiveModeId == GameModeId.PRECISION_PULSE) {
            HudPill(
                stringResource(R.string.hud_pulse),
                stringResource(
                    if (game.pulseIsActive) R.string.pulse_active else R.string.pulse_wait
                ),
                palette
            )
        }
        if (game.session.effectiveModeId == GameModeId.WAVE_SURVIVAL) {
            HudPill(
                stringResource(R.string.hud_wave),
                stringResource(
                    R.string.wave_value,
                    game.currentWave,
                    game.rules.finalWave ?: 5
                ),
                palette
            )
        }
    }
}

@Composable
private fun HudPill(
    title: String,
    value: String,
    palette: PulsePalette
) {
    Surface(
        shape = CircleShape,
        color = palette.glassSurface.copy(alpha = 0.92f)
    ) {
        Row(
            modifier = Modifier.padding(horizontal = 9.dp, vertical = 5.dp),
            horizontalArrangement = Arrangement.spacedBy(5.dp)
        ) {
            Text(
                text = title,
                color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.56f),
                fontSize = 8.sp,
                fontWeight = FontWeight.Bold
            )
            Text(
                text = value,
                color = palette.ring,
                fontSize = 10.sp,
                fontWeight = FontWeight.SemiBold
            )
        }
    }
}

@Composable
private fun GameFooter(
    uiState: GameUiState,
    controller: GameController,
    palette: PulsePalette,
    onShowModes: () -> Unit,
    onShowThemes: () -> Unit,
    onShowAccess: () -> Unit,
    onShowSettings: () -> Unit
) {
    val fontScale = LocalDensity.current.fontScale
    val shape = RoundedCornerShape(14.dp)
    val border = BorderStroke(1.dp, footerBorderColor(uiState))
    val colors = ButtonDefaults.outlinedButtonColors(
        containerColor = palette.glassSurface.copy(alpha = 0.88f),
        contentColor = MaterialTheme.colorScheme.onSurface,
        disabledContainerColor = palette.glassSurface.copy(alpha = 0.42f),
        disabledContentColor = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.30f)
    )
    val modesButton: @Composable RowScope.() -> Unit = {
        OutlinedButton(
            onClick = onShowModes,
            enabled = controller.canChangeMode(),
            modifier = Modifier
                .weight(1f)
                .height(52.dp)
                .testTag("game.modes"),
            shape = shape,
            border = border,
            colors = colors,
            contentPadding = PaddingValues(horizontal = 8.dp)
        ) {
            Text(stringResource(R.string.footer_mode), maxLines = 1)
        }
    }
    val themesButton: @Composable RowScope.() -> Unit = {
        OutlinedButton(
            onClick = onShowThemes,
            modifier = Modifier
                .weight(1f)
                .height(52.dp)
                .testTag("game.themes"),
            shape = shape,
            border = border,
            colors = colors,
            contentPadding = PaddingValues(horizontal = 8.dp)
        ) {
            Text(
                stringResource(R.string.footer_theme),
                color = palette.ring,
                maxLines = 1
            )
        }
    }
    val accessButton: @Composable RowScope.() -> Unit = {
        OutlinedButton(
            onClick = onShowAccess,
            modifier = Modifier
                .weight(1f)
                .height(52.dp)
                .testTag("game.access"),
            shape = shape,
            border = border,
            colors = colors,
            contentPadding = PaddingValues(horizontal = 8.dp)
        ) {
            Text(
                text = stringResource(
                    if (uiState.betaFullAccess) R.string.footer_beta else R.string.footer_plus
                ),
                color = palette.ring,
                maxLines = 1
            )
        }
    }

    if (fontScale > 1.5f) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(bottom = 4.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            Row(
                horizontalArrangement = Arrangement.spacedBy(10.dp)
            ) {
                modesButton()
                themesButton()
            }
            Row(
                horizontalArrangement = Arrangement.spacedBy(10.dp)
            ) {
                accessButton()
                SettingsGear(palette, uiState, onShowSettings, Modifier.weight(1f))
            }
        }
    } else {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(bottom = 4.dp),
            horizontalArrangement = Arrangement.spacedBy(10.dp)
        ) {
            modesButton()
            themesButton()
            accessButton()
            SettingsGear(palette, uiState, onShowSettings)
        }
    }
}

@Composable
private fun SettingsGear(
    palette: PulsePalette,
    uiState: GameUiState,
    onShowSettings: () -> Unit,
    modifier: Modifier = Modifier
) {
    val gearDescription = stringResource(R.string.settings_open_label)
    Surface(
        onClick = onShowSettings,
        modifier = modifier
            .size(48.dp)
            .testTag("settings.open"),
        shape = CircleShape,
        color = palette.glassSurface.copy(alpha = 0.92f),
        contentColor = palette.ring,
        border = BorderStroke(1.dp, footerBorderColor(uiState)),
        shadowElevation = 6.dp
    ) {
        Box(
            modifier = Modifier
                .fillMaxSize()
                .semantics {
                    contentDescription = gearDescription
                    role = Role.Button
                },
            contentAlignment = Alignment.Center
        ) {
            Text(
                stringResource(R.string.settings_gear_symbol),
                fontSize = 18.sp,
                fontWeight = FontWeight.Bold
            )
        }
    }
}

@Composable
private fun footerBorderColor(uiState: GameUiState): Color =
    Color.White.copy(alpha = if (uiState.highContrast) 0.30f else 0.12f)

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun ModePickerSheet(
    uiState: GameUiState,
    controller: GameController,
    onDismiss: () -> Unit
) {
    val palette = uiState.activeThemeId.palette()
    ModalBottomSheet(
        onDismissRequest = onDismiss,
        containerColor = palette.backgroundBottom.copy(alpha = 0.98f),
        contentColor = MaterialTheme.colorScheme.onSurface,
        tonalElevation = 0.dp,
        scrimColor = Color.Black.copy(alpha = 0.62f)
    ) {
        Column(
            modifier = Modifier
                .fillMaxHeight(0.92f)
                .padding(horizontal = 18.dp)
                .padding(bottom = 20.dp)
        ) {
            SheetHeader(R.string.mode_picker_title, palette, onDismiss)
            if (uiState.betaFullAccess) {
                Text(
                    text = stringResource(R.string.beta_all_modes_open),
                    color = palette.ring,
                    fontSize = 14.sp,
                    fontWeight = FontWeight.SemiBold
                )
            }
            Column(
                modifier = Modifier
                    .weight(1f)
                    .verticalScroll(rememberScrollState())
                    .padding(top = 12.dp),
                verticalArrangement = Arrangement.spacedBy(10.dp)
            ) {
                GameModeId.entries.forEach { modeId ->
                    ModeCard(
                        modeId = modeId,
                        selected = uiState.game.session.modeId == modeId,
                        unlocked = controller.canUseMode(modeId),
                        onSelect = {
                            if (controller.selectMode(modeId)) onDismiss()
                        }
                    )
                }
            }
        }
    }
}

@Composable
private fun SheetHeader(
    @StringRes title: Int,
    palette: PulsePalette,
    onDismiss: () -> Unit
) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Text(
            text = stringResource(title),
            modifier = Modifier
                .weight(1f)
                .semantics { heading() },
            fontSize = 28.sp,
            fontWeight = FontWeight.Bold
        )
        TextButton(onClick = onDismiss) {
            Text(
                text = stringResource(R.string.action_close),
                color = palette.ring,
                fontWeight = FontWeight.SemiBold
            )
        }
    }
}

@Composable
private fun ModeCard(
    modeId: GameModeId,
    selected: Boolean,
    unlocked: Boolean,
    onSelect: () -> Unit
) {
    val shape = RoundedCornerShape(18.dp)
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .clip(shape)
            .background(
                if (selected) {
                    MaterialTheme.colorScheme.primary.copy(alpha = 0.11f)
                } else {
                    MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.76f)
                }
            )
            .border(
                width = if (selected) 1.5.dp else 1.dp,
                color = if (selected) {
                    MaterialTheme.colorScheme.primary
                } else {
                    Color.White.copy(alpha = 0.10f)
                },
                shape = shape
            )
            .clickable(enabled = unlocked, onClick = onSelect)
            .testTag("mode." + modeId.name.lowercase())
            .padding(14.dp)
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text(
                text = stringResource(modeId.titleResource()),
                modifier = Modifier.weight(1f),
                fontSize = 17.sp,
                fontWeight = FontWeight.Bold
            )
            Text(
                text = stringResource(
                    when {
                        selected -> R.string.state_selected
                        unlocked -> R.string.state_available
                        else -> R.string.state_plus
                    }
                ),
                color = MaterialTheme.colorScheme.primary,
                fontSize = 13.sp,
                fontWeight = FontWeight.SemiBold
            )
        }
        Text(
            text = stringResource(modeId.subtitleResource()),
            modifier = Modifier.padding(top = 5.dp),
            color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.68f),
            fontSize = 14.sp
        )
        Text(
            text = stringResource(modeId.instructionResource()),
            modifier = Modifier.padding(top = 4.dp),
            fontSize = 11.sp,
            color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.58f)
        )
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun ThemePickerSheet(
    uiState: GameUiState,
    controller: GameController,
    onDismiss: () -> Unit
) {
    val palette = uiState.activeThemeId.palette()
    ModalBottomSheet(
        onDismissRequest = onDismiss,
        containerColor = palette.backgroundBottom.copy(alpha = 0.98f),
        contentColor = MaterialTheme.colorScheme.onSurface,
        tonalElevation = 0.dp,
        scrimColor = Color.Black.copy(alpha = 0.62f)
    ) {
        Column(
            modifier = Modifier
                .fillMaxHeight(0.88f)
                .padding(horizontal = 18.dp)
                .padding(bottom = 20.dp)
        ) {
            SheetHeader(R.string.theme_picker_title, palette, onDismiss)
            if (uiState.betaFullAccess) {
                Text(
                    text = stringResource(R.string.beta_all_themes_open),
                    color = palette.ring,
                    fontSize = 14.sp,
                    fontWeight = FontWeight.SemiBold
                )
            }
            Column(
                modifier = Modifier
                    .weight(1f)
                    .verticalScroll(rememberScrollState())
                    .padding(top = 12.dp),
                verticalArrangement = Arrangement.spacedBy(10.dp)
            ) {
                PulseThemeId.entries.forEach { themeId ->
                    ThemeCard(
                        themeId = themeId,
                        selected = uiState.activeThemeId == themeId,
                        unlocked = controller.canUseTheme(themeId),
                        selectable = uiState.betaFullAccess || themeId != PulseThemeId.PRISM_PLUS,
                        betaFullAccess = uiState.betaFullAccess,
                        onSelect = {
                            if (controller.selectTheme(themeId)) onDismiss()
                        }
                    )
                }
            }
        }
    }
}

@Composable
private fun ThemeCard(
    themeId: PulseThemeId,
    selected: Boolean,
    unlocked: Boolean,
    selectable: Boolean,
    betaFullAccess: Boolean,
    onSelect: () -> Unit
) {
    val palette = themeId.palette()
    val shape = RoundedCornerShape(18.dp)
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(shape)
            .background(
                if (selected) {
                    palette.glassSurface.copy(alpha = 0.96f)
                } else {
                    MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.76f)
                }
            )
            .border(
                width = if (selected) 1.5.dp else 1.dp,
                color = if (selected) palette.ring else Color.White.copy(alpha = 0.10f),
                shape = shape
            )
            .clickable(enabled = selectable, onClick = onSelect)
            .testTag("theme." + themeId.name.lowercase())
            .padding(12.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        ThemePreview(palette)
        Column(
            modifier = Modifier
                .weight(1f)
                .padding(horizontal = 12.dp)
        ) {
            Text(
                text = stringResource(themeId.titleResource()),
                fontSize = 17.sp,
                fontWeight = FontWeight.Bold
            )
            Text(
                text = stringResource(themeId.subtitleResource()),
                color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.62f),
                fontSize = 14.sp
            )
        }
        Text(
            text = themeAccessLabel(themeId, selected, unlocked, betaFullAccess),
            color = palette.ring,
            fontSize = 13.sp,
            fontWeight = FontWeight.SemiBold
        )
    }
}

@Composable
private fun themeAccessLabel(
    themeId: PulseThemeId,
    selected: Boolean,
    unlocked: Boolean,
    betaFullAccess: Boolean
): String {
    if (selected) return stringResource(R.string.state_in_use)
    if (betaFullAccess || unlocked) return stringResource(R.string.state_use)
    return when (themeId) {
        PulseThemeId.EMBER -> stringResource(R.string.theme_price_shards, 18)
        PulseThemeId.AURORA -> stringResource(R.string.theme_price_shards, 45)
        PulseThemeId.PRISM_PLUS -> stringResource(R.string.state_plus)
        PulseThemeId.CLARITY -> stringResource(R.string.state_free)
    }
}

@Composable
private fun ThemePreview(palette: PulsePalette) {
    Canvas(modifier = Modifier.size(58.dp)) {
        val center = Offset(size.width / 2, size.height / 2)
        val radius = size.minDimension * 0.40f
        drawCircle(palette.backgroundBottom, radius)
        drawCircle(palette.ring, radius, style = Stroke(width = 4.dp.toPx()))
        drawCircle(
            palette.ball,
            radius = 5.dp.toPx(),
            center = Offset(center.x, center.y - radius)
        )
        drawPath(
            diamondPath(Offset(center.x + radius * 0.72f, center.y), 5.dp.toPx()),
            palette.gem
        )
    }
}

@Composable
private fun AccessDialog(
    betaFullAccess: Boolean,
    palette: PulsePalette,
    onDismiss: () -> Unit
) {
    Dialog(onDismissRequest = onDismiss) {
        Surface(
            modifier = Modifier
                .widthIn(max = 320.dp)
                .fillMaxWidth(),
            shape = RoundedCornerShape(24.dp),
            color = palette.glassSurface.copy(alpha = 0.96f),
            contentColor = MaterialTheme.colorScheme.onSurface,
            border = BorderStroke(1.dp, Color.White.copy(alpha = 0.10f)),
            tonalElevation = 0.dp,
            shadowElevation = 16.dp
        ) {
            Column(modifier = Modifier.padding(22.dp)) {
                Text(
                    text = stringResource(R.string.game_mark_symbol),
                    color = palette.ring,
                    fontSize = 24.sp
                )
                Text(
                    text = stringResource(
                        if (betaFullAccess) {
                            R.string.beta_access_title
                        } else {
                            R.string.plus_access_title
                        }
                    ),
                    modifier = Modifier.padding(top = 5.dp),
                    fontSize = 23.sp,
                    fontWeight = FontWeight.Bold
                )
                Text(
                    text = stringResource(
                        if (betaFullAccess) R.string.beta_access_body else R.string.plus_access_body
                    ),
                    modifier = Modifier.padding(top = 10.dp),
                    color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.72f),
                    fontSize = 14.sp
                )
                TextButton(
                    onClick = onDismiss,
                    modifier = Modifier
                        .align(Alignment.End)
                        .padding(top = 8.dp)
                ) {
                    Text(
                        text = stringResource(R.string.action_close),
                        color = palette.ring,
                        fontWeight = FontWeight.SemiBold
                    )
                }
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun SettingsSheet(
    controller: GameController,
    onDismiss: () -> Unit
) {
    val settings = controller.settings
    val palette = controller.uiState.activeThemeId.palette()
    ModalBottomSheet(
        onDismissRequest = onDismiss,
        containerColor = palette.backgroundBottom.copy(alpha = 0.98f),
        contentColor = MaterialTheme.colorScheme.onSurface,
        tonalElevation = 0.dp,
        scrimColor = Color.Black.copy(alpha = 0.62f)
    ) {
        Column(
            modifier = Modifier
                .fillMaxHeight(0.92f)
                .padding(horizontal = 18.dp)
                .padding(bottom = 20.dp)
        ) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(
                    text = stringResource(R.string.settings_title),
                    modifier = Modifier
                        .weight(1f)
                        .semantics { heading() },
                    fontSize = 28.sp,
                    fontWeight = FontWeight.Bold
                )
                TextButton(
                    onClick = onDismiss,
                    modifier = Modifier.testTag("settings.close")
                ) {
                    Text(
                        text = stringResource(R.string.action_close),
                        color = palette.ring,
                        fontWeight = FontWeight.SemiBold
                    )
                }
            }
            Column(
                modifier = Modifier
                    .weight(1f)
                    .verticalScroll(rememberScrollState())
                    .testTag("settings.sheet")
                    .padding(top = 12.dp),
                verticalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                SettingsSection(R.string.settings_section_audio, palette) {
                    SettingsToggle(
                        tag = "settings.music",
                        label = stringResource(R.string.settings_music_label),
                        hint = stringResource(R.string.settings_music_hint),
                        checked = settings.musicEnabled,
                        onChecked = settings::setMusicEnabled
                    )
                    SettingsToggle(
                        tag = "settings.sfx",
                        label = stringResource(R.string.settings_sfx_label),
                        hint = stringResource(R.string.settings_sfx_hint),
                        checked = settings.soundEnabled,
                        onChecked = settings::setSoundEnabled
                    )
                }
                SettingsSection(R.string.settings_section_feedback, palette) {
                    SettingsToggle(
                        tag = "settings.haptics",
                        label = stringResource(R.string.settings_haptics_label),
                        hint = stringResource(R.string.settings_haptics_hint),
                        checked = settings.hapticsEnabled,
                        onChecked = settings::setHapticsEnabled
                    )
                }
                SettingsSection(R.string.settings_section_display, palette) {
                    SettingsToggle(
                        tag = "settings.reduceMotion",
                        label = stringResource(R.string.settings_reduce_motion_label),
                        hint = stringResource(R.string.settings_reduce_motion_hint),
                        checked = settings.reduceMotionEnabled,
                        onChecked = settings::setReduceMotionEnabled
                    )
                    SettingsToggle(
                        tag = "settings.highContrast",
                        label = stringResource(R.string.settings_high_contrast_label),
                        hint = stringResource(R.string.settings_high_contrast_hint),
                        checked = settings.highContrastEnabled,
                        onChecked = settings::setHighContrastEnabled
                    )
                }
                SettingsSection(R.string.settings_section_language, palette) {
                    AppLanguage.entries.forEach { language ->
                        LanguageOption(
                            tag = "settings.language." + (language.tag ?: "system"),
                            label = languageOptionLabel(language),
                            selected = settings.language == language,
                            palette = palette,
                            onSelect = {
                                settings.setLanguage(language)
                                controller.applyMusicSettings()
                            }
                        )
                    }
                }
                SettingsSection(R.string.settings_section_credit, palette) {
                    Text(
                        text = stringResource(R.string.settings_music_credit),
                        color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.66f),
                        fontSize = 13.sp
                    )
                }
            }
        }
    }
}

@Composable
private fun languageOptionLabel(language: AppLanguage): String = when (language) {
    AppLanguage.SYSTEM -> stringResource(R.string.settings_language_system)
    AppLanguage.ENGLISH -> stringResource(R.string.settings_language_en)
    AppLanguage.VIETNAMESE -> stringResource(R.string.settings_language_vi)
    AppLanguage.JAPANESE -> stringResource(R.string.settings_language_ja)
    AppLanguage.SIMPLIFIED_CHINESE -> stringResource(R.string.settings_language_zh)
}

@Composable
private fun SettingsSection(
    @StringRes title: Int,
    palette: PulsePalette,
    content: @Composable () -> Unit
) {
    Column(
        modifier = Modifier.fillMaxWidth()
    ) {
        Text(
            text = stringResource(title),
            color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.56f),
            fontSize = 11.sp,
            fontWeight = FontWeight.Bold,
            letterSpacing = 1.5.sp
        )
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(top = 6.dp)
                .clip(RoundedCornerShape(18.dp))
                .background(palette.glassSurface.copy(alpha = 0.76f))
                .border(
                    width = 1.dp,
                    color = Color.White.copy(alpha = 0.10f),
                    shape = RoundedCornerShape(18.dp)
                )
                .padding(14.dp),
            verticalArrangement = Arrangement.spacedBy(10.dp)
        ) {
            content()
        }
    }
}

@Composable
private fun SettingsToggle(
    tag: String,
    label: String,
    hint: String,
    checked: Boolean,
    onChecked: (Boolean) -> Unit
) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Column(modifier = Modifier.weight(1f)) {
            Text(text = label, fontWeight = FontWeight.Medium, fontSize = 15.sp)
            Text(
                text = hint,
                color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.62f),
                fontSize = 12.sp
            )
        }
        Switch(
            checked = checked,
            onCheckedChange = onChecked,
            modifier = Modifier
                .testTag(tag)
                .semantics {
                    contentDescription = label
                    stateDescription = hint
                }
        )
    }
}

@Composable
private fun LanguageOption(
    tag: String,
    label: String,
    selected: Boolean,
    palette: PulsePalette,
    onSelect: () -> Unit
) {
    val shape = RoundedCornerShape(12.dp)
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(shape)
            .background(
                if (selected) {
                    MaterialTheme.colorScheme.primary.copy(alpha = 0.11f)
                } else {
                    Color.Transparent
                }
            )
            .border(
                width = if (selected) 1.5.dp else 0.dp,
                color = if (selected) {
                    MaterialTheme.colorScheme.primary
                } else {
                    Color.Transparent
                },
                shape = shape
            )
            .clickable(onClick = onSelect)
            .testTag(tag)
            .padding(horizontal = 10.dp, vertical = 10.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Text(
            text = label,
            modifier = Modifier.weight(1f),
            fontWeight = if (selected) FontWeight.SemiBold else FontWeight.Normal,
            fontSize = 15.sp
        )
        Text(
            text = stringResource(if (selected) R.string.state_selected else R.string.state_use),
            color = if (selected) palette.ring else MaterialTheme.colorScheme.onSurface.copy(alpha = 0.5f),
            fontSize = 12.sp,
            fontWeight = FontWeight.SemiBold
        )
    }
}

private fun DrawScope.drawGlassPulse(
    game: GameSnapshot,
    palette: PulsePalette,
    frameTimeNanos: Long,
    reduceMotion: Boolean,
    highContrast: Boolean
) {
    val center = Offset(size.width / 2, size.height / 2)
    val phase = frameTimeNanos / 1_000_000_000.0 * palette.pulseFrequency
    val pulse = if (reduceMotion) {
        0f
    } else {
        sin(phase).toFloat() * palette.pulseAmplitudeDp.dp.toPx()
    }
    val orbitRadius = max(36.dp.toPx(), size.minDimension / 2 - 30.dp.toPx() + pulse)

    drawCircle(
        color = palette.ring.copy(alpha = 0.18f),
        radius = orbitRadius,
        center = center,
        style = Stroke(width = 8.dp.toPx())
    )
    drawCircle(
        color = palette.ring.copy(alpha = if (highContrast) 1f else 0.86f),
        radius = orbitRadius,
        center = center,
        style = Stroke(width = 1.8.dp.toPx())
    )
    drawCircle(
        color = Color.White.copy(alpha = if (highContrast) 0.22f else 0.08f),
        radius = orbitRadius - 5.dp.toPx(),
        center = center,
        style = Stroke(width = 0.8.dp.toPx())
    )
    game.obstacles.forEach { obstacle ->
        drawObstacle(obstacle, center, orbitRadius, palette)
    }
    drawGem(game, center, orbitRadius, palette, highContrast)
    drawEffects(game, center, orbitRadius, palette, frameTimeNanos)
    drawBall(game, center, orbitRadius, palette, frameTimeNanos, highContrast)
}

private fun DrawScope.drawObstacle(
    obstacle: Obstacle,
    center: Offset,
    radius: Float,
    palette: PulsePalette
) {
    val start = Math.toDegrees(obstacle.angle - obstacle.width / 2).toFloat()
    val sweep = Math.toDegrees(obstacle.width).toFloat()
    val topLeft = Offset(center.x - radius, center.y - radius)
    val arcSize = Size(radius * 2, radius * 2)

    drawArc(
        color = palette.hazard.copy(alpha = 0.28f),
        startAngle = start,
        sweepAngle = sweep,
        useCenter = false,
        topLeft = topLeft,
        size = arcSize,
        style = Stroke(width = 18.dp.toPx(), cap = StrokeCap.Round)
    )
    drawArc(
        color = palette.hazard,
        startAngle = start,
        sweepAngle = sweep,
        useCenter = false,
        topLeft = topLeft,
        size = arcSize,
        style = Stroke(width = 10.dp.toPx(), cap = StrokeCap.Round)
    )
    drawSpikes(obstacle, center, radius, palette)
}

private fun DrawScope.drawSpikes(
    obstacle: Obstacle,
    center: Offset,
    radius: Float,
    palette: PulsePalette
) {
    val spikeCount = max(3, ceil(obstacle.width / 0.11).toInt())
    repeat(spikeCount + 1) { index ->
        val progress = index.toDouble() / spikeCount
        val angle = obstacle.angle - obstacle.width / 2 + obstacle.width * progress
        val left = orbitPoint(center, radius - 4.dp.toPx(), angle - 0.025)
        val right = orbitPoint(center, radius - 4.dp.toPx(), angle + 0.025)
        val tip = orbitPoint(center, radius - 15.dp.toPx(), angle)
        val spike = Path().apply {
            moveTo(left.x, left.y)
            lineTo(tip.x, tip.y)
            lineTo(right.x, right.y)
            close()
        }
        drawPath(spike, palette.hazard.copy(alpha = 0.94f))
    }
}

private fun DrawScope.drawGem(
    game: GameSnapshot,
    center: Offset,
    radius: Float,
    palette: PulsePalette,
    highContrast: Boolean
) {
    val gemCenter = orbitPoint(center, radius, game.gem.angle)
    val precision = game.session.effectiveModeId == GameModeId.PRECISION_PULSE
    val active = !precision || game.pulseIsActive
    val gemRadius = (if (active) 8.5.dp else 6.dp).toPx()
    val inactiveAlpha = if (highContrast) 0.62f else 0.42f

    drawCircle(
        color = palette.gem.copy(alpha = if (active) 0.20f else 0.08f),
        radius = if (active) 18.dp.toPx() else 10.dp.toPx(),
        center = gemCenter
    )
    drawPath(
        path = diamondPath(gemCenter, gemRadius),
        color = palette.gem.copy(alpha = if (active) 1f else inactiveAlpha)
    )
    if (precision) {
        drawCircle(
            color = palette.gem.copy(
                alpha = if (active) 0.9f else if (highContrast) 0.5f else 0.24f
            ),
            radius = (if (active) 15.dp else 10.dp).toPx(),
            center = gemCenter,
            style = Stroke(
                width = if (active) 2.4.dp.toPx() else (if (highContrast) 1.8.dp else 1.2.dp).toPx(),
                pathEffect = if (active) null else {
                    PathEffect.dashPathEffect(floatArrayOf(5.dp.toPx(), 4.dp.toPx()))
                }
            )
        )
    }
}

private fun DrawScope.drawEffects(
    game: GameSnapshot,
    center: Offset,
    radius: Float,
    palette: PulsePalette,
    nowNanos: Long
) {
    game.gemBurst?.let { burst ->
        val progress = effectProgress(burst.startedAtNanos, 420_000_000L, nowNanos)
        val burstCenter = orbitPoint(center, radius, burst.angle)
        drawCircle(
            color = palette.gem.copy(alpha = 1f - progress),
            radius = 8.dp.toPx() + progress * 22.dp.toPx(),
            center = burstCenter,
            style = Stroke(width = max(1.dp.toPx(), 3.dp.toPx() - progress * 2.dp.toPx()))
        )
    }
    game.collisionEffect?.let { collision ->
        val progress = effectProgress(collision.startedAtNanos, 650_000_000L, nowNanos)
        val collisionCenter = orbitPoint(center, radius, collision.angle)
        drawCircle(
            color = palette.hazard.copy(alpha = 0.46f * (1f - progress)),
            radius = 12.dp.toPx() + progress * 34.dp.toPx(),
            center = collisionCenter
        )
        drawCircle(
            color = palette.hazard.copy(alpha = 1f - progress),
            radius = radius + progress * 12.dp.toPx(),
            center = center,
            style = Stroke(width = max(1.dp.toPx(), 5.dp.toPx() - progress * 3.dp.toPx()))
        )
    }
}

private fun DrawScope.drawBall(
    game: GameSnapshot,
    center: Offset,
    radius: Float,
    palette: PulsePalette,
    nowNanos: Long,
    highContrast: Boolean
) {
    val ballCenter = orbitPoint(center, radius, game.ballAngle)
    val collisionProgress = game.collisionEffect?.let {
        effectProgress(it.startedAtNanos, 650_000_000L, nowNanos)
    } ?: 0f
    val ballRadius = 9.dp.toPx() * (1f + collisionProgress * 0.28f)

    drawCircle(
        color = palette.ball.copy(alpha = 0.20f),
        radius = ballRadius + 10.dp.toPx(),
        center = ballCenter
    )
    drawCircle(
        color = palette.ball.copy(alpha = 0.94f),
        radius = ballRadius,
        center = ballCenter
    )
    if (highContrast) {
        drawCircle(
            color = Color.White.copy(alpha = 0.9f),
            radius = ballRadius,
            center = ballCenter,
            style = Stroke(width = 1.6.dp.toPx())
        )
    }
    drawCircle(
        color = Color.White.copy(alpha = 0.76f),
        radius = ballRadius * 0.30f,
        center = Offset(
            ballCenter.x - ballRadius * 0.28f,
            ballCenter.y - ballRadius * 0.32f
        )
    )
}

private fun orbitPoint(center: Offset, radius: Float, angle: Double): Offset = Offset(
    x = center.x + radius * cos(angle).toFloat(),
    y = center.y + radius * sin(angle).toFloat()
)

private fun diamondPath(center: Offset, radius: Float): Path = Path().apply {
    moveTo(center.x, center.y - radius)
    lineTo(center.x + radius, center.y)
    lineTo(center.x, center.y + radius)
    lineTo(center.x - radius, center.y)
    close()
}

private fun effectProgress(startNanos: Long, durationNanos: Long, nowNanos: Long): Float =
    ((nowNanos - startNanos).toDouble() / durationNanos)
        .coerceIn(0.0, 1.0)
        .toFloat()

@StringRes
private fun GameModeId.titleResource(): Int = when (this) {
    GameModeId.CLASSIC -> R.string.mode_classic_title
    GameModeId.RUSH_60 -> R.string.mode_rush_title
    GameModeId.PRECISION_PULSE -> R.string.mode_precision_title
    GameModeId.WAVE_SURVIVAL -> R.string.mode_wave_title
    GameModeId.DAILY_CHALLENGE -> R.string.mode_daily_title
}

@StringRes
private fun GameModeId.subtitleResource(): Int = when (this) {
    GameModeId.CLASSIC -> R.string.mode_classic_subtitle
    GameModeId.RUSH_60 -> R.string.mode_rush_subtitle
    GameModeId.PRECISION_PULSE -> R.string.mode_precision_subtitle
    GameModeId.WAVE_SURVIVAL -> R.string.mode_wave_subtitle
    GameModeId.DAILY_CHALLENGE -> R.string.mode_daily_subtitle
}

@StringRes
private fun GameModeId.instructionResource(): Int = when (this) {
    GameModeId.CLASSIC -> R.string.mode_classic_instruction
    GameModeId.RUSH_60 -> R.string.mode_rush_instruction
    GameModeId.PRECISION_PULSE -> R.string.mode_precision_instruction
    GameModeId.WAVE_SURVIVAL -> R.string.mode_wave_instruction
    GameModeId.DAILY_CHALLENGE -> R.string.mode_daily_instruction
}

@StringRes
private fun PulseThemeId.titleResource(): Int = when (this) {
    PulseThemeId.CLARITY -> R.string.theme_clarity_title
    PulseThemeId.EMBER -> R.string.theme_ember_title
    PulseThemeId.AURORA -> R.string.theme_aurora_title
    PulseThemeId.PRISM_PLUS -> R.string.theme_prism_title
}

@StringRes
private fun PulseThemeId.subtitleResource(): Int = when (this) {
    PulseThemeId.CLARITY -> R.string.theme_clarity_subtitle
    PulseThemeId.EMBER -> R.string.theme_ember_subtitle
    PulseThemeId.AURORA -> R.string.theme_aurora_subtitle
    PulseThemeId.PRISM_PLUS -> R.string.theme_prism_subtitle
}
