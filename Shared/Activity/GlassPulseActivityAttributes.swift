import ActivityKit
import Foundation

struct GlassPulseActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
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
