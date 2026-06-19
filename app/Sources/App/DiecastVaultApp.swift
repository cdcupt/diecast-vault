import SwiftUI
import SwiftData
import DiecastVaultCore

@main
struct DiecastVaultApp: App {
    /// Spike-1 deterministic entry: launching with `-spike1Cabinet 1` (or env
    /// `DV_SPIKE1=1`) boots straight into the 3D-cabinet perf scene so the
    /// harness can run without a synthetic UI tap. Normal launches show the
    /// full tab shell.
    private static var launchesIntoSpike1: Bool {
        UserDefaults.standard.bool(forKey: "spike1Cabinet")
            || ProcessInfo.processInfo.environment["DV_SPIKE1"] == "1"
    }

    /// Deterministic deep-link for sim verification (no UI-automation tool needed
    /// in this environment). `DV_ROUTE=detail|realcar|viewer` boots straight into
    /// a sample Release detail / its Real-Car face / the 3D viewer so each new
    /// surface can be screenshotted. Unset in normal launches → full tab shell.
    private static var debugRoute: String? {
        ProcessInfo.processInfo.environment["DV_ROUTE"]
    }

    private static let routeSample = Release(
        key: .init(mgtNumber: "MGT00748", drive: .lhd),
        name: "Toyota GR Supra", edition: "1510/2022", isLit: true
    )

    /// Owns the live in-app language override; injected as `\.locale` so the whole
    /// tree re-resolves its String Catalog entries the instant the choice changes.
    @StateObject private var localeManager = LocaleManager()

    /// Owns the user's chosen cabinet style; injected so the 3D Home and the style
    /// picker share one live, persisted source of truth.
    @StateObject private var stylePreference = CabinetStylePreference()

    var body: some Scene {
        WindowGroup {
            Group {
                if Self.launchesIntoSpike1 {
                    NavigationStack { Spike1CabinetView() }
                } else if let route = Self.debugRoute {
                    NavigationStack { Self.routedView(route) }
                } else {
                    RootTabView()
                }
            }
            .tint(Ink.tungsten)
            .environmentObject(localeManager)
            .environmentObject(stylePreference)
            // Live language switch: re-rendering against this locale is what makes
            // every localized `Text` flip without a relaunch (see LocaleManager).
            .environment(\.locale, localeManager.locale)
        }
        // Local-first SwiftData store, seeded on first run; iCloud sync OFF for now.
        .modelContainer(PersistenceController.shared)
    }

    @ViewBuilder
    private static func routedView(_ route: String) -> some View {
        switch route {
        case "viewer":
            ModelViewerView(release: routeSample)
        case "realcar":
            ReleaseDetailView(release: routeSample, initialFace: .realCar)
        case "catalog":
            CatalogView()
        case "me":
            MeView()
        case "language":
            LanguageView()
        case "stylePicker":
            CabinetStylePickerView()
        case "scan":
            // The full scan flow — shows the capability-invite on the simulator
            // (PhotogrammetrySession.isSupported == false). DV_FORCE_SCAN_SUPPORT=1
            // overrides to exercise the guided path.
            ScanFlowView()
        case "bond":
            // DEV bond path: land straight on the BOND step (sample USDZ stands in
            // for a live scan) so the bond→save→cabinet chain runs without a camera.
            ScanFlowView(startAtBond: true)
        case "devbond":
            // Seed a fresh bonded model, then show the full shell so it appears LIT
            // in the cabinet — verifies the bond→save→appears-in-cabinet chain.
            DevBondedCabinet()
        default:
            ReleaseDetailView(release: routeSample)
        }
    }
}

/// DEV verification view (DV_ROUTE=devbond): bonds a new owned model via the
/// bundled sample USDZ on first appear, then shows the full tab shell so the
/// freshly-bonded car is visible LIT in the 3D cabinet — the bond→save→cabinet
/// chain, end to end, with no camera.
private struct DevBondedCabinet: View {
    @Environment(\.modelContext) private var modelContext
    @State private var seeded = false

    /// A release deliberately NOT in the first-run lit seed, so it reads as freshly
    /// bonded against the matte shelf.
    private static let freshDraft = BondDraft(mgtNumber: "MGT00702", drive: .lhd, editionNo: "0319/2023")

    var body: some View {
        RootTabView()
            .task {
                guard !seeded else { return }
                seeded = true
                guard let copy = Self.freshDraft.ownedCopy(hasModel: true) else { return }
                let id = copy.key.stableID
                let existing = try? modelContext.fetch(
                    FetchDescriptor<OwnedModel>(predicate: #Predicate { $0.stableID == id })
                )
                if existing?.isEmpty ?? true {
                    modelContext.insert(OwnedModel(copy))
                    try? modelContext.save()
                }
            }
    }
}
