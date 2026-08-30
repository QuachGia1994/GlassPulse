import SwiftUI

extension GameEngine {
    func draw(
        in context: inout GraphicsContext,
        size: CGSize,
        now: Date,
        theme: PulseTheme
    ) {
        RenderDiagnostics.measureSimulation {
            advance(to: now)
        }
        guard size.width > 0, size.height > 0 else { return }

        RenderDiagnostics.measureCanvasFrame {
            let geometry = renderGeometry(size: size, now: now, theme: theme)
            drawAmbientRings(in: &context, geometry: geometry, theme: theme)
            for obstacle in obstacles {
                drawObstacle(obstacle, in: &context, geometry: geometry, theme: theme)
            }
            drawGem(in: &context, geometry: geometry, theme: theme)
            drawEffects(in: &context, geometry: geometry, theme: theme, now: now)
            drawBall(in: &context, geometry: geometry, theme: theme, now: now)
        }
    }

    private func renderGeometry(
        size: CGSize,
        now: Date,
        theme: PulseTheme
    ) -> RenderGeometry {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let phase = now.timeIntervalSinceReferenceDate * theme.pulseFrequency
        let pulse = CGFloat(sin(phase)) * theme.pulseAmplitude
        let radius = max(36, min(size.width, size.height) / 2 - 30 + pulse)
        return RenderGeometry(center: center, orbitRadius: radius, ballRadius: 9)
    }

    private func drawAmbientRings(
        in context: inout GraphicsContext,
        geometry: RenderGeometry,
        theme: PulseTheme
    ) {
        let outer = ellipse(center: geometry.center, radius: geometry.orbitRadius)
        let inner = ellipse(center: geometry.center, radius: geometry.orbitRadius - 5)
        context.drawLayer { layer in
            layer.addFilter(.shadow(color: theme.palette.ring.opacity(0.45), radius: 9))
            layer.stroke(outer, with: .color(theme.palette.ring.opacity(0.82)), lineWidth: 1.8)
        }
        context.stroke(inner, with: .color(.white.opacity(0.08)), lineWidth: 0.8)
    }

    private func drawObstacle(
        _ obstacle: Obstacle,
        in context: inout GraphicsContext,
        geometry: RenderGeometry,
        theme: PulseTheme
    ) {
        var arc = Path()
        arc.addArc(
            center: geometry.center,
            radius: geometry.orbitRadius,
            startAngle: .radians(obstacle.angle - obstacle.width / 2),
            endAngle: .radians(obstacle.angle + obstacle.width / 2),
            clockwise: false
        )
        context.drawLayer { layer in
            layer.addFilter(.shadow(color: theme.palette.hazard.opacity(0.62), radius: 7))
            layer.stroke(
                arc,
                with: .color(theme.palette.hazard),
                style: StrokeStyle(lineWidth: 10, lineCap: .round)
            )
        }
        drawSpikes(for: obstacle, in: &context, geometry: geometry, theme: theme)
    }

    private func drawSpikes(
        for obstacle: Obstacle,
        in context: inout GraphicsContext,
        geometry: RenderGeometry,
        theme: PulseTheme
    ) {
        let spikeCount = max(3, Int(ceil(obstacle.width / 0.11)))
        for index in 0...spikeCount {
            let progress = Double(index) / Double(spikeCount)
            let angle = obstacle.angle - obstacle.width / 2 + obstacle.width * progress
            let path = spikePath(angle: angle, geometry: geometry)
            context.fill(path, with: .color(theme.palette.hazard.opacity(0.94)))
        }
    }

    private func spikePath(angle: Double, geometry: RenderGeometry) -> Path {
        let left = point(
            on: geometry.center,
            radius: geometry.orbitRadius - 4,
            angle: angle - 0.025
        )
        let right = point(
            on: geometry.center,
            radius: geometry.orbitRadius - 4,
            angle: angle + 0.025
        )
        let tip = point(on: geometry.center, radius: geometry.orbitRadius - 15, angle: angle)
        var path = Path()
        path.move(to: left)
        path.addLine(to: tip)
        path.addLine(to: right)
        path.closeSubpath()
        return path
    }

    private func drawGem(
        in context: inout GraphicsContext,
        geometry: RenderGeometry,
        theme: PulseTheme
    ) {
        let center = point(on: geometry.center, radius: geometry.orbitRadius, angle: gem.angle)
        let isPrecision = effectiveModeID == .precisionPulse
        let active = !isPrecision || pulseIsActive
        let radius: CGFloat = active ? 8.5 : 6
        let gemPath = diamond(center: center, radius: radius)
        context.drawLayer { layer in
            layer.addFilter(.shadow(color: theme.palette.gem.opacity(active ? 0.78 : 0.28), radius: active ? 12 : 4))
            layer.fill(gemPath, with: .color(theme.palette.gem.opacity(active ? 1 : 0.42)))
        }
        if isPrecision {
            let haloRadius: CGFloat = active ? 15 : 10
            context.stroke(
                ellipse(center: center, radius: haloRadius),
                with: .color(theme.palette.gem.opacity(active ? 0.9 : 0.24)),
                style: StrokeStyle(lineWidth: active ? 2.4 : 1.2, dash: active ? [] : [3, 3])
            )
        }
        context.fill(
            diamond(center: CGPoint(x: center.x - 2, y: center.y - 2), radius: active ? 2.4 : 1.6),
            with: .color(.white.opacity(active ? 0.86 : 0.45))
        )
    }

    private func drawBall(
        in context: inout GraphicsContext,
        geometry: RenderGeometry,
        theme: PulseTheme,
        now: Date
    ) {
        let center = point(on: geometry.center, radius: geometry.orbitRadius, angle: ballAngle)
        let collisionProgress = effectProgress(
            startedAt: collisionEffect?.startedAt,
            duration: 0.65,
            now: now
        )
        let radius = geometry.ballRadius * (1 + collisionProgress * 0.28)
        let ball = ellipse(center: center, radius: radius)
        context.drawLayer { layer in
            layer.addFilter(.shadow(color: theme.palette.ball.opacity(0.78), radius: 12))
            layer.fill(ball, with: .color(theme.palette.ball.opacity(0.92)))
        }
        let highlightCenter = CGPoint(x: center.x - radius * 0.28, y: center.y - radius * 0.32)
        context.fill(ellipse(center: highlightCenter, radius: radius * 0.30), with: .color(.white.opacity(0.76)))
    }

    private func drawEffects(
        in context: inout GraphicsContext,
        geometry: RenderGeometry,
        theme: PulseTheme,
        now: Date
    ) {
        drawGemBurst(in: &context, geometry: geometry, theme: theme, now: now)
        drawCollisionFlash(in: &context, geometry: geometry, theme: theme, now: now)
    }

    private func drawGemBurst(
        in context: inout GraphicsContext,
        geometry: RenderGeometry,
        theme: PulseTheme,
        now: Date
    ) {
        guard let gemBurst else { return }
        let progress = effectProgress(startedAt: gemBurst.startedAt, duration: 0.42, now: now)
        let center = point(on: geometry.center, radius: geometry.orbitRadius, angle: gemBurst.angle)
        let burst = ellipse(center: center, radius: 8 + progress * 22)
        context.drawLayer { layer in
            layer.opacity = Double(1 - progress)
            layer.stroke(burst, with: .color(theme.palette.gem), lineWidth: 3 - progress * 2)
        }
    }

    private func drawCollisionFlash(
        in context: inout GraphicsContext,
        geometry: RenderGeometry,
        theme: PulseTheme,
        now: Date
    ) {
        guard let collisionEffect else { return }
        let progress = effectProgress(startedAt: collisionEffect.startedAt, duration: 0.65, now: now)
        let center = point(on: geometry.center, radius: geometry.orbitRadius, angle: collisionEffect.angle)
        context.drawLayer { layer in
            layer.opacity = Double(1 - progress)
            layer.fill(ellipse(center: center, radius: 12 + progress * 34), with: .color(theme.palette.hazard.opacity(0.46)))
            layer.stroke(
                ellipse(center: geometry.center, radius: geometry.orbitRadius + progress * 12),
                with: .color(theme.palette.hazard),
                lineWidth: 5 - progress * 3
            )
        }
    }

    private func effectProgress(
        startedAt: Date?,
        duration: Double,
        now: Date
    ) -> CGFloat {
        guard let startedAt else { return 0 }
        return CGFloat(min(max(now.timeIntervalSince(startedAt) / duration, 0), 1))
    }

    private func ellipse(center: CGPoint, radius: CGFloat) -> Path {
        Path(
            ellipseIn: CGRect(
                x: center.x - radius,
                y: center.y - radius,
                width: radius * 2,
                height: radius * 2
            )
        )
    }

    private func diamond(center: CGPoint, radius: CGFloat) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: center.x, y: center.y - radius))
        path.addLine(to: CGPoint(x: center.x + radius, y: center.y))
        path.addLine(to: CGPoint(x: center.x, y: center.y + radius))
        path.addLine(to: CGPoint(x: center.x - radius, y: center.y))
        path.closeSubpath()
        return path
    }

    private func point(
        on center: CGPoint,
        radius: CGFloat,
        angle: Double
    ) -> CGPoint {
        CGPoint(
            x: center.x + radius * CGFloat(cos(angle)),
            y: center.y + radius * CGFloat(sin(angle))
        )
    }
}

private struct RenderGeometry {
    let center: CGPoint
    let orbitRadius: CGFloat
    let ballRadius: CGFloat
}
