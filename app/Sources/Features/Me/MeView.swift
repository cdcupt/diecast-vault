import SwiftUI

/// Me tab — account, capability, and settings. Slice 1 is a styled placeholder;
/// Sign in with Apple, the capability summary, and preferences arrive later.
struct MeView: View {
    var body: some View {
        PlaceholderScreen(
            eyebrow: "Me",
            title: "Me",
            blurb: "Your account, device capability, and preferences. Sign in with Apple and iCloud sync arrive in a later slice.",
            symbol: "person.crop.circle"
        )
    }
}

#Preview {
    NavigationStack { MeView() }
        .tint(Ink.tungsten)
}
