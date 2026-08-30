import AVFAudio
import Foundation
import Observation

/// Bundled background-music loop playback. One pinned master, one packaged
/// encode per platform; never streams. Lifecycle: start only after the launch
/// UI is ready, pause on background/interruption, resume only when enabled and
/// previously playing.
@MainActor
@Observable
final class MusicEngine {
    private enum Source {
        static let resource = "bgm"
        static let `extension` = "m4a"
        static let volume: Float = 0.35
    }

    @ObservationIgnored private weak var settings: GameSettings?
    @ObservationIgnored private var player: AVAudioPlayer?
    @ObservationIgnored private var interruptionObserver: NSObjectProtocol?
    @ObservationIgnored private var wasPlayingBeforeInterruption = false
    @ObservationIgnored private var isSceneActive = true

    private(set) var lastError: String?
    private(set) var isPlaying = false

    init(settings: GameSettings? = nil) {
        self.settings = settings
        observeInterruptions()
    }

    func applySettings(_ settings: GameSettings) {
        self.settings = settings
        if settings.musicEnabled {
            startIfReady()
        } else {
            stop()
        }
    }

    /// Called once the launch UI has finished so playback never races cold start.
    func startIfReady() {
        guard settings?.musicEnabled ?? true else { return }
        guard isSceneActive else { return }
        if player == nil {
            guard let url = Bundle.main.url(
                forResource: Source.resource,
                withExtension: Source.extension
            ) else {
                lastError = "Bundled music resource not found"
                return
            }
            do {
                let audioPlayer = try AVAudioPlayer(contentsOf: url)
                audioPlayer.numberOfLoops = -1
                audioPlayer.volume = Source.volume
                player = audioPlayer
            } catch {
                lastError = "Music playback failed: \(error.localizedDescription)"
                return
            }
        }
        activateSessionAndPlay()
    }

    func handleScenePhase(active: Bool) {
        isSceneActive = active
        if active {
            if settings?.musicEnabled ?? true, wasPlayingBeforeInterruption || isPlaying {
                wasPlayingBeforeInterruption = false
                activateSessionAndPlay()
            }
        } else {
            wasPlayingBeforeInterruption = isPlaying
            pause()
        }
    }

    func release() {
        player?.stop()
        player = nil
        isPlaying = false
        if let interruptionObserver {
            NotificationCenter.default.removeObserver(interruptionObserver)
        }
        interruptionObserver = nil
    }

    private func stop() {
        wasPlayingBeforeInterruption = false
        player?.stop()
        player?.currentTime = 0
        isPlaying = false
    }

    private func pause() {
        guard isPlaying else { return }
        player?.pause()
        isPlaying = false
    }

    private func activateSessionAndPlay() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.ambient, options: [.mixWithOthers])
            try session.setActive(true)
        } catch {
            lastError = "Audio session failed: \(error.localizedDescription)"
            return
        }
        guard let player else { return }
        if player.play() {
            isPlaying = true
            lastError = nil
        } else {
            lastError = "Music playback failed to start"
        }
    }

    private func observeInterruptions() {
        interruptionObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance(),
            queue: nil
        ) { [weak self] notification in
            let rawType = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt
            Task { @MainActor [weak self] in
                self?.handleInterruption(rawType)
            }
        }
    }

    private func handleInterruption(_ rawType: UInt?) {
        guard let rawType,
              let type = AVAudioSession.InterruptionType(rawValue: rawType) else { return }
        switch type {
        case .began:
            wasPlayingBeforeInterruption = isPlaying
            pause()
        case .ended:
            if wasPlayingBeforeInterruption, settings?.musicEnabled ?? true {
                wasPlayingBeforeInterruption = false
                activateSessionAndPlay()
            }
        @unknown default:
            return
        }
    }
}
