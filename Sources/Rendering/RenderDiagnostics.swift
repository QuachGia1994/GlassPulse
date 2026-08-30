import Foundation
import os

struct GameRenderSnapshot: Equatable, Sendable {
    let ballAngle: Double
    let obstacles: [Obstacle]
    let gem: Gem
    let precisionPulseActive: Bool
}

extension GameEngine {
    var renderSnapshot: GameRenderSnapshot {
        GameRenderSnapshot(
            ballAngle: ballAngle,
            obstacles: obstacles,
            gem: gem,
            precisionPulseActive: effectiveModeID != .precisionPulse || pulseIsActive
        )
    }
}

enum RendererBenchmarkFlags {
    static var spriteKitEnabled: Bool {
#if DEBUG || GLASS_PULSE_BETA
        ProcessInfo.processInfo.arguments.contains("--spritekit-benchmark")
#else
        false
#endif
    }
}

@MainActor
enum RenderDiagnostics {
    private static let signposter = OSSignposter(
        subsystem: "com.quachgia.glasspulse",
        category: "render"
    )
    private static let logger = Logger(
        subsystem: "com.quachgia.glasspulse",
        category: "render-metrics"
    )
    private static var canvasSamples: [Double] = []
    private static let sampleWindow = 240

    static func measureSimulation(_ operation: () -> Void) {
#if DEBUG || GLASS_PULSE_BETA
        let interval = signposter.beginInterval("SimulationUpdate")
        defer { signposter.endInterval("SimulationUpdate", interval) }
#endif
        operation()
    }

    static func measureCanvasFrame(_ operation: () -> Void) {
#if DEBUG || GLASS_PULSE_BETA
        let startedAt = ProcessInfo.processInfo.systemUptime
        let interval = signposter.beginInterval("CanvasFrame")
        defer {
            signposter.endInterval("CanvasFrame", interval)
            recordCanvasFrame(milliseconds: (ProcessInfo.processInfo.systemUptime - startedAt) * 1_000)
        }
#endif
        operation()
    }

    static func measureSpriteSnapshot(_ operation: () -> Void) {
#if DEBUG || GLASS_PULSE_BETA
        let interval = signposter.beginInterval("SpriteSnapshotApply")
        defer { signposter.endInterval("SpriteSnapshotApply", interval) }
#endif
        operation()
    }

    private static func recordCanvasFrame(milliseconds: Double) {
        canvasSamples.append(milliseconds)
        guard canvasSamples.count >= sampleWindow else { return }
        let sorted = canvasSamples.sorted()
        let p50 = percentile(0.50, values: sorted)
        let p95 = percentile(0.95, values: sorted)
        let p99 = percentile(0.99, values: sorted)
        logger.info("Canvas CPU ms p50=\(p50) p95=\(p95) p99=\(p99)")
        canvasSamples.removeAll(keepingCapacity: true)
    }

    private static func percentile(_ percentile: Double, values: [Double]) -> Double {
        guard !values.isEmpty else { return 0 }
        let index = Int((Double(values.count - 1) * percentile).rounded(.toNearestOrAwayFromZero))
        return values[index]
    }
}
