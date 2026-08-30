import ActivityKit
import Foundation
import Observation

@MainActor
@Observable
final class GameActivityController {
    @ObservationIgnored private var activity: Activity<GlassPulseActivityAttributes>?
    private(set) var lastError: String?

    func synchronize(engine: GameEngine, profile: PlayerProfile, now: Date = .now) {
        switch engine.state {
        case .playing:
            startOrUpdate(engine: engine, profile: profile, now: now)
        case .paused:
            update(engine: engine, profile: profile, now: now)
        case .over:
            end(engine: engine, profile: profile, now: now)
        case .start:
            break
        }
    }

    func updateMeaningfulEvent(
        engine: GameEngine,
        profile: PlayerProfile,
        now: Date = .now
    ) {
        guard activity != nil else { return }
        update(engine: engine, profile: profile, now: now)
    }

    private func startOrUpdate(
        engine: GameEngine,
        profile: PlayerProfile,
        now: Date
    ) {
        guard isEligible(engine) else { return }
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        guard activity == nil else {
            update(engine: engine, profile: profile, now: now)
            return
        }

        do {
            activity = try Activity.request(
                attributes: attributes(for: engine),
                content: content(engine: engine, profile: profile, now: now),
                pushType: nil
            )
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
    }

    private func update(
        engine: GameEngine,
        profile: PlayerProfile,
        now: Date
    ) {
        guard let activity else { return }
        let content = content(engine: engine, profile: profile, now: now)
        Task {
            await activity.update(content)
        }
    }

    private func end(
        engine: GameEngine,
        profile: PlayerProfile,
        now: Date
    ) {
        guard let activity else { return }
        let content = content(engine: engine, profile: profile, now: now)
        self.activity = nil
        Task {
            await activity.end(content, dismissalPolicy: .immediate)
        }
    }

    private func isEligible(_ engine: GameEngine) -> Bool {
        engine.modeID == .dailyChallenge || engine.modeID == .rush60
    }

    private func attributes(for engine: GameEngine) -> GlassPulseActivityAttributes {
        let title = engine.modeID == .dailyChallenge
            ? "Daily · \(engine.effectiveModeID.title)"
            : engine.modeID.title
        return GlassPulseActivityAttributes(
            modeTitle: title,
            isDaily: engine.modeID == .dailyChallenge
        )
    }

    private func content(
        engine: GameEngine,
        profile: PlayerProfile,
        now: Date
    ) -> ActivityContent<GlassPulseActivityAttributes.ContentState> {
        let remainingSeconds = engine.remainingTime.map { max(0, Int(ceil($0))) }
        let timerEndDate = engine.state == .playing
            ? engine.remainingTime.map { now.addingTimeInterval($0) }
            : nil
        let state = GlassPulseActivityAttributes.ContentState(
            score: engine.score,
            remainingSeconds: remainingSeconds,
            timerEndDate: timerEndDate,
            dailyStreak: profile.dailyStreak,
            localDailyBest: profile.dailyBest(for: engine.session.dailyKey),
            isPaused: engine.state == .paused
        )
        return ActivityContent(state: state, staleDate: timerEndDate)
    }
}
