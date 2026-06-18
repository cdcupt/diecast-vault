import SwiftUI

/// Library tab — the community library of shared scans. Slice 1 is a styled
/// placeholder; browse + share/upload arrive once the backend lands.
struct LibraryView: View {
    var body: some View {
        PlaceholderScreen(
            eyebrow: "tab.library",
            title: "tab.library",
            blurb: "library.blurb",
            symbol: "cloud"
        )
    }
}

#Preview {
    NavigationStack { LibraryView() }
        .tint(Ink.tungsten)
}
