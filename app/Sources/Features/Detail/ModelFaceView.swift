import SwiftUI
import DiecastVaultCore

/// The "Model" face of Release detail: the niche/poster, mono+drive metadata, the
/// designed model-presence state (light-as-state), a Pick-to-shelf action, and the
/// "View in 3D" CTA that lifts the model onto the dark stage. Every control here
/// performs a real action — v1.0 carries no camera/scan affordances and no
/// coming-soon copy (App Review 2.1a).
struct ModelFaceView: View {
    let release: Release
    let scanState: ScanState
    let isOwned: Bool
    let onPick: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            poster
            meta

            switch scanState {
            case .hasModel:
                ctas
            case .noScanPro, .noScanBasic:
                noModelState
            }
        }
    }

    // MARK: Poster (lit niche vs matte recess)

    private var poster: some View {
        ZStack {
            if release.isLit {
                RadialGradient(
                    colors: [Ink.tungstenGlow, .clear],
                    center: .init(x: 0.5, y: 1.05), startRadius: 0, endRadius: 220
                )
                .background(Ink.cellSurface)
            } else {
                Ink.cellRecess
            }

            VStack {
                HStack(alignment: .top) {
                    CatalogPlacard(mgtNumber: release.mgtNumber)
                    Spacer()
                    DriveDecal(drive: release.drive)
                }
                Spacer()
            }
            .padding(12)

            Image(systemName: "car.side.fill")
                .font(.system(size: 64))
                .foregroundStyle(release.isLit ? Ink.primary.opacity(0.88) : Ink.muted.opacity(0.4))
        }
        .frame(height: 200)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Ink.line, lineWidth: 1)
        )
        .shadow(color: release.isLit ? Color(Palette.ink).opacity(0.08) : .clear, radius: 16, y: 10)
    }

    private var meta: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(release.name)
                .font(Voice.serif(26))
                .foregroundStyle(Ink.primary)
            HStack(spacing: 10) {
                Text(release.mgtNumber)
                    .font(Voice.mono(13))
                    .foregroundStyle(Ink.steel)
                if let edition = release.edition {
                    Text(edition)
                        .font(Voice.mono(12))
                        .foregroundStyle(Ink.muted)
                }
                ownershipTag
            }
        }
    }

    private var ownershipTag: some View {
        Text(isOwned ? "detail.tag.yours" : "detail.tag.community")
            .textCase(.uppercase)
            .font(Voice.mono(9, weight: .semibold))
            .tracking(0.5)
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(isOwned ? Color(Palette.tungstenGlow) : Ink.steelSoft)
            .foregroundStyle(isOwned ? Ink.tungstenDeep : Ink.steel)
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
    }

    // MARK: CTAs (model present)

    private var ctas: some View {
        VStack(spacing: 10) {
            Button(action: onPick) {
                ctaLabel(isOwned ? "detail.cta.onShelf" : "detail.cta.pick",
                         systemImage: isOwned ? "checkmark" : "plus")
                    .foregroundStyle(.white)
                    .background(isOwned ? Ink.ok : Ink.tungsten,
                                in: RoundedRectangle(cornerRadius: 11, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(isOwned)

            NavigationLink(value: ViewerRoute(release: release)) {
                ctaLabel("detail.cta.view3D", systemImage: "cube.transparent")
                    .foregroundStyle(Ink.primary)
                    .background(
                        RoundedRectangle(cornerRadius: 11, style: .continuous)
                            .stroke(Ink.primary, lineWidth: 1.5)
                    )
            }
            .buttonStyle(.plain)
        }
    }

    private func ctaLabel(_ title: LocalizedStringKey, systemImage: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
            Text(title).font(.system(size: 15, weight: .semibold))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 13)
    }

    // MARK: No-model state (matte niche)

    /// Calm, factual state for a release without a 3D model in the library: a
    /// steel note plus the same working Pick-to-shelf action lit releases get —
    /// the copy lands matte on the shelf. No dead controls, no promises.
    private var noModelState: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "info.circle")
                    Text("detail.invite.basicTitle")
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundStyle(Ink.steel)

                Text("detail.invite.basicNote")
                    .font(.callout)
                    .foregroundStyle(Ink.soft)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(Ink.steelSoft)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Ink.steel, lineWidth: 1)
            )

            Button(action: onPick) {
                ctaLabel(isOwned ? "detail.cta.onShelf" : "detail.cta.pick",
                         systemImage: isOwned ? "checkmark" : "plus")
                    .foregroundStyle(.white)
                    .background(isOwned ? Ink.ok : Ink.tungsten,
                                in: RoundedRectangle(cornerRadius: 11, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(isOwned)
        }
    }
}
