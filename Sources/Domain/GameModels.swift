import Foundation

enum GameState: Equatable, Sendable {
    case start
    case playing
    case over
}

struct Obstacle: Equatable, Sendable {
    var angle: Double
    var width: Double
    var speed: Double
}

struct Gem: Equatable, Sendable {
    var angle: Double
}

struct GameScenario: Equatable, Sendable {
    var ballAngle: Double
    var direction: Double
    var obstacles: [Obstacle]
    var gem: Gem
}

struct BurstEffect: Equatable, Sendable {
    let angle: Double
    let startedAt: Date
}

struct CollisionEffect: Equatable, Sendable {
    let angle: Double
    let startedAt: Date
}

enum DifficultyChange: Equatable, Sendable {
    case addObstacle
    case increaseObstacleSpeed(multiplier: Double)
}

struct GameEconomy: Equatable, Sendable {
    let pointsPerGem: Int
    let difficultyInterval: Int
    let obstacleLimit: Int
    let obstacleSpeedMultiplier: Double
    let gemCollectionRadius: Double
    let gemObstacleMargin: Double

    static let standard = GameEconomy(
        pointsPerGem: 1,
        difficultyInterval: 3,
        obstacleLimit: 3,
        obstacleSpeedMultiplier: 1.04,
        gemCollectionRadius: 0.18,
        gemObstacleMargin: 0.60
    )

    func difficultyChange(score: Int, obstacleCount: Int) -> DifficultyChange? {
        guard score > 0, score.isMultiple(of: difficultyInterval) else { return nil }
        guard obstacleCount < obstacleLimit else {
            return .increaseObstacleSpeed(multiplier: obstacleSpeedMultiplier)
        }
        return .addObstacle
    }

    func reward(for score: Int) -> Int {
        max(0, score)
    }
}

enum AngleMath {
    static let fullTurn = 2 * Double.pi

    static func normalized(_ angle: Double) -> Double {
        let remainder = angle.truncatingRemainder(dividingBy: fullTurn)
        return remainder >= 0 ? remainder : remainder + fullTurn
    }

    static func distance(_ first: Double, _ second: Double) -> Double {
        let difference = abs(normalized(first) - normalized(second))
        return min(difference, fullTurn - difference)
    }
}

struct SplitMix64: RandomNumberGenerator, Sendable {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var value = state
        value = (value ^ (value >> 30)) &* 0xBF58476D1CE4E5B9
        value = (value ^ (value >> 27)) &* 0x94D049BB133111EB
        return value ^ (value >> 31)
    }
}
