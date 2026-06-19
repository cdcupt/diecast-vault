import Foundation

/// Whether this device can run the guided Object Capture flow + on-device
/// photogrammetry. This is the pure, testable expression of the runtime gate the
/// app layer wires to `PhotogrammetrySession.isSupported` /
/// `ObjectCaptureSession` availability (TECH.html §5 — capture is
/// LiDAR-Pro-iPhone-only and never runs in the simulator).
///
/// The gate is binary by design: a supported device gets the guided capture
/// flow; everything else (older iPhones, the simulator) gets the
/// capability-invite path — an invitation to contribute on a Pro iPhone, never a
/// dead or greyed control (DESIGN §4.5b).
public enum ScanCapability: String, Codable, Sendable, CaseIterable {
    /// LiDAR Pro iPhone: guided capture + reconstruction are available.
    case supported
    /// Older iPhone or the simulator: show the contributor invitation instead.
    case unsupported

    /// Convenience over a single runtime boolean (e.g.
    /// `PhotogrammetrySession.isSupported && ObjectCaptureSession.isSupported`).
    public init(isSupported: Bool) {
        self = isSupported ? .supported : .unsupported
    }

    /// Whether the guided capture + reconstruction flow should be offered.
    public var canCapture: Bool { self == .supported }
}

/// The supported Pro-iPhone family the invite names, so the copy stays specific
/// and honest ("needs a Pro iPhone — iPhone 12 Pro through 17 Pro") rather than a
/// vague capability complaint (DESIGN §4.5b).
public enum ScanInvite: Sendable {
    /// Lower / upper bound of the LiDAR-Pro iPhone window the capture path needs.
    public static let proDeviceRangeLower = "iPhone 12 Pro"
    public static let proDeviceRangeUpper = "iPhone 17 Pro"
}
