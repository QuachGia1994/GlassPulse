import SwiftUI

@main
@MainActor
struct GlassPulseApp: App {
    @State private var profile = PlayerProfile()
    @State private var plusStore = PlusStore()
    @State private var sensory = SensoryEngine()
    @State private var isShowingLaunchSplash = true

    var body: some Scene {
        WindowGroup {
            ZStack {
                GlassPulseGame()
                if isShowingLaunchSplash {
                    LaunchSplashView(
                        isBetaFullAccess: plusStore.isBetaFullAccess
                    )
                    .transition(.opacity.combined(with: .scale(scale: 1.03)))
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
            try await Task.sleep(for: .milliseconds(1_050))
        } catch {
            return
        }
        guard !Task.isCancelled else { return }
        withAnimation(.easeOut(duration: 0.34)) {
            isShowingLaunchSplash = false
        }
    }
}
