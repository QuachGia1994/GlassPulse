import ActivityKit
import Foundation
import Observation

private struct GameActivityPayload: Sendable {
    let state: GlassPulseActivityAttributes.ContentState
    let staleDate: Date?

    var content: ActivityContent<GlassPulseActivityAttributes.ContentState> {
        ActivityContent(state: state, staleDate: staleDate)
    }
}

@MainActor
@Observable
final class GameActivityController {
    @ObservationIgnored private var activityID: String?
    @ObservationIgnored private var pendingEndTask: Task<Void, Never>?
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
        guard activityID != nil else { return }
        update(engine: engine, profile: profile, now: now)
    }

    func finishPendingEnd() async {
        guard let pendingEndTask else { return }
        await pendingEndTask.value
        self.pendingEndTask = nil
    }

    private func startOrUpdate(
        engine: GameEngine,
        profile: PlayerProfile,
        now: Date
    ) {
        guard isEligible(engine) else { return }
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        guard activityID == nil else {
            update(engine: engine, profile: profile, now: now)
            return
        }

        do {
            let requestedActivity = try Activity.request(
                attributes: attributes(for: engine),
                content: payload(engine: engine, profile: profile, now: now).content,
                pushType: nil
            )
            activityID = requestedActivity.id
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
        guard let activityID else { return }
        let payload = payload(engine: engine, profile: profile, now: now)
        Task {
            await Self.updateActivity(id: activityID, payload: payload)
        }
    }

    private func end(
        engine: GameEngine,
        profile: PlayerProfile,
        now: Date
    ) {
        guard let activityID else { return }
        let payload = payload(engine: engine, profile: profile, now: now)
        self.activityID = nil
        pendingEndTask = Task {
            await Self.endActivity(id: activityID, payload: payload)
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

    private func payload(
        engine: GameEngine,
        profile: PlayerProfile,
        now: Date
    ) -> GameActivityPayload {
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
        return GameActivityPayload(state: state, staleDate: timerEndDate)
    }

    nonisolated private static func updateActivity(
        id: String,
        payload: GameActivityPayload
    ) async {
        guard let activity = Activity<GlassPulseActivityAttributes>.activities.first(
            where: { $0.id == id }
        ) else { return }
        await activity.update(payload.content)
    }

    nonisolated private static func endActivity(
        id: String,
        payload: GameActivityPayload
    ) async {
        guard let activity = Activity<GlassPulseActivityAttributes>.activities.first(
            where: { $0.id == id }
        ) else { return }
        await activity.end(payload.content, dismissalPolicy: .immediate)
    }
}
