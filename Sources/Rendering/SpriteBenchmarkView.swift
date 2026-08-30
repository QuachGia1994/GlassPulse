import SpriteKit
import SwiftUI

@MainActor
struct SpriteBenchmarkView: View {
    let snapshot: GameRenderSnapshot

    @State private var renderer = SpriteBenchmarkRenderer()

    var body: some View {
        SpriteView(
            scene: renderer.scene,
            isPaused: false,
            preferredFramesPerSecond: 120,
            options: [.allowsTransparency]
        )
        .onAppear {
            renderer.apply(snapshot)
        }
        .onChange(of: snapshot) { _, snapshot in
            renderer.apply(snapshot)
        }
        .accessibilityHidden(true)
    }
}

@MainActor
private final class SpriteBenchmarkRenderer {
    let scene = SKScene(size: CGSize(width: 320, height: 320))

    private let orbitNode = SKShapeNode()
    private let gemNode = SKShapeNode()
    private let ballNode = SKShapeNode()
    private var obstacleNodes: [SKShapeNode] = []

    init() {
        scene.backgroundColor = .clear
        scene.scaleMode = .resizeFill

        orbitNode.strokeColor = .systemCyan
        orbitNode.lineWidth = 2
        orbitNode.glowWidth = 3
        scene.addChild(orbitNode)

        gemNode.fillColor = .systemYellow
        gemNode.strokeColor = .white
        gemNode.lineWidth = 1
        scene.addChild(gemNode)

        ballNode.fillColor = .systemOrange
        ballNode.strokeColor = .white
        ballNode.lineWidth = 1
        ballNode.glowWidth = 4
        scene.addChild(ballNode)
    }

    func apply(_ snapshot: GameRenderSnapshot) {
        RenderDiagnostics.measureSpriteSnapshot {
            render(snapshot)
        }
    }

    private func render(_ snapshot: GameRenderSnapshot) {
        let size = scene.size
        guard size.width > 0, size.height > 0 else { return }
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let radius = max(36, min(size.width, size.height) / 2 - 30)

        orbitNode.path = CGPath(
            ellipseIn: CGRect(
                x: center.x - radius,
                y: center.y - radius,
                width: radius * 2,
                height: radius * 2
            ),
            transform: nil
        )
        renderBall(snapshot, center: center, radius: radius)
        renderGem(snapshot, center: center, radius: radius)
        renderObstacles(snapshot.obstacles, center: center, radius: radius)
    }

    private func renderBall(
        _ snapshot: GameRenderSnapshot,
        center: CGPoint,
        radius: CGFloat
    ) {
        ballNode.path = CGPath(
            ellipseIn: CGRect(x: -9, y: -9, width: 18, height: 18),
            transform: nil
        )
        ballNode.position = point(center: center, radius: radius, angle: snapshot.ballAngle)
    }

    private func renderGem(
        _ snapshot: GameRenderSnapshot,
        center: CGPoint,
        radius: CGFloat
    ) {
        gemNode.path = diamondPath(radius: snapshot.precisionPulseActive ? 8.5 : 6)
        gemNode.position = point(center: center, radius: radius, angle: snapshot.gem.angle)
        gemNode.alpha = snapshot.precisionPulseActive ? 1 : 0.42
    }

    private func renderObstacles(
        _ obstacles: [Obstacle],
        center: CGPoint,
        radius: CGFloat
    ) {
        synchronizeObstacleNodeCount(obstacles.count)
        for (node, obstacle) in zip(obstacleNodes, obstacles) {
            let path = CGMutablePath()
            path.addArc(
                center: center,
                radius: radius,
                startAngle: -CGFloat(obstacle.angle + obstacle.width / 2),
                endAngle: -CGFloat(obstacle.angle - obstacle.width / 2),
                clockwise: false
            )
            node.path = path
        }
    }

    private func synchronizeObstacleNodeCount(_ count: Int) {
        while obstacleNodes.count < count {
            let node = SKShapeNode()
            node.strokeColor = .systemRed
            node.lineWidth = 10
            node.lineCap = .round
            node.glowWidth = 3
            obstacleNodes.append(node)
            scene.addChild(node)
        }
        while obstacleNodes.count > count {
            obstacleNodes.removeLast().removeFromParent()
        }
    }

    private func point(center: CGPoint, radius: CGFloat, angle: Double) -> CGPoint {
        let spriteAngle = -angle
        return CGPoint(
            x: center.x + radius * CGFloat(cos(spriteAngle)),
            y: center.y + radius * CGFloat(sin(spriteAngle))
        )
    }

    private func diamondPath(radius: CGFloat) -> CGPath {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: 0, y: radius))
        path.addLine(to: CGPoint(x: radius, y: 0))
        path.addLine(to: CGPoint(x: 0, y: -radius))
        path.addLine(to: CGPoint(x: -radius, y: 0))
        path.closeSubpath()
        return path
    }
}
