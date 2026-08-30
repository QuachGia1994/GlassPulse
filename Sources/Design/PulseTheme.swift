import SwiftUI

enum ThemeUnlock: Equatable, Sendable {
    case free
    case shards(Int)
    case plus
}

struct ThemePalette {
    let backgroundTop: Color
    let backgroundBottom: Color
    let ring: Color
    let ball: Color
    let gem: Color
    let hazard: Color
}

enum PulseTheme: String, CaseIterable, Identifiable, Sendable {
    case clarity
    case ember
    case aurora
    case prismPlus

    var id: String { rawValue }

    var title: String {
        switch self {
        case .clarity: "Clarity"
        case .ember: "Ember"
        case .aurora: "Aurora"
        case .prismPlus: "Prism Plus"
        }
    }

    var subtitle: String {
        switch self {
        case .clarity: "Kính xanh nguyên bản"
        case .ember: "Nhịp ấm, tương phản mạnh"
        case .aurora: "Ánh cực quang dịu"
        case .prismPlus: "Pulse đa sắc dành cho Plus"
        }
    }

    var unlock: ThemeUnlock {
        switch self {
        case .clarity: .free
        case .ember: .shards(18)
        case .aurora: .shards(45)
        case .prismPlus: .plus
        }
    }

    var pulseAmplitude: CGFloat {
        switch self {
        case .clarity: 3.0
        case .ember: 3.8
        case .aurora: 4.4
        case .prismPlus: 5.0
        }
    }

    var pulseFrequency: Double {
        switch self {
        case .clarity: 2.0
        case .ember: 2.35
        case .aurora: 1.75
        case .prismPlus: 2.65
        }
    }

    var palette: ThemePalette {
        switch self {
        case .clarity:
            ThemePalette(
                backgroundTop: Color(red: 0.02, green: 0.10, blue: 0.16),
                backgroundBottom: Color(red: 0.01, green: 0.02, blue: 0.06),
                ring: Color(red: 0.36, green: 0.88, blue: 1.00),
                ball: Color(red: 0.42, green: 0.82, blue: 1.00),
                gem: Color(red: 0.42, green: 1.00, blue: 0.72),
                hazard: Color(red: 1.00, green: 0.30, blue: 0.42)
            )
        case .ember:
            ThemePalette(
                backgroundTop: Color(red: 0.19, green: 0.06, blue: 0.04),
                backgroundBottom: Color(red: 0.04, green: 0.01, blue: 0.02),
                ring: Color(red: 1.00, green: 0.59, blue: 0.24),
                ball: Color(red: 1.00, green: 0.78, blue: 0.36),
                gem: Color(red: 1.00, green: 0.92, blue: 0.48),
                hazard: Color(red: 1.00, green: 0.18, blue: 0.18)
            )
        case .aurora:
            ThemePalette(
                backgroundTop: Color(red: 0.04, green: 0.15, blue: 0.13),
                backgroundBottom: Color(red: 0.02, green: 0.03, blue: 0.08),
                ring: Color(red: 0.42, green: 1.00, blue: 0.76),
                ball: Color(red: 0.66, green: 0.92, blue: 1.00),
                gem: Color(red: 0.82, green: 0.62, blue: 1.00),
                hazard: Color(red: 1.00, green: 0.32, blue: 0.58)
            )
        case .prismPlus:
            ThemePalette(
                backgroundTop: Color(red: 0.13, green: 0.06, blue: 0.24),
                backgroundBottom: Color(red: 0.02, green: 0.02, blue: 0.09),
                ring: Color(red: 0.73, green: 0.56, blue: 1.00),
                ball: Color(red: 0.48, green: 0.94, blue: 1.00),
                gem: Color(red: 1.00, green: 0.58, blue: 0.92),
                hazard: Color(red: 1.00, green: 0.28, blue: 0.46)
            )
        }
    }
}
