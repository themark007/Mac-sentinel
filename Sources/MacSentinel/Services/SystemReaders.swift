import Darwin
import Foundation

final class CPUReader {
    private var previousTicks: [UInt64]?

    func sample() -> CPUSnapshot {
        var cpuInfo = host_cpu_load_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info_data_t>.stride / MemoryLayout<integer_t>.stride)

        let result = withUnsafeMutablePointer(to: &cpuInfo) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { rebound in
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, rebound, &count)
            }
        }

        var loads = [Double](repeating: 0, count: 3)
        getloadavg(&loads, 3)

        guard result == KERN_SUCCESS else {
            return CPUSnapshot(loadAverage: loads, thermalState: ProcessInfo.processInfo.thermalLabel)
        }

        let ticks = [
            UInt64(cpuInfo.cpu_ticks.0),
            UInt64(cpuInfo.cpu_ticks.1),
            UInt64(cpuInfo.cpu_ticks.2),
            UInt64(cpuInfo.cpu_ticks.3)
        ]

        let delta: [UInt64]
        if let previousTicks {
            delta = zip(ticks, previousTicks).map { current, previous in
                current >= previous ? current - previous : 0
            }
        } else {
            delta = ticks
        }
        previousTicks = ticks

        let user = Double(delta[0])
        let system = Double(delta[1])
        let idle = Double(delta[2])
        let nice = Double(delta[3])
        let total = max(1, user + system + idle + nice)
        let active = user + system + nice

        return CPUSnapshot(
            usage: active / total * 100,
            user: user / total * 100,
            system: system / total * 100,
            idle: idle / total * 100,
            loadAverage: loads,
            coreCount: ProcessInfo.processInfo.activeProcessorCount,
            thermalState: ProcessInfo.processInfo.thermalLabel
        )
    }
}

enum MemoryReader {
    static func sample() -> MemorySnapshot {
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.stride / MemoryLayout<integer_t>.stride)

        let result = withUnsafeMutablePointer(to: &stats) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { rebound in
                host_statistics64(mach_host_self(), HOST_VM_INFO64, rebound, &count)
            }
        }

        guard result == KERN_SUCCESS else {
            return MemorySnapshot()
        }

        let pageSize = UInt64(vm_kernel_page_size)
        let total = ProcessInfo.processInfo.physicalMemory
        let freePages = UInt64(stats.free_count + stats.speculative_count)
        let activePages = UInt64(stats.active_count)
        let internalPages = UInt64(stats.internal_page_count)
        let wiredPages = UInt64(stats.wire_count)
        let compressedPages = UInt64(stats.compressor_page_count)

        let free = freePages * pageSize
        let wired = wiredPages * pageSize
        let compressed = compressedPages * pageSize
        let app = max(activePages, internalPages) * pageSize
        let used = min(total, total > free ? total - free : 0)
        let ratio = total > 0 ? Double(used) / Double(total) : 0
        let compressionRatio = total > 0 ? Double(compressed) / Double(total) : 0

        let pressure: HealthLevel
        if ratio > 0.94 || compressionRatio > 0.35 {
            pressure = .critical
        } else if ratio > 0.86 || compressionRatio > 0.22 {
            pressure = .hot
        } else if ratio > 0.74 || compressionRatio > 0.12 {
            pressure = .watch
        } else {
            pressure = .good
        }

        return MemorySnapshot(
            totalBytes: total,
            usedBytes: used,
            appBytes: app,
            wiredBytes: wired,
            compressedBytes: compressed,
            freeBytes: free,
            swapOuts: UInt64(stats.swapouts),
            pressure: pressure
        )
    }
}

extension ProcessInfo {
    var thermalLabel: String {
        switch thermalState {
        case .nominal: return "Nominal"
        case .fair: return "Fair"
        case .serious: return "Serious"
        case .critical: return "Critical"
        @unknown default: return "Unknown"
        }
    }
}
