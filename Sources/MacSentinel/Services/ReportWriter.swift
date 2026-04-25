import Foundation

enum ReportWriter {
    static func markdown(snapshot: DashboardSnapshot, insights: [SystemInsight]) -> String {
        var lines: [String] = []
        lines.append("# MacSentinel Health Report")
        lines.append("")
        lines.append("Generated: \(snapshot.createdAt.formatted(date: .abbreviated, time: .standard))")
        lines.append("Host: \(Host.current().localizedName ?? "Local Mac")")
        lines.append("")
        lines.append("## Summary")
        lines.append("")
        lines.append("- CPU: \(snapshot.cpu.usage.percentString), load \(snapshot.cpu.loadAverage.map { String(format: "%.2f", $0) }.joined(separator: ", "))")
        lines.append("- Memory: \(snapshot.memory.usedBytes.bytesString) used of \(snapshot.memory.totalBytes.bytesString), pressure \(snapshot.memory.pressure.rawValue)")
        if let root = snapshot.volumes.first(where: { $0.mountPath == "/" }) ?? snapshot.volumes.first {
            lines.append("- Storage: \(root.usedBytes.bytesString) used of \(root.totalBytes.bytesString), \(root.availableBytes.bytesString) free")
        }
        lines.append("- Processes sampled: \(snapshot.processes.count)")
        lines.append("- Apps indexed: \(snapshot.apps.count)")
        lines.append("- Containers: \(snapshot.containers.count)")
        lines.append("")

        lines.append("## Recommendations")
        lines.append("")
        for insight in insights {
            lines.append("- **\(insight.title)** (\(insight.severity.rawValue)): \(insight.detail) \(insight.recommendation)")
        }
        lines.append("")

        lines.append("## Top Processes")
        lines.append("")
        lines.append("| Process | PID | CPU | Memory | Threads | State |")
        lines.append("| --- | ---: | ---: | ---: | ---: | --- |")
        for process in snapshot.processes.prefix(15) {
            lines.append("| \(escape(process.displayName)) | \(process.pid) | \(process.cpuPercent.percentString) | \(process.memoryBytes.bytesString) | \(process.threads) | \(process.state) |")
        }
        lines.append("")

        lines.append("## Storage Buckets")
        lines.append("")
        lines.append("| Bucket | Category | Size | Path |")
        lines.append("| --- | --- | ---: | --- |")
        for bucket in snapshot.storage.prefix(18) {
            lines.append("| \(escape(bucket.title)) | \(bucket.category.rawValue) | \(bucket.sizeBytes.bytesString) | `\(bucket.path)` |")
        }
        lines.append("")

        lines.append("## Recent Alerts")
        lines.append("")
        if snapshot.alerts.isEmpty {
            lines.append("No alerts recorded in this session.")
        } else {
            for alert in snapshot.alerts.prefix(20) {
                lines.append("- \(alert.createdAt.formatted(date: .omitted, time: .standard)) **\(alert.title)**: \(alert.detail)")
            }
        }

        return lines.joined(separator: "\n")
    }

    static func writeMarkdown(snapshot: DashboardSnapshot, insights: [SystemInsight], to url: URL) throws {
        try markdown(snapshot: snapshot, insights: insights).write(to: url, atomically: true, encoding: .utf8)
    }

    private static func escape(_ text: String) -> String {
        text
            .replacingOccurrences(of: "|", with: "\\|")
            .replacingOccurrences(of: "\n", with: " ")
    }
}
