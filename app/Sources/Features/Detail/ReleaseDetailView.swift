import SwiftUI
import SwiftData
import DiecastVaultCore

/// Release detail (DESIGN §4.5 / §4.5b). Carries the `Model | Real Car`
/// segmented control: **Model** shows the car, its metadata, and a "View in 3D"
/// CTA (lifting into the dark stage); **Real Car** is the light reference profile
/// (stubbed locally in slice 2). The three scan states are expressed through
/// light, not greyed buttons.
struct ReleaseDetailView: View {
    let release: Release

    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var contributionStore: ContributionStore
    @Query private var owned: [OwnedModel]

    @State private var face: DetailFace
    /// Presents the guided scan flow from the Pro gap-nudge ("Be the first…").
    @State private var showScan = false
    /// Set when the non-Pro "Notify me when it's scanned" path is taken (stubbed —
    /// no push backend in v1.1; surfaces a confirmation toast).
    @State private var notifyInterest = false

    /// Slice 2 runs the simulator as a "Pro" device so the tungsten contribution
    /// invite is exercised; capability detection arrives with the capture pipeline.
    private let isProDevice = true

    init(release: Release, initialFace: DetailFace = .model) {
        self.release = release
        _face = State(initialValue: initialFace)
        let id = release.id
        _owned = Query(filter: #Predicate<OwnedModel> { $0.stableID == id })
    }

    private var isOwned: Bool { !owned.isEmpty }
    private var scanState: ScanState { release.scanState(isProDevice: isProDevice) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Picker("View", selection: $face) {
                    ForEach(DetailFace.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)

                switch face {
                case .model:
                    ModelFaceView(
                        release: release,
                        scanState: scanState,
                        isOwned: isOwned,
                        onPick: pickToShelf,
                        onScanFirst: { showScan = true },
                        onNotify: { notifyInterest = true }
                    )
                case .realCar:
                    RealCarFaceView(release: release)
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 8)
            .padding(.bottom, 28)
        }
        .background(Ink.paper)
        .navigationTitle(release.name)
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: ViewerRoute.self) { route in
            ModelViewerView(release: route.release)
        }
        .sheet(isPresented: $showScan) {
            // Launch the guided scan pre-bonded to THIS release so a fresh world-
            // first lights the right niche. Re-inject the store across the sheet.
            ScanFlowView(prefillKey: release.key)
                .environmentObject(contributionStore)
        }
        .overlay(alignment: .bottom) {
            if notifyInterest { notifyToast }
        }
    }

    /// Calm confirmation for the non-Pro / "notify me" gap-nudge path. Auto-hides.
    private var notifyToast: some View {
        HStack(spacing: 8) {
            Image(systemName: "bell.badge")
                .foregroundStyle(Ink.steel)
            Text("detail.invite.notified")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Ink.primary)
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
        .background(Ink.steelSoft, in: Capsule())
        .overlay(Capsule().stroke(Ink.steel.opacity(0.4), lineWidth: 1))
        .padding(.bottom, 24)
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .task {
            try? await Task.sleep(nanoseconds: 2_400_000_000)
            withAnimation { notifyInterest = false }
        }
    }

    /// Add this release to the local collection (local-first, no network).
    private func pickToShelf() {
        guard !isOwned else { return }
        let copy = OwnedCopy(key: release.key, editionNo: release.edition, hasModel: release.isLit)
        modelContext.insert(OwnedModel(copy))
        try? modelContext.save()
    }
}

/// The two faces of the detail screen. Titles localize to 模型 | 真车 for zh-Hans.
enum DetailFace: String, CaseIterable, Identifiable {
    case model
    case realCar
    var id: String { rawValue }
    var title: LocalizedStringKey { self == .model ? "detail.face.model" : "detail.face.realCar" }
}

/// Typed route so "View in 3D" pushes the dark-stage viewer.
struct ViewerRoute: Hashable {
    let release: Release
}
