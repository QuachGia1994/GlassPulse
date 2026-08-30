import SwiftUI

@main
@MainActor
struct GlassPulseApp: App {
    @State private var profile = PlayerProfile()
    @State private var plusStore: PlusStore
    @State private var sensory = SensoryEngine()
    @State private var isShowingLaunchSplash = true

    init() {
#if DEBUG
        let testingEntitlement = ProcessInfo.processInfo.arguments.contains("--ui-testing-plus")
        _plusStore = State(initialValue: PlusStore(testingEntitlementEnabled: testingEntitlement))
#else
        _plusStore = State(initialValue: PlusStore())
#endif
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                GlassPulseGame()
                if isShowingLaunchSplash {
                    LaunchSplashView(
                        isBetaFullAccess: plusStore.isBetaFullAccess
                    )
                    .transition(.opacity)
                    .zIndex(1)
                }
            }
            .environment(profile)
            .environment(plusStore)
            .environment(sensory)
            .preferredColorScheme(.dark)
            .task { await finishLaunchSplash() }
        }
    }

    private func finishLaunchSplash() async {
        do {
            try await Task.sleep(for: .milliseconds(450))
        } catch {
            return
        }
        guard !Task.isCancelled else { return }
        withAnimation(.easeOut(duration: 0.22)) {
            isShowingLaunchSplash = false
        }
    }
}
