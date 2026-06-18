import SwiftUI
import DiecastVaultCore

/// Home tab — the lit display cabinet. Slice 1 renders a simple placeholder grid
/// of niches driven by `Release.sampleShelf`; the real-time RealityKit cabinet
/// arrives in Spike-1.
struct CabinetView: View {
    private let shelf = Release.sampleShelf

    private let columns = [
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14)
    ]

    private var litCount: Int { shelf.filter(\.isLit).count }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Lightbar(label: "The Cabinet")

                // Scale-contrast hierarchy: a big lit count towering over mono meta.
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("\(litCount)")
                        .font(Voice.serif(48))
                        .foregroundStyle(Ink.primary)
                    Text("/ \(shelf.count) lit")
                        .font(Voice.mono(13))
                        .foregroundStyle(Ink.muted)
                    Spacer()
                }

                LazyVGrid(columns: columns, spacing: 14) {
                    ForEach(shelf) { release in
                        NavigationLink(value: release) {
                            CabinetCell(release: release)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .background(Ink.paper)
        .navigationTitle("Cabinet")
        .navigationBarTitleDisplayMode(.large)
        .navigationDestination(for: Release.self) { release in
            ReleasePlaceholderView(release: release)
        }
    }
}

/// Minimal release detail stand-in (full detail + lift-to-3D land in later slices).
private struct ReleasePlaceholderView: View {
    let release: Release

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Lightbar(label: "Release")
            Text(release.name)
                .font(Voice.serif(28))
                .foregroundStyle(Ink.primary)
            HStack(spacing: 10) {
                CatalogPlacard(mgtNumber: release.mgtNumber)
                Text(release.mgtNumber)
                    .font(Voice.mono(15))
                    .foregroundStyle(Ink.steel)
                DriveDecal(drive: release.drive)
            }
            if let edition = release.edition {
                Text(edition)
                    .font(Voice.mono(13))
                    .foregroundStyle(Ink.muted)
            }
            Text(release.isLit ? "Scan present — 3D viewer arrives in Spike-1." : "No scan yet — pick or scan it.")
                .font(.callout)
                .foregroundStyle(Ink.soft)
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(Ink.paper)
        .navigationTitle(release.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack { CabinetView() }
        .tint(Ink.tungsten)
}
