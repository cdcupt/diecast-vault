import SwiftUI
import DiecastVaultCore

/// Catalog tab — browse / search the Mini GT catalog and pick a release's drive
/// side. Search matches number / name / livery; the tapped result expands in
/// place to reveal the teal-L / amber-R drive toggle (drive is required — it is
/// part of the key). Choosing a drive continues to the Release detail.
struct CatalogView: View {
    private let index = CatalogIndex()

    @State private var query = ""
    @State private var expanded: String?          // mgtNumber of the open row
    @State private var chosenDrive: [String: Drive] = [:]

    private var hits: [CatalogIndex.Hit] { index.search(query) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Lightbar(label: "Catalog")

                if hits.isEmpty {
                    emptyState
                } else {
                    ForEach(hits) { hit in
                        CatalogRow(
                            hit: hit,
                            isExpanded: expanded == hit.mgtNumber,
                            chosenDrive: chosenDrive[hit.mgtNumber],
                            onTap: { toggle(hit) },
                            onChooseDrive: { chosenDrive[hit.mgtNumber] = $0 },
                            release: { drive in index.release(forNumber: hit.mgtNumber, drive: drive) }
                        )
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .background(Ink.paper)
        .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Number, name, or livery")
        .autocorrectionDisabled()
        .textInputAutocapitalization(.never)
        .navigationTitle("Catalog")
        .navigationBarTitleDisplayMode(.large)
        .navigationDestination(for: Release.self) { release in
            ReleaseDetailView(release: release)
        }
    }

    private func toggle(_ hit: CatalogIndex.Hit) {
        withAnimation(.snappy(duration: 0.22)) {
            expanded = expanded == hit.mgtNumber ? nil : hit.mgtNumber
            // Default the drive to the only one offered, so single-drive picks are one tap.
            if expanded == hit.mgtNumber, chosenDrive[hit.mgtNumber] == nil, hit.drives.count == 1 {
                chosenDrive[hit.mgtNumber] = hit.drives.first
            }
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("No match for “\(query)”")
                .font(Voice.serif(20))
                .foregroundStyle(Ink.primary)
            Text("Try the catalog number or the livery.")
                .font(.callout)
                .foregroundStyle(Ink.soft)
        }
        .padding(.top, 24)
    }
}

/// One catalog result. Collapsed: a mono placard + serif name row. Expanded: the
/// designed drive toggle + a "Continue with [drive]" CTA disabled until a drive
/// is chosen.
private struct CatalogRow: View {
    let hit: CatalogIndex.Hit
    let isExpanded: Bool
    let chosenDrive: Drive?
    let onTap: () -> Void
    let onChooseDrive: (Drive) -> Void
    let release: (Drive) -> Release

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: onTap) { header }
                .buttonStyle(.plain)

            if isExpanded {
                VStack(alignment: .leading, spacing: 12) {
                    Text("CHOOSE DRIVE")
                        .font(Voice.mono(10, weight: .semibold))
                        .tracking(1.5)
                        .foregroundStyle(Ink.muted)

                    DriveToggle(drives: hit.drives, selection: chosenDrive, onChoose: onChooseDrive)

                    continueCTA
                }
                .padding(.top, 12)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(14)
        .background(Ink.cellSurface)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(isExpanded ? Ink.tungsten : Ink.line, lineWidth: isExpanded ? 1.5 : 1)
        )
    }

    private var header: some View {
        HStack(spacing: 12) {
            CatalogPlacard(mgtNumber: hit.mgtNumber)
            VStack(alignment: .leading, spacing: 2) {
                Text(hit.mgtNumber)
                    .font(Voice.mono(10))
                    .foregroundStyle(Ink.steel)
                Text(hit.name)
                    .font(Voice.serif(16))
                    .foregroundStyle(Ink.primary)
                if let edition = hit.edition {
                    Text(edition)
                        .font(Voice.mono(10))
                        .foregroundStyle(Ink.muted)
                }
            }
            Spacer()
            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Ink.muted)
        }
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var continueCTA: some View {
        if let drive = chosenDrive {
            NavigationLink(value: release(drive)) {
                HStack {
                    Spacer()
                    Text("Continue with \(drive == .lhd ? "LHD" : "RHD")")
                        .font(.system(size: 14, weight: .semibold))
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                    Spacer()
                }
                .foregroundStyle(.white)
                .padding(.vertical, 12)
                .background(Ink.tungsten, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
            }
            .buttonStyle(.plain)
        } else {
            HStack {
                Spacer()
                Text("Choose a drive to continue")
                    .font(.system(size: 14, weight: .semibold))
                Spacer()
            }
            .foregroundStyle(Ink.muted)
            .padding(.vertical, 12)
            .background(Ink.cellRecess, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
        }
    }
}

#Preview {
    NavigationStack { CatalogView() }
        .tint(Ink.tungsten)
}
