import Foundation

enum GameModeID: String, CaseIterable, Codable, Identifiable, Sendable {
    case classic
    case rush60
    case precisionPulse
    case waveSurvival
    case dailyChallenge

    var id: String { rawValue }

    var title: String {
        switch self {
        case .classic: "Classic"
        case .rush60: "Rush 60"
        case .precisionPulse: "Precision Pulse"
        case .waveSurvival: "Wave Survival"
        case .dailyChallenge: "Daily Challenge"
        }
    }

    var subtitle: String {
        switch self {
        case .classic: "Nhịp vô tận nguyên bản."
        case .rush60: "Gom điểm và giữ combo trong 60 giây."
        case .precisionPulse: "Chỉ gom gem đúng cửa sổ pulse."
        case .waveSurvival: "Sống sót qua các wave nguy hiểm."
        case .dailyChallenge: "Một thử thách cố định cho từng ngày."
        }
    }

    var instruction: String {
        switch self {
        case .classic: "Chạm để đảo chiều. Né hazard, gom gem."
        case .rush60: "Chạm để đảo chiều. Giữ combo tới hết 60 giây."
        case .precisionPulse: "Chạm để đảo chiều. Gom gem khi pulse đang sáng."
        case .waveSurvival: "Chạm để đảo chiều. Sống sót qua 5 wave."
        case .dailyChallenge: "Chạm để đảo chiều. Luật hôm nay cố định cho mọi lượt."
        }
    }

    var requiresPlus: Bool {
        switch self {
        case .rush60, .precisionPulse, .waveSurvival: true
        case .classic, .dailyChallenge: false
        }
    }
}

enum GameRunOutcome: Equatable, Sendable {
    case collision
    case completed
}

struct GameModeRules: Equatable, Sendable {
    let sessionDuration: TimeInterval?
    let comboCap: Int
    let pulseCycleDuration: TimeInterval?
    let pulseActiveDuration: TimeInterval?
    let waveDuration: TimeInterval?
    let finalWave: Int?
    let dailyFirstClearBonus: Int

    static func rules(for modeID: GameModeID) -> GameModeRules {
        switch modeID {
        case .classic:
            GameModeRules(
                sessionDuration: nil,
                comboCap: 1,
                pulseCycleDuration: nil,
                pulseActiveDuration: nil,
                waveDuration: nil,
                finalWave: nil,
                dailyFirstClearBonus: 0
            )
        case .rush60:
            GameModeRules(
                sessionDuration: 60,
                comboCap: 5,
                pulseCycleDuration: nil,
                pulseActiveDuration: nil,
                waveDuration: nil,
                finalWave: nil,
                dailyFirstClearBonus: 0
            )
        case .precisionPulse:
            GameModeRules(
                sessionDuration: nil,
                comboCap: 4,
                pulseCycleDuration: 1.60,
                pulseActiveDuration: 0.56,
                waveDuration: nil,
                finalWave: nil,
                dailyFirstClearBonus: 0
            )
        case .waveSurvival:
            GameModeRules(
                sessionDuration: nil,
                comboCap: 1,
                pulseCycleDuration: nil,
                pulseActiveDuration: nil,
                waveDuration: 8,
                finalWave: 5,
                dailyFirstClearBonus: 0
            )
        case .dailyChallenge:
            GameModeRules(
                sessionDuration: nil,
                comboCap: 1,
                pulseCycleDuration: nil,
                pulseActiveDuration: nil,
                waveDuration: nil,
                finalWave: nil,
                dailyFirstClearBonus: 10
            )
        }
    }
}

struct GameSessionContext: Equatable, Sendable {
    static let dailyRulesetVersion = 1

    let modeID: GameModeID
    let effectiveModeID: GameModeID
    let seed: UInt64
    let rulesetVersion: Int
    let dailyKey: String?
    let dailyDate: Date?

    var rules: GameModeRules {
        var rules = GameModeRules.rules(for: effectiveModeID)
        if modeID == .dailyChallenge {
            let dailyDuration = rules.sessionDuration ?? (rules.waveDuration == nil ? 60 : nil)
            rules = GameModeRules(
                sessionDuration: dailyDuration,
                comboCap: rules.comboCap,
                pulseCycleDuration: rules.pulseCycleDuration,
                pulseActiveDuration: rules.pulseActiveDuration,
                waveDuration: rules.waveDuration,
                finalWave: rules.finalWave,
                dailyFirstClearBonus: GameModeRules.rules(for: .dailyChallenge).dailyFirstClearBonus
            )
        }
        return rules
    }

    static func standard(
        modeID: GameModeID,
        seed: UInt64 = UInt64.random(in: UInt64.min...UInt64.max)
    ) -> GameSessionContext {
        guard modeID != .dailyChallenge else {
            return daily(date: .now, calendar: .current)
        }
        return GameSessionContext(
            modeID: modeID,
            effectiveModeID: modeID,
            seed: seed,
            rulesetVersion: 1,
            dailyKey: nil,
            dailyDate: nil
        )
    }

    static func daily(
        date: Date,
        calendar: Calendar
    ) -> GameSessionContext {
        let key = DailyChallenge.key(for: date, calendar: calendar)
        let seed = DailyChallenge.seed(for: key, rulesetVersion: dailyRulesetVersion)
        let rotation = DailyChallenge.rotation[Int(seed % UInt64(DailyChallenge.rotation.count))]
        return GameSessionContext(
            modeID: .dailyChallenge,
            effectiveModeID: rotation,
            seed: seed,
            rulesetVersion: dailyRulesetVersion,
            dailyKey: key,
            dailyDate: calendar.startOfDay(for: date)
        )
    }
}

enum DailyChallenge {
    static let rotation: [GameModeID] = [
        .classic,
        .rush60,
        .precisionPulse,
        .waveSurvival
    ]

    static func key(for date: Date, calendar: Calendar) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return String(
            format: "%04d-%02d-%02d",
            components.year ?? 0,
            components.month ?? 0,
            components.day ?? 0
        )
    }

    static func seed(for key: String, rulesetVersion: Int) -> UInt64 {
        let bytes = "glass-pulse-daily-v\(rulesetVersion)-\(key)".utf8
        return bytes.reduce(UInt64(14_695_981_039_346_656_037)) { hash, byte in
            (hash ^ UInt64(byte)) &* 1_099_511_628_211
        }
    }
}
