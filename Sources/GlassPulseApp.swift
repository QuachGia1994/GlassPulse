import SwiftUI

@main
@MainActor
struct GlassPulseApp: App {
    @State private var settings: GameSettings
    @State private var profile = PlayerProfile()
    @State private var plusStore: PlusStore
    @State private var sensory: SensoryEngine
    @State private var music: MusicEngine
    @State private var isShowingLaunchSplash = true
    @Environment(\.scenePhase) private var scenePhase

    init() {
#if DEBUG
        let testingEntitlement = ProcessInfo.processInfo.arguments.contains("--ui-testing-plus")
        _plusStore = State(initialValue: PlusStore(testingEntitlementEnabled: testingEntitlement))
#else
        _plusStore = State(initialValue: PlusStore())
#endif
        let initialSettings = GameSettings()
        _settings = State(initialValue: initialSettings)
        _sensory = State(initialValue: SensoryEngine(settings: initialSettings))
        _music = State(initialValue: MusicEngine(settings: initialSettings))
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                GlassPulseGame()
                if isShowingLaunchSplash {
                    LaunchSplashView(
                        isBetaFullAccess: plusStore.isBetaFullAccess,
                        reduceMotionOverride: settings.reduceMotionEnabled
                    )
                    .transition(.opacity)
                    .zIndex(1)
                }
            }
            .environment(settings)
            .environment(profile)
            .environment(plusStore)
            .environment(sensory)
            .modifier(AppLocaleEnvironment(settings: settings))
            .preferredColorScheme(.dark)
            .task { await finishLaunchSplash() }
            .onChange(of: scenePhase) { _, phase in
                music.handleScenePhase(active: phase == .active)
            }
            .onChange(of: settings.musicEnabled) { _, _ in
                music.applySettings(settings)
            }
            .onChange(of: settings.soundEnabled) { _, _ in
                sensory.applySettings(settings)
            }
            .onChange(of: settings.hapticsEnabled) { _, _ in
                sensory.applySettings(settings)
            }
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
        music.applySettings(settings)
        music.startIfReady()
    }
}

private struct AppLocaleEnvironment: ViewModifier {
    @Environment(\.locale) private var systemLocale
    let settings: GameSettings

    func body(content: Content) -> some View {
        content.environment(
            \.locale,
            settings.resolvedLocale ?? systemLocale
        )
    }
}
