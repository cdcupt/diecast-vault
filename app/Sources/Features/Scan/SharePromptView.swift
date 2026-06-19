import SwiftUI
import DiecastVaultCore

/// The post-bond share prompt (mockup #s-share-prompt). The model is already
/// saved locally; this opt-in invites the user to share their scan to the
/// community so other owners don't have to re-scan. Framing shifts on whether
/// they are the first to scan this `(release, drive)` (highest leverage) vs.
/// offering an alternate to an existing canonical scan.
///
/// Sharing is explicit, credited, and revocable — personal models never
/// auto-upload (TECH.html scope boundary). "Done" returns to the cabinet, where
/// the freshly-bonded model is now LIT.
struct SharePromptView: View {
    let copy: OwnedCopy
    /// True when no canonical community scan exists yet for this key.
    let isFirstToScan: Bool

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var router: ScanRouter

    private var displayName: String {
        Release.catalogSample.first { $0.mgtNumber == copy.mgtNumber }?.name ?? copy.mgtNumber
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                statusChip
                Text(isFirstToScan ? "share.title.first" : "share.title.alt")
                    .font(Voice.serif(28))
                    .foregroundStyle(Ink.primary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(isFirstToScan ? "share.body.first" : "share.body.alt")
                    .font(.callout)
                    .foregroundStyle(Ink.soft)

                bondedCard

                Button { finish() } label: {
                    PrimaryCTALabel(title: "share.cta.share", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(.plain)

                Button { finish() } label: {
                    Text("share.cta.notNow")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Ink.tungstenDeep)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                }
                .buttonStyle(.plain)

                Text("share.fineprint")
                    .font(.caption2)
                    .foregroundStyle(Ink.muted)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 18)
            .padding(.top, 8)
            .padding(.bottom, 32)
        }
        .background(Ink.paper)
        .navigationTitle(Text("share.title.nav"))
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
    }

    private var statusChip: some View {
        HStack(spacing: 8) {
            Text("share.chip.bonded")
                .font(Voice.mono(10, weight: .heavy))
                .textCase(.uppercase)
                .foregroundStyle(.white)
                .padding(.horizontal, 9).padding(.vertical, 4)
                .background(Ink.ok, in: Capsule())
            if isFirstToScan {
                Text("share.chip.first")
                    .font(Voice.mono(10, weight: .heavy))
                    .textCase(.uppercase)
                    .foregroundStyle(Ink.tungstenDeep)
                    .padding(.horizontal, 9).padding(.vertical, 4)
                    .background(Color(Palette.tungstenGlow), in: Capsule())
            }
        }
    }

    private var bondedCard: some View {
        HStack(spacing: 13) {
            ZStack {
                RadialGradient(colors: [Ink.tungstenGlow, .clear], center: .init(x: 0.5, y: 1.1), startRadius: 0, endRadius: 80)
                    .background(Ink.cellSurface)
                DiecastGlyph().frame(width: 86, height: 54)
            }
            .frame(width: 108, height: 78)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 8) {
                Text(displayName)
                    .font(Voice.serif(18))
                    .foregroundStyle(Ink.primary)
                    .lineLimit(2)
                HStack(spacing: 6) {
                    Text(copy.mgtNumber)
                        .font(Voice.mono(10))
                        .foregroundStyle(Ink.steel)
                    DriveDecal(drive: copy.drive).scaleEffect(0.82)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(Ink.cellSurface)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Ink.line, lineWidth: 1))
    }

    /// Close the whole scan flow and return to the cabinet (the model is saved).
    private func finish() {
        router.finish()
    }
}
