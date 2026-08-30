import ActivityKit
import Foundation

struct GlassPulseActivityAttributes: ActivityAttributes, Sendable {
    struct ContentState: Codable, Hashable, Sendable {
        let score: Int
        let remainingSeconds: Int?
        let timerEndDate: Date?
        let dailyStreak: Int
        let localDailyBest: Int
        let isPaused: Bool
    }

    let modeTitle: String
    let isDaily: Bool
}
