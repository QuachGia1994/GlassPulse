import SwiftUI

@MainActor
struct GlassPulseGame: View {
    @Environment(PlayerProfile.self) private var profile
    @Environment(PlusStore.self) private var plusStore
    @Environment(SensoryEngine.self) private var sensory
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @State private var engine = GameEngine()
    @State private var activityController = GameActivityController()
    @State private var showModes = false
    @State private var showThemes = false
    @State private var showPlus = false
    @State private var didRecordCurrentRun = false
    @State private var dailyBonusForCurrentRun = 0

    private var activeTheme: PulseTheme {
        profile.activeTheme(access: plusStore.access)
    }

    var body: some View {
        GeometryReader { proxy in
            let usableHeight = proxy.size.height - proxy.safeAreaInsets.top - proxy.safeAreaInsets.bottom
            let chromeBudget: CGFloat = dynamicTypeSize.isAccessibilitySize ? 230 : 150
            let boardSide = max(180, min(proxy.size.width - 32, usableHeight - chromeBudget))

            ZStack {
                background
                VStack(spacing: 10) {
                    header
                    Spacer(minLength: 6)
                    gameBoard(side: boardSide)
                    Spacer(minLength: 6)
                    footer
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
        }
        .task {
            engine.connectSensory(sensory.client)
            await plusStore.start()
            applySelectedModeIfIdle()
        }
        .onChange(of: profile.selectedModeID) { _, _ in
            applySelectedModeIfIdle()
        }
        .onChange(of: plusStore.hasActivePlusSubscription) { _, _ in
            applySelectedModeIfIdle()
        }
        .onChange(of: engine.state) { _, state in
            handleStateChange(state)
        }
        .onChange(of: engine.score) { _, _ in
            activityController.updateMeaningfulEvent(engine: engine, profile: profile)
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase != .active else { return }
            engine.pause()
        }
        .sheet(isPresented: $showModes) {
            ModePickerView()
                .presentationDetents([.large])
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
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                brandTitle
                Text(engine.modeID.title)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(activeTheme.palette.ring)
                Text("\(engine.score)")
                    .font(.system(size: 38, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText())
            }
            Spacer(minLength: 6)
            metric("KỶ LỤC", value: "\(profile.bestScore)")
            metric("STREAK", value: "\(profile.dailyStreak)")
            metric("SHARD", value: "\(profile.totalShards)")
        }
        .frame(maxWidth: .infinity)
    }

    private func gameBoard(side: CGFloat) -> some View {
        ZStack(alignment: .topTrailing) {
            playfield(side: side)
            modeHUD
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(12)
                .allowsHitTesting(false)
            if engine.state == .playing {
                pauseControl
                    .padding(12)
            }
        }
        .frame(width: side, height: side)
        .animation(
            .spring(response: 0.34, dampingFraction: 0.78),
            value: engine.state
        )
    }

    private func playfield(side: CGFloat) -> some View {
        rendererSurface
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
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Vòng chơi Glass Pulse")
            .accessibilityValue("Điểm \(engine.score). \(engine.statusText)")
            .accessibilityHint(boardAccessibilityHint)
            .accessibilityIdentifier("game.board")
    }

    @ViewBuilder
    private var rendererSurface: some View {
        if RendererBenchmarkFlags.spriteKitEnabled {
            TimelineView(.animation(minimumInterval: 1.0 / 120.0)) { timeline in
                SpriteBenchmarkView(snapshot: engine.renderSnapshot)
                    .onChange(of: timeline.date, initial: true) { _, now in
                        RenderDiagnostics.measureSimulation {
                            engine.advance(to: now)
                        }
                    }
            }
        } else {
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
        }
    }

    @ViewBuilder
    private var modeHUD: some View {
        if engine.state != .start {
            VStack(alignment: .leading, spacing: 5) {
                if engine.modeID == .dailyChallenge {
                    hudPill("HÔM NAY", engine.effectiveModeID.title)
                    hudPill("LOCAL BEST", "\(profile.dailyBest(for: engine.session.dailyKey))")
                }
                if let remaining = engine.remainingTime {
                    hudPill("CÒN", "\(Int(ceil(remaining)))s")
                }
                if engine.effectiveModeID == .rush60 || engine.effectiveModeID == .precisionPulse {
                    hudPill("COMBO", "x\(engine.combo)")
                }
                if engine.effectiveModeID == .precisionPulse {
                    hudPill("PULSE", engine.pulseIsActive ? "SÁNG ◉" : "CHỜ ○")
                }
                if engine.effectiveModeID == .waveSurvival {
                    hudPill("WAVE", "\(engine.currentWave)/\(engine.rules.finalWave ?? 5)")
                }
            }
        }
    }

    private func hudPill(_ title: String, _ value: String) -> some View {
        HStack(spacing: 5) {
            Text(title)
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption2.weight(.semibold).monospacedDigit())
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(.thinMaterial, in: Capsule())
    }

    @ViewBuilder
    private var statusOverlay: some View {
        switch engine.state {
        case .playing:
            EmptyView()
        case .paused:
            VStack(spacing: 12) {
                Text(engine.statusText)
                    .font(.headline)
                Button {
                    engine.resume()
                } label: {
                    Label("Tiếp tục", systemImage: "play.fill")
                        .font(.headline)
                        .padding(.horizontal, 8)
                }
                .buttonStyle(.borderedProminent)
                .tint(activeTheme.palette.ring)
                .accessibilityIdentifier("game.resume")
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 18)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .transition(.scale.combined(with: .opacity))
        case .start, .over:
            VStack(spacing: 8) {
                Image(systemName: statusIcon)
                    .font(.title2)
                    .foregroundStyle(activeTheme.palette.ring)
                Text(engine.statusText)
                    .font(.headline)
                    .multilineTextAlignment(.center)
                if engine.state == .over {
                    Text("+\(engine.rewardForCurrentRun) shard")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                    if dailyBonusForCurrentRun > 0 {
                        Text("+\(dailyBonusForCurrentRun) Daily bonus")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(activeTheme.palette.ring)
                    }
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
        HStack(spacing: 8) {
            Button {
                showModes = true
            } label: {
                Label("Mode", systemImage: "square.grid.2x2.fill")
                    .frame(maxWidth: .infinity)
            }
            .disabled(!canChangeMode)
            .accessibilityIdentifier("game.modes")

            Button {
                engine.pause()
                showThemes = true
            } label: {
                Label("Theme", systemImage: "paintpalette.fill")
                    .frame(maxWidth: .infinity)
            }
            .accessibilityIdentifier("game.themes")

            Button {
                engine.pause()
                showPlus = true
            } label: {
                Label(plusButtonTitle, systemImage: "sparkles")
                    .frame(maxWidth: .infinity)
            }
            .tint(activeTheme.palette.ring)
        }
        .font(.caption.weight(.medium))
        .buttonStyle(.bordered)
        .buttonBorderShape(.roundedRectangle(radius: 14))
    }

    private var canChangeMode: Bool {
        engine.state == .start || engine.state == .over
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

    private var pauseControl: some View {
        Button {
            engine.pause()
        } label: {
            Image(systemName: "pause.fill")
                .font(.headline)
                .frame(width: 44, height: 44)
        }
        .buttonStyle(.plain)
        .foregroundStyle(activeTheme.palette.ring)
        .background(.thinMaterial, in: Circle())
        .overlay { Circle().stroke(.white.opacity(0.16), lineWidth: 1) }
        .accessibilityLabel("Tạm dừng")
        .accessibilityIdentifier("game.pause")
        .transition(.scale.combined(with: .opacity))
    }

    private var plusButtonTitle: String {
        if plusStore.isBetaFullAccess { return "Beta" }
        return plusStore.isPlusUnlocked ? "Plus bật" : "Plus"
    }

    private var statusIcon: String {
        switch engine.state {
        case .start: "hand.tap.fill"
        case .playing: "circle"
        case .paused: "play.circle.fill"
        case .over:
            engine.runOutcome == .completed ? "checkmark.circle.fill" : "waveform.path.ecg"
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
        if engine.state == .start || engine.state == .over {
            applySelectedModeIfIdle()
        }
        if engine.state == .over {
            didRecordCurrentRun = false
            dailyBonusForCurrentRun = 0
        }
        engine.handleTap()
    }

    private func handleStateChange(_ state: GameState) {
        if state == .over, !didRecordCurrentRun {
            didRecordCurrentRun = true
            profile.recordRun(
                score: engine.score,
                reward: engine.rewardForCurrentRun
            )
            recordDailyCompletionIfNeeded()
        }
        activityController.synchronize(engine: engine, profile: profile)
    }

    private func recordDailyCompletionIfNeeded() {
        guard engine.modeID == .dailyChallenge,
              engine.runOutcome == .completed,
              let dayKey = engine.session.dailyKey,
              let dailyDate = engine.session.dailyDate else { return }
        dailyBonusForCurrentRun = profile.recordDailyCompletion(
            dayKey: dayKey,
            date: dailyDate,
            score: engine.score,
            firstClearBonus: engine.rules.dailyFirstClearBonus,
            calendar: .current
        )
    }

    private func applySelectedModeIfIdle() {
        guard canChangeMode else { return }
        let modeID = profile.activeMode(access: plusStore.access)
        let session: GameSessionContext
        if modeID == .dailyChallenge {
            session = GameSessionContext.daily(date: .now, calendar: .current)
            guard engine.modeID != modeID || engine.session.dailyKey != session.dailyKey else { return }
        } else {
            guard engine.modeID != modeID else { return }
            session = GameSessionContext.standard(modeID: modeID)
        }
        let replacement = GameEngine(session: session)
        replacement.connectSensory(sensory.client)
        engine = replacement
        didRecordCurrentRun = false
        dailyBonusForCurrentRun = 0
    }
}
