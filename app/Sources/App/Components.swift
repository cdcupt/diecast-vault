import SwiftUI
import DiecastVaultCore

/// The signature "lightbar" eyebrow from the design — a lit bulb, a mono label,
/// and a tungsten light-spill segment. Sits above section content.
struct Lightbar: View {
    let label: String

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(Ink.tungsten)
                .frame(width: 9, height: 9)
                .overlay(
                    Circle()
                        .stroke(Ink.tungstenGlow, lineWidth: 4)
                )
            Text(label.uppercased())
                .font(Voice.mono(11, weight: .semibold))
                .tracking(2)
                .foregroundStyle(Ink.steel)
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [Ink.tungsten, Ink.tungstenGlow, .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: 2)
                .clipShape(Capsule())
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(label)
    }
}

/// The teal (L) / burnt-amber (R) drive decal — the other half of the key.
struct DriveDecal: View {
    let drive: Drive

    var body: some View {
        Text(drive.decal)
            .font(Voice.mono(13, weight: .heavy))
            .foregroundStyle(.white)
            .frame(width: 24, height: 24)
            .background(drive == .lhd ? Ink.lhd : Ink.rhd)
            .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
            .accessibilityLabel(drive.displayName)
    }
}

/// A small mono catalog placard (the "748" tab in the design).
struct CatalogPlacard: View {
    let mgtNumber: String

    /// Show just the trailing digits, matching the niche placard in the design.
    private var shortCode: String {
        let digits = mgtNumber.drop { !$0.isNumber }
        return String(digits.suffix(3))
    }

    var body: some View {
        Text(shortCode)
            .font(Voice.mono(11, weight: .semibold))
            .foregroundStyle(Ink.steel)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(Ink.cellRecess)
            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
            .accessibilityLabel("Catalog \(mgtNumber)")
    }
}

/// One cabinet niche. Light is state: a LIT niche glows with pooled tungsten and
/// lifts off the paper; a MATTE recess is carved into the wall with no scan yet.
/// (Real 3D content lands in Spike-1; here the car is a placeholder glyph.)
struct CabinetCell: View {
    let release: Release

    var body: some View {
        ZStack {
            background
            // Placard + drive decal pinned to the top corners.
            VStack {
                HStack(alignment: .top) {
                    CatalogPlacard(mgtNumber: release.mgtNumber)
                    Spacer()
                    DriveDecal(drive: release.drive)
                }
                Spacer()
            }
            .padding(8)

            // Placeholder car glyph (Spike-1 replaces with a RealityKit hero).
            Image(systemName: "car.side.fill")
                .font(.system(size: 38))
                .foregroundStyle(release.isLit ? Ink.primary.opacity(0.88) : Ink.muted.opacity(0.45))

            // Serif car name along the bottom.
            VStack {
                Spacer()
                HStack {
                    Text(release.name)
                        .font(Voice.serif(15))
                        .foregroundStyle(release.isLit ? Ink.primary : Ink.muted)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                    Spacer()
                }
            }
            .padding(10)
        }
        .aspectRatio(1, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Ink.line, lineWidth: 1)
        )
        .shadow(
            color: release.isLit ? Color(Palette.ink).opacity(0.08) : .clear,
            radius: 14, x: 0, y: 10
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(release.name), \(release.drive.displayName), \(release.isLit ? "scan present" : "no scan yet")")
    }

    @ViewBuilder
    private var background: some View {
        if release.isLit {
            // Pre-baked tungsten glow pooled at the base of a lit niche.
            ZStack {
                Ink.cellSurface
                RadialGradient(
                    colors: [Ink.tungstenGlow, .clear],
                    center: .init(x: 0.5, y: 1.1),
                    startRadius: 0,
                    endRadius: 150
                )
            }
        } else {
            // Carved, unlit recess.
            Ink.cellRecess
        }
    }
}
