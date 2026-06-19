import SwiftUI
import DiecastVaultCore

/// The UNSUPPORTED-device path (simulator + non-Pro iPhones): the
/// capability-invite. `PhotogrammetrySession.isSupported == false`, so instead of
/// a dead / greyed "Scan" control we render a warm contributor invitation
/// (DESIGN §4.5b) — "Scanning new cars needs a Pro iPhone (12 Pro–17 Pro)",
/// framed as joining the people who seed the community library, with a clear way
/// to still browse + bond what you own.
///
/// This is the state most reviewers see in the simulator, so it is treated as a
/// first-class designed screen, not a fallback afterthought.
struct CapabilityInviteView: View {
    /// Continue to the bond step (you can still record + name a copy you own,
    /// using a community scan when one exists — bonding never needs the camera).
    var onBond: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Lightbar(label: "scan.invite.eyebrow")

                hero
                requirement
                contributorPitch
                bondAffordance
            }
            .padding(.horizontal, 18)
            .padding(.top, 8)
            .padding(.bottom, 32)
        }
        .background(Ink.paper)
        .navigationTitle(Text("scan.title"))
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: Hero — a lit niche waiting to be seeded

    private var hero: some View {
        VStack(alignment: .leading, spacing: 14) {
            ZStack {
                RadialGradient(
                    colors: [Ink.tungstenGlow, .clear],
                    center: .init(x: 0.5, y: 1.05), startRadius: 0, endRadius: 240
                )
                .background(Ink.cellSurface)

                VStack(spacing: 12) {
                    Image(systemName: "camera.metering.center.weighted")
                        .font(.system(size: 52, weight: .light))
                        .foregroundStyle(Ink.tungsten)
                    Text("scan.invite.heroCaption")
                        .font(Voice.mono(10, weight: .semibold))
                        .tracking(1.6)
                        .textCase(.uppercase)
                        .foregroundStyle(Ink.steel)
                }
            }
            .frame(height: 190)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Ink.line, lineWidth: 1)
            )
            .shadow(color: Color(Palette.ink).opacity(0.08), radius: 16, y: 10)

            Text("scan.invite.title")
                .font(Voice.serif(28))
                .foregroundStyle(Ink.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: The honest requirement (specific Pro window)

    private var requirement: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "iphone.gen3")
                .font(.system(size: 18))
                .foregroundStyle(Ink.steel)
            VStack(alignment: .leading, spacing: 4) {
                Text("scan.invite.requirement.title")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Ink.primary)
                // Names the specific LiDAR-Pro window (12 Pro – 17 Pro).
                Text("scan.invite.requirement.body \(ScanInvite.proDeviceRangeLower) \(ScanInvite.proDeviceRangeUpper)")
                    .font(.footnote)
                    .foregroundStyle(Ink.soft)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Ink.steelSoft, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    // MARK: Why it matters — the contributor framing

    private var contributorPitch: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .foregroundStyle(Ink.tungstenDeep)
                Text("scan.invite.pitch.title")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Ink.tungstenDeep)
            }
            Text("scan.invite.pitch.body")
                .font(.callout)
                .foregroundStyle(Ink.soft)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color(Palette.tungstenGlow).opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Ink.tungsten, lineWidth: 1)
        )
    }

    // MARK: You can still bond what you own (never a dead end)

    private var bondAffordance: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("scan.invite.bond.note")
                .font(.footnote)
                .foregroundStyle(Ink.muted)

            Button(action: onBond) {
                HStack(spacing: 8) {
                    Image(systemName: "link")
                    Text("scan.invite.bond.cta")
                        .font(.system(size: 15, weight: .semibold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(Ink.tungsten, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
            }
            .buttonStyle(.plain)
        }
    }
}

#Preview {
    NavigationStack { CapabilityInviteView(onBond: {}) }
        .tint(Ink.tungsten)
}
