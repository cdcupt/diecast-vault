import Foundation
import QuartzCore
import os

#if canImport(UIKit)
import UIKit
#endif

/// A live frame-rate + memory sampler for Spike-1. Drives off `CADisplayLink`
/// so it measures the *actual* presented frame cadence of whatever scene is on
/// screen (RealityKit here), then reports min / avg FPS, resident memory, and
/// thermal state over a fixed window.
///
/// SIMULATOR CAVEAT: the simulator renders on the Mac GPU via a software/host
/// path — its FPS and memory numbers are NOT representative of on-device GPU
/// cost. This harness validates that the scene *renders* and gives a rough,
/// directional cost signal; the binding 60/30-fps + thermal verdict from the
/// PRD must be re-measured on a physical device with Instruments attached.
@MainActor
final class PerfHarness: ObservableObject {
    /// A single rolling readout, published for the on-screen HUD.
    struct Sample: Equatable {
        var instantFPS: Double = 0
        var avgFPS: Double = 0
        var minFPS: Double = 0
        var residentMB: Double = 0
        var thermal: String = "nominal"
        var elapsed: TimeInterval = 0
        var finished: Bool = false
    }

    @Published private(set) var sample = Sample()

    private let log = Logger(subsystem: "com.daichenlab.diecastvault", category: "Spike1.Perf")

    private var link: CADisplayLink?
    private var startTime: CFTimeInterval = 0
    private var lastTick: CFTimeInterval = 0
    private var frameCount: Int = 0
    private var minFPS: Double = .greatestFiniteMagnitude
    private var fpsAccumulator: Double = 0
    private var fpsBuckets: Int = 0

    /// Run the sampler for `window` seconds, then stop and emit a summary line.
    private let window: TimeInterval

    init(window: TimeInterval = 6) {
        self.window = window
    }

    func start() {
        stop()
        startTime = CACurrentMediaTime()
        lastTick = startTime
        frameCount = 0
        minFPS = .greatestFiniteMagnitude
        fpsAccumulator = 0
        fpsBuckets = 0
        sample = Sample()

        let link = CADisplayLink(target: self, selector: #selector(tick(_:)))
        // Let it run at whatever cadence the display offers (ProMotion-aware).
        link.add(to: .main, forMode: .common)
        self.link = link
        log.info("Spike-1 perf harness started (window \(self.window, format: .fixed(precision: 1))s)")
    }

    func stop() {
        link?.invalidate()
        link = nil
    }

    @objc private func tick(_ link: CADisplayLink) {
        let now = link.timestamp
        let dt = now - lastTick
        lastTick = now
        frameCount += 1

        // Skip the very first interval (warm-up / no baseline yet).
        guard dt > 0, frameCount > 1 else { return }

        let instant = 1.0 / dt
        fpsAccumulator += instant
        fpsBuckets += 1
        if instant < minFPS { minFPS = instant }

        let elapsed = now - startTime
        let avg = fpsBuckets > 0 ? fpsAccumulator / Double(fpsBuckets) : 0

        sample = Sample(
            instantFPS: instant,
            avgFPS: avg,
            minFPS: minFPS == .greatestFiniteMagnitude ? 0 : minFPS,
            residentMB: Self.residentMemoryMB(),
            thermal: Self.thermalDescription(),
            elapsed: elapsed,
            finished: elapsed >= window
        )

        if elapsed >= window {
            finish(avg: avg)
        }
    }

    private func finish(avg: Double) {
        stop()
        let s = sample
        // Single, parseable summary line for the spike report / console capture.
        log.notice("""
        Spike-1 RESULT | avgFPS=\(avg, format: .fixed(precision: 1)) \
        minFPS=\(s.minFPS, format: .fixed(precision: 1)) \
        residentMB=\(s.residentMB, format: .fixed(precision: 1)) \
        thermal=\(s.thermal, privacy: .public) \
        window=\(self.window, format: .fixed(precision: 1))s \
        (SIMULATOR — not device-representative)
        """)
        // Also a plain print so it shows in `xcrun simctl` log / Xcode console
        // even without the unified-log subsystem filter.
        print("[Spike-1] RESULT avgFPS=\(String(format: "%.1f", avg)) "
            + "minFPS=\(String(format: "%.1f", s.minFPS)) "
            + "residentMB=\(String(format: "%.1f", s.residentMB)) "
            + "thermal=\(s.thermal) (SIMULATOR — not device-representative)")
    }

    // MARK: - Probes

    /// Resident memory footprint in MB via `task_vm_info` (phys_footprint).
    static func residentMemoryMB() -> Double {
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size) / 4
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
            }
        }
        guard kerr == KERN_SUCCESS else { return 0 }
        return Double(info.phys_footprint) / (1024 * 1024)
    }

    static func thermalDescription() -> String {
        switch ProcessInfo.processInfo.thermalState {
        case .nominal: return "nominal"
        case .fair: return "fair"
        case .serious: return "serious"
        case .critical: return "critical"
        @unknown default: return "unknown"
        }
    }
}
