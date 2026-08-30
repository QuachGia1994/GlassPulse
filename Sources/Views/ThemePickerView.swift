import SwiftUI

@MainActor
struct ThemePickerView: View {
    @Environment(PlayerProfile.self) private var profile
    @Environment(PlusStore.self) private var plusStore
    @Environment(\.dismiss) private var dismiss

    @State private var selectionError: PlayerProfileError?
    @State private var showPlus = false

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(PulseTheme.allCases) { theme in
                        themeCard(theme)
                    }
                }
                .padding()
            }
            .navigationTitle("Theme & Pulse")
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
            "Chưa thể mở theme",
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

    private func themeCard(_ theme: PulseTheme) -> some View {
        let selected = profile.activeTheme(hasPlus: plusStore.isPlusUnlocked) == theme
        return HStack(spacing: 14) {
            themePreview(theme)
            VStack(alignment: .leading, spacing: 4) {
                Text(theme.title)
                    .font(.headline)
                Text(theme.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            Button(actionTitle(for: theme, selected: selected)) {
                select(theme)
            }
            .buttonStyle(.borderedProminent)
            .tint(theme.palette.ring)
            .disabled(selected)
        }
        .padding(14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(selected ? theme.palette.ring : .white.opacity(0.08), lineWidth: selected ? 2 : 1)
        }
    }

    private func themePreview(_ theme: PulseTheme) -> some View {
        ZStack {
            Circle()
                .stroke(theme.palette.ring.opacity(0.85), lineWidth: 3)
            Circle()
                .fill(theme.palette.ball)
                .frame(width: 11, height: 11)
                .offset(y: -25)
            Diamond()
                .fill(theme.palette.gem)
                .frame(width: 10, height: 10)
                .offset(x: 24, y: 8)
        }
        .frame(width: 64, height: 64)
        .background(theme.palette.backgroundBottom, in: Circle())
    }

    private func actionTitle(for theme: PulseTheme, selected: Bool) -> String {
        guard !selected else { return "Đang dùng" }
        if profile.owns(theme) { return "Dùng" }
        switch theme.unlock {
        case .free: return "Dùng"
        case .shards(let price): return "Mở \(price)"
        case .plus: return plusStore.isPlusUnlocked ? "Dùng" : "Xem Plus"
        }
    }

    private func select(_ theme: PulseTheme) {
        if case .plus = theme.unlock, !plusStore.isPlusUnlocked {
            showPlus = true
            return
        }
        switch profile.select(theme, hasPlus: plusStore.isPlusUnlocked) {
        case .success:
            dismiss()
        case .failure(let error):
            selectionError = error
        }
    }
}

private struct Diamond: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.midY))
        path.closeSubpath()
        return path
    }
}
