import Darwin
import Foundation

final class ProcessSampler {
    private var previousTimes: [Int32: UInt64] = [:]
    private var lastSampleAt: Date?

    func sample() -> [ProcessSample] {
        let now = Date()
        let elapsed = max(0.5, now.timeIntervalSince(lastSampleAt ?? now.addingTimeInterval(-1)))
        let pids = allPIDs()
        var currentTimes: [Int32: UInt64] = [:]
        let totalMemory = ProcessInfo.processInfo.physicalMemory

        let samples = pids.compactMap { pid -> ProcessSample? in
            guard pid > 0 else { return nil }

            var taskInfo = proc_taskinfo()
            let taskBytes = proc_pidinfo(
                pid,
                PROC_PIDTASKINFO,
                0,
                &taskInfo,
                Int32(MemoryLayout<proc_taskinfo>.stride)
            )
            guard taskBytes == Int32(MemoryLayout<proc_taskinfo>.stride) else { return nil }

            var bsdInfo = proc_bsdinfo()
            let bsdBytes = proc_pidinfo(
                pid,
                PROC_PIDTBSDINFO,
                0,
                &bsdInfo,
                Int32(MemoryLayout<proc_bsdinfo>.stride)
            )
            guard bsdBytes == Int32(MemoryLayout<proc_bsdinfo>.stride) else { return nil }

            let totalTime = UInt64(taskInfo.pti_total_user + taskInfo.pti_total_system)
            currentTimes[pid] = totalTime

            let cpuPercent: Double
            if let previous = previousTimes[pid], totalTime >= previous {
                let elapsedNano = elapsed * 1_000_000_000
                cpuPercent = min(999, Double(totalTime - previous) / elapsedNano * 100)
            } else {
                cpuPercent = 0
            }

            var nameTuple = bsdInfo.pbi_name
            var command = stringFromTuple(&nameTuple)
            if command.isEmpty {
                var commTuple = bsdInfo.pbi_comm
                command = stringFromTuple(&commTuple)
            }

            let path = processPath(pid: pid)
            let state = processState(Int32(bsdInfo.pbi_status))
            let threads = Int(taskInfo.pti_threadnum)
            let memory = UInt64(taskInfo.pti_resident_size)
            var flags: [ProcessFlag] = []

            if cpuPercent > 90 { flags.append(.highCPU) }
            if memory > 1_500_000_000 || (totalMemory > 0 && Double(memory) / Double(totalMemory) > 0.18) {
                flags.append(.highMemory)
            }
            if threads > 80 { flags.append(.manyThreads) }
            if state == "Stopped" { flags.append(.stopped) }
            if state == "Zombie" { flags.append(.zombie) }
            if path.isEmpty { flags.append(.unknownPath) }

            return ProcessSample(
                pid: pid,
                parentPID: Int32(bitPattern: bsdInfo.pbi_ppid),
                user: userName(uid: bsdInfo.pbi_uid),
                command: command,
                path: path,
                cpuPercent: cpuPercent,
                memoryBytes: memory,
                virtualBytes: UInt64(taskInfo.pti_virtual_size),
                threads: threads,
                runningThreads: Int(taskInfo.pti_numrunning),
                state: state,
                priority: Int(taskInfo.pti_priority),
                flags: flags
            )
        }

        previousTimes = currentTimes
        lastSampleAt = now

        return samples.sorted {
            if $0.isFlagged != $1.isFlagged { return $0.isFlagged && !$1.isFlagged }
            if abs($0.cpuPercent - $1.cpuPercent) > 0.2 { return $0.cpuPercent > $1.cpuPercent }
            return $0.memoryBytes > $1.memoryBytes
        }
    }

    private func allPIDs() -> [Int32] {
        let bytes = proc_listpids(UInt32(PROC_ALL_PIDS), 0, nil, 0)
        guard bytes > 0 else { return [] }

        let count = Int(bytes) / MemoryLayout<pid_t>.stride
        var pids = [pid_t](repeating: 0, count: count)
        let written = pids.withUnsafeMutableBytes { buffer in
            proc_listpids(UInt32(PROC_ALL_PIDS), 0, buffer.baseAddress, Int32(buffer.count))
        }
        guard written > 0 else { return [] }
        return pids.filter { $0 > 0 }
    }

    private func processPath(pid: Int32) -> String {
        var buffer = [CChar](repeating: 0, count: Int(MAXPATHLEN))
        let length = proc_pidpath(pid, &buffer, UInt32(buffer.count))
        guard length > 0 else { return "" }
        return String(cString: buffer)
    }

    private func processState(_ status: Int32) -> String {
        switch status {
        case 1: return "Idle"
        case 2: return "Running"
        case 3: return "Sleeping"
        case 4: return "Stopped"
        case 5: return "Zombie"
        default: return "Unknown"
        }
    }

    private func userName(uid: uid_t) -> String {
        guard let user = getpwuid(uid), let name = user.pointee.pw_name else {
            return "\(uid)"
        }
        return String(cString: name)
    }

    private func stringFromTuple<T>(_ tuple: inout T) -> String {
        withUnsafePointer(to: &tuple) { pointer in
            pointer.withMemoryRebound(to: CChar.self, capacity: MemoryLayout<T>.size) { cString in
                String(cString: cString)
            }
        }
    }
}
