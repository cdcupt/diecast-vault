import SwiftUI
import DiecastVaultCore

/// The graceful-degradation seam from TECH.html §4.2. The cabinet has two
/// renderers behind one protocol so a Spike-1 NO-GO is a *swap, not a rewrite*:
///
/// - `RealityKitCabinetRenderer` — the primary real-time RealityKit scene
///   (Spike-1 GO). One mesh; hero niche = full USDZ; others = billboard/low-LOD;
///   clamped orbit + gyro.
/// - `PseudoThreeDCabinetRenderer` — the documented flat-preview fallback
///   (Spike-1 NO-GO). Not built in this spike; named here so the seam exists.
///
/// Keeping this as a protocol means `CabinetView` (and later the capability
/// gate) can choose a renderer at runtime — e.g. by `iOS 18` / RealityView
/// availability or by a device-capability probe — without touching call sites.
@MainActor
protocol CabinetRenderer {
    /// A stable identity for logging / the Gate-1 packet.
    var rendererName: String { get }

    /// The SwiftUI surface that draws the cabinet for the given shelf. The
    /// `harness` is injected so the perf HUD measures the live scene.
    func makeView(shelf: [Release], harness: PerfHarness) -> AnyView
}

/// Chooses the live renderer. Real-time RealityKit when `RealityView` is
/// available (iOS 18+), otherwise the pseudo-3D fallback. The simulator on
/// this machine runs a recent iOS, so the RealityKit path is exercised.
enum CabinetRendererFactory {
    @MainActor
    static func makeDefault() -> CabinetRenderer {
        if #available(iOS 18.0, *) {
            return RealityKitCabinetRenderer()
        } else {
            return PseudoThreeDCabinetRenderer()
        }
    }
}

/// Spike-1 NO-GO fallback placeholder. Intentionally minimal — the full
/// flat-preview Home is out of scope for the de-risk spike; this only proves the
/// seam swaps cleanly and gives <iOS 18 devices a non-crashing surface.
struct PseudoThreeDCabinetRenderer: CabinetRenderer {
    let rendererName = "PseudoThreeD (fallback)"

    func makeView(shelf: [Release], harness: PerfHarness) -> AnyView {
        AnyView(
            VStack(spacing: 12) {
                Text("Pseudo-3D fallback")
                    .font(Voice.serif(22))
                    .foregroundStyle(Ink.primary)
                Text("RealityView requires iOS 18+. The flat-preview cabinet renders here on older devices.")
                    .font(.callout)
                    .foregroundStyle(Ink.soft)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Ink.paper)
        )
    }
}
