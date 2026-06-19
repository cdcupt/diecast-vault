import SwiftUI
import DiecastVaultCore

/// Spike-1 host screen: the real-time 3D cabinet (the single dark surface),
/// framed by light chrome, with a live FPS / memory / thermal HUD overlaid for
/// the de-risk measurement. Reached from the Cabinet tab via a "3D cabinet
/// (Spike-1)" entry.
struct Spike1CabinetView: View {
    /// A 24-niche shelf (top of the PRD's 12–24 range) to stress the scene.
    private let shelf = Release.spikeShelf
    @StateObject private var harness = PerfHarness(window: 6)
    @State private var renderer: CabinetRenderer = CabinetRendererFactory.makeDefault()

    var body: some View {
        ZStack {
            // The dark stage fills the screen; light chrome is the safe-area band.
            Color(Palette.stage0).ignoresSafeArea()

            renderer.makeView(
                shelf: shelf,
                style: .museum,            // the dark stress scene reads best on the dark case
                modelURL: SampleModel.url,
                harness: harness,
                onSelect: { _ in }         // perf scene: taps are inert
            )

            VStack {
                perfHUD
                Spacer()
                caption
            }
            .padding(16)
        }
        .navigationTitle("3D Cabinet")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Ink.paper, for: .navigationBar)
    }

    /// Live readout on the stage's tungsten-rim control material.
    private var perfHUD: some View {
        let s = harness.sample
        return VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Circle()
                    .fill(s.finished ? Ink.ok : Ink.tungsten)
                    .frame(width: 8, height: 8)
                Text(s.finished ? "PERF SAMPLE COMPLETE" : "SAMPLING…")
                    .font(Voice.mono(10, weight: .semibold))
                    .tracking(1.5)
                    .foregroundStyle(.white.opacity(0.7))
            }
            Text(String(format: "fps  %.0f  ·  avg %.0f  ·  min %.0f",
                        s.instantFPS, s.avgFPS, s.minFPS))
                .font(Voice.mono(13, weight: .medium))
                .foregroundStyle(.white)
            Text(String(format: "mem %.0f MB  ·  thermal %@  ·  %.1fs",
                        s.residentMB, s.thermal, s.elapsed))
                .font(Voice.mono(11))
                .foregroundStyle(.white.opacity(0.75))
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(Palette.stage1).opacity(0.85))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color(Palette.stageRim).opacity(0.5), lineWidth: 1)
                )
        )
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var caption: some View {
        Text("Drag to orbit (clamped) · tilt for gyro parallax · \(renderer.rendererName)")
            .font(Voice.mono(10))
            .foregroundStyle(.white.opacity(0.55))
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
    }
}

extension Release {
    /// A 24-niche shelf for the Spike-1 stress scene: ~half lit so the
    /// light-as-state contrast and the per-niche lights are both exercised.
    static let spikeShelf: [Release] = {
        let names = [
            "Toyota GR Supra", "Nissan Skyline GT-R", "Mazda RX-7 FD3S",
            "Honda Civic Type R", "Porsche 911 GT3 RS", "Subaru Impreza WRX",
            "Lamborghini Huracán", "Ford Mustang GT", "BMW M3 E46",
            "Mercedes 190E", "Audi RS6 Avant", "Toyota AE86",
            "Mitsubishi Lancer Evo", "Lexus LFA", "Ferrari F40",
            "McLaren F1", "Datsun 240Z", "Acura NSX",
            "Chevrolet Corvette C8", "Dodge Challenger", "Volkswagen Golf GTI",
            "Alpine A110", "Pagani Huayra", "Koenigsegg Jesko"
        ]
        return names.enumerated().map { index, name in
            let drive: Drive = index % 2 == 0 ? .lhd : .rhd
            let number = String(format: "MGT%05d", 100 + index * 13)
            return Release(
                key: .init(mgtNumber: number, drive: drive),
                name: name,
                edition: String(format: "%04d/202%d", (index * 37) % 2000, index % 4),
                isLit: index % 5 != 2   // ~20 of 24 lit
            )
        }
    }()
}
