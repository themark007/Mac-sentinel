import Foundation

enum FileSizing {
    static func allocatedSize(of url: URL, limit: Int = 250_000) -> UInt64 {
        let keys: Set<URLResourceKey> = [
            .isRegularFileKey,
            .isDirectoryKey,
            .isSymbolicLinkKey,
            .totalFileAllocatedSizeKey,
            .fileAllocatedSizeKey
        ]

        if let values = try? url.resourceValues(forKeys: keys),
           values.isRegularFile == true || values.isSymbolicLink == true {
            return UInt64(values.totalFileAllocatedSize ?? values.fileAllocatedSize ?? 0)
        }

        guard let enumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: Array(keys),
            options: [.skipsHiddenFiles],
            errorHandler: { _, _ in true }
        ) else {
            return 0
        }

        var total: UInt64 = 0
        var visited = 0
        for case let file as URL in enumerator {
            visited += 1
            if visited > limit { break }
            guard let values = try? file.resourceValues(forKeys: keys),
                  values.isDirectory != true else {
                continue
            }
            total += UInt64(values.totalFileAllocatedSize ?? values.fileAllocatedSize ?? 0)
        }
        return total
    }
}
