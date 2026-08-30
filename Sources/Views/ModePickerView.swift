import SwiftUI

@MainActor
struct ModePickerView: View {
    @Environment(PlayerProfile.self) private var profile
    @Environment(PlusStore.self) private var plusStore
    @Environment(SensoryEngine.self) private var sensory
    @Environment(\.dismiss) private var dismiss

    @State private var selectionError: PlayerProfileError?
    @State private var showPlus = false

    var body: some View {
        @Bindable var sensory = sensory
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 12) {
                    if plusStore.isBetaFullAccess {
                        Label("Beta Full Access: mọi mode đã mở", systemImage: "checkmark.seal.fill")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.cyan)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    ForEach(GameModeID.allCases) { modeID in
                        modeCard(modeID)
                    }
                    sensoryControls(soundEnabled: $sensory.soundEnabled, hapticsEnabled: $sensory.hapticsEnabled)
                }
                .padding()
            }
            .navigationTitle("Chọn mode")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Đóng") { dismiss() }
                }
            }
        }
        .sheet(isPresented: $showPlus) {
            PlusView()
                .presentationDetents([.medium, .large])
        }
        .alert(
            "Chưa thể chọn mode",
            isPresented: Binding(
                get: { selectionError != nil },
                set: { if !$0 { selectionError = nil } }
            )
        ) {
            Button("Đã hiểu", role: .cancel) {}
        } message: {
            Text(selectionError?.localizedDescription ?? "")
        }
    }

    private func modeCard(_ modeID: GameModeID) -> some View {
        let selected = profile.activeMode(access: plusStore.access) == modeID
        let unlocked = plusStore.access.canUse(modeID)
        return Button {
            select(modeID)
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: icon(for: modeID))
                    .font(.title3)
                    .frame(width: 32)
                    .foregroundStyle(.cyan)
                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 8) {
                        Text(modeID.title)
                            .font(.headline)
                        if selected {
                            Text("Đang chọn")
                                .font(.caption2.weight(.bold))
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(.cyan.opacity(0.18), in: Capsule())
                        } else if !unlocked {
                            Label("Plus", systemImage: "lock.fill")
                                .font(.caption2.weight(.bold))
                        }
                    }
                    Text(modeID.subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(modeID.instruction)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                Image(systemName: selected ? "checkmark.circle.fill" : "chevron.right")
                    .foregroundStyle(selected ? .cyan : .secondary)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("mode.\(modeID.rawValue)")
    }

    private func sensoryControls(
        soundEnabled: Binding<Bool>,
        hapticsEnabled: Binding<Bool>
    ) -> some View {
        VStack(spacing: 8) {
            Toggle("Âm thanh", isOn: soundEnabled)
            Toggle("Haptic", isOn: hapticsEnabled)
        }
        .font(.subheadline)
        .padding(14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func select(_ modeID: GameModeID) {
        if modeID.requiresPlus, !plusStore.access.hasPlus {
            showPlus = true
            return
        }
        switch profile.select(mode: modeID, access: plusStore.access) {
        case .success:
            dismiss()
        case .failure(let error):
            selectionError = error
        }
    }

    private func icon(for modeID: GameModeID) -> String {
        switch modeID {
        case .classic: "circle.dashed"
        case .rush60: "timer"
        case .precisionPulse: "scope"
        case .waveSurvival: "wave.3.right"
        case .dailyChallenge: "calendar"
        }
    }
}
