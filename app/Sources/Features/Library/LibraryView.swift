import SwiftUI

/// Library tab — the community library of shared scans. Slice 1 is a styled
/// placeholder; browse + share/upload arrive once the backend lands.
struct LibraryView: View {
    var body: some View {
        PlaceholderScreen(
            eyebrow: "Library",
            title: "Library",
            blurb: "Reuse scans the community has shared, and contribute your own. Browse and upload arrive once the backend lands.",
            symbol: "cloud"
        )
    }
}

#Preview {
    NavigationStack { LibraryView() }
        .tint(Ink.tungsten)
}
