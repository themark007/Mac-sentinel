import AppKit
import Foundation

enum AppInventory {
    static func scan() -> [ManagedApp] {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let roots = [
            "/Applications",
            "\(home)/Applications",
            "/System/Applications",
            "/System/Applications/Utilities",
            "/System/Volumes/Preboot/Cryptexes/App/System/Applications"
        ]

        var running: [String: NSRunningApplication] = [:]
        for app in NSWorkspace.shared.runningApplications {
            guard let path = app.bundleURL?.path else { continue }
            running[path] = app
        }

        var seen = Set<String>()
        var apps: [ManagedApp] = []

        for root in roots where FileManager.default.fileExists(atPath: root) {
            guard let enumerator = FileManager.default.enumerator(
                at: URL(fileURLWithPath: root),
                includingPropertiesForKeys: [.contentModificationDateKey, .isDirectoryKey],
                options: [.skipsHiddenFiles],
                errorHandler: { _, _ in true }
            ) else {
                continue
            }

            for case let url as URL in enumerator {
                guard url.pathExtension == "app" else { continue }
                enumerator.skipDescendants()
                guard !seen.contains(url.path) else { continue }
                seen.insert(url.path)

                let values = try? url.resourceValues(forKeys: [.contentModificationDateKey])
                let runningApp = running[url.path]
                let system = url.path.hasPrefix("/System/") ||
                    url.path.hasPrefix("/System/Volumes/") ||
                    url.path.hasPrefix("/Applications/Xcode.app/Contents/")

                apps.append(ManagedApp(
                    name: url.deletingPathExtension().lastPathComponent,
                    path: url.path,
                    sizeBytes: FileSizing.allocatedSize(of: url, limit: 120_000),
                    modifiedAt: values?.contentModificationDate,
                    isRunning: runningApp != nil,
                    pid: runningApp?.processIdentifier,
                    isSystemApp: system
                ))
            }
        }

        return apps.sorted {
            if $0.isRunning != $1.isRunning { return $0.isRunning && !$1.isRunning }
            if $0.sizeBytes != $1.sizeBytes { return $0.sizeBytes > $1.sizeBytes }
            return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }

    static func reveal(path: String) {
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)])
    }

    static func quit(pid: Int32?) {
        guard let pid,
              let app = NSRunningApplication(processIdentifier: pid) else {
            return
        }
        app.terminate()
    }

    static func moveToTrash(path: String) throws {
        let url = URL(fileURLWithPath: path)
        guard path.hasPrefix("/Applications/") ||
                path.hasPrefix("\(FileManager.default.homeDirectoryForCurrentUser.path)/Applications/") else {
            return
        }
        var resultingURL: NSURL?
        try FileManager.default.trashItem(at: url, resultingItemURL: &resultingURL)
    }
}

enum ProcessActions {
    static func terminate(pid: Int32) {
        kill(pid, SIGTERM)
    }

    static func forceQuit(pid: Int32) {
        kill(pid, SIGKILL)
    }

    static func reveal(path: String) {
        guard !path.isEmpty else { return }
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)])
    }
}
