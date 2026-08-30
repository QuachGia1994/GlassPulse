import AVFAudio
import CoreHaptics
import Observation
import UIKit

struct SensoryClient: Sendable {
    let reversed: @MainActor @Sendable () -> Void
    let collected: @MainActor @Sendable () -> Void
    let collided: @MainActor @Sendable () -> Void
    let proximity: @MainActor @Sendable (Double, Bool) -> Void
    let stoppedContinuous: @MainActor @Sendable () -> Void

    static let silent = SensoryClient(
        reversed: {},
        collected: {},
        collided: {},
        proximity: { _, _ in },
        stoppedContinuous: {}
    )
}

enum SensoryError: Error, Equatable, LocalizedError {
    case audioFormatUnavailable
    case playbackFailed(String)
    case hapticFailed(String)

    var errorDescription: String? {
        switch self {
        case .audioFormatUnavailable:
            "Không thể tạo định dạng âm thanh."
        case .playbackFailed(let reason):
            "Không thể phát âm thanh: \(reason)"
        case .hapticFailed(let reason):
            "Không thể phát haptic: \(reason)"
        }
    }
}

private enum SensoryEvent: CaseIterable, Hashable {
    case reverse
    case collect
    case collision

    var frequency: Double {
        switch self {
        case .reverse: 310
        case .collect: 760
        case .collision: 118
        }
    }

    var duration: Double {
        switch self {
        case .reverse: 0.055
        case .collect: 0.11
        case .collision: 0.20
        }
    }

    var volume: Double {
        switch self {
        case .reverse: 0.035
        case .collect: 0.070
        case .collision: 0.060
        }
    }
}

@MainActor
@Observable
final class SensoryEngine {
    @ObservationIgnored private let audioEngine = AVAudioEngine()
    @ObservationIgnored private let eventNode = AVAudioPlayerNode()
    @ObservationIgnored private let reverseFeedback = UIImpactFeedbackGenerator(style: .light)
    @ObservationIgnored private let collectFeedback = UIImpactFeedbackGenerator(style: .rigid)
    @ObservationIgnored private let collisionFeedback = UINotificationFeedbackGenerator()
    @ObservationIgnored private var audioFormat: AVAudioFormat?
    @ObservationIgnored private var toneBuffers: [SensoryEvent: AVAudioPCMBuffer] = [:]
    @ObservationIgnored private var hapticEngine: CHHapticEngine?
    @ObservationIgnored private var continuousPlayer: CHHapticAdvancedPatternPlayer?
    @ObservationIgnored private var lastProximityUpdate: Date?
    @ObservationIgnored private var audioInterruptionObserver: NSObjectProtocol?
    @ObservationIgnored private weak var settings: GameSettings?

    private(set) var lastError: SensoryError?
    private(set) var supportsAdaptiveHaptics = false

    var soundEnabled: Bool { settings?.soundEnabled ?? true }
    var hapticsEnabled: Bool { settings?.hapticsEnabled ?? true }

    init(settings: GameSettings? = nil) {
        self.settings = settings
        configureAudioGraph()
        configureHaptics()
        observeAudioInterruptions()
    }

    func applySettings(_ settings: GameSettings) {
        self.settings = settings
        if !settings.hapticsEnabled { stopContinuousHaptic() }
        if !settings.soundEnabled {
            eventNode.stop()
            audioEngine.pause()
        }
    }

    var client: SensoryClient {
        SensoryClient(
            reversed: { [weak self] in self?.play(.reverse) },
            collected: { [weak self] in self?.play(.collect) },
            collided: { [weak self] in self?.play(.collision) },
            proximity: { [weak self] proximity, pulseActive in
                self?.updateProximity(proximity, pulseActive: pulseActive)
            },
            stoppedContinuous: { [weak self] in self?.stopContinuousHaptic() }
        )
    }

    private func configureAudioGraph() {
        guard let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1) else {
            lastError = .audioFormatUnavailable
            return
        }
        audioFormat = format
        audioEngine.attach(eventNode)
        audioEngine.connect(eventNode, to: audioEngine.mainMixerNode, format: format)
        toneBuffers = Dictionary(
            uniqueKeysWithValues: SensoryEvent.allCases.compactMap { event in
                makeToneBuffer(for: event).map { (event, $0) }
            }
        )
    }

    private func observeAudioInterruptions() {
        audioInterruptionObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance(),
            queue: nil
        ) { [weak self] notification in
            let rawType = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt
            Task { @MainActor [weak self] in
                self?.handleAudioInterruption(rawType)
            }
        }
    }

    private func handleAudioInterruption(_ rawType: UInt?) {
        guard let rawType,
              let type = AVAudioSession.InterruptionType(rawValue: rawType) else { return }
        switch type {
        case .began:
            eventNode.pause()
            audioEngine.pause()
            stopContinuousHaptic()
        case .ended:
            lastError = nil
        @unknown default:
            return
        }
    }

    private func configureHaptics() {
        supportsAdaptiveHaptics = CHHapticEngine.capabilitiesForHardware().supportsHaptics
        guard supportsAdaptiveHaptics else { return }
        do {
            let engine = try CHHapticEngine()
            engine.playsHapticsOnly = true
            engine.isAutoShutdownEnabled = true
            engine.resetHandler = { [weak self] in
                Task { @MainActor [weak self] in
                    self?.handleHapticReset()
                }
            }
            engine.stoppedHandler = { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.continuousPlayer = nil
                    self?.lastProximityUpdate = nil
                }
            }
            hapticEngine = engine
        } catch {
            supportsAdaptiveHaptics = false
            lastError = .hapticFailed(error.localizedDescription)
        }
    }

    private func play(_ event: SensoryEvent) {
        if hapticsEnabled { playTransientHaptic(event) }
        guard soundEnabled else { return }
        do {
            try startAudioIfNeeded()
            guard let buffer = toneBuffers[event] else {
                throw SensoryError.audioFormatUnavailable
            }
            eventNode.stop()
            eventNode.scheduleBuffer(buffer)
            eventNode.volume = Float(event.volume)
            eventNode.play()
            lastError = nil
        } catch let error as SensoryError {
            lastError = error
        } catch {
            lastError = .playbackFailed(error.localizedDescription)
        }
    }

    private func playTransientHaptic(_ event: SensoryEvent) {
        switch event {
        case .reverse:
            reverseFeedback.prepare()
            reverseFeedback.impactOccurred(intensity: 0.58)
        case .collect:
            collectFeedback.prepare()
            collectFeedback.impactOccurred(intensity: 0.78)
        case .collision:
            collisionFeedback.prepare()
            collisionFeedback.notificationOccurred(.error)
        }
    }

    private func updateProximity(_ proximity: Double, pulseActive: Bool) {
        guard hapticsEnabled, supportsAdaptiveHaptics else { return }
        let clamped = min(max(proximity, 0), 1)
        guard clamped >= 0.15 else {
            stopContinuousHaptic()
            return
        }
        let now = Date.now
        if let lastProximityUpdate,
           now.timeIntervalSince(lastProximityUpdate) < 1.0 / 25.0 { return }
        self.lastProximityUpdate = now

        do {
            let player = try continuousHapticPlayer()
            let intensity = Float((0.18 + 0.72 * clamped) * (pulseActive ? 1 : 0.42))
            let sharpness = Float(-0.45 + 0.90 * clamped)
            try player.sendParameters(
                [
                    CHHapticDynamicParameter(parameterID: .hapticIntensityControl, value: intensity, relativeTime: 0),
                    CHHapticDynamicParameter(parameterID: .hapticSharpnessControl, value: sharpness, relativeTime: 0)
                ],
                atTime: CHHapticTimeImmediate
            )
            lastError = nil
        } catch {
            lastError = .hapticFailed(error.localizedDescription)
            stopContinuousHaptic()
        }
    }

    private func continuousHapticPlayer() throws -> CHHapticAdvancedPatternPlayer {
        if let continuousPlayer { return continuousPlayer }
        guard let hapticEngine else { throw SensoryError.hapticFailed("Core Haptics unavailable") }
        try hapticEngine.start()
        let event = CHHapticEvent(
            eventType: .hapticContinuous,
            parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 1),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.5)
            ],
            relativeTime: 0,
            duration: 1
        )
        let pattern = try CHHapticPattern(events: [event], parameters: [])
        let player = try hapticEngine.makeAdvancedPlayer(with: pattern)
        player.loopEnabled = true
        try player.start(atTime: CHHapticTimeImmediate)
        continuousPlayer = player
        return player
    }

    private func stopContinuousHaptic() {
        guard let continuousPlayer else {
            lastProximityUpdate = nil
            return
        }
        do {
            try continuousPlayer.stop(atTime: CHHapticTimeImmediate)
        } catch {
            lastError = .hapticFailed(error.localizedDescription)
        }
        self.continuousPlayer = nil
        lastProximityUpdate = nil
    }

    private func handleHapticReset() {
        continuousPlayer = nil
        lastProximityUpdate = nil
        do {
            try hapticEngine?.start()
        } catch {
            lastError = .hapticFailed(error.localizedDescription)
        }
    }

    private func startAudioIfNeeded() throws {
        guard !audioEngine.isRunning else { return }
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.ambient, options: [.mixWithOthers])
            try session.setActive(true)
            try audioEngine.start()
        } catch {
            throw SensoryError.playbackFailed(error.localizedDescription)
        }
    }

    private func makeToneBuffer(for event: SensoryEvent) -> AVAudioPCMBuffer? {
        guard let audioFormat,
              let buffer = AVAudioPCMBuffer(
                pcmFormat: audioFormat,
                frameCapacity: AVAudioFrameCount(audioFormat.sampleRate * event.duration)
              ),
              let channel = buffer.floatChannelData?[0] else { return nil }

        buffer.frameLength = buffer.frameCapacity
        for frame in 0..<Int(buffer.frameLength) {
            let progress = Double(frame) / Double(max(Int(buffer.frameLength) - 1, 1))
            let phase = 2 * Double.pi * event.frequency * Double(frame) / audioFormat.sampleRate
            let envelope = min(progress / 0.08, 1) * pow(1 - progress, 2)
            channel[frame] = Float(sin(phase) * envelope * 0.20)
        }
        return buffer
    }
}
