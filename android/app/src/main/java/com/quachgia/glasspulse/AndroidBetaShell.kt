package com.quachgia.glasspulse

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.safeDrawing
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp

@Composable
fun AndroidBetaShell(betaFullAccess: Boolean) {
    var detailsExpanded by rememberSaveable { mutableStateOf(false) }
    Scaffold(
        modifier = Modifier.testTag("android.shell"),
        containerColor = MaterialTheme.colorScheme.background,
        contentWindowInsets = WindowInsets.safeDrawing
    ) { innerPadding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(innerPadding)
                .padding(horizontal = 24.dp, vertical = 20.dp),
            verticalArrangement = Arrangement.Center,
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            GlassPulseMark()
            Spacer(Modifier.height(28.dp))
            Text(
                text = stringResource(R.string.android_scaffold_title),
                modifier = Modifier.semantics { heading() },
                style = MaterialTheme.typography.headlineMedium,
                fontWeight = FontWeight.SemiBold
            )
            Spacer(Modifier.height(12.dp))
            Text(
                text = stringResource(R.string.android_scaffold_body),
                style = MaterialTheme.typography.bodyLarge,
                color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.78f)
            )
            Spacer(Modifier.height(20.dp))
            AccessCard(betaFullAccess = betaFullAccess)
            Spacer(Modifier.height(20.dp))
            ScopeControl(
                expanded = detailsExpanded,
                onToggle = { detailsExpanded = !detailsExpanded }
            )
            if (detailsExpanded) {
                Spacer(Modifier.height(12.dp))
                Text(
                    text = stringResource(R.string.android_scope_expanded),
                    modifier = Modifier.testTag("android.scope.details"),
                    style = MaterialTheme.typography.bodyMedium
                )
            }
        }
    }
}

@Composable
private fun AccessCard(betaFullAccess: Boolean) {
    val accessText = stringResource(
        if (betaFullAccess) R.string.android_beta_access else R.string.android_production_access
    )
    Surface(
        modifier = Modifier
            .fillMaxWidth()
            .testTag("android.access.card"),
        shape = RoundedCornerShape(18.dp),
        color = MaterialTheme.colorScheme.surface
    ) {
        Row(
            modifier = Modifier.padding(horizontal = 18.dp, vertical = 16.dp),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Text(
                text = stringResource(R.string.android_channel_label),
                style = MaterialTheme.typography.labelLarge
            )
            Text(
                text = accessText,
                modifier = Modifier.testTag("android.access.value"),
                color = MaterialTheme.colorScheme.primary,
                fontWeight = FontWeight.SemiBold
            )
        }
    }
}

@Composable
private fun ScopeControl(
    expanded: Boolean,
    onToggle: () -> Unit
) {
    val label = stringResource(R.string.android_scope_button)
    OutlinedButton(
        onClick = onToggle,
        modifier = Modifier
            .fillMaxWidth()
            .height(48.dp)
            .testTag("android.scope.button")
            .semantics { contentDescription = label }
    ) {
        Text(text = label)
    }
}

@Composable
private fun GlassPulseMark() {
    val accent = MaterialTheme.colorScheme.primary
    val foreground = MaterialTheme.colorScheme.onBackground
    val description = stringResource(R.string.android_logo_description)
    Canvas(
        modifier = Modifier
            .size(124.dp)
            .clearAndSetSemantics { contentDescription = description }
            .testTag("android.logo")
    ) {
        val center = Offset(size.width / 2f, size.height / 2f)
        val ringRadius = size.minDimension * 0.34f
        drawCircle(
            color = accent,
            radius = ringRadius,
            center = center,
            style = Stroke(width = size.minDimension * 0.045f)
        )
        drawCircle(
            color = foreground,
            radius = size.minDimension * 0.075f,
            center = Offset(center.x, center.y - ringRadius)
        )
        val half = size.minDimension * 0.075f
        val diamond = Path().apply {
            moveTo(center.x, center.y - half)
            lineTo(center.x + half, center.y)
            lineTo(center.x, center.y + half)
            lineTo(center.x - half, center.y)
            close()
        }
        drawPath(path = diamond, color = accent)
    }
}
