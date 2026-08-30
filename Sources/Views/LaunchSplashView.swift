import SwiftUI

@MainActor
struct LaunchSplashView: View {
    let isBetaFullAccess: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isPulsing = false

    var body: some View {
        ZStack {
            background
            content
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Glass Pulse")
        .accessibilityIdentifier("launch.splash")
        .onAppear(perform: startPulsing)
    }

    private var background: some View {
        LinearGradient(
            colors: [
                Color(red: 0.03, green: 0.08, blue: 0.15),
                Color(red: 0.04, green: 0.01, blue: 0.08)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }

    private var content: some View {
        VStack(spacing: 22) {
            GlassPulseLogo(size: 132)
                .scaleEffect(reduceMotion ? 1 : (isPulsing ? 1.04 : 0.96))
            VStack(spacing: 8) {
                Text("GLASS PULSE")
                    .font(.title2.weight(.semibold))
                    .tracking(5)
                if isBetaFullAccess {
                    Text("BETA FULL ACCESS")
                        .font(.caption2.weight(.bold))
                        .tracking(2)
                        .foregroundStyle(.cyan)
                }
            }
        }
    }

    private func startPulsing() {
        guard !reduceMotion else { return }
        withAnimation(
            .easeInOut(duration: 0.72)
                .repeatForever(autoreverses: true)
        ) {
            isPulsing = true
        }
    }
}
