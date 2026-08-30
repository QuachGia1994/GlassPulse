import SwiftUI

@MainActor
struct SettingsView: View {
    @Environment(GameSettings.self) private var settings
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        @Bindable var settings = settings
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    section("settings.section.audio") {
                        Toggle(isOn: Binding(
                            get: { settings.musicEnabled },
                            set: { settings.setMusicEnabled($0) }
                        )) {
                            settingLabel("settings.music.label", hint: "settings.music.hint")
                        }
                        .accessibilityIdentifier("settings.music")

                        Toggle(isOn: Binding(
                            get: { settings.soundEnabled },
                            set: { settings.setSoundEnabled($0) }
                        )) {
                            settingLabel("settings.sfx.label", hint: "settings.sfx.hint")
                        }
                        .accessibilityIdentifier("settings.sfx")
                    }

                    section("settings.section.feedback") {
                        Toggle(isOn: Binding(
                            get: { settings.hapticsEnabled },
                            set: { settings.setHapticsEnabled($0) }
                        )) {
                            settingLabel("settings.haptics.label", hint: "settings.haptics.hint")
                        }
                        .accessibilityIdentifier("settings.haptics")
                    }

                    section("settings.section.display") {
                        Toggle(isOn: Binding(
                            get: { settings.reduceMotionEnabled },
                            set: { settings.setReduceMotionEnabled($0) }
                        )) {
                            settingLabel(
                                "settings.reduceMotion.label",
                                hint: "settings.reduceMotion.hint"
                            )
                        }
                        .accessibilityIdentifier("settings.reduceMotion")

                        Toggle(isOn: Binding(
                            get: { settings.highContrastEnabled },
                            set: { settings.setHighContrastEnabled($0) }
                        )) {
                            settingLabel(
                                "settings.highContrast.label",
                                hint: "settings.highContrast.hint"
                            )
                        }
                        .accessibilityIdentifier("settings.highContrast")
                    }

                    section("settings.section.language") {
                        Picker(selection: Binding(
                            get: { settings.language },
                            set: { settings.setLanguage($0) }
                        )) {
                            ForEach(AppLanguage.allCases) { language in
                                Text(LocalizedStringKey(language.titleKey)).tag(language)
                            }
                        } label: {
                            settingLabel("settings.language.label", hint: "settings.language.hint")
                        }
                        .accessibilityIdentifier("settings.language")
                    }

                    section("settings.section.credit") {
                        Text("settings.music.credit")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding()
            }
            .accessibilityIdentifier("settings.sheet")
            .navigationTitle(Text("settings.title"))
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
                    .accessibilityLabel(Text("settings.close.label"))
                    .accessibilityIdentifier("settings.close")
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func section(
        _ titleKey: LocalizedStringKey,
        @ViewBuilder content: () -> some View
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(titleKey)
                .font(.caption.weight(.bold))
                .tracking(1.5)
                .foregroundStyle(.secondary)
            VStack(spacing: 8) {
                content()
            }
            .padding(14)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
    }

    private func settingLabel(
        _ titleKey: LocalizedStringKey,
        hint: LocalizedStringKey
    ) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(titleKey)
                .font(.subheadline.weight(.medium))
            Text(hint)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }
}

extension AppLanguage {
    var titleKey: String {
        switch self {
        case .system: "settings.language.system"
        case .english: "settings.language.en"
        case .vietnamese: "settings.language.vi"
        case .japanese: "settings.language.ja"
        case .simplifiedChinese: "settings.language.zhHans"
        }
    }
}
