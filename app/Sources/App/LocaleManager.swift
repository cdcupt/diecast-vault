import SwiftUI
import Combine

/// The two shipping languages (DESIGN F4 — "English / 简体中文 · live, no relaunch").
/// 繁體中文 comes later; the raw values are BCP-47 / `.lproj` identifiers so they
/// map straight onto a `Bundle` and a SwiftUI `Locale`.
enum AppLanguage: String, CaseIterable, Identifiable {
    case english = "en"
    case simplifiedChinese = "zh-Hans"

    var id: String { rawValue }

    /// The locale the UI renders in when this language is the active override.
    var locale: Locale { Locale(identifier: rawValue) }

    /// Endonym shown as the row's primary label (a language is named in itself).
    var endonym: String {
        switch self {
        case .english: return "English"
        case .simplifiedChinese: return "简体中文"
        }
    }

    /// English gloss shown as a secondary label, mirroring the mockup's
    /// "简体中文 · Simplified Chinese" / "English" rows.
    var exonym: String {
        switch self {
        case .english: return "English"
        case .simplifiedChinese: return "Simplified Chinese"
        }
    }
}

/// Owns the **in-app** language override and re-renders the UI live when it
/// changes — no relaunch and no trip through iOS Settings (DESIGN F4).
///
/// How the live switch works:
/// 1. The choice is persisted to `UserDefaults` (`AppleLanguages`, the same key
///    iOS reads, **and** our own key so we can restore on next launch).
/// 2. We expose `locale`; the app root injects it via `.environment(\.locale,)`,
///    so every `Text` re-resolves its catalog entry the moment `language`
///    changes (this object is `@Observable`/`ObservableObject`, so the view tree
///    invalidates).
/// 3. For strings looked up through `String(localized:)` / `LocalizedStringKey`
///    SwiftUI honours the environment locale automatically; nothing reads the
///    process-wide bundle, so the switch is immediate and total.
///
/// iOS caveat (documented per the brief): `Bundle.main` is locked to the launch
/// language for *imperative* `NSLocalizedString` lookups — those would still need
/// a relaunch. We avoid that trap entirely by keeping every user-facing string in
/// SwiftUI views (which re-resolve against `\.locale`) and by reading copy that
/// must be fetched in code (the zh Real-Car sample) off `LocaleManager.language`
/// rather than off the frozen main bundle.
@MainActor
final class LocaleManager: ObservableObject {
    private static let storageKey = "dv.appLanguage"

    @Published private(set) var language: AppLanguage

    /// The SwiftUI locale to inject at the app root.
    var locale: Locale { language.locale }

    init() {
        // Deterministic sim verification: `DV_LANG=zh-Hans` (or `en`) forces the
        // launch language so the zh build can be screenshotted without UI taps.
        if let forced = ProcessInfo.processInfo.environment["DV_LANG"],
           let lang = AppLanguage(rawValue: forced) {
            self.language = lang
            return
        }
        let stored = UserDefaults.standard.string(forKey: Self.storageKey)
        self.language = stored.flatMap(AppLanguage.init(rawValue:)) ?? Self.systemDefault()
    }

    /// Switch the whole app live and persist the choice.
    func select(_ language: AppLanguage) {
        guard language != self.language else { return }
        self.language = language
        UserDefaults.standard.set(language.rawValue, forKey: Self.storageKey)
        // Keep the OS preference in lock-step so any framework UI (share sheets,
        // system alerts) presented after the switch also picks the language up.
        UserDefaults.standard.set([language.rawValue], forKey: "AppleLanguages")
    }

    /// First-launch default: honour the device language when it is one we ship,
    /// otherwise fall back to English.
    private static func systemDefault() -> AppLanguage {
        let preferred = Locale.preferredLanguages.first ?? "en"
        if preferred.hasPrefix("zh") { return .simplifiedChinese }
        return .english
    }
}
