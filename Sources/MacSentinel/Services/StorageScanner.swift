import Foundation

struct StorageScanResult {
    var volumes: [DiskVolume]
    var buckets: [StorageBucket]
}

enum StorageScanner {
    static func scan() async -> StorageScanResult {
        let volumes = mountedVolumes()
        let buckets = await scanBuckets()
        return StorageScanResult(volumes: volumes, buckets: buckets)
    }

    static func mountedVolumes() -> [DiskVolume] {
        let keys: Set<URLResourceKey> = [
            .volumeLocalizedNameKey,
            .volumeTotalCapacityKey,
            .volumeAvailableCapacityKey,
            .volumeIsInternalKey
        ]

        let urls = FileManager.default.mountedVolumeURLs(
            includingResourceValuesForKeys: Array(keys),
            options: [.skipHiddenVolumes]
        ) ?? [URL(fileURLWithPath: "/")]

        return urls.compactMap { url in
            guard let values = try? url.resourceValues(forKeys: keys) else { return nil }
            let total = UInt64(max(0, values.volumeTotalCapacity ?? 0))
            let available = UInt64(max(0, values.volumeAvailableCapacity ?? 0))
            guard total > 0 else { return nil }
            return DiskVolume(
                name: values.volumeLocalizedName ?? url.path,
                mountPath: url.path,
                totalBytes: total,
                availableBytes: available,
                isInternal: values.volumeIsInternal ?? false
            )
        }
        .sorted { $0.mountPath < $1.mountPath }
    }

    static func clean(bucket: StorageBucket) async throws -> UInt64 {
        guard bucket.cleanable else { return 0 }
        let url = URL(fileURLWithPath: bucket.path)
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: url.path) else { return 0 }

        let before = await duSize(url.path)
        let contents = try fileManager.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: nil,
            options: []
        )

        for item in contents {
            var resultingURL: NSURL?
            try? fileManager.trashItem(at: item, resultingItemURL: &resultingURL)
        }

        return before
    }

    private static func scanBuckets() async -> [StorageBucket] {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let entries: [(String, String, StorageCategory, Bool, String)] = [
            ("Applications", "/Applications", .application, false, "Installed apps"),
            ("User Applications", "\(home)/Applications", .application, false, "User app bundles"),
            ("Downloads", "\(home)/Downloads", .user, false, "Downloads"),
            ("Desktop", "\(home)/Desktop", .user, false, "Desktop files"),
            ("Documents", "\(home)/Documents", .user, false, "Documents"),
            ("Movies", "\(home)/Movies", .media, false, "Video libraries"),
            ("Pictures", "\(home)/Pictures", .media, false, "Photo libraries"),
            ("Music", "\(home)/Music", .media, false, "Audio libraries"),
            ("User Caches", "\(home)/Library/Caches", .cache, true, "Recoverable cache files"),
            ("System Caches", "/Library/Caches", .cache, false, "Shared cache files"),
            ("App Support", "\(home)/Library/Application Support", .container, false, "App data"),
            ("App Containers", "\(home)/Library/Containers", .container, false, "Sandbox data"),
            ("Group Containers", "\(home)/Library/Group Containers", .container, false, "Shared app data"),
            ("Logs", "\(home)/Library/Logs", .cache, true, "Diagnostic logs"),
            ("Xcode DerivedData", "\(home)/Library/Developer/Xcode/DerivedData", .developer, true, "Build cache"),
            ("Xcode Archives", "\(home)/Library/Developer/Xcode/Archives", .developer, false, "Archived builds"),
            ("CoreSimulator", "\(home)/Library/Developer/CoreSimulator", .developer, true, "Simulator data"),
            ("Docker Home", "\(home)/.docker", .container, false, "Docker metadata"),
            ("Colima", "\(home)/.colima", .container, false, "Colima VMs"),
            ("Lima", "\(home)/.lima", .container, false, "Lima VMs"),
            ("OrbStack", "\(home)/Library/Group Containers/dev.orbstack", .container, false, "OrbStack data"),
            ("Trash", "\(home)/.Trash", .trash, false, "Trash contents"),
            ("Temp Folders", "/private/var/folders", .system, false, "macOS temp area")
        ]

        var buckets: [StorageBucket] = []
        for entry in entries {
            guard FileManager.default.fileExists(atPath: entry.1) else { continue }
            let size = await duSize(entry.1)
            guard size > 0 else { continue }
            buckets.append(StorageBucket(
                title: entry.0,
                path: entry.1,
                sizeBytes: size,
                category: entry.2,
                cleanable: entry.3,
                note: entry.4
            ))
        }

        return buckets.sorted { $0.sizeBytes > $1.sizeBytes }
    }

    private static func duSize(_ path: String) async -> UInt64 {
        let command = "/usr/bin/du -skx \(path.shellEscaped) 2>/dev/null | /usr/bin/awk '{print $1}'"
        let result = await Shell.run(command, timeout: 25)
        guard let first = result.stdout
            .split(whereSeparator: \.isNewline)
            .first,
            let kb = UInt64(first.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            return 0
        }
        return kb * 1024
    }
}
