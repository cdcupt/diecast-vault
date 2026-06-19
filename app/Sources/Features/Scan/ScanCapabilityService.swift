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

    /// The current device's capability. Honors the env override first, then the
    /// real Apple availability signals.
    static var current: ScanCapability {
        if let forced = forcedOverride { return forced }
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
    static var isObjectCaptureAvailable: Bool {
        #if targetEnvironment(simulator)
        return false
        #elseif canImport(RealityKit)
        if #available(iOS 17.0, *) {
            return ObjectCaptureSession.isSupported
        }
        return false
        #else
        return false
        #endif
    }
}
