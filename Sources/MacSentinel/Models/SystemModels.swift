import Foundation

enum DashboardSection: String, CaseIterable, Identifiable {
    case overview = "Overview"
    case insights = "Insights"
    case processes = "Processes"
    case storage = "Storage"
    case containers = "Containers"
    case apps = "Apps"
    case alerts = "Alerts"
    case sources = "Sources"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .overview: return "gauge.with.dots.needle.bottom.50percent"
        case .insights: return "sparkles"
        case .processes: return "list.bullet.rectangle.portrait"
        case .storage: return "internaldrive"
        case .containers: return "shippingbox"
        case .apps: return "square.grid.3x3"
        case .alerts: return "bell.badge"
        case .sources: return "point.3.connected.trianglepath.dotted"
        }
    }
}

struct CPUSnapshot: Codable, Equatable {
    var usage: Double = 0
    var user: Double = 0
    var system: Double = 0
    var idle: Double = 100
    var loadAverage: [Double] = [0, 0, 0]
    var coreCount: Int = ProcessInfo.processInfo.activeProcessorCount
    var thermalState: String = "Nominal"
}

struct MemorySnapshot: Codable, Equatable {
    var totalBytes: UInt64 = ProcessInfo.processInfo.physicalMemory
    var usedBytes: UInt64 = 0
    var appBytes: UInt64 = 0
    var wiredBytes: UInt64 = 0
    var compressedBytes: UInt64 = 0
    var freeBytes: UInt64 = 0
    var swapOuts: UInt64 = 0
    var pressure: HealthLevel = .good

    var usedRatio: Double {
        guard totalBytes > 0 else { return 0 }
        return min(1, Double(usedBytes) / Double(totalBytes))
    }
}

enum HealthLevel: String, Codable, Equatable {
    case good = "Good"
    case watch = "Watch"
    case hot = "Hot"
    case critical = "Critical"

    var rank: Int {
        switch self {
        case .good: return 0
        case .watch: return 1
        case .hot: return 2
        case .critical: return 3
        }
    }
}

struct AlertSettings: Codable, Equatable {
    var enabled: Bool = true
    var notificationsEnabled: Bool = false
    var cpuThreshold: Double = 85
    var memoryThreshold: Double = 88
    var storageThreshold: Double = 90
    var processCPUThreshold: Double = 120
    var sampleIntervalSeconds: Double = 2
    var autoRefreshStorage: Bool = true

    static let defaults = AlertSettings()
}

struct AlertEvent: Identifiable, Codable, Equatable {
    var id = UUID()
    var createdAt = Date()
    var severity: HealthLevel
    var title: String
    var detail: String
    var symbol: String
}

struct SystemInsight: Identifiable, Codable, Equatable {
    var id = UUID()
    var severity: HealthLevel
    var title: String
    var detail: String
    var recommendation: String
    var symbol: String
    var metric: String
}

struct ProcessSample: Identifiable, Codable, Equatable {
    var id: Int32 { pid }
    var pid: Int32
    var parentPID: Int32
    var user: String
    var command: String
    var path: String
    var cpuPercent: Double
    var memoryBytes: UInt64
    var virtualBytes: UInt64
    var threads: Int
    var runningThreads: Int
    var state: String
    var priority: Int
    var flags: [ProcessFlag]

    var displayName: String {
        if !command.isEmpty { return command }
        return URL(fileURLWithPath: path).lastPathComponent
    }

    var isFlagged: Bool { !flags.isEmpty }
}

enum ProcessFlag: String, Codable, Equatable, CaseIterable {
    case highCPU = "High CPU"
    case highMemory = "High RAM"
    case manyThreads = "Thread spike"
    case stopped = "Stopped"
    case zombie = "Zombie"
    case unknownPath = "Unknown path"
}

struct DiskVolume: Identifiable, Codable, Equatable {
    var id: String { mountPath }
    var name: String
    var mountPath: String
    var totalBytes: UInt64
    var availableBytes: UInt64
    var isInternal: Bool

    var usedBytes: UInt64 {
        totalBytes > availableBytes ? totalBytes - availableBytes : 0
    }

    var usedRatio: Double {
        guard totalBytes > 0 else { return 0 }
        return min(1, Double(usedBytes) / Double(totalBytes))
    }
}

struct StorageBucket: Identifiable, Codable, Equatable {
    var id: String { path }
    var title: String
    var path: String
    var sizeBytes: UInt64
    var category: StorageCategory
    var cleanable: Bool
    var note: String
}

enum StorageCategory: String, Codable, Equatable, CaseIterable {
    case user = "User"
    case cache = "Cache"
    case developer = "Developer"
    case container = "Container"
    case application = "Application"
    case media = "Media"
    case system = "System"
    case trash = "Trash"
}

struct ContainerRuntime: Identifiable, Codable, Equatable {
    var id: String { name }
    var name: String
    var status: String
    var installed: Bool
}

struct ContainerItem: Identifiable, Codable, Equatable {
    var id: String
    var runtime: String
    var name: String
    var image: String
    var status: String
    var size: String
}

struct ManagedApp: Identifiable, Codable, Equatable {
    var id: String { path }
    var name: String
    var path: String
    var sizeBytes: UInt64
    var modifiedAt: Date?
    var isRunning: Bool
    var pid: Int32?
    var isSystemApp: Bool
}

struct DashboardSnapshot: Codable {
    var createdAt: Date
    var cpu: CPUSnapshot
    var memory: MemorySnapshot
    var processes: [ProcessSample]
    var volumes: [DiskVolume]
    var storage: [StorageBucket]
    var runtimes: [ContainerRuntime]
    var containers: [ContainerItem]
    var apps: [ManagedApp]
    var alerts: [AlertEvent] = []
    var settings: AlertSettings = .defaults
}

extension UInt64 {
    var bytesString: String {
        ByteCountFormatter.storage.string(fromByteCount: Int64(self))
    }
}

extension Int64 {
    var bytesString: String {
        ByteCountFormatter.storage.string(fromByteCount: self)
    }
}

extension Double {
    var percentString: String {
        String(format: "%.0f%%", self)
    }
}

extension ByteCountFormatter {
    static let storage: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB, .useTB]
        formatter.countStyle = .file
        formatter.includesUnit = true
        formatter.isAdaptive = true
        return formatter
    }()
}
