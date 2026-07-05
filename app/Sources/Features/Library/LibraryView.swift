import SwiftUI
import DiecastVaultCore

/// Library tab — the community library of shared scans (DESIGN Flow F / mockup
/// #s-community). Deduped by `(number, drive)`: one canonical scan per release,
/// each carrying a "scanned by @handle" provenance credit — with a "· you" suffix
/// on the user's own opted-in shares. Browse + upload over a live backend land in
/// v1.1; the list here reads the local `ContributionStore` (sample + freshly
/// queued shares), so the credit lines are honest, not mocked HTML.
struct LibraryView: View {
    /// Deterministic sim override so the offline state is screenshot-able without
    /// toggling the device radios. Defaults off → uses the live NWPathMonitor.
    var forceOffline: Bool = false

    @EnvironmentObject private var contributionStore: ContributionStore
    @StateObject private var reachability = Reachability()

    /// The live library needs the network; when offline it is unavailable and only
    /// the cached shelf (the user's own opted-in shares) is shown.
    private var isOffline: Bool { forceOffline || !reachability.isOnline }

    /// Newest-shared first (a fresh queue from the share prompt lands on top).
    private var items: [CommunityContribution] {
        contributionStore.contributions.reversed()
    }

    /// Offline shows only what's cached on this device — the user's own shares.
    private var visibleItems: [CommunityContribution] {
        isOffline ? items.filter(\.isMine) : items
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                vaultBar
                if isOffline { offlineBanner }

                if visibleItems.isEmpty {
                    isOffline ? AnyView(offlineEmpty) : AnyView(emptyState)
                } else {
                    shelfLabel
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 12),
                                        GridItem(.flexible(), spacing: 12)], spacing: 12) {
                        ForEach(visibleItems) { item in
                            CommunityCard(item: item)
                        }
                    }
                    Text(isOffline ? "offline.cached.note" : "library.stub.note")
                        .font(.caption2)
                        .foregroundStyle(Ink.muted)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .multilineTextAlignment(.center)
                        .padding(.top, 4)
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 8)
            .padding(.bottom, 28)
        }
        .background(Ink.paper)
        .navigationTitle(Text("tab.library"))
        .navigationBarTitleDisplayMode(.large)
    }

    // MARK: Offline + empty states (authored, never dead-grey)

    /// The offline banner — steel, on-brand: the cached shelf still works; the live
    /// library is dimmed until reconnect. Carries a mono OFFLINE chip.
    private var offlineBanner: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "wifi.slash")
                .font(.system(size: 18))
                .foregroundStyle(Ink.steel)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Text("offline.banner.title")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Ink.primary)
                    Text("offline.badge")
                        .font(Voice.mono(8, weight: .heavy))
                        .tracking(0.8)
                        .foregroundStyle(Ink.steel)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Ink.steelSoft, in: Capsule())
                }
                Text("offline.banner.body")
                    .font(.footnote)
                    .foregroundStyle(Ink.soft)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Ink.steelSoft.opacity(0.6), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Ink.steel.opacity(0.3), lineWidth: 1)
        )
    }

    /// Empty community library (online, nothing shared yet) — authored invite.
    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "cloud")
                .font(.system(size: 34, weight: .light))
                .foregroundStyle(Ink.steel)
            Text("library.empty.headline")
                .font(Voice.serif(22))
                .foregroundStyle(Ink.primary)
            Text("library.empty.blurb")
                .font(.callout)
                .foregroundStyle(Ink.soft)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 300)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 36)
    }

    /// Offline with no cached personal shares — still authored, points at the cache.
    private var offlineEmpty: some View {
        VStack(spacing: 12) {
            Image(systemName: "tray")
                .font(.system(size: 34, weight: .light))
                .foregroundStyle(Ink.steel)
            Text("offline.cached.note")
                .font(.callout)
                .foregroundStyle(Ink.soft)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 300)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 36)
    }

    /// The steel "Community Vault" lightbar — the system/community identity (steel),
    /// echoing the mockup's deduped-by-(no.,drive) telemetry.
    private var vaultBar: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("library.communityVault")
                .font(Voice.serif(18))
                .foregroundStyle(.white)
            Text("library.vault.tele \(contributionStore.contributions.count)")
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
        .accessibilityLabel(Text("community.sharedBy.a11y \(item.name) \(item.creditHandle)"))
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
                // No download counter: the bundled starter library has no live
                // backend, and fabricated telemetry is exactly the content class
                // App Review rejected twice (2.1a).
            }
            credit
        }
        .padding(.horizontal, 10).padding(.vertical, 9)
    }

    /// "shared by @handle" — appends a localized "· you" on the user's own shares.
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
