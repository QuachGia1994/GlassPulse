import Foundation
import SwiftUI

@MainActor
struct GlassPulseGame: View {
    @Environment(PlayerProfile.self) private var profile
    @Environment(PlusStore.self) private var plusStore
    @Environment(SensoryEngine.self) private var sensory
    @Environment(GameSettings.self) private var settings
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @State private var engine = GameEngine()
    @State private var activityController = GameActivityController()
    @State private var showModes = false
    @State private var showThemes = false
    @State private var showPlus = false
    @State private var showSettings = false
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
                gameplayInputSurface
                VStack(spacing: 10) {
                    header
                        .allowsHitTesting(false)
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
            configureUITestHarnessIfNeeded()
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
            ModePickerView(onSelection: selectModeFromPicker)
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
        .sheet(isPresented: $showSettings) {
            SettingsView()
                .presentationDetents([.medium, .large])
        }
    }

    private var gameplayInputSurface: some View {
        Button(action: handleGameplaySurfaceTap) {
            Color.clear
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
        .accessibilityLabel(String(localized: "game.input.label"))
        .accessibilityValue(directionAccessibilityValue)
        .accessibilityHint(gameplayInputHint)
        .accessibilityIdentifier("game.input.surface")
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
                    .accessibilityIdentifier("game.mode.current")
                Text("\(engine.score)")
                    .font(.system(size: 38, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText())
            }
            Spacer(minLength: 6)
            metric("KỶ LỤC", value: "\(profile.bestScore)")
            metric("STREAK", value: "\(profile.dailyStreak)")
            metric("SHARD", value: "\(profile.totalShards)")
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(String(localized: "game.metric.shards"))
                .accessibilityValue("\(profile.totalShards)")
                .accessibilityIdentifier("game.metric.shards")
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
            statusOverlay
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
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
                    .stroke(.white.opacity(settings.highContrastEnabled ? 0.30 : 0.14), lineWidth: 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            .allowsHitTesting(false)
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
                        theme: activeTheme,
                        presentation: RenderPresentation(
                            reduceMotion: settings.reduceMotionEnabled,
                            highContrast: settings.highContrastEnabled
                        )
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
            pausedCard
        case .start:
            startCard
        case .over:
            gameOverCard
        }
    }

    private var pausedCard: some View {
        VStack(spacing: 12) {
            Text(engine.statusText)
                .font(.headline)
            Button {
                engine.resume()
            } label: {
                Label("Tiếp tục", systemImage: "play.fill")
                    .font(.headline)
                    .padding(.horizontal, 8)
                    .frame(minHeight: 44)
            }
            .buttonStyle(.borderedProminent)
            .tint(activeTheme.palette.ring)
            .accessibilityIdentifier("game.resume")
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 18)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .transition(.scale.combined(with: .opacity))
    }

    private var startCard: some View {
        VStack(spacing: 8) {
            Image(systemName: statusIcon)
                .font(.title2)
                .foregroundStyle(activeTheme.palette.ring)
            Text(engine.statusText)
                .font(.headline)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .allowsHitTesting(false)
        .transition(.scale.combined(with: .opacity))
    }

    private var gameOverCard: some View {
        VStack(spacing: 10) {
            Image(systemName: statusIcon)
                .font(.title2)
                .foregroundStyle(activeTheme.palette.ring)
            Text(engine.statusText)
                .font(.headline)
                .multilineTextAlignment(.center)
            Text(rewardSummary)
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
            if dailyBonusForCurrentRun > 0 {
                Text(dailyBonusSummary)
                    .font(.caption.weight(.semibold).monospacedDigit())
                    .foregroundStyle(activeTheme.palette.ring)
            }
            gameOverActions
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .transition(.scale.combined(with: .opacity))
    }

    private var gameOverActions: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) {
                retryButton
                chooseModeButton
            }
            VStack(spacing: 8) {
                retryButton
                chooseModeButton
            }
        }
    }

    private var retryButton: some View {
        Button(action: retryCurrentRun) {
            Label(String(localized: "game.over.retry"), systemImage: "arrow.clockwise")
                .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(.borderedProminent)
        .tint(activeTheme.palette.ring)
        .accessibilityIdentifier("game.retry")
    }

    private var chooseModeButton: some View {
        Button {
            showModes = true
        } label: {
            Label(String(localized: "game.over.chooseMode"), systemImage: "square.grid.2x2.fill")
                .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(.bordered)
        .accessibilityIdentifier("game.chooseMode")
    }

    private var footer: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(spacing: 8) {
                    HStack(spacing: 8) {
                        modesButton
                        themesButton
                    }
                    HStack(spacing: 8) {
                        plusButton
                        settingsGear
                    }
                }
            } else {
                HStack(spacing: 8) {
                    modesButton
                    themesButton
                    plusButton
                    settingsGear
                }
            }
        }
        .font(.caption.weight(.medium))
        .buttonStyle(.bordered)
        .buttonBorderShape(.roundedRectangle(radius: 14))
    }

    private var modesButton: some View {
        Button {
            showModes = true
        } label: {
            Label("Mode", systemImage: "square.grid.2x2.fill")
                .frame(maxWidth: .infinity)
        }
        .disabled(!canChangeMode)
        .accessibilityIdentifier("game.modes")
    }

    private var themesButton: some View {
        Button {
            engine.pause()
            showThemes = true
        } label: {
            Label("Theme", systemImage: "paintpalette.fill")
                .frame(maxWidth: .infinity)
        }
        .accessibilityIdentifier("game.themes")
    }

    private var plusButton: some View {
        Button {
            engine.pause()
            showPlus = true
        } label: {
            Label(plusButtonTitle, systemImage: "sparkles")
                .frame(maxWidth: .infinity)
        }
        .tint(activeTheme.palette.ring)
    }

    private var settingsGear: some View {
        Button {
            engine.pause()
            showSettings = true
        } label: {
            Image(systemName: "gearshape.fill")
                .font(.headline)
                .frame(width: 44, height: 44)
        }
        .buttonStyle(.plain)
        .foregroundStyle(activeTheme.palette.ring)
        .background(.thinMaterial, in: Circle())
        .overlay {
            Circle().stroke(
                .white.opacity(settings.highContrastEnabled ? 0.30 : 0.16),
                lineWidth: 1
            )
        }
        .accessibilityLabel(Text("settings.open.label"))
        .accessibilityIdentifier("settings.open")
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

    private var rewardSummary: String {
        String.localizedStringWithFormat(
            String(localized: "game.over.reward.format"),
            engine.rewardForCurrentRun
        )
    }

    private var dailyBonusSummary: String {
        String.localizedStringWithFormat(
            String(localized: "game.over.dailyBonus.format"),
            dailyBonusForCurrentRun
        )
    }

    private var directionAccessibilityValue: String {
        engine.direction >= 0
            ? String(localized: "game.input.direction.clockwise")
            : String(localized: "game.input.direction.counterclockwise")
    }

    private var gameplayInputHint: String {
        switch engine.state {
        case .start:
            String(localized: "game.input.hint.start")
        case .playing:
            String(localized: "game.input.hint.playing")
        case .paused:
            String(localized: "game.input.hint.paused")
        case .over:
            String(localized: "game.input.hint.over")
        }
    }

    private var boardAccessibilityHint: String {
        gameplayInputHint
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

    private func handleGameplaySurfaceTap() {
        switch engine.state {
        case .start:
            applySelectedModeIfIdle()
            Task { @MainActor in
                await activityController.finishPendingEnd()
                guard engine.state == .start else { return }
                engine.handleTap()
            }
        case .playing:
            engine.handleTap()
        case .paused, .over:
            return
        }
    }

    private func retryCurrentRun() {
        guard engine.state == .over else { return }
        let replaySession = engine.session.replayContext()
        Task { @MainActor in
            await activityController.finishPendingEnd()
            guard engine.state == .over else { return }
            replaceEngine(session: replaySession, startImmediately: true)
        }
    }

    private func selectModeFromPicker(_ modeID: GameModeID) {
        guard canChangeMode else { return }
        let session = modeID == .dailyChallenge
            ? GameSessionContext.daily(date: .now, calendar: .current)
            : GameSessionContext.standard(modeID: modeID)
        replaceEngine(session: session, startImmediately: false)
    }

    private func replaceEngine(
        session: GameSessionContext,
        startImmediately: Bool
    ) {
        let replacement = GameEngine(session: session)
        replacement.connectSensory(sensory.client)
        engine = replacement
        didRecordCurrentRun = false
        dailyBonusForCurrentRun = 0
        guard startImmediately else { return }
        engine.handleTap()
        handleStateChange(engine.state)
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
        replaceEngine(session: session, startImmediately: false)
    }

    private func configureUITestHarnessIfNeeded() {
#if DEBUG
        guard ProcessInfo.processInfo.arguments.contains("--ui-testing-game-over") else { return }
        let scenario = GameScenario(
            ballAngle: 0,
            direction: 1,
            obstacles: [Obstacle(angle: 0.32, width: 0.14, speed: 0)],
            gem: Gem(angle: 0.08)
        )
        let session = GameSessionContext.standard(modeID: .classic, seed: 9_001)
        let harnessEngine = GameEngine(scenario: scenario, session: session)
        harnessEngine.connectSensory(sensory.client)
        let start = Date(timeIntervalSinceReferenceDate: 9_001)
        harnessEngine.handleTap(now: start)
        for step in 1...4 {
            harnessEngine.advance(to: start.addingTimeInterval(Double(step) * 0.10))
        }
        engine = harnessEngine
        didRecordCurrentRun = false
        dailyBonusForCurrentRun = 0
        handleStateChange(engine.state)
#endif
    }
}
