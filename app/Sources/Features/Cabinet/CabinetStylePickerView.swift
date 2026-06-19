import SwiftUI
import DiecastVaultCore

/// "Choose your cabinet" (DESIGN §4.2b) — the style picker shown as a sheet from
/// the lightbar STYLE chip and from Me. Each style is a LIVE mini-cabinet swatch
/// (one lit + one empty niche), not a flat colour chip. The current selection
/// carries the locked tungsten ring; tapping cross-dissolves the Home cabinet via
/// the shared `CabinetStylePreference`. Selection persists per-user; purely
/// cosmetic — "the same shelves, dressed differently", never a feature unlock.
struct CabinetStylePickerView: View {
    @EnvironmentObject private var stylePreference: CabinetStylePreference
    @Environment(\.dismiss) private var dismiss

    private let columns = [
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14)
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("cabinet.style.picker.blurb")
                        .font(.footnote)
                        .foregroundStyle(Ink.soft)
                        .padding(.horizontal, 2)

                    LazyVGrid(columns: columns, spacing: 14) {
                        ForEach(CabinetStyle.allCases) { style in
                            styleTile(style)
                        }
                    }
                }
                .padding(18)
            }
            .background(Ink.paper)
            .navigationTitle(Text("cabinet.style.picker.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button { dismiss() } label: { Text("cabinet.style.picker.done") }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func styleTile(_ style: CabinetStyle) -> some View {
        let isSelected = stylePreference.style == style
        return Button {
            withAnimation(.easeInOut(duration: 0.35)) {
                stylePreference.select(style)
            }
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                MiniCabinetSwatch(style: style)
                    .overlay(alignment: .topTrailing) {
                        if isSelected {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 18))
                                .foregroundStyle(Ink.tungsten)
                                .padding(6)
                        }
                    }

                HStack(spacing: 6) {
                    Text(LocalizedStringKey(style.nameKey))
                        .font(Voice.serif(15))
                        .foregroundStyle(Ink.primary)
                    if style == .lightbarWhite {
                        Text("cabinet.style.default")
                            .textCase(.uppercase)
                            .font(Voice.mono(8, weight: .heavy))
                            .foregroundStyle(Ink.steel)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Ink.cellRecess, in: Capsule())
                    }
                }
                Text(LocalizedStringKey(style.taglineKey))
                    .font(Voice.mono(9))
                    .foregroundStyle(Ink.muted)
                    .lineLimit(2)
            }
            .padding(10)
            .background(Ink.cellSurface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(isSelected ? Ink.tungsten : Ink.line, lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(LocalizedStringKey(style.nameKey)))
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

/// A live mini-cabinet swatch — one LIT niche and one EMPTY niche rendered from
/// the style's own `CabinetTheme`, so the picker previews the real material/light
/// look (DESIGN §4.2b: "a live mini-cabinet swatch … not a flat colour chip").
private struct MiniCabinetSwatch: View {
    let style: CabinetStyle

    var body: some View {
        let t = style.theme
        HStack(spacing: 6) {
            niche(lit: true, theme: t)
            niche(lit: false, theme: t)
        }
        .padding(7)
        .background(
            // The carcass + a thin lightbar cap across the top (the fixture).
            ZStack(alignment: .top) {
                Color(t.carcass)
                Rectangle()
                    .fill(LinearGradient(
                        colors: [Color(t.lightbar.color).opacity(0.0), Color(t.lightbar.washColor), Color(t.lightbar.color).opacity(0.0)],
                        startPoint: .leading, endPoint: .trailing))
                    .frame(height: 4)
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .aspectRatio(2, contentMode: .fit)
    }

    @ViewBuilder
    private func niche(lit: Bool, theme: CabinetTheme) -> some View {
        ZStack {
            if lit {
                // Lit face + a pooled floor glow in the niche-light temperature.
                Color(theme.litFace)
                RadialGradient(
                    colors: [Color(theme.nicheLight.washColor).opacity(style.isDarkCase ? 0.55 : 0.5), .clear],
                    center: .init(x: 0.5, y: 1.05), startRadius: 0, endRadius: 60
                )
                Image(systemName: "car.side.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(carTint(theme: theme, lit: true))
            } else {
                Color(theme.matteRecess)
                Image(systemName: "plus")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(carTint(theme: theme, lit: false).opacity(0.6))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
    }

    /// A legible glyph tint: dark on light boards, light on the dark Museum case.
    private func carTint(theme: CabinetTheme, lit: Bool) -> Color {
        let luminance = 0.299 * theme.litFace.r + 0.587 * theme.litFace.g + 0.114 * theme.litFace.b
        let onDark = luminance < 0.4
        if lit {
            return onDark ? Color.white.opacity(0.9) : Ink.primary.opacity(0.85)
        } else {
            return onDark ? Color.white.opacity(0.5) : Ink.muted
        }
    }
}

#Preview {
    CabinetStylePickerView()
        .environmentObject(CabinetStylePreference())
        .tint(Ink.tungsten)
}
