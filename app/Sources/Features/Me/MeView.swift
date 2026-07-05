import SwiftUI
import SwiftData
import UIKit
import DiecastVaultCore

/// Me tab (DESIGN F4 §Settings) — the local-collection identity and the
/// settings rows. Language is the live in-app switch; every control here
/// performs a real action (no account, no sync, no share pitch — those return
/// only with their real backends, per the App Review 2.1a lessons).
struct MeView: View {
    @EnvironmentObject private var localeManager: LocaleManager
    @EnvironmentObject private var stylePreference: CabinetStylePreference
    @State private var showStylePicker = false
    /// Set when a mailto: open fails (no Mail app) — drives the copy-address alert.
    @State private var mailFallbackAddress: String?

    /// The user's actual on-device collection — the source of truth for the
    /// Storage row (NOT contribution shares, which are always 0 in this build).
    @Query private var owned: [OwnedModel]

    /// App version for the About row — read from the bundle, never hardcoded.
    private var appVersion: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.1.0"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(v) (\(b))"
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    Lightbar(label: "tab.me")
                    identity
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

    // The contribution/recognition card is deliberately ABSENT in v1.0: sharing
    // has no entry point in this build, so a card promising "models you share
    // will be credited" would pitch a feature that cannot be exercised — the
    // exact incomplete-feature class App Review rejected twice (2.1a). It
    // returns with the real share flow.

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

    // MARK: Storage (on-device usage; everything stays local in this version —
    // an iCloud Sync control returns only when CloudKit is actually wired)

    private var storage: some View {
        SettingsGroup(header: "me.section.storage") {
            SettingsRow(
                icon: "iphone",
                title: "me.row.localStorage",
                // The real owned-model count from SwiftData — no invented byte
                // estimates (the only 3D asset is the shared app-bundle sample).
                value: Text("me.row.localStorage.count \(owned.count)"),
                chevron: false
            )
        }
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

    // MARK: Safety & legal (report / DMCA via mail, with a copy-address
    // fallback when no mail client is installed; license stated in the footer)

    private static let supportAddress = "support@daichenlab.com"

    private var legal: some View {
        SettingsGroup(header: "me.section.legal", footer: "me.section.legal.footer") {
            mailRow(icon: "flag", title: "me.row.report", subject: "Diecast Vault — report a problem")
            divider
            mailRow(icon: "doc.text", title: "me.row.dmca", subject: "Diecast Vault — DMCA / takedown")
        }
        .alert(
            Text("me.mail.fallback.title"),
            isPresented: Binding(
                get: { mailFallbackAddress != nil },
                set: { if !$0 { mailFallbackAddress = nil } }
            ),
            presenting: mailFallbackAddress
        ) { address in
            Button {
                UIPasteboard.general.string = address
                mailFallbackAddress = nil
            } label: {
                Text("me.mail.fallback.copy")
            }
            Button(role: .cancel) { mailFallbackAddress = nil } label: {
                Text("me.mail.fallback.dismiss")
            }
        } message: { address in
            Text("me.mail.fallback.body \(address)")
        }
    }

    /// A settings row that opens a prefilled mailto. If no mail client is
    /// installed (Mail is commonly deleted), it falls back to an alert showing
    /// the address with a Copy button — the contact routes must never dead-end.
    private func mailRow(icon: String, title: LocalizedStringKey, subject: String) -> some View {
        Button {
            let encoded = subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
            guard let url = URL(string: "mailto:\(Self.supportAddress)?subject=\(encoded)") else {
                mailFallbackAddress = Self.supportAddress
                return
            }
            UIApplication.shared.open(url, options: [:]) { success in
                if !success { mailFallbackAddress = Self.supportAddress }
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
