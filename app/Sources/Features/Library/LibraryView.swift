import SwiftUI
import DiecastVaultCore

/// Library tab — the community library of shared scans (DESIGN Flow F / mockup
/// #s-community). Deduped by `(number, drive)`: one canonical scan per release,
/// each carrying a "scanned by @handle" provenance credit — with a "· you" suffix
/// on the user's own opted-in shares. Browse + upload over a live backend land in
/// v1.1; the list here reads the local `ContributionStore` (sample + freshly
/// queued shares), so the credit lines are honest, not mocked HTML.
struct LibraryView: View {
    @EnvironmentObject private var contributionStore: ContributionStore

    /// Newest-shared first (a fresh queue from the share prompt lands on top).
    private var items: [CommunityContribution] {
        contributionStore.contributions.reversed()
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                vaultBar
                shelfLabel
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 12),
                                    GridItem(.flexible(), spacing: 12)], spacing: 12) {
                    ForEach(items) { item in
                        CommunityCard(item: item)
                    }
                }
                Text("library.stub.note")
                    .font(.caption2)
                    .foregroundStyle(Ink.muted)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .multilineTextAlignment(.center)
                    .padding(.top, 4)
            }
            .padding(.horizontal, 18)
            .padding(.top, 8)
            .padding(.bottom, 28)
        }
        .background(Ink.paper)
        .navigationTitle(Text("tab.library"))
        .navigationBarTitleDisplayMode(.large)
    }

    /// The steel "Community Vault" lightbar — the system/community identity (steel),
    /// echoing the mockup's deduped-by-(no.,drive) telemetry.
    private var vaultBar: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("library.communityVault")
                .font(Voice.serif(18))
                .foregroundStyle(.white)
            Text("\(contributionStore.contributions.count) SCANS · 1 CANONICAL / (NO.,DRIVE)")
                .font(Voice.mono(10, weight: .medium))
                .foregroundStyle(.white.opacity(0.7))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            LinearGradient(colors: [Color(Palette.steel), Color(Palette.stage1)],
                           startPoint: .top, endPoint: .bottom),
            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
        )
    }

    private var shelfLabel: some View {
        Text("library.recentlyAdded")
            .textCase(.uppercase)
            .font(Voice.mono(10, weight: .semibold))
            .tracking(1.4)
            .foregroundStyle(Ink.muted)
    }
}

/// One community library item: a lit niche, a "Comm" provenance chip, and the
/// "scanned by @handle · you" credit line (mockup #s-community placard).
struct CommunityCard: View {
    let item: CommunityContribution

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            niche
            placard
        }
        .background(Ink.cellSurface)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Ink.line, lineWidth: 1))
        .shadow(color: Color(Palette.ink).opacity(0.06), radius: 12, y: 8)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(item.name), scanned by \(item.creditHandle)")
    }

    private var niche: some View {
        ZStack {
            RadialGradient(colors: [Ink.tungstenGlow, .clear],
                           center: .init(x: 0.5, y: 1.1), startRadius: 0, endRadius: 120)
                .background(Ink.cellSurface)
            DiecastGlyph().frame(width: 110, height: 64)
            VStack {
                HStack {
                    Spacer()
                    Text("detail.tag.community")
                        .textCase(.uppercase)
                        .font(Voice.mono(8, weight: .heavy))
                        .foregroundStyle(Ink.steel)
                        .padding(.horizontal, 6).padding(.vertical, 3)
                        .background(Ink.steelSoft, in: Capsule())
                }
                Spacer()
            }
            .padding(8)
        }
        .frame(height: 100)
    }

    private var placard: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(item.name)
                .font(Voice.serif(15))
                .foregroundStyle(Ink.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            HStack(spacing: 5) {
                Text(item.mgtNumber)
                    .font(Voice.mono(9))
                    .foregroundStyle(Ink.steel)
                DriveDecal(drive: item.drive).scaleEffect(0.6).frame(width: 16, height: 16)
                Spacer(minLength: 0)
                Text(verbatim: "↓ \(item.downloads)")
                    .font(Voice.mono(9))
                    .foregroundStyle(Ink.muted)
            }
            credit
        }
        .padding(.horizontal, 10).padding(.vertical, 9)
    }

    /// "scanned by @handle" — appends a localized "· you" on the user's own shares.
    private var credit: some View {
        HStack(spacing: 0) {
            Text("community.scannedBy \(item.creditHandle)")
                .font(Voice.mono(9))
                .foregroundStyle(item.isMine ? Ink.tungstenDeep : Ink.muted)
            if item.isMine {
                Text(verbatim: " · ")
                    .font(Voice.mono(9))
                    .foregroundStyle(Ink.tungstenDeep)
                Text("community.you")
                    .font(Voice.mono(9, weight: .semibold))
                    .foregroundStyle(Ink.tungstenDeep)
            }
        }
        .lineLimit(1)
        .minimumScaleFactor(0.7)
    }
}

#Preview {
    NavigationStack { LibraryView() }
        .environmentObject(ContributionStore())
        .tint(Ink.tungsten)
}
