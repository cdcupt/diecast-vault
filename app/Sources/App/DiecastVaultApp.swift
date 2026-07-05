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

    /// Owns the user's opted-in community shares (upload stubbed for v1.1). Shared
    /// so a fresh share from the post-bond prompt is reflected live in Me and in
    /// the Library credit lines — recognition derived, never hardcoded.
    @StateObject private var contributionStore = ContributionStore()

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
            .environmentObject(contributionStore)
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
            // The model-load-failed state is reached with DV_VIEWER_ERROR=1 alongside.
            ModelViewerView(release: routeSample)
        case "realcar":
            ReleaseDetailView(release: routeSample, initialFace: .realCar)
        case "catalog":
            CatalogView()
        case "me":
            MeView()
        case "library":
            LibraryView()
        case "language":
            LanguageView()
        case "stylePicker":
            CabinetStylePickerView()
        #if DEBUG
        case "scan":
            // DEBUG-only: the unshipped capture flow — shows the capability-invite
            // on the simulator (PhotogrammetrySession.isSupported == false).
            // DV_FORCE_SCAN_SUPPORT=1 overrides to exercise the guided path.
            // Compiled out of Release so no store binary carries a scan route.
            ScanFlowView()
        case "share":
            // DEBUG-only: the post-bond SHARE prompt (requires a real capture,
            // impossible in production) so the opt-in is screenshot-able in the sim.
            SharePromptScreenshotHost()
        #endif
        case "bond":
            // DEV add-a-car path: land straight on the bond form so the
            // add→save→cabinet chain runs without a camera.
            AddCarFlowView()
        case "noscan":
            // DEV: a MATTE (no-model) release detail — the calm no-model note with
            // the working Pick-to-shelf action.
            ReleaseDetailView(release: Release(
                key: .init(mgtNumber: "MGT00910", drive: .lhd),
                name: "Lamborghini Huracán EVO", edition: "0344/2019", isLit: false))
        case "devbond":
            // Seed a fresh bonded model, then show the full shell so it appears LIT
            // in the cabinet — verifies the bond→save→appears-in-cabinet chain.
            DevBondedCabinet()
        case "emptyCabinet":
            // DEV: the empty (zero-lit) cabinet over an UNSEEDED store, so the
            // authored "your cabinet is dark" invite is screenshot-able.
            NavigationStack { CabinetView() }
                .modelContainer(PersistenceController.inMemory(seeded: false))
                .environmentObject(CabinetStylePreference())
                .environmentObject(ContributionStore())
        case "emptyLibrary":
            // DEV: the empty community library (no opted-in shares yet).
            NavigationStack { LibraryView() }
                .environmentObject(ContributionStore(seed: []))
        case "offlineLibrary":
            // DEV: the offline community library — cached-shelf-works banner.
            NavigationStack { LibraryView(forceOffline: true) }
                .environmentObject(ContributionStore())
        default:
            ReleaseDetailView(release: routeSample)
        }
    }
}

/// DEV host (DV_ROUTE=share): presents the post-bond SHARE prompt inside a scan
/// router so the contribution opt-in surface is screenshot-able without walking
/// the whole capture→bond chain. Uses a representative first-to-scan copy.
private struct SharePromptScreenshotHost: View {
    @StateObject private var router = ScanRouter()
    private static let copy = OwnedCopy(
        key: .init(mgtNumber: "MGT00802", drive: .rhd),
        editionNo: "0640/2022", hasModel: true)

    var body: some View {
        NavigationStack {
            SharePromptView(copy: Self.copy, isFirstToScan: true)
        }
        .environmentObject(router)
        .tint(Ink.tungsten)
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
