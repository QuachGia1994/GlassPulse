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
                    if plusStore.isBetaFullAccess {
                        Label("Beta Full Access: mọi theme đã mở", systemImage: "checkmark.seal.fill")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.cyan)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    ForEach(PulseTheme.allCases) { theme in
                        themeCard(theme)
                    }
                }
                .padding()
            }
            .navigationTitle("Theme & Pulse")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.body.weight(.semibold))
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .accessibilityLabel("Đóng")
                    .accessibilityIdentifier("theme.close")
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
        let selected = profile.activeTheme(access: plusStore.access) == theme
        return ViewThatFits(in: .horizontal) {
            HStack(alignment: .center, spacing: 14) {
                themePreview(theme)
                themeDescription(theme)
                Spacer(minLength: 8)
                themeAccessory(theme, selected: selected)
            }
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 14) {
                    themePreview(theme)
                    themeDescription(theme)
                }
                themeAccessory(theme, selected: selected)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .padding(14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(selected ? theme.palette.ring : .white.opacity(0.08), lineWidth: selected ? 2 : 1)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("theme.card.\(theme.id)")
    }

    private func themeDescription(_ theme: PulseTheme) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(theme.title)
                .font(.headline)
            Text(theme.subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    private func themeAccessory(_ theme: PulseTheme, selected: Bool) -> some View {
        if selected {
            Label("Đang dùng", systemImage: "checkmark")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(.white.opacity(0.12), in: Capsule())
                .overlay { Capsule().stroke(theme.palette.ring.opacity(0.9), lineWidth: 1) }
                .accessibilityLabel("Đang dùng \(theme.title)")
                .accessibilityIdentifier("theme.selected")
        } else {
            Button(actionTitle(for: theme)) {
                select(theme)
            }
            .buttonStyle(.borderedProminent)
            .tint(theme.palette.ring)
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

    private func actionTitle(for theme: PulseTheme) -> String {
        if profile.canUse(theme, access: plusStore.access) { return "Dùng" }
        switch theme.unlock {
        case .free: return "Dùng"
        case .shards(let price): return "Mở \(price)"
        case .plus: return plusStore.access.hasPlus ? "Dùng" : "Xem Plus"
        }
    }

    private func select(_ theme: PulseTheme) {
        if case .plus = theme.unlock, !plusStore.access.hasPlus {
            showPlus = true
            return
        }
        switch profile.select(theme, access: plusStore.access) {
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
