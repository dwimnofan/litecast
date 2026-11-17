import Foundation
import IOKit.ps
import Observation

struct BatteryStatus: Equatable, Sendable {
    var level: Int // 0...100
    var isCharging: Bool
    var isPluggedIn: Bool

    /// nil for anything that isn't an internal battery with a readable capacity.
    init?(description d: [String: Any]) {
        guard d[kIOPSTypeKey] as? String == kIOPSInternalBatteryType,
              let current = d[kIOPSCurrentCapacityKey] as? Int,
              let max = d[kIOPSMaxCapacityKey] as? Int, max > 0 else { return nil }
        level = Swift.min(100, Swift.max(0, current * 100 / max))
        isCharging = d[kIOPSIsChargingKey] as? Bool ?? false
        isPluggedIn = d[kIOPSPowerSourceStateKey] as? String == kIOPSACPowerValue
    }
}

/// Event-driven via IOPSNotificationCreateRunLoopSource; no polling. `status` stays nil on Macs without a battery.
@MainActor
@Observable
final class BatteryMonitor {
    private(set) var status: BatteryStatus?
    @ObservationIgnored private var source: CFRunLoopSource?

    func start() {
        guard source == nil else { return }
        update()
        let context = Unmanaged.passUnretained(self).toOpaque()
        guard let created = IOPSNotificationCreateRunLoopSource({ context in
            guard let context else { return }
            let monitor = Unmanaged<BatteryMonitor>.fromOpaque(context).takeUnretainedValue()
            // The source is attached to the main run loop, so this runs on the main thread.
            MainActor.assumeIsolated { monitor.update() }
        }, context)?.takeRetainedValue() else { return }
        CFRunLoopAddSource(CFRunLoopGetMain(), created, .defaultMode)
        source = created
    }

    func stop() {
        if let source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .defaultMode) }
        source = nil
    }

    private func update() {
        guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let list = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef] else {
            status = nil
            return
        }
        status = list.lazy
            .compactMap { IOPSGetPowerSourceDescription(info, $0)?.takeUnretainedValue() as? [String: Any] }
            .compactMap { BatteryStatus(description: $0) }
            .first
    }
}
