import SwiftUI
import DiecastVaultCore

/// Me tab (DESIGN F4 §Settings) — the signed-in identity, the contribution
/// summary that frames sharing as helping other owners, and the settings rows.
/// Language is the live in-app switch; the rest are honest placeholders until
/// their backends land. Account/contribution numbers are local sample copy.
struct MeView: View {
    @EnvironmentObject private var localeManager: LocaleManager

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Lightbar(label: "tab.me")
                identity
                contribution
                settings
                footer
            }
            .padding(.horizontal, 18)
            .padding(.top, 8)
            .padding(.bottom, 28)
        }
        .background(Ink.paper)
        .navigationTitle(Text("tab.me"))
        .navigationBarTitleDisplayMode(.large)
    }

    // MARK: Identity

    private var identity: some View {
        HStack(spacing: 12) {
            Image(systemName: "person.crop.circle.fill")
                .font(.system(size: 40))
                .foregroundStyle(Ink.steel)
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: "@erik_64")
                    .font(Voice.serif(20))
                    .foregroundStyle(Ink.primary)
                Text("me.signedIn")
                    .font(.footnote)
                    .foregroundStyle(Ink.soft)
            }
            Spacer()
            Text("me.tier.pro")
                .textCase(.uppercase)
                .font(Voice.mono(10, weight: .heavy))
                .foregroundStyle(.white)
                .padding(.horizontal, 9).padding(.vertical, 4)
                .background(Ink.tungsten, in: Capsule())
        }
    }

    // MARK: Contribution summary

    private var contribution: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("me.contribution.heading")
                .textCase(.uppercase)
                .font(Voice.mono(10, weight: .semibold))
                .tracking(1.2)
                .foregroundStyle(Ink.muted)

            // Scale-contrast: the lit count towers; the breakdown sits in mono.
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("9")
                    .font(Voice.serif(40))
                    .foregroundStyle(Ink.primary)
                Text("me.contribution.litReleases")
                    .font(.callout)
                    .foregroundStyle(Ink.soft)
                Spacer()
            }

            Text("me.contribution.stats")
                .font(Voice.mono(10))
                .foregroundStyle(Ink.muted)

            Text("me.contribution.note")
                .font(.footnote)
                .foregroundStyle(Ink.soft)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color(Palette.tungstenGlow).opacity(0.4))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Ink.tungsten.opacity(0.5), lineWidth: 1)
        )
    }

    // MARK: Settings

    private var settings: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("me.settings.heading")
                .textCase(.uppercase)
                .font(Voice.mono(10, weight: .semibold))
                .tracking(1.2)
                .foregroundStyle(Ink.muted)

            VStack(spacing: 0) {
                NavigationLink {
                    LanguageView()
                } label: {
                    SettingsRow(
                        icon: "globe",
                        title: "me.row.language",
                        value: Text(verbatim: localeManager.language.endonym)
                    )
                }
                .buttonStyle(.plain)

                divider
                SettingsRow(icon: "icloud", title: "me.row.icloud", value: Text("me.row.icloud.value"), chevron: false)
                divider
                SettingsRow(icon: "iphone", title: "me.row.device", value: Text(verbatim: "iPhone 17 Pro"), chevron: false)
            }
            .background(Ink.cellSurface)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Ink.line, lineWidth: 1)
            )
        }
    }

    private var divider: some View {
        Rectangle().fill(Ink.line).frame(height: 1).padding(.leading, 48)
    }

    private var footer: some View {
        Text("me.footer")
            .font(Voice.mono(9))
            .foregroundStyle(Ink.muted)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.top, 4)
    }
}

/// One settings row: a steel glyph, a localized title, a trailing value, and an
/// optional disclosure chevron. Keeps the settings list visually consistent.
private struct SettingsRow: View {
    let icon: String
    let title: LocalizedStringKey
    let value: Text
    var chevron: Bool = true

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(Ink.steel)
                .frame(width: 24)
            Text(title)
                .font(.body)
                .foregroundStyle(Ink.primary)
            Spacer()
            value
                .font(.callout)
                .foregroundStyle(Ink.muted)
            if chevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Ink.muted)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
        .contentShape(Rectangle())
    }
}

/// Me → Language (DESIGN F4 §Language picker). Switches the whole app live —
/// no relaunch — via `LocaleManager`; the current language is marked 已选 / Selected.
struct LanguageView: View {
    @EnvironmentObject private var localeManager: LocaleManager

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("language.displayLanguage")
                    .textCase(.uppercase)
                    .font(Voice.mono(10, weight: .semibold))
                    .tracking(1.2)
                    .foregroundStyle(Ink.muted)

                VStack(spacing: 0) {
                    ForEach(Array(AppLanguage.allCases.enumerated()), id: \.element.id) { index, language in
                        if index > 0 {
                            Rectangle().fill(Ink.line).frame(height: 1).padding(.leading, 16)
                        }
                        languageRow(language)
                    }
                }
                .background(Ink.cellSurface)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Ink.line, lineWidth: 1)
                )

                liveNote
                whatLocalizes
            }
            .padding(.horizontal, 18)
            .padding(.top, 12)
            .padding(.bottom, 28)
        }
        .background(Ink.paper)
        .navigationTitle(Text("me.row.language"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private func languageRow(_ language: AppLanguage) -> some View {
        let isSelected = localeManager.language == language
        return Button {
            // Live switch: this re-renders the whole tree via the injected locale.
            localeManager.select(language)
        } label: {
            HStack(spacing: 8) {
                // Endonym + English gloss, mirroring the mockup's two-line label.
                Text(verbatim: language.endonym)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Ink.primary)
                if language != .english {
                    Text(verbatim: language.exonym)
                        .font(.footnote)
                        .foregroundStyle(Ink.muted)
                }
                Spacer()
                if isSelected {
                    Text("language.selected")
                        .font(Voice.mono(10, weight: .semibold))
                        .foregroundStyle(Ink.tungstenDeep)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(Color(Palette.tungstenGlow), in: Capsule())
                } else {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Ink.muted)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    private var liveNote: some View {
        Text("language.liveNote")
            .font(.footnote)
            .foregroundStyle(Ink.soft)
            .padding(.horizontal, 4)
    }

    private var whatLocalizes: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "globe")
                .font(.system(size: 14))
                .foregroundStyle(Ink.steel)
            VStack(alignment: .leading, spacing: 4) {
                Text("language.whatLocalizes.title")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Ink.primary)
                Text("language.whatLocalizes.body")
                    .font(.footnote)
                    .foregroundStyle(Ink.soft)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Ink.steelSoft, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

#Preview {
    NavigationStack { MeView() }
        .environmentObject(LocaleManager())
        .tint(Ink.tungsten)
}
