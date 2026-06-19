import SwiftUI
import Combine
import DiecastVaultCore

/// Owns the user's chosen cabinet style and re-renders the cabinet live when it
/// changes (DESIGN §4.2b — "confirm cross-dissolves the whole Home cabinet …
/// Selection persists per-user"). Cosmetic only: it changes no data or behavior.
///
/// Mirrors `LocaleManager`'s shape — a `@MainActor ObservableObject` backed by
/// `UserDefaults`, with a `DV_CABINET_STYLE` env override so each style can be
/// screenshotted deterministically in the simulator with no UI taps.
@MainActor
final class CabinetStylePreference: ObservableObject {
    private static let storageKey = "dv.cabinetStyle"

    @Published private(set) var style: CabinetStyle

    init() {
        if let forced = ProcessInfo.processInfo.environment["DV_CABINET_STYLE"],
           let style = CabinetStyle(rawValue: forced) {
            self.style = style
            return
        }
        let stored = UserDefaults.standard.string(forKey: Self.storageKey)
        self.style = stored.flatMap(CabinetStyle.init(rawValue:)) ?? .default
    }

    /// Switch the cabinet's dress live and persist the choice per-user.
    func select(_ style: CabinetStyle) {
        guard style != self.style else { return }
        self.style = style
        UserDefaults.standard.set(style.rawValue, forKey: Self.storageKey)
    }
}
