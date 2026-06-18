import SwiftUI

/// Catalog tab — browse / pick a Mini GT release and its drive side. Slice 1 is
/// a styled placeholder; search + drive (L/R) select arrive in a later slice.
struct CatalogView: View {
    var body: some View {
        PlaceholderScreen(
            eyebrow: "Catalog",
            title: "Catalog",
            blurb: "Browse the Mini GT catalog, pick a release, and choose its drive side. Search and the L/R picker arrive in a later slice.",
            symbol: "magnifyingglass"
        )
    }
}

#Preview {
    NavigationStack { CatalogView() }
        .tint(Ink.tungsten)
}
