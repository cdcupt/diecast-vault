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

    /// The SwiftUI surface that draws the cabinet for the given shelf in the given
    /// `style`. `modelURL` is the bundled full USDZ used by the LOD hero niche;
    /// `harness` is injected so the perf HUD can measure the live scene; `onSelect`
    /// routes a tapped niche by light-as-state (lit → detail, matte → catalog).
    func makeView(
        shelf: [Release],
        style: CabinetStyle,
        modelURL: URL?,
        harness: PerfHarness,
        onSelect: @escaping (Release) -> Void
    ) -> AnyView
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

    func makeView(
        shelf: [Release],
        style: CabinetStyle,
        modelURL: URL?,
        harness: PerfHarness,
        onSelect: @escaping (Release) -> Void
    ) -> AnyView {
        // Flat-preview grid of niches so <iOS 18 devices still get a working,
        // tappable, light-as-state Home (no RealityView). The 2D CabinetCell
        // carries the same lit/matte look + drive decal + mono placard.
        AnyView(PseudoThreeDCabinet(shelf: shelf, onSelect: onSelect))
    }
}

/// The <iOS 18 fallback Home: a 2-up grid of `CabinetCell`s that reuses the same
/// light-as-state styling and routes taps exactly like the 3D cabinet.
private struct PseudoThreeDCabinet: View {
    let shelf: [Release]
    let onSelect: (Release) -> Void

    private let columns = [
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14)
    ]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 14) {
                ForEach(shelf) { release in
                    Button { onSelect(release) } label: {
                        CabinetCell(release: release)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(18)
        }
        .background(Ink.paper)
    }
}
