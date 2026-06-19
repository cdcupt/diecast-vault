import SwiftUI
import DiecastVaultCore

/// The 3D viewer — the single sanctioned dark surface (DESIGN §4.6). Lifts a
/// release's model onto a spotlit dark stage with rotate/pinch + idle auto-orbit,
/// mono catalog+drive telemetry, and a tungsten "View in AR" button that opens
/// AR Quick Look for the bundled USDZ.
///
/// `RealityView` (iOS 18+) is availability-gated; on older systems a graceful
/// light fallback explains the requirement and still offers AR Quick Look (which
/// is available from iOS 12), so no path is a dead end.
struct ModelViewerView: View {
    let release: Release

    @Environment(\.dismiss) private var dismiss
    @State private var showAR = false

    /// Load state of the dark stage. `.loading` until the RealityView build reports
    /// back; `.failed` drives the authored model-load-failed state (with retry),
    /// never a dead-grey stage. `attempt` is bumped to rebuild the scene on retry.
    private enum LoadState { case loading, loaded, failed }
    @State private var loadState: LoadState = .loading
    @State private var attempt = 0

    /// Deterministic sim override: `DV_VIEWER_ERROR=1` forces the model-load-failed
    /// state (the live failure only happens with a corrupt/absent USDZ) so it is
    /// screenshot-able. The retry then clears the override for that session.
    @State private var forceError = ProcessInfo.processInfo.environment["DV_VIEWER_ERROR"] == "1"

    /// The model the stage loads. Nil-ed while `forceError` is set so the stage's
    /// own load path fails honestly (rather than faking the overlay).
    private var modelURL: URL? { forceError ? nil : SampleModel.url }

    var body: some View {
        ZStack {
            Color(Palette.stage0).ignoresSafeArea()

            stage

            if loadState == .failed { errorOverlay }

            VStack {
                topBar
                Spacer()
                if loadState != .failed { controlBar }
            }
            .padding(16)
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .statusBarHidden(false)
        .fullScreenCover(isPresented: $showAR) {
            if let url = SampleModel.url {
                ARQuickLookView(url: url).ignoresSafeArea()
            }
        }
    }

    // MARK: Stage (gated)

    @ViewBuilder
    private var stage: some View {
        if #available(iOS 18.0, *) {
            StageRealityView(release: release, modelURL: modelURL) { loaded in
                loadState = loaded ? .loaded : .failed
            }
            .id(attempt)   // rebuild the scene on retry
            .opacity(loadState == .failed ? 0 : 1)
        } else {
            stageFallback
        }
    }

    /// Authored model-load-failed state — the single dark surface stays on-brand
    /// (tungsten, serif headline), explains honestly, and offers Retry + AR rather
    /// than dead-ending. Retry clears any forced-error override and rebuilds.
    private var errorOverlay: some View {
        VStack(spacing: 16) {
            Image(systemName: "cube.transparent")
                .font(.system(size: 46, weight: .light))
                .foregroundStyle(Color(Palette.stageRim))
            Text("viewer.error.title")
                .font(Voice.serif(22))
                .foregroundStyle(.white)
            Text("viewer.error.body")
                .font(.callout)
                .foregroundStyle(.white.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 36)

            HStack(spacing: 10) {
                Button {
                    forceError = false
                    loadState = .loading
                    attempt += 1
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.clockwise")
                        Text("viewer.error.retry").font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16).padding(.vertical, 10)
                    .background(Color(Palette.tungsten), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .accessibilityLabel(Text("viewer.error.retry"))

                if SampleModel.url != nil {
                    Button { showAR = true } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "arkit")
                            Text("viewer.viewInAR").font(.system(size: 14, weight: .semibold))
                        }
                        .foregroundStyle(.white.opacity(0.9))
                        .padding(.horizontal, 16).padding(.vertical, 10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(Color(Palette.stageRim).opacity(0.5), lineWidth: 1)
                        )
                    }
                    .accessibilityLabel(Text("viewer.viewInAR"))
                }
            }
            .padding(.top, 4)
        }
        .padding(.vertical, 28)
        .accessibilityElement(children: .contain)
    }

    /// Light, graceful fallback for < iOS 18 (no RealityView). AR Quick Look is
    /// still reachable from the control bar below.
    private var stageFallback: some View {
        VStack(spacing: 14) {
            Image(systemName: "arkit")
                .font(.system(size: 46, weight: .light))
                .foregroundStyle(Color(Palette.stageRim))
            Text("viewer.fallback.title")
                .font(Voice.serif(20))
                .foregroundStyle(.white)
            Text("viewer.fallback.blurb \(release.name)")
                .font(.callout)
                .foregroundStyle(.white.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
    }

    // MARK: Chrome

    private var topBar: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.85))
                    .frame(width: 36, height: 36)
                    .background(Color(Palette.stage1).opacity(0.7), in: Circle())
            }
            .accessibilityLabel(Text("viewer.close"))

            Spacer()

            Text(release.name)
                .font(Voice.serif(17))
                .foregroundStyle(.white)

            Spacer()
            // Symmetry spacer matching the close button.
            Color.clear.frame(width: 36, height: 36)
        }
    }

    private var controlBar: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(release.mgtNumber)
                        .font(Voice.mono(11, weight: .medium))
                        .foregroundStyle(.white.opacity(0.85))
                    DriveDecal(drive: release.drive)
                        .scaleEffect(0.72)
                }
                Text(telemetryDetail)
                    .font(Voice.mono(10))
                    .foregroundStyle(.white.opacity(0.55))
            }

            Spacer()

            Button {
                showAR = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "arkit")
                    Text("viewer.viewInAR")
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(Color(Palette.tungsten), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            }
            .disabled(SampleModel.url == nil)
            .opacity(SampleModel.url == nil ? 0.4 : 1)
            .accessibilityLabel(Text("viewer.viewInAR"))
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(Color(Palette.stage1).opacity(0.85))
                .overlay(
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .stroke(Color(Palette.stageRim).opacity(0.35), lineWidth: 1)
                )
        )
    }

    private var telemetryDetail: String {
        let edition = release.edition.map { "EDITION \($0)" } ?? "SAMPLE MODEL"
        return "\(edition) · sample USDZ"
    }
}
