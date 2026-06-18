import SwiftUI

/// Styled "coming soon" surface in the locked light chrome. Used by the
/// non-Cabinet tabs in slice 1 so the shell reads as intentional, not empty.
struct PlaceholderScreen: View {
    let eyebrow: String
    let title: String
    let blurb: String
    let symbol: String

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Lightbar(label: eyebrow)

            Image(systemName: symbol)
                .font(.system(size: 40, weight: .regular))
                .foregroundStyle(Ink.steel)
                .frame(width: 64, height: 64)
                .background(Ink.steelSoft)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

            Text(title)
                .font(Voice.serif(28))
                .foregroundStyle(Ink.primary)

            Text(blurb)
                .font(.body)
                .foregroundStyle(Ink.soft)
                .frame(maxWidth: 420, alignment: .leading)

            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(Ink.paper)
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.large)
    }
}
