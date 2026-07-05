import SwiftUI
import DiecastVaultCore

/// Typed routes for the bond / share leg of the scan flow.
enum ScanRoute: Hashable {
    case bond(scan: ScanResult?)
    case share(copy: OwnedCopy, isFirstToScan: Bool)
}

/// Owns the scan flow's navigation path and a `finish()` that pops the whole
/// modal back to the cabinet once a model is saved. A child several screens deep
/// (the share prompt) can call `finish()` without knowing how it was presented.
@MainActor
final class ScanRouter: ObservableObject {
    @Published var path: [ScanRoute] = []
    /// Bumped to ask `ScanFlowView` to dismiss the whole sheet.
    @Published var finishedToken = 0

    func go(_ route: ScanRoute) { path.append(route) }
    func finish() { finishedToken += 1 }
}

/// The production "Add a car" sheet: a plain, camera-free flow that hosts
/// `BondView` directly. There is no scan framing anywhere on this path — App
/// Review rejected v1.0 twice under Guideline 2.1(a) for advertising a scan
/// feature that had not shipped (first a stalled capture simulation, then a
/// "coming in an update" placeholder), so until the real capture pipeline lands
/// AND is device-validated, adding a car is presented purely as attaching a
/// catalog identity to a copy you own.
struct AddCarFlowView: View {
    /// When launched from a release detail, the form opens pre-seeded with that
    /// release's `(number, drive)`.
    var prefillKey: CatalogKey? = nil

    @Environment(\.dismiss) private var dismiss
    @StateObject private var router = ScanRouter()

    var body: some View {
        NavigationStack(path: $router.path) {
            BondView(scanResult: nil, prefillKey: prefillKey)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("scan.cancel") { dismiss() }
                            .foregroundStyle(Ink.tungstenDeep)
                    }
                }
        }
        .environmentObject(router)
        .tint(Ink.tungsten)
        .onChange(of: router.finishedToken) { _, _ in dismiss() }
    }
}

/// DEV-ONLY capture-flow coordinator — no production surface presents this view.
/// It is reachable only via the `DV_ROUTE=scan` debug route (process-environment
/// gated, unreachable on a store install). Decides between the two top-level
/// paths at runtime:
///
/// - Guided flow (tip → orbit → reconstruct → keep/re-scan verdict → BOND →
///   share prompt): only when `ScanCapabilityService` reports a supported
///   device AND guided capture has shipped. In v1.0 it has NOT shipped — the
///   live ObjectCaptureSession/PhotogrammetrySession pipeline (Spike-0) is
///   unbuilt, so no device takes this path in release builds.
/// - Everyone else: the capability-invite, which still routes to BOND.
///
/// A `DV_FORCE_SCAN_SUPPORT=1` env override exercises the guided UI in
/// development without a device. Production adds cars through `AddCarFlowView`.
struct ScanFlowView: View {
    /// Inject a fixed capability for deterministic screenshots; defaults to the
    /// real runtime detection.
    var capability: ScanCapability = ScanCapabilityService.current
    /// DEV path: open straight on the BOND step (no live scan, bundled sample USDZ
    /// attached) so the bond→save→cabinet chain is testable in the simulator.
    var startAtBond: Bool = false
    /// When launched from a release's "Be the first to scan this" gap-nudge, the
    /// bond is prefilled with that release's `(number, drive)` so a world-first
    /// lights the right niche. Implies starting at the bond step on the simulator.
    var prefillKey: CatalogKey? = nil

    @Environment(\.dismiss) private var dismiss
    @StateObject private var flow = ScanFlowModel()
    @StateObject private var router = ScanRouter()

    var body: some View {
        NavigationStack(path: $router.path) {
            root
                .navigationDestination(for: ScanRoute.self) { route in
                    switch route {
                    case let .bond(scan):
                        BondView(scanResult: scan, prefillKey: prefillKey)
                    case let .share(copy, isFirst):
                        SharePromptView(copy: copy, isFirstToScan: isFirst)
                    }
                }
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("scan.cancel") { dismiss() }
                            .foregroundStyle(Ink.tungstenDeep)
                    }
                }
        }
        .environmentObject(router)
        .tint(Ink.tungsten)
        .onChange(of: router.finishedToken) { _, _ in dismiss() }
    }

    @ViewBuilder
    private var root: some View {
        if startAtBond || prefillKey != nil {
            // DEV / gap-nudge path: land on BOND immediately (sample USDZ stands in
            // for a scan). A `prefillKey` seeds the form from the release.
            BondView(scanResult: nil, prefillKey: prefillKey)
        } else if capability.canCapture {
            guidedFlow
        } else {
            // Unsupported / simulator: the contributor invitation. Bonding is still
            // reachable (the dev path attaches the bundled sample USDZ).
            CapabilityInviteView(onBond: { router.go(.bond(scan: nil)) })
        }
    }

    /// The guided four-step flow for supported devices. Each step advances `flow`;
    /// the verdict's "Keep" routes to BOND with the produced `ScanResult`.
    @ViewBuilder
    private var guidedFlow: some View {
        stepView
            .onAppear(perform: presetStepIfRequested)
    }

    /// Deterministic sim deep-link: `DV_SCAN_STEP=capture|reconstruct|verdict`
    /// pre-positions the flow so each guided state can be screenshotted without a
    /// camera (the live capture/reconstruct only run on a Pro iPhone).
    private func presetStepIfRequested() {
        guard flow.step == .tip,
              let raw = ProcessInfo.processInfo.environment["DV_SCAN_STEP"],
              let step = ScanStep.named(raw)
        else { return }
        flow.preset(step: step, modelURL: SampleModel.url)
    }

    @ViewBuilder
    private var stepView: some View {
        switch flow.step {
        case .tip:
            ScanTipView(onStart: { flow.startCapture() })
        case .capture:
            ScanCaptureView(
                coverage: flow.coverage,
                shotCount: flow.shotCount,
                onFinish: { flow.finishAndReconstruct(modelURL: SampleModel.url) }
            )
        case .reconstruct:
            ScanReconView(progress: flow.reconProgress, shotCount: flow.shotCount)
        case .verdict:
            if let result = flow.result {
                ScanVerdictView(
                    result: result,
                    onKeep: { router.go(.bond(scan: result)) },
                    onRescan: { flow.rescan() }
                )
            }
        }
    }
}
