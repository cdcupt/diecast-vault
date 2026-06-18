import SwiftUI

@main
struct DiecastVaultApp: App {
    /// Spike-1 deterministic entry: launching with `-spike1Cabinet 1` (or env
    /// `DV_SPIKE1=1`) boots straight into the 3D-cabinet perf scene so the
    /// harness can run without a synthetic UI tap. Normal launches show the
    /// full tab shell.
    private static var launchesIntoSpike1: Bool {
        UserDefaults.standard.bool(forKey: "spike1Cabinet")
            || ProcessInfo.processInfo.environment["DV_SPIKE1"] == "1"
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if Self.launchesIntoSpike1 {
                    NavigationStack { Spike1CabinetView() }
                } else {
                    RootTabView()
                }
            }
            .tint(Ink.tungsten)
        }
    }
}
