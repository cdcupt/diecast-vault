import SwiftUI

/// The four tabs of the native shell. Labels follow the locked design
/// (Cabinet · Catalog · Library · Me); Chinese localization maps these to
/// 陈列柜 / 目录 / 社区库 / 我的 in a later slice.
enum AppTab: Int, CaseIterable, Identifiable {
    case cabinet
    case catalog
    case library
    case me

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .cabinet: return "Cabinet"
        case .catalog: return "Catalog"
        case .library: return "Library"
        case .me: return "Me"
        }
    }

    /// SF Symbols chosen to echo the design glyphs (▦ ⌕ ☁ ⚙→person).
    var symbol: String {
        switch self {
        case .cabinet: return "square.grid.2x2"
        case .catalog: return "magnifyingglass"
        case .library: return "cloud"
        case .me: return "person.crop.circle"
        }
    }
}

/// App-level tab shell. Each tab owns its own `NavigationStack` so navigation
/// state is isolated per surface (cross-tab routing arrives with the Router in
/// a later slice).
struct RootTabView: View {
    @State private var selection: AppTab = .cabinet

    init() {
        Self.configureBarAppearance()
    }

    var body: some View {
        TabView(selection: $selection) {
            ForEach(AppTab.allCases) { tab in
                NavigationStack {
                    screen(for: tab)
                }
                .tabItem {
                    Label(tab.title, systemImage: tab.symbol)
                }
                .tag(tab)
            }
        }
    }

    @ViewBuilder
    private func screen(for tab: AppTab) -> some View {
        switch tab {
        case .cabinet: CabinetView()
        case .catalog: CatalogView()
        case .library: LibraryView()
        case .me: MeView()
        }
    }

    /// Warm light chrome: paper-toned bars, ink titles, tungsten selection.
    private static func configureBarAppearance() {
        let paper = UIColor(Ink.paper)
        let ink = UIColor(Ink.primary)

        let nav = UINavigationBarAppearance()
        nav.configureWithOpaqueBackground()
        nav.backgroundColor = paper
        nav.shadowColor = UIColor(Ink.line)
        nav.titleTextAttributes = [.foregroundColor: ink]
        // Large editorial serif title.
        if let serif = UIFont(name: "NewYork-Bold", size: 34)
            ?? UIFont.systemFont(ofSize: 34, weight: .bold).withSerifDesign() {
            nav.largeTitleTextAttributes = [.foregroundColor: ink, .font: serif]
        } else {
            nav.largeTitleTextAttributes = [.foregroundColor: ink]
        }
        UINavigationBar.appearance().standardAppearance = nav
        UINavigationBar.appearance().scrollEdgeAppearance = nav

        let tabBar = UITabBarAppearance()
        tabBar.configureWithOpaqueBackground()
        tabBar.backgroundColor = paper
        tabBar.shadowColor = UIColor(Ink.line)
        UITabBar.appearance().standardAppearance = tabBar
        UITabBar.appearance().scrollEdgeAppearance = tabBar
    }
}

private extension UIFont {
    /// Apply the serif (New York) design to a system font when available.
    func withSerifDesign() -> UIFont? {
        guard let descriptor = fontDescriptor.withDesign(.serif) else { return nil }
        return UIFont(descriptor: descriptor, size: pointSize)
    }
}

#Preview {
    RootTabView()
        .tint(Ink.tungsten)
}
