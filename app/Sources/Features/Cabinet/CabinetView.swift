import SwiftUI
import SwiftData
import DiecastVaultCore

/// Home tab — the lit display cabinet, now the real-time RealityKit 3D vitrine
/// (Slice 4). The niches reflect the user's PERSISTED collection: owned models =
/// LIT niches showing their car; known-but-unscanned catalog releases = MATTE
/// recesses; the rest dark/empty. Light = state, in 3D.
///
/// Tapping a LIT niche opens the shared Release detail; a MATTE niche routes to
/// the Catalog/pick path. The lightbar header carries the localized count and a
/// STYLE chip into the "Choose your cabinet" picker. Styles are cosmetic, live,
/// and persisted per-user. Non-RealityView devices get the graceful 2D fallback.
struct CabinetView: View {
    @Query(sort: \OwnedModel.acquiredAt, order: .reverse) private var owned: [OwnedModel]
    @EnvironmentObject private var stylePreference: CabinetStylePreference
    @EnvironmentObject private var contributionStore: ContributionStore

    /// Cross-tab pick path (matte niche → Catalog). A simple binding the shell
    /// can observe later; for now the detail covers lit niches and matte niches
    /// open the catalog entry for that release inline.
    @State private var route: Release?
    @State private var showStylePicker = false
    @State private var showScan = false

    /// The perf harness HUD is debug-only now (the cabinet IS the home).
    /// `DV_PERF_HUD=1` overlays the live FPS/mem/thermal readout for measurement.
    private static var showsPerfHUD: Bool {
        ProcessInfo.processInfo.environment["DV_PERF_HUD"] == "1"
    }

    @StateObject private var harness = PerfHarness(window: 6)
    @State private var renderer: CabinetRenderer = CabinetRendererFactory.makeDefault()

    /// Owned rows projected to LIT releases (newest first, matching the @Query).
    private var ownedReleases: [Release] {
        owned.map { row in
            Release(
                key: CatalogKey(mgtNumber: row.mgtNumber, drive: row.drive),
                name: displayName(for: row),
                edition: row.editionNo,
                isLit: row.hasModel
            )
        }
    }

    /// The shelf the cabinet renders: owned LIT niches first, then the
    /// known-but-unscanned catalog releases (MATTE recesses) the user does not
    /// own — so the cabinet reads as a partly-filled case, light-as-state.
    private var shelf: [Release] {
        let ownedIDs = Set(ownedReleases.map(\.id))
        let known = Release.catalogSample
            .filter { !ownedIDs.contains($0.id) }
            .map { Release(key: $0.key, name: $0.name, edition: $0.edition, isLit: false) }
            .sorted { $0.mgtNumber < $1.mgtNumber }
        return ownedReleases + known
    }

    private var litCount: Int { ownedReleases.filter(\.isLit).count }

    var body: some View {
        ZStack {
            Color(stylePreference.style.theme.stageBackdrop).ignoresSafeArea()

            // The real-time cabinet fills the screen; a style swap cross-dissolves
            // it (opacity transition only — no layout-bound motion).
            renderer.makeView(
                shelf: shelf,
                style: stylePreference.style,
                modelURL: SampleModel.url,
                harness: harness,
                onSelect: handleSelect
            )
            .id(stylePreference.style)   // rebuild the scene on style change
            .transition(.opacity)

            // The chrome overlay (lightbar header + empty-invite card + perf HUD)
            // sits ON TOP of the cabinet. Its passive parts — opaque card
            // backgrounds, the count line, Spacers, the HUD — must NOT swallow
            // touches meant for the 3D cabinet below, or the RealityView never
            // sees a tap/drag at all (the root cause of both dead gestures). Each
            // passive piece carries `.allowsHitTesting(false)` so input falls
            // through to the cabinet; only the genuine controls (STYLE chip,
            // empty-invite buttons) stay hit-testable in their own right.
            VStack(spacing: 0) {
                header
                Spacer()
                if litCount == 0 { emptyInvite }
                Spacer()
                if Self.showsPerfHUD { perfHUD.allowsHitTesting(false) }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
        }
        .navigationTitle(Text("tab.cabinet"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showScan = true
                } label: {
                    Image(systemName: "plus")
                        .foregroundStyle(Ink.tungsten)
                }
                .accessibilityLabel(Text("addcar.title"))
            }
        }
        .navigationDestination(item: $route) { release in
            ReleaseDetailView(release: release)
        }
        .sheet(isPresented: $showStylePicker) {
            CabinetStylePickerView()
                .environmentObject(stylePreference)
        }
        .sheet(isPresented: $showScan) {
            AddCarFlowView()
                .environmentObject(contributionStore)
        }
    }

    // MARK: Lightbar header (count + STYLE chip)

    private var header: some View {
        let onLight = stylePreference.style.isDarkCase
        return HStack(alignment: .center, spacing: 12) {
            // The signature lit bulb + localized count line — purely informational,
            // so it must not block touches reaching the cabinet underneath.
            HStack(spacing: 10) {
                Circle()
                    .fill(Ink.tungsten)
                    .frame(width: 9, height: 9)
                    .overlay(Circle().stroke(Ink.tungstenGlow, lineWidth: 4))
                VStack(alignment: .leading, spacing: 1) {
                    Text("cabinet.lightbar")
                        .textCase(.uppercase)
                        .font(Voice.mono(10, weight: .semibold))
                        .tracking(1.6)
                        .foregroundStyle(onLight ? Color.white.opacity(0.85) : Ink.steel)
                    Text("cabinet.litCount.full \(litCount) \(shelf.count)")
                        .font(Voice.mono(11, weight: .medium))
                        .foregroundStyle(onLight ? Color.white.opacity(0.7) : Ink.soft)
                }
            }
            .allowsHitTesting(false)

            Spacer()

            // The STYLE chip is the ONE interactive control here — it keeps hit
            // testing so a tap opens the picker.
            styleChip(onLight: onLight)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(onLight ? Color(Palette.stage1).opacity(0.82) : Ink.paper.opacity(0.92))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(onLight ? Color(Palette.stageRim).opacity(0.4) : Ink.line, lineWidth: 1)
                )
                // The card backdrop is decorative; let touches pass through it so
                // a drag/tap starting on the header band still reaches the cabinet
                // everywhere except the STYLE chip itself.
                .allowsHitTesting(false)
        )
    }

    /// The mono STYLE chip on the right of the lightbar → the picker (DESIGN §4.2).
    private func styleChip(onLight: Bool) -> some View {
        Button {
            showStylePicker = true
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "square.stack.3d.up.fill")
                    .font(.system(size: 11, weight: .semibold))
                Text("cabinet.style.chip")
                    .textCase(.uppercase)
                    .font(Voice.mono(9, weight: .heavy))
                    .tracking(1.2)
            }
            .foregroundStyle(onLight ? Color(Palette.tungstenGlow) : Ink.tungstenDeep)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                Capsule().fill(onLight ? Color(Palette.stage0).opacity(0.7) : Color(Palette.tungstenGlow).opacity(0.6))
            )
            .overlay(
                Capsule().stroke(Ink.tungsten.opacity(onLight ? 0.5 : 0.4), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("cabinet.style.chip"))
        .accessibilityValue(Text(stylePreference.style.nameKey))
    }

    // MARK: Empty invite (zero lit niches)

    /// Authored empty state: when nothing is owned the cabinet is a wall of MATTE
    /// recesses (the 3D scene still renders, dark but alive), and a tungsten invite
    /// card floats over it pointing to the two ways to light the first niche. Never
    /// a dead-grey screen — the dark cabinet IS the message, with a way forward.
    private var emptyInvite: some View {
        let onLight = stylePreference.style.isDarkCase
        return VStack(spacing: 14) {
            Group {
                Image(systemName: "lightbulb.slash")
                    .font(.system(size: 34, weight: .light))
                    .foregroundStyle(Ink.tungsten)
                VStack(spacing: 6) {
                    Text("cabinet.empty.headline")
                        .font(Voice.serif(24))
                        .foregroundStyle(onLight ? .white : Ink.primary)
                        .multilineTextAlignment(.center)
                    Text("cabinet.empty.invite")
                        .font(.callout)
                        .foregroundStyle(onLight ? Color.white.opacity(0.72) : Ink.soft)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 280)
                }
            }
            // Icon + copy are informational — pass touches through so only the two
            // CTAs below capture taps.
            .allowsHitTesting(false)
            HStack(spacing: 10) {
                Button { showScan = true } label: {
                    PrimaryCTALabel(title: "cabinet.empty.add", systemImage: "plus")
                        .fixedSize()
                }
                .buttonStyle(.plain)
                Button { route = Release.catalogSample.first { !$0.isLit } } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "magnifyingglass")
                        Text("cabinet.empty.pick").font(.system(size: 15, weight: .semibold))
                    }
                    .foregroundStyle(Ink.tungstenDeep)
                    .padding(.horizontal, 16).padding(.vertical, 14)
                    .overlay(
                        RoundedRectangle(cornerRadius: 11, style: .continuous)
                            .stroke(Ink.tungsten, lineWidth: 1.5)
                    )
                    .background(
                        RoundedRectangle(cornerRadius: 11, style: .continuous)
                            .fill(onLight ? Color(Palette.tungstenGlow).opacity(0.85) : Ink.paper.opacity(0.9))
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(onLight ? Color(Palette.stage1).opacity(0.78) : Ink.paper.opacity(0.92))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Ink.tungsten.opacity(0.45), lineWidth: 1)
                )
                // Decorative card surface — don't capture touches, so a drag/tap
                // on the empty-state padding still reaches the cabinet behind it.
                .allowsHitTesting(false)
        )
        .shadow(color: Color(Palette.ink).opacity(0.18), radius: 22, y: 12)
        .padding(.horizontal, 8)
        .accessibilityElement(children: .contain)
    }

    // MARK: Routing

    /// Light-as-state routing: a LIT niche opens the shared Release detail; a
    /// MATTE niche opens the same detail in its pick state (the catalog path).
    private func handleSelect(_ release: Release) {
        route = release
    }

    // MARK: Perf HUD (debug-only)

    private var perfHUD: some View {
        let s = harness.sample
        return VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Circle().fill(s.finished ? Ink.ok : Ink.tungsten).frame(width: 8, height: 8)
                Text(s.finished ? "PERF SAMPLE COMPLETE" : "SAMPLING…")
                    .font(Voice.mono(10, weight: .semibold)).tracking(1.5)
                    .foregroundStyle(.white.opacity(0.7))
            }
            Text(String(format: "fps %.0f · avg %.0f · min %.0f", s.instantFPS, s.avgFPS, s.minFPS))
                .font(Voice.mono(12, weight: .medium)).foregroundStyle(.white)
            Text(String(format: "mem %.0f MB · thermal %@ · %.1fs · %@",
                        s.residentMB, s.thermal, s.elapsed, renderer.rendererName))
                .font(Voice.mono(10)).foregroundStyle(.white.opacity(0.7))
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(Palette.stage1).opacity(0.85))
                .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color(Palette.stageRim).opacity(0.5), lineWidth: 1))
        )
        .padding(.bottom, 12)
    }

    /// Prefer the catalog's proper name; fall back to the stored number.
    private func displayName(for row: OwnedModel) -> String {
        Release.catalogSample.first { $0.mgtNumber == row.mgtNumber }?.name ?? row.mgtNumber
    }
}

#Preview {
    NavigationStack { CabinetView() }
        .modelContainer(PersistenceController.inMemory())
        .environmentObject(CabinetStylePreference())
        .environmentObject(ContributionStore())
        .tint(Ink.tungsten)
}
