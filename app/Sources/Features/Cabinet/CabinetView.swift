import SwiftUI
import SwiftData
import DiecastVaultCore

/// Home tab — the lit display cabinet. Slice 2 renders the user's PERSISTED
/// collection (SwiftData, seeded on first run) as a grid of niches; picking a
/// release in the Catalog adds a lit niche here. Tapping a niche opens the shared
/// Release detail. The real-time RealityKit cabinet remains reachable (Spike-1).
struct CabinetView: View {
    @Query(sort: \OwnedModel.acquiredAt, order: .reverse) private var owned: [OwnedModel]

    private let columns = [
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14)
    ]

    /// Project persisted rows to display releases (LIT when a model is bonded).
    private var shelf: [Release] {
        owned.map { row in
            Release(
                key: CatalogKey(mgtNumber: row.mgtNumber, drive: row.drive),
                name: displayName(for: row),
                edition: row.editionNo,
                isLit: row.hasModel
            )
        }
    }

    private var litCount: Int { shelf.filter(\.isLit).count }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Lightbar(label: "cabinet.lightbar")

                // Scale-contrast hierarchy: a big lit count towering over mono meta.
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("\(litCount)")
                        .font(Voice.serif(48))
                        .foregroundStyle(Ink.primary)
                    Text("cabinet.litCount \(shelf.count)")
                        .font(Voice.mono(13))
                        .foregroundStyle(Ink.muted)
                    Spacer()
                }

                NavigationLink {
                    Spike1CabinetView()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "cube.transparent")
                        Text("cabinet.open3D")
                            .font(Voice.mono(12, weight: .semibold))
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Ink.tungsten))
                }
                .buttonStyle(.plain)

                if shelf.isEmpty {
                    emptyState
                } else {
                    LazyVGrid(columns: columns, spacing: 14) {
                        ForEach(shelf) { release in
                            NavigationLink(value: release) {
                                CabinetCell(release: release)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .background(Ink.paper)
        .navigationTitle(Text("tab.cabinet"))
        .navigationBarTitleDisplayMode(.large)
        .navigationDestination(for: Release.self) { release in
            ReleaseDetailView(release: release)
        }
    }

    /// Prefer the catalog's proper name; fall back to the stored number.
    private func displayName(for row: OwnedModel) -> String {
        Release.catalogSample.first { $0.mgtNumber == row.mgtNumber }?.name ?? row.mgtNumber
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("cabinet.empty.title")
                .font(Voice.serif(22))
                .foregroundStyle(Ink.primary)
            Text("cabinet.empty.blurb")
                .font(.callout)
                .foregroundStyle(Ink.soft)
        }
        .padding(.top, 24)
    }
}

#Preview {
    NavigationStack { CabinetView() }
        .modelContainer(PersistenceController.inMemory())
        .tint(Ink.tungsten)
}
