package com.quachgia.glasspulse

import androidx.annotation.StringRes
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
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.safeDrawing
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.layout.weight
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Surface
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

    LaunchedEffect(controller) {
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
                .background(Brush.verticalGradient(listOf(palette.backgroundTop, palette.backgroundBottom)))
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
    if (showAccess) {
        AccessDialog(uiState.betaFullAccess) { showAccess = false }
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
    onShowAccess: () -> Unit
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
            Spacer(Modifier.height(8.dp))
            GameBoard(
                uiState = uiState,
                controller = controller,
                palette = palette,
                side = boardSide,
                onShowModes = onShowModes
            )
            Spacer(Modifier.weight(1f))
            GameFooter(
                uiState = uiState,
                controller = controller,
                palette = palette,
                onShowModes = onShowModes,
                onShowThemes = onShowThemes,
                onShowAccess = onShowAccess
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
            .background(palette.glassSurface)
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
            Button(
                onClick = controller::pause,
                modifier = Modifier
                    .align(Alignment.TopEnd)
                    .padding(12.dp)
                    .size(46.dp)
                    .testTag("game.pause"),
                contentPadding = PaddingValues(0.dp)
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
            frameTimeNanos = uiState.frameTimeNanos
        )
    }
}

@Composable
private fun StatusCard(
    modifier: Modifier = Modifier,
    content: @Composable () -> Unit
) {
    Surface(
        modifier = modifier.widthIn(max = 310.dp),
        shape = RoundedCornerShape(22.dp),
        color = Color(0xE62A282D),
        tonalElevation = 8.dp,
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
    StatusCard {
        Column(
            modifier = Modifier.padding(horizontal = 24.dp, vertical = 20.dp),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            Text(
                stringResource(R.string.game_mark_symbol),
                color = palette.ring,
                fontSize = 27.sp
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
    StatusCard {
        Column(
            modifier = Modifier.padding(horizontal = 24.dp, vertical = 20.dp),
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
                    .padding(top = 12.dp)
                    .testTag("game.resume")
            ) {
                Text(
                    text = stringResource(R.string.action_resume),
                    color = palette.backgroundBottom
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
    StatusCard {
        Column(
            modifier = Modifier.padding(horizontal = 20.dp, vertical = 18.dp),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            Text(
                text = stringResource(
                    if (completed) R.string.game_status_completed else R.string.game_status_collision
                ),
                textAlign = TextAlign.Center,
                fontSize = 19.sp,
                fontWeight = FontWeight.Bold
            )
            Text(
                text = stringResource(
                    R.string.game_reward,
                    uiState.game.rewardForCurrentRun
                ),
                modifier = Modifier.padding(top = 5.dp),
                color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.66f)
            )
            if (uiState.dailyBonus > 0) {
                Text(
                    text = stringResource(R.string.game_daily_bonus, uiState.dailyBonus),
                    color = palette.ring,
                    fontWeight = FontWeight.SemiBold
                )
            }
            Button(
                onClick = controller::retry,
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(top = 12.dp)
                    .testTag("game.retry")
            ) {
                Text(stringResource(R.string.action_retry))
            }
            OutlinedButton(
                onClick = onShowModes,
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(top = 6.dp)
                    .testTag("game.chooseMode")
            ) {
                Text(stringResource(R.string.action_choose_mode))
            }
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
    onShowAccess: () -> Unit
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(bottom = 4.dp),
        horizontalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        OutlinedButton(
            onClick = onShowModes,
            enabled = controller.canChangeMode(),
            modifier = Modifier
                .weight(1f)
                .testTag("game.modes"),
            contentPadding = PaddingValues(horizontal = 8.dp)
        ) {
            Text(stringResource(R.string.footer_mode), maxLines = 1)
        }
        OutlinedButton(
            onClick = onShowThemes,
            modifier = Modifier
                .weight(1f)
                .testTag("game.themes"),
            contentPadding = PaddingValues(horizontal = 8.dp)
        ) {
            Text(stringResource(R.string.footer_theme), color = palette.ring, maxLines = 1)
        }
        OutlinedButton(
            onClick = onShowAccess,
            modifier = Modifier
                .weight(1f)
                .testTag("game.access"),
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
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun ModePickerSheet(
    uiState: GameUiState,
    controller: GameController,
    onDismiss: () -> Unit
) {
    ModalBottomSheet(onDismissRequest = onDismiss) {
        Column(
            modifier = Modifier
                .fillMaxHeight(0.92f)
                .verticalScroll(rememberScrollState())
                .padding(horizontal = 18.dp)
                .padding(bottom = 28.dp),
            verticalArrangement = Arrangement.spacedBy(10.dp)
        ) {
            Text(
                text = stringResource(R.string.mode_picker_title),
                modifier = Modifier.semantics { heading() },
                fontSize = 26.sp,
                fontWeight = FontWeight.Bold
            )
            if (uiState.betaFullAccess) {
                Text(
                    text = stringResource(R.string.beta_all_modes_open),
                    color = MaterialTheme.colorScheme.primary,
                    fontWeight = FontWeight.SemiBold
                )
            }
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
                    MaterialTheme.colorScheme.primary.copy(alpha = 0.14f)
                } else {
                    MaterialTheme.colorScheme.surface
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
            .padding(16.dp)
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text(
                text = stringResource(modeId.titleResource()),
                modifier = Modifier.weight(1f),
                fontSize = 18.sp,
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
                fontWeight = FontWeight.SemiBold
            )
        }
        Text(
            text = stringResource(modeId.subtitleResource()),
            modifier = Modifier.padding(top = 5.dp),
            color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.68f)
        )
        Text(
            text = stringResource(modeId.instructionResource()),
            modifier = Modifier.padding(top = 4.dp),
            fontSize = 12.sp,
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
    ModalBottomSheet(onDismissRequest = onDismiss) {
        Column(
            modifier = Modifier
                .fillMaxHeight(0.88f)
                .verticalScroll(rememberScrollState())
                .padding(horizontal = 18.dp)
                .padding(bottom = 28.dp),
            verticalArrangement = Arrangement.spacedBy(10.dp)
        ) {
            Text(
                text = stringResource(R.string.theme_picker_title),
                modifier = Modifier.semantics { heading() },
                fontSize = 26.sp,
                fontWeight = FontWeight.Bold
            )
            if (uiState.betaFullAccess) {
                Text(
                    text = stringResource(R.string.beta_all_themes_open),
                    color = MaterialTheme.colorScheme.primary,
                    fontWeight = FontWeight.SemiBold
                )
            }
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
            .background(MaterialTheme.colorScheme.surface)
            .border(
                width = if (selected) 2.dp else 1.dp,
                color = if (selected) palette.ring else Color.White.copy(alpha = 0.10f),
                shape = shape
            )
            .clickable(enabled = selectable, onClick = onSelect)
            .testTag("theme." + themeId.name.lowercase())
            .padding(14.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        ThemePreview(palette)
        Column(
            modifier = Modifier
                .weight(1f)
                .padding(horizontal = 14.dp)
        ) {
            Text(
                text = stringResource(themeId.titleResource()),
                fontSize = 18.sp,
                fontWeight = FontWeight.Bold
            )
            Text(
                text = stringResource(themeId.subtitleResource()),
                color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.62f)
            )
        }
        Text(
            text = themeAccessLabel(themeId, selected, unlocked, betaFullAccess),
            color = palette.ring,
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
    Canvas(modifier = Modifier.size(66.dp)) {
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
    onDismiss: () -> Unit
) {
    AlertDialog(
        onDismissRequest = onDismiss,
        title = {
            Text(
                stringResource(
                    if (betaFullAccess) R.string.beta_access_title else R.string.plus_access_title
                )
            )
        },
        text = {
            Text(
                stringResource(
                    if (betaFullAccess) R.string.beta_access_body else R.string.plus_access_body
                )
            )
        },
        confirmButton = {
            TextButton(onClick = onDismiss) {
                Text(stringResource(R.string.action_close))
            }
        }
    )
}

private fun DrawScope.drawGlassPulse(
    game: GameSnapshot,
    palette: PulsePalette,
    frameTimeNanos: Long
) {
    val center = Offset(size.width / 2, size.height / 2)
    val phase = frameTimeNanos / 1_000_000_000.0 * palette.pulseFrequency
    val pulse = sin(phase).toFloat() * palette.pulseAmplitudeDp.dp.toPx()
    val orbitRadius = max(36.dp.toPx(), size.minDimension / 2 - 30.dp.toPx() + pulse)

    drawCircle(
        color = palette.ring.copy(alpha = 0.18f),
        radius = orbitRadius,
        center = center,
        style = Stroke(width = 8.dp.toPx())
    )
    drawCircle(
        color = palette.ring.copy(alpha = 0.86f),
        radius = orbitRadius,
        center = center,
        style = Stroke(width = 1.8.dp.toPx())
    )
    drawCircle(
        color = Color.White.copy(alpha = 0.08f),
        radius = orbitRadius - 5.dp.toPx(),
        center = center,
        style = Stroke(width = 0.8.dp.toPx())
    )
    game.obstacles.forEach { obstacle ->
        drawObstacle(obstacle, center, orbitRadius, palette)
    }
    drawGem(game, center, orbitRadius, palette)
    drawEffects(game, center, orbitRadius, palette, frameTimeNanos)
    drawBall(game, center, orbitRadius, palette, frameTimeNanos)
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
    palette: PulsePalette
) {
    val gemCenter = orbitPoint(center, radius, game.gem.angle)
    val precision = game.session.effectiveModeId == GameModeId.PRECISION_PULSE
    val active = !precision || game.pulseIsActive
    val gemRadius = (if (active) 8.5.dp else 6.dp).toPx()

    drawCircle(
        color = palette.gem.copy(alpha = if (active) 0.20f else 0.08f),
        radius = if (active) 18.dp.toPx() else 10.dp.toPx(),
        center = gemCenter
    )
    drawPath(
        path = diamondPath(gemCenter, gemRadius),
        color = palette.gem.copy(alpha = if (active) 1f else 0.42f)
    )
    if (precision) {
        drawCircle(
            color = palette.gem.copy(alpha = if (active) 0.9f else 0.24f),
            radius = (if (active) 15.dp else 10.dp).toPx(),
            center = gemCenter,
            style = Stroke(
                width = if (active) 2.4.dp.toPx() else 1.2.dp.toPx(),
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
    nowNanos: Long
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
