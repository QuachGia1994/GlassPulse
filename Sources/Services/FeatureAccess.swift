struct FeatureAccess: Equatable, Sendable {
    let isBetaFullAccess: Bool
    let hasActivePlusSubscription: Bool

    var hasPlus: Bool {
        isBetaFullAccess || hasActivePlusSubscription
    }

    func canUse(_ modeID: GameModeID) -> Bool {
        !modeID.requiresPlus || hasPlus
    }

    static func current(
        hasActivePlusSubscription: Bool
    ) -> FeatureAccess {
#if GLASS_PULSE_BETA
        FeatureAccess(
            isBetaFullAccess: true,
            hasActivePlusSubscription: hasActivePlusSubscription
        )
#else
        FeatureAccess(
            isBetaFullAccess: false,
            hasActivePlusSubscription: hasActivePlusSubscription
        )
#endif
    }
}
