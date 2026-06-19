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

/// The "Scan a car" entry point and capture-flow coordinator. Decides between the
/// two top-level paths at runtime:
///
/// - SUPPORTED device (`PhotogrammetrySession.isSupported`): the guided flow —
///   tip → ObjectCaptureSession orbit → PhotogrammetrySession reconstruct →
///   keep/re-scan verdict → BOND → share prompt.
/// - UNSUPPORTED device / simulator: the capability-invite (a contributor
///   invitation, never a dead control), which still routes to BOND so an owner
///   can name a copy they own.
///
/// Capture + reconstruction only truly run on a physical Pro iPhone (that IS
/// Spike-0). The gating below is what makes the simulator show the invite; a
/// `DV_FORCE_SCAN_SUPPORT=1` override exercises the guided UI without a device.
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
