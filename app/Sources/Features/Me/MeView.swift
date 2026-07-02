import SwiftUI
import UIKit
import DiecastVaultCore

/// Me tab (DESIGN F4 §Settings) — the signed-in identity, the contribution
/// summary that frames sharing as helping other owners, and the settings rows.
/// Language is the live in-app switch; the rest are honest placeholders until
/// their backends land. Account/contribution numbers are local sample copy.
struct MeView: View {
    @EnvironmentObject private var localeManager: LocaleManager
    @EnvironmentObject private var stylePreference: CabinetStylePreference
    @EnvironmentObject private var contributionStore: ContributionStore
    @State private var showStylePicker = false

    /// iCloud Sync — OFF by default (DESIGN F4 §Storage). Local-only effect for now
    /// (no `cloudKitDatabase` is wired yet); the preference persists so the real
    /// sync wiring in v1.1 reads an honest user choice. Stored, not hardcoded.
    @AppStorage("dv.icloudSync") private var icloudSync = false

    /// App version for the About row — read from the bundle, never hardcoded.
    private var appVersion: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.1.0"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(v) (\(b))"
    }

    /// Recognition is DERIVED from the user's opted-in shares — never hardcoded, so
    /// it tracks a fresh share from the post-bond prompt the instant it lands.
    private var summary: ContributionSummary { contributionStore.summary }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    Lightbar(label: "tab.me")
                    identity
                    contribution
                    account
                    storage
                    general
                    legal
                    about
                    footer.id("me-bottom")
                }
                .padding(.horizontal, 18)
                .padding(.top, 8)
                .padding(.bottom, 28)
            }
            .background(Ink.paper)
            .navigationTitle(Text("tab.me"))
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $showStylePicker) {
                CabinetStylePickerView()
                    .environmentObject(stylePreference)
            }
            .onAppear {
                // Deterministic sim hook: `DV_SCROLL=bottom` jumps to the list tail
                // so the Safety & legal + About sections are screenshot-able.
                if ProcessInfo.processInfo.environment["DV_SCROLL"] == "bottom" {
                    proxy.scrollTo("me-bottom", anchor: .bottom)
                }
            }
        }
    }

    // MARK: Identity (local-only — there is no sign-in or tier in this build,
    // so the card claims neither; it names the on-device collection honestly)

    private var identity: some View {
        HStack(spacing: 12) {
            Image(systemName: "person.crop.circle.fill")
                .font(.system(size: 40))
                .foregroundStyle(Ink.steel)
            VStack(alignment: .leading, spacing: 2) {
                Text("me.localName")
                    .font(Voice.serif(20))
                    .foregroundStyle(Ink.primary)
                Text("me.signedIn")
                    .font(.footnote)
                    .foregroundStyle(Ink.soft)
            }
            Spacer()
        }
    }

    // MARK: Contribution summary

    private var contribution: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("me.contribution.heading")
                .textCase(.uppercase)
                .font(Voice.mono(10, weight: .semibold))
                .tracking(1.2)
                .foregroundStyle(Ink.muted)

            if summary.litReleases > 0 {
                // The headline reads the derived count — "You've lit N releases…".
                Text("me.contribution.litHeadline \(summary.litReleases)")
                    .font(Voice.serif(24))
                    .foregroundStyle(Ink.primary)
                    .fixedSize(horizontal: false, vertical: true)

                // Telemetry breakdown in mono (shares · downloads · world-firsts).
                Text("me.contribution.tele \(summary.litReleases) \(summary.totalDownloads) \(summary.worldFirsts)")
                    .font(Voice.mono(10))
                    .foregroundStyle(Ink.soft)

                badges

                Text("me.contribution.creditNote")
                    .font(.footnote)
                    .foregroundStyle(Ink.soft)
            } else {
                // Fresh install: nothing shared yet, so nothing is claimed —
                // recognition is earned, never seeded. Aspirational empty state.
                Text("me.contribution.emptyHeadline")
                    .font(Voice.serif(24))
                    .foregroundStyle(Ink.primary)
                    .fixedSize(horizontal: false, vertical: true)

                Text("me.contribution.note")
                    .font(.footnote)
                    .foregroundStyle(Ink.soft)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color(Palette.tungstenGlow).opacity(0.4))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Ink.tungsten.opacity(0.5), lineWidth: 1)
        )
    }

    /// Light badges earned from opted-in shares (mockup #s-settings strip).
    private var badges: some View {
        HStack(spacing: 6) {
            ForEach(summary.badges) { badge in
                badgeChip(badge)
            }
        }
    }

    @ViewBuilder
    private func badgeChip(_ badge: ContributionBadge) -> some View {
        switch badge {
        case .firstLight:
            chip("me.badge.firstLight \(summary.worldFirsts)",
                 fg: Ink.tungstenDeep, bg: Color(Palette.tungstenGlow))
        case .seeder:
            chip("me.badge.seeder", fg: Ink.steel, bg: Ink.steelSoft)
        case .verifiedOwner:
            chip("me.badge.verifiedOwner", fg: .white, bg: Ink.ok)
        }
    }

    private func chip(_ key: LocalizedStringKey, fg: Color, bg: Color) -> some View {
        Text(key)
            .font(Voice.mono(10, weight: .semibold))
            .foregroundStyle(fg)
            .padding(.horizontal, 9).padding(.vertical, 4)
            .background(bg, in: Capsule())
    }

    // MARK: Account (none exists in this build — the row says so honestly;
    // everything lives on-device)

    private var account: some View {
        SettingsGroup(header: "me.section.account") {
            SettingsRow(
                icon: "iphone",
                title: "me.row.account",
                value: Text("me.row.account.signedIn"),
                chevron: false
            )
        }
    }

    // MARK: Storage (iCloud Sync toggle + on-device usage)

    private var storage: some View {
        SettingsGroup(header: "me.section.storage", footer: "me.row.icloudSync.note") {
            SettingsToggleRow(
                icon: "icloud",
                title: "me.row.icloudSync",
                isOn: $icloudSync
            )
            divider
            SettingsRow(
                icon: "iphone",
                title: "me.row.localStorage",
                // Derived from the live collection size; storage estimate is a stub
                // (~40 MB / car) until the real on-disk USDZ accounting lands.
                value: Text("me.row.localStorage.value \(summary.litReleases) \(storageEstimate)"),
                chevron: false
            )
        }
    }

    /// Rough on-disk estimate (sample USDZ ~40 MB / car) for the storage row.
    private var storageEstimate: String {
        let bytes = Int64(summary.litReleases) * 40_000_000
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useGB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: max(bytes, 0))
    }

    // MARK: General (cabinet style + language)

    private var general: some View {
        SettingsGroup(header: "me.section.general") {
            Button { showStylePicker = true } label: {
                SettingsRow(
                    icon: "square.stack.3d.up.fill",
                    title: "me.row.cabinetStyle",
                    value: Text(LocalizedStringKey(stylePreference.style.nameKey))
                )
            }
            .buttonStyle(.plain)

            divider
            NavigationLink { LanguageView() } label: {
                SettingsRow(
                    icon: "globe",
                    title: "me.row.language",
                    value: Text(verbatim: localeManager.language.endonym)
                )
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: Safety & legal (report / DMCA — local mailto stubs for now)

    private var legal: some View {
        SettingsGroup(header: "me.section.legal") {
            mailRow(icon: "flag", title: "me.row.report", subject: "Diecast Vault — report a problem")
            divider
            mailRow(icon: "doc.text", title: "me.row.dmca", subject: "Diecast Vault — DMCA / takedown")
            divider
            SettingsRow(icon: "checkmark.seal", title: "me.row.license", value: Text(verbatim: ""), chevron: false)
        }
    }

    /// A settings row that opens a prefilled mailto (stubbed contact until the
    /// backend support routing lands). Falls back gracefully if mail isn't set up.
    private func mailRow(icon: String, title: LocalizedStringKey, subject: String) -> some View {
        Button {
            let encoded = subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
            if let url = URL(string: "mailto:support@daichenlab.com?subject=\(encoded)") {
                UIApplication.shared.open(url)
            }
        } label: {
            SettingsRow(icon: icon, title: title, value: Text(verbatim: ""))
        }
        .buttonStyle(.plain)
    }

    // MARK: About

    private var about: some View {
        SettingsGroup(header: "me.section.about") {
            SettingsRow(
                icon: "info.circle",
                title: "me.row.version",
                value: Text(verbatim: appVersion),
                chevron: false
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

/// A titled settings group: a mono uppercase section header, a rounded card of
/// rows, and an optional footnote underneath (e.g. the iCloud quota note). Keeps
/// every section of the Me list visually consistent and on-brand.
private struct SettingsGroup<Content: View>: View {
    let header: LocalizedStringKey
    var footer: LocalizedStringKey? = nil
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(header)
                .textCase(.uppercase)
                .font(Voice.mono(10, weight: .semibold))
                .tracking(1.2)
                .foregroundStyle(Ink.muted)

            VStack(spacing: 0) { content }
                .background(Ink.cellSurface)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Ink.line, lineWidth: 1)
                )

            if let footer {
                Text(footer)
                    .font(.footnote)
                    .foregroundStyle(Ink.soft)
                    .padding(.horizontal, 4)
            }
        }
    }
}

/// A settings row carrying a tungsten-tinted toggle (e.g. iCloud Sync). The
/// switch is the row's only trailing control — no chevron.
private struct SettingsToggleRow: View {
    let icon: String
    let title: LocalizedStringKey
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(Ink.steel)
                .frame(width: 24)
            Toggle(isOn: $isOn) {
                Text(title)
                    .font(.body)
                    .foregroundStyle(Ink.primary)
            }
            .tint(Ink.tungsten)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
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
        .environmentObject(CabinetStylePreference())
        .environmentObject(ContributionStore())
        .tint(Ink.tungsten)
}
