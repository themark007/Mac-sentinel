import Foundation

enum InsightEngine {
    static func make(snapshot: DashboardSnapshot) -> [SystemInsight] {
        var insights: [SystemInsight] = []

        if snapshot.cpu.usage >= 80 {
            let culprit = snapshot.processes.max { $0.cpuPercent < $1.cpuPercent }
            insights.append(SystemInsight(
                severity: snapshot.cpu.usage >= 92 ? .critical : .hot,
                title: "CPU saturation",
                detail: "CPU is at \(snapshot.cpu.usage.percentString). Top process: \(culprit?.displayName ?? "unknown").",
                recommendation: "Sort Processes by CPU, quit runaway apps, and check browser renderer tabs before force quitting system services.",
                symbol: "cpu",
                metric: snapshot.cpu.usage.percentString
            ))
        }

        if snapshot.memory.pressure.rank >= HealthLevel.watch.rank {
            let top = snapshot.processes.max { $0.memoryBytes < $1.memoryBytes }
            insights.append(SystemInsight(
                severity: snapshot.memory.pressure,
                title: "Memory pressure rising",
                detail: "RAM is \(Int(snapshot.memory.usedRatio * 100))% used with \(snapshot.memory.compressedBytes.bytesString) compressed.",
                recommendation: "Close the biggest memory apps first. Current largest process: \(top?.displayName ?? "unknown") using \(top?.memoryBytes.bytesString ?? "unknown").",
                symbol: "memorychip",
                metric: snapshot.memory.usedBytes.bytesString
            ))
        }

        if let root = snapshot.volumes.first(where: { $0.mountPath == "/" }), root.usedRatio >= 0.80 {
            let biggest = snapshot.storage.first
            insights.append(SystemInsight(
                severity: root.usedRatio >= 0.94 ? .critical : root.usedRatio >= 0.88 ? .hot : .watch,
                title: "SSD space is tight",
                detail: "\(root.availableBytes.bytesString) free on \(root.name). Biggest bucket: \(biggest?.title ?? "unknown").",
                recommendation: "Start with Downloads, media libraries, Xcode data, containers, and caches. Use clean buttons only for recoverable cache buckets.",
                symbol: "internaldrive",
                metric: "\(Int(root.usedRatio * 100))%"
            ))
        }

        if let threadHot = snapshot.processes.filter({ $0.threads > 80 }).max(by: { $0.threads < $1.threads }) {
            insights.append(SystemInsight(
                severity: .watch,
                title: "Thread-heavy process",
                detail: "\(threadHot.displayName) is running \(threadHot.threads) threads.",
                recommendation: "If the app feels stuck, reveal it, try a normal quit first, then terminate only if it remains unresponsive.",
                symbol: "rectangle.stack.badge.person.crop",
                metric: "\(threadHot.threads)"
            ))
        }

        if let cache = snapshot.storage.filter({ $0.cleanable }).max(by: { $0.sizeBytes < $1.sizeBytes }), cache.sizeBytes > 1_000_000_000 {
            insights.append(SystemInsight(
                severity: .watch,
                title: "Recoverable cache found",
                detail: "\(cache.title) is using \(cache.sizeBytes.bytesString).",
                recommendation: "Move cache contents to Trash from the Storage tab, then reopen heavy apps so they rebuild only what they need.",
                symbol: "sparkles.rectangle.stack",
                metric: cache.sizeBytes.bytesString
            ))
        }

        if let largeApp = snapshot.apps.max(by: { $0.sizeBytes < $1.sizeBytes }), largeApp.sizeBytes > 5_000_000_000 {
            insights.append(SystemInsight(
                severity: .watch,
                title: "Large app bundle",
                detail: "\(largeApp.name) is \(largeApp.sizeBytes.bytesString).",
                recommendation: "Review large apps you no longer use. MacSentinel only offers Trash for non-system apps.",
                symbol: "square.grid.3x3",
                metric: largeApp.sizeBytes.bytesString
            ))
        }

        if snapshot.containers.isEmpty == false {
            insights.append(SystemInsight(
                severity: .good,
                title: "Container inventory active",
                detail: "MacSentinel sees \(snapshot.containers.count) Docker/Podman containers.",
                recommendation: "Use your runtime CLI to prune stopped containers/images after confirming they are disposable.",
                symbol: "shippingbox",
                metric: "\(snapshot.containers.count)"
            ))
        }

        if insights.isEmpty {
            insights.append(SystemInsight(
                severity: .good,
                title: "System looks calm",
                detail: "CPU, memory, storage, and process health are inside the configured guardrails.",
                recommendation: "Keep alerts enabled and export a report when you want a baseline before installing heavy tools.",
                symbol: "checkmark.seal",
                metric: "OK"
            ))
        }

        return insights.sorted { lhs, rhs in
            if lhs.severity.rank != rhs.severity.rank { return lhs.severity.rank > rhs.severity.rank }
            return lhs.title < rhs.title
        }
    }
}
