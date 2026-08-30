import SwiftUI

@MainActor
struct GlassPulseGame: View {
    @Environment(PlayerProfile.self) private var profile
    @Environment(PlusStore.self) private var plusStore
    @Environment(SensoryEngine.self) private var sensory
    @Environment(\.scenePhase) private var scenePhase

    @State private var engine = GameEngine()
    @State private var showThemes = false
    @State private var showPlus = false
    @State private var didRecordCurrentRun = false

    private var activeTheme: PulseTheme {
        profile.activeTheme(access: plusStore.access)
    }

    var body: some View {
        GeometryReader { proxy in
            let boardSide = min(
                max(proxy.size.width - 32, 180),
                max(proxy.size.height - 184, 180)
            )

            ZStack {
                background
                VStack(spacing: 14) {
                    header
                    gameBoard(side: boardSide)
                    footer
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            }
        }
        .task {
            engine.connectSensory(sensory.client)
            profile.registerDailyPlay()
            await plusStore.start()
        }
        .onChange(of: engine.state) { _, state in
            handleStateChange(state)
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase != .active else { return }
            engine.pause()
        }
        .sheet(isPresented: $showThemes) {
            ThemePickerView()
                .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showPlus) {
            PlusView()
                .presentationDetents([.medium, .large])
        }
    }

    private var background: some View {
        RadialGradient(
            colors: [
                activeTheme.palette.backgroundTop,
                activeTheme.palette.backgroundBottom
            ],
            center: .top,
            startRadius: 24,
            endRadius: 720
        )
        .ignoresSafeArea()
        .animation(.easeInOut(duration: 0.35), value: activeTheme)
    }

    private var header: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                brandTitle
                Text("\(engine.score)")
                    .font(.system(size: 40, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText())
            }
            Spacer(minLength: 8)
            metric("KỶ LỤC", value: "\(profile.bestScore)")
            metric("STREAK", value: "\(profile.dailyStreak)")
            metric("SHARD", value: "\(profile.totalShards)")
        }
        .frame(maxWidth: .infinity)
    }

    private func gameBoard(side: CGFloat) -> some View {
        ZStack(alignment: .topTrailing) {
            playfield(side: side)
            pauseControl
                .padding(12)
        }
        .frame(width: side, height: side)
        .animation(
            .spring(response: 0.34, dampingFraction: 0.78),
            value: engine.state
        )
    }

    private func playfield(side: CGFloat) -> some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { timeline in
            Canvas { context, size in
                engine.draw(
                    in: &context,
                    size: size,
                    now: timeline.date,
                    theme: activeTheme
                )
            }
        }
        .frame(width: side, height: side)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(.white.opacity(0.14), lineWidth: 1)
        }
        .overlay { statusOverlay }
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .onTapGesture { handleGameTap() }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Vòng chơi Glass Pulse")
        .accessibilityValue("Điểm \(engine.score). \(engine.statusText)")
        .accessibilityHint(boardAccessibilityHint)
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("game.board")
    }

    @ViewBuilder
    private var statusOverlay: some View {
        if engine.state != .playing {
            VStack(spacing: 8) {
                Image(systemName: statusIcon)
                    .font(.title2)
                    .foregroundStyle(activeTheme.palette.ring)
                Text(engine.statusText)
                    .font(.headline)
                    .multilineTextAlignment(.center)
                if engine.state == .paused {
                    Text("Nhấn Tiếp tục để chơi")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if engine.state == .over {
                    Text("+\(engine.rewardForCurrentRun) shard")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .allowsHitTesting(false)
            .transition(.scale.combined(with: .opacity))
        }
    }

    private var footer: some View {
        HStack(spacing: 12) {
            Button {
                engine.pause()
                showThemes = true
            } label: {
                Label("Theme", systemImage: "paintpalette.fill")
                    .frame(maxWidth: .infinity)
            }

            Button {
                engine.pause()
                showPlus = true
            } label: {
                Label(plusButtonTitle, systemImage: "sparkles")
                    .frame(maxWidth: .infinity)
            }
            .tint(activeTheme.palette.ring)
        }
        .buttonStyle(.bordered)
        .buttonBorderShape(.roundedRectangle(radius: 14))
    }

    private var brandTitle: some View {
        HStack(spacing: 6) {
            Text("GLASS PULSE")
                .font(.caption.weight(.semibold))
                .tracking(3.2)
                .foregroundStyle(.secondary)
            if plusStore.isBetaFullAccess {
                Text("BETA")
                    .font(.system(size: 8, weight: .bold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(activeTheme.palette.ring.opacity(0.18), in: Capsule())
                    .foregroundStyle(activeTheme.palette.ring)
            }
        }
    }

    @ViewBuilder
    private var pauseControl: some View {
        if engine.state == .playing || engine.state == .paused {
            Button(action: togglePause) {
                Image(systemName: engine.state == .paused ? "play.fill" : "pause.fill")
                    .font(.headline)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .foregroundStyle(activeTheme.palette.ring)
            .background(.thinMaterial, in: Circle())
            .overlay { Circle().stroke(.white.opacity(0.16), lineWidth: 1) }
            .accessibilityLabel(engine.state == .paused ? "Tiếp tục" : "Tạm dừng")
            .accessibilityIdentifier("game.pause")
            .transition(.scale.combined(with: .opacity))
        }
    }

    private var plusButtonTitle: String {
        if plusStore.isBetaFullAccess { return "Beta mở" }
        return plusStore.isPlusUnlocked ? "Plus bật" : "Plus"
    }

    private var statusIcon: String {
        switch engine.state {
        case .start: "hand.tap.fill"
        case .playing: "circle"
        case .paused: "pause.circle.fill"
        case .over: "waveform.path.ecg"
        }
    }

    private var boardAccessibilityHint: String {
        guard engine.state != .paused else {
            return "Nhấn nút Tiếp tục để chơi."
        }
        return "Chạm để bắt đầu hoặc đảo chiều bóng."
    }

    private func metric(_ title: String, value: String) -> some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text(value)
                .font(.headline.monospacedDigit())
            Text(title)
                .font(.system(size: 9, weight: .medium))
                .tracking(1)
                .foregroundStyle(.secondary)
        }
    }

    private func handleGameTap() {
        guard engine.state != .paused else { return }
        if engine.state == .over {
            didRecordCurrentRun = false
        }
        engine.handleTap()
    }

    private func togglePause() {
        switch engine.state {
        case .playing:
            engine.pause()
        case .paused:
            engine.resume()
        case .start, .over:
            return
        }
    }

    private func handleStateChange(_ state: GameState) {
        guard state == .over, !didRecordCurrentRun else { return }
        didRecordCurrentRun = true
        profile.recordRun(
            score: engine.score,
            reward: engine.rewardForCurrentRun
        )
    }
}
