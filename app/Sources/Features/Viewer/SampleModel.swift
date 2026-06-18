import Foundation

/// Locates the bundled sample USDZ. Slice 2 ships exactly one procedurally
/// generated low-poly car (`SampleCar.usdz`, see tools/usdz-gen) so the 3D
/// viewer and AR Quick Look have a real model with no network. When the
/// community backend lands, the per-`(mgtNumber, drive)` USDZ resolved from R2
/// replaces this; until then every release lifts the same sample body.
enum SampleModel {
    static let resourceName = "SampleCar"
    static let resourceExtension = "usdz"

    /// On-disk URL of the bundled USDZ, or `nil` if it isn't packaged (the
    /// viewer then shows its graceful "model unavailable" fallback).
    static var url: URL? {
        Bundle.main.url(forResource: resourceName, withExtension: resourceExtension)
    }
}
