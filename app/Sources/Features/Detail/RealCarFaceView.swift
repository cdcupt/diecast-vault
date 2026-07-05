import SwiftUI
import DiecastVaultCore

/// The "Real Car" face of Release detail (DESIGN §4.5b) — a LIGHT editorial
/// reference profile of the full-size car, served from the bundled local
/// profiles (`RealCarProfile.sample(for:)`). The dark stage belongs to the Model
/// face only; this view stays in light chrome. Attribution treatment is kept
/// faithful so a server-backed version remains a drop-in — but the UI makes no
/// roadmap claims (App Review 2.1a: no coming-soon copy anywhere in v1.0).
struct RealCarFaceView: View {
    let release: Release

    @EnvironmentObject private var localeManager: LocaleManager

    /// Sample profile in the active language — the HISTORY prose stays a local
    /// sample (per the slice-3 brief) but is provided in zh too so the zh build
    /// reads natively. Real (server-backed) enrichment is a drop-in later.
    private var profile: RealCarProfile {
        let sampleLocale: SampleLocale =
            localeManager.language == .simplifiedChinese ? .simplifiedChinese : .english
        return RealCarProfile.sample(for: release, locale: sampleLocale)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            heroPhoto
            history
            specs
            gallery
            compare
        }
    }

    // MARK: Hero

    private var heroPhoto: some View {
        VStack(alignment: .leading, spacing: 6) {
            ReferenceImagePlaceholder(image: profile.hero, height: 180)
            attribution(profile.hero)
        }
    }

    // MARK: History

    private var history: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("realcar.history.heading \(shortName)")
                    .font(Voice.serif(18))
                    .foregroundStyle(Ink.primary)
                Spacer()
                SourceChip(label: Text("realcar.source \(profile.historySource)"))
            }
            ForEach(profile.history, id: \.self) { paragraph in
                Text(paragraph)
                    .font(.callout)
                    .foregroundStyle(Ink.soft)
            }
        }
    }

    private var shortName: String {
        // Use the last token of the marque+model for a tighter heading.
        String(release.name.split(separator: " ").suffix(2).joined(separator: " "))
    }

    // MARK: Specs

    private var specs: some View {
        VStack(spacing: 0) {
            ForEach(Array(profile.specs.enumerated()), id: \.element.id) { index, spec in
                HStack {
                    Text(spec.key)
                        .font(Voice.mono(10, weight: .medium))
                        .foregroundStyle(Ink.muted)
                    Spacer()
                    Text(spec.value)
                        .font(Voice.mono(11))
                        .foregroundStyle(Ink.soft)
                }
                .padding(.vertical, 9)
                if index < profile.specs.count - 1 {
                    Rectangle().fill(Ink.line).frame(height: 1)
                }
            }
        }
        .padding(.horizontal, 14)
        .background(Ink.cellSurface)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Ink.line, lineWidth: 1)
        )
    }

    // MARK: Gallery

    private var gallery: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("realcar.gallery.heading")
                .textCase(.uppercase)
                .font(Voice.mono(10, weight: .semibold))
                .tracking(1.2)
                .foregroundStyle(Ink.muted)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(profile.gallery) { image in
                        VStack(alignment: .leading, spacing: 4) {
                            ReferenceImagePlaceholder(image: image, height: 72)
                                .frame(width: 96)
                            SourceChip(label: Text(verbatim: image.license), compact: true)
                        }
                    }
                }
            }
        }
    }

    // MARK: Side-by-side compare

    private var compare: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("realcar.compare.heading")
                .textCase(.uppercase)
                .font(Voice.mono(10, weight: .semibold))
                .tracking(1.2)
                .foregroundStyle(Ink.muted)
            HStack(spacing: 0) {
                comparePane(title: "realcar.compare.yours", lit: true)
                Rectangle().fill(Ink.line).frame(width: 1)
                comparePane(title: "realcar.compare.realCar", lit: false)
            }
            .frame(height: 110)
            .background(Ink.cellSurface)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Ink.line, lineWidth: 1)
            )
        }
    }

    private func comparePane(title: LocalizedStringKey, lit: Bool) -> some View {
        ZStack {
            if lit {
                RadialGradient(colors: [Ink.tungstenGlow, .clear],
                               center: .init(x: 0.5, y: 1.05), startRadius: 0, endRadius: 120)
                    .background(Ink.cellSurface)
            } else {
                LinearGradient(colors: [Color(white: 0.78), Color(white: 0.56)],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
            }
            Image(systemName: "car.side.fill")
                .font(.system(size: 30))
                .foregroundStyle(lit ? Ink.primary.opacity(0.85) : .white.opacity(0.9))
            VStack {
                HStack {
                    Text(title)
                        .textCase(.uppercase)
                        .font(Voice.mono(8, weight: .semibold))
                        .foregroundStyle(lit ? Ink.muted : .white.opacity(0.9))
                    Spacer()
                }
                Spacer()
            }
            .padding(8)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: Bits

    private func attribution(_ image: RealCarImage) -> some View {
        Group {
            if image.origin == .ai {
                Text("realcar.attribution.ai")
            } else {
                Text("realcar.attribution.photo \(image.attribution) \(image.license)")
            }
        }
        .font(Voice.mono(9))
        .foregroundStyle(image.origin == .ai ? Ink.warn : Ink.muted)
    }
}

/// A reference-image placeholder. A real photo gets a cool grey gradient + glint;
/// an AI fallback gets a deliberately different hatched warm treatment + an
/// "Illustration" badge so it is never mistaken for a real photograph.
private struct ReferenceImagePlaceholder: View {
    let image: RealCarImage
    let height: CGFloat

    var body: some View {
        ZStack {
            if image.origin == .ai {
                Color(Palette.warn).opacity(0.14)
                Image(systemName: "sparkles")
                    .font(.system(size: 22))
                    .foregroundStyle(Ink.warn.opacity(0.7))
            } else {
                LinearGradient(colors: [Color(white: 0.82), Color(white: 0.55)],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
                Image(systemName: "photo")
                    .font(.system(size: 22))
                    .foregroundStyle(.white.opacity(0.85))
            }
            if image.origin == .ai {
                VStack {
                    HStack {
                        HStack(spacing: 3) {
                            Image(systemName: "exclamationmark.triangle.fill")
                            Text("realcar.illustrationBadge")
                        }
                        .font(Voice.mono(8, weight: .heavy))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6).padding(.vertical, 3)
                        .background(Ink.warn, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                        Spacer()
                    }
                    Spacer()
                }
                .padding(6)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: height)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(Ink.line, lineWidth: 1)
        )
    }
}

/// A small steel source/license cite chip.
private struct SourceChip: View {
    let label: Text
    var compact = false

    var body: some View {
        label
            .font(Voice.mono(compact ? 7 : 9, weight: .semibold))
            .foregroundStyle(Ink.steel)
            .padding(.horizontal, compact ? 5 : 8).padding(.vertical, compact ? 2 : 3)
            .background(Ink.steelSoft)
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous).stroke(Color(Palette.steel).opacity(0.2), lineWidth: 1)
            )
    }
}
