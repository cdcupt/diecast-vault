import SwiftUI
import SwiftData
import DiecastVaultCore

/// Release detail (DESIGN §4.5 / §4.5b). Carries the `Model | Real Car`
/// segmented control: **Model** shows the car, its metadata, the model-presence
/// state, and a "View in 3D" CTA (lifting into the dark stage); **Real Car** is
/// the light reference profile. Model presence is expressed through light, not
/// greyed buttons, and every control on this screen performs a real action —
/// v1.0 carries no camera/scan affordances (App Review 2.1a).
struct ReleaseDetailView: View {
    let release: Release

    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var contributionStore: ContributionStore
    @Query private var owned: [OwnedModel]

    @State private var face: DetailFace
    /// Set when the pick-to-shelf save fails — surfaces an alert instead of a
    /// silently-lying green "On your shelf" state.
    @State private var showSaveError = false

    init(release: Release, initialFace: DetailFace = .model) {
        self.release = release
        _face = State(initialValue: initialFace)
        let id = release.id
        _owned = Query(filter: #Predicate<OwnedModel> { $0.stableID == id })
    }

    private var isOwned: Bool { !owned.isEmpty }
    /// v1.0 ships no capture path on any device, so model presence is computed
    /// for the non-Pro posture unconditionally.
    private var scanState: ScanState { release.scanState(isProDevice: false) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Picker("detail.face.picker", selection: $face) {
                    ForEach(DetailFace.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)

                switch face {
                case .model:
                    ModelFaceView(
                        release: release,
                        scanState: scanState,
                        isOwned: isOwned,
                        onPick: pickToShelf
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
        .alert(Text("error.save.title"), isPresented: $showSaveError) {
            Button(role: .cancel) {} label: { Text("error.save.dismiss") }
        } message: {
            Text("error.save.body")
        }
    }

    /// Add this release to the local collection (local-first, no network). A
    /// failed save rolls back and says so — the button state must never show
    /// "On your shelf" over data that won't survive a relaunch.
    private func pickToShelf() {
        guard !isOwned else { return }
        let copy = OwnedCopy(key: release.key, editionNo: release.edition, hasModel: release.isLit)
        modelContext.insert(OwnedModel(copy))
        do {
            try modelContext.save()
        } catch {
            AppLog.persistence.error("pickToShelf save failed: \(error, privacy: .public)")
            modelContext.rollback()
            showSaveError = true
        }
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
