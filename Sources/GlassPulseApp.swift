import SwiftUI

@main
@MainActor
struct GlassPulseApp: App {
    @State private var profile = PlayerProfile()
    @State private var plusStore = PlusStore()
    @State private var sensory = SensoryEngine()

    var body: some Scene {
        WindowGroup {
            GlassPulseGame()
                .environment(profile)
                .environment(plusStore)
                .environment(sensory)
                .preferredColorScheme(.dark)
        }
    }
}
