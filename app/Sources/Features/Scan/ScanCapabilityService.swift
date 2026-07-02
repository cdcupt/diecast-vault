import Foundation
import DiecastVaultCore
#if canImport(RealityKit)
import RealityKit
#endif

/// Bridges the pure `ScanCapability` gate to Apple's NATIVE capture stack at
/// runtime. Capture + reconstruction are LiDAR-Pro-iPhone-only and never run in
/// the simulator, so we gate on the real availability signals:
///
/// - `PhotogrammetrySession.isSupported` — on-device reconstruction (the harder
///   requirement; false on the simulator and on non-Pro / no-LiDAR iPhones).
/// - `ObjectCaptureSession` availability — the guided capture session (iOS 17+,
///   same device class).
///
/// No external SPM dependency is used — these are Apple frameworks
/// (RealityKit), so there is no network-fetch risk in this build environment.
///
/// A `DV_FORCE_SCAN_SUPPORT` env override (`1` = force supported, `0` = force
/// unsupported) lets the deterministic sim screenshots exercise the guided path
/// without a device while leaving genuine runtime detection in place by default.
enum ScanCapabilityService {

    /// v1.0 ships with guided capture OFF for every device: the live
    /// `ObjectCaptureSession` / `PhotogrammetrySession` pipeline (Spike-0) has not
    /// been implemented and validated on hardware yet, and App Review correctly
    /// rejected the deterministic stand-in as a scan stuck at 72% with no camera
    /// (Guideline 2.1a, submission 4a2e9d18). Until this flips, every device gets
    /// the capability-invite path — which is honest "arriving in an update" copy,
    /// with bonding still fully available. Flip to `true` only once the real
    /// capture pipeline lands AND has been validated on a physical LiDAR Pro
    /// iPhone.
    static let guidedCaptureShipped = false

    /// The current device's capability. Honors the env override first, then the
    /// ship flag, then the real Apple availability signals.
    static var current: ScanCapability {
        if let forced = forcedOverride { return forced }
        guard guidedCaptureShipped else { return .unsupported }
        return ScanCapability(isSupported: isPhotogrammetrySupported && isObjectCaptureAvailable)
    }

    // MARK: Override (deterministic sim verification only)

    private static var forcedOverride: ScanCapability? {
        switch ProcessInfo.processInfo.environment["DV_FORCE_SCAN_SUPPORT"] {
        case "1": return .supported
        case "0": return .unsupported
        default: return nil
        }
    }

    // MARK: Real Apple availability signals

    /// On-device photogrammetry support — the load-bearing gate. `false` on the
    /// simulator and any iPhone without the required Pro hardware.
    static var isPhotogrammetrySupported: Bool {
        #if targetEnvironment(simulator)
        return false
        #elseif canImport(RealityKit)
        if #available(iOS 17.0, *) {
            return PhotogrammetrySession.isSupported
        }
        return false
        #else
        return false
        #endif
    }

    /// Guided Object Capture session availability (RealityKit, iOS 17+, same Pro
    /// device class). Never available in the simulator.
    ///
    /// `ObjectCaptureSession` lives in the `_RealityKit_SwiftUI` overlay and is
    /// `@MainActor`-isolated, so it is not in scope from this plain `import
    /// RealityKit` synchronous accessor on the iOS device SDK. Object Capture and
    /// on-device photogrammetry ship together on the exact same hardware class
    /// (LiDAR Pro iPhone, iOS 17+), so we gate on the photogrammetry signal —
    /// the load-bearing requirement — which is equivalent at runtime and keeps
    /// this a clean, dependency-light synchronous check.
    static var isObjectCaptureAvailable: Bool {
        isPhotogrammetrySupported
    }
}
