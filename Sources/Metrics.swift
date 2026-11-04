import Foundation
import Darwin
import IOKit.ps
import CoreWLAN

struct CPUTicks {
    let values: [UInt32]

    func usage(since previous: CPUTicks) -> Double? {
        guard values.count == 4, previous.values.count == 4 else { return nil }
        let delta = zip(values, previous.values).map { UInt64($0 &- $1) }
        let total = delta.reduce(0, +)
        guard total > 0 else { return nil }
        return Double(total - delta[Int(CPU_STATE_IDLE)]) / Double(total)
    }
}

struct FocusSession {
    var remaining: TimeInterval = 25 * 60
    var deadline: Date?
    var complete = false
    var isPaused: Bool { deadline == nil && remaining > 0 && remaining < 25 * 60 }

    func seconds(at now: Date) -> Int {
        Int(ceil(max(0, deadline?.timeIntervalSince(now) ?? remaining)))
    }

    mutating func toggle(at now: Date) {
        if let deadline {
            remaining = max(0, deadline.timeIntervalSince(now))
            self.deadline = nil
        } else {
            if remaining <= 0 { remaining = 25 * 60 }
            complete = false
            deadline = now.addingTimeInterval(remaining)
        }
    }

    mutating func tick(at now: Date) -> Bool {
        guard let deadline, now >= deadline else { return false }
        self.deadline = nil
        remaining = 0
        complete = true
        return true
    }
}

struct Battery {
    let percent: Double
    let charging: Bool
    let pluggedIn: Bool
}

struct WiFiStatus {
    let powered: Bool
    let connected: Bool
    let name: String?
    let signal: Double?
    var label: String { !powered ? "Wi-Fi mati" : !connected ? "Wi-Fi terputus" : name ?? "Wi-Fi tersambung" }
}

final class MetricsReader {
    private let host = mach_host_self()
    deinit { mach_port_deallocate(mach_task_self_, host) }

    func cpu() -> CPUTicks? {
        var info = host_cpu_load_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout.size(ofValue: info) / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics(host, HOST_CPU_LOAD_INFO, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return nil }
        return CPUTicks(values: [info.cpu_ticks.0, info.cpu_ticks.1, info.cpu_ticks.2, info.cpu_ticks.3])
    }

    func memory() -> (used: Double, total: Double)? {
        var info = vm_statistics64_data_t()
        var count = mach_msg_type_number_t(MemoryLayout.size(ofValue: info) / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(host, HOST_VM_INFO64, $0, &count)
            }
        }
        var pageSize: vm_size_t = 0
        guard result == KERN_SUCCESS, host_page_size(host, &pageSize) == KERN_SUCCESS else { return nil }
        let total = Double(ProcessInfo.processInfo.physicalMemory)
        let pages = UInt64(info.active_count) + UInt64(info.wire_count) + UInt64(info.compressor_page_count)
        return (min(total, Double(pages) * Double(pageSize)), total)
    }

    func battery() -> Battery? {
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef] else { return nil }
        for source in sources {
            guard let info = IOPSGetPowerSourceDescription(snapshot, source)?.takeUnretainedValue() as? [String: Any],
                  let current = info[kIOPSCurrentCapacityKey] as? Int,
                  let maximum = info[kIOPSMaxCapacityKey] as? Int, maximum > 0 else { continue }
            return Battery(percent: min(1, max(0, Double(current) / Double(maximum))),
                           charging: info[kIOPSIsChargingKey] as? Bool ?? false,
                           pluggedIn: info[kIOPSPowerSourceStateKey] as? String == kIOPSACPowerValue)
        }
        return nil
    }

    func wifi(connected: Bool) -> WiFiStatus {
        guard let interface = CWWiFiClient.shared().interface() else {
            return WiFiStatus(powered: false, connected: false, name: nil, signal: nil)
        }
        let powered = interface.powerOn()
        let rssi = interface.rssiValue()
        let signal: Double? = rssi < 0 ? min(1, max(0, Double(rssi + 90) / 40)) : nil
        return WiFiStatus(powered: powered, connected: powered && connected, name: interface.ssid(), signal: signal)
    }
}
