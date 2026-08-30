import AVFAudio
import Observation
import UIKit

struct SensoryClient: Sendable {
    let reversed: @MainActor @Sendable () -> Void
    let collected: @MainActor @Sendable () -> Void
    let collided: @MainActor @Sendable () -> Void

    static let silent = SensoryClient(
        reversed: {},
        collected: {},
        collided: {}
    )
}

enum SensoryError: Error, Equatable, LocalizedError {
    case audioFormatUnavailable
    case playbackFailed(String)

    var errorDescription: String? {
        switch self {
        case .audioFormatUnavailable:
            "Không thể tạo định dạng âm thanh."
        case .playbackFailed(let reason):
            "Không thể phát âm thanh: \(reason)"
        }
    }
}

private enum SensoryEvent {
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

    private(set) var lastError: SensoryError?

    init() {
        configureAudioGraph()
    }

    var client: SensoryClient {
        SensoryClient(
            reversed: { [weak self] in self?.play(.reverse) },
            collected: { [weak self] in self?.play(.collect) },
            collided: { [weak self] in self?.play(.collision) }
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
    }

    private func play(_ event: SensoryEvent) {
        playHaptic(event)
        do {
            try startAudioIfNeeded()
            guard let buffer = makeToneBuffer(for: event) else {
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

    private func playHaptic(_ event: SensoryEvent) {
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
