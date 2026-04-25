import Foundation

@MainActor
final class SystemSampler: ObservableObject {
    @Published var cpu = CPUSnapshot()
    @Published var memory = MemorySnapshot()
    @Published var processes: [ProcessSample] = []
    @Published var volumes: [DiskVolume] = []
    @Published var storageBuckets: [StorageBucket] = []
    @Published var runtimes: [ContainerRuntime] = []
    @Published var containers: [ContainerItem] = []
    @Published var apps: [ManagedApp] = []
    @Published var alertSettings = PreferencesStore.loadAlertSettings() {
        didSet {
            PreferencesStore.saveAlertSettings(alertSettings)
            if alertSettings.notificationsEnabled {
                NotificationService.requestAuthorization()
            }
        }
    }
    @Published var alertEvents: [AlertEvent] = []
    @Published var isScanningStorage = false
    @Published var isScanningApps = false
    @Published var isScanningContainers = false
    @Published var lastRefresh = Date()
    @Published var statusMessage = "Starting collectors"

    private let cpuReader = CPUReader()
    private let processSampler = ProcessSampler()
    private var lastAlertTimes: [String: Date] = [:]
    private var fastLoop: Task<Void, Never>?
    private var slowLoop: Task<Void, Never>?

    var flaggedProcesses: [ProcessSample] {
        Array(processes.filter(\.isFlagged).prefix(8))
    }

    var rootVolume: DiskVolume? {
        volumes.first { $0.mountPath == "/" } ?? volumes.first
    }

    var insights: [SystemInsight] {
        InsightEngine.make(snapshot: snapshot())
    }

    var health: HealthLevel {
        let cpuHealth: HealthLevel = cpu.usage > 92 ? .critical : cpu.usage > 78 ? .hot : cpu.usage > 60 ? .watch : .good
        let diskHealth: HealthLevel
        if let rootVolume {
            diskHealth = rootVolume.usedRatio > 0.94 ? .critical : rootVolume.usedRatio > 0.86 ? .hot : rootVolume.usedRatio > 0.76 ? .watch : .good
        } else {
            diskHealth = .good
        }
        let processHealth: HealthLevel = flaggedProcesses.contains(where: { $0.flags.contains(.zombie) || $0.flags.contains(.stopped) }) ? .hot : .good
        return [cpuHealth, memory.pressure, diskHealth, processHealth].max { $0.rank < $1.rank } ?? .good
    }

    func start() {
        guard fastLoop == nil else { return }
        if alertSettings.notificationsEnabled {
            NotificationService.requestAuthorization()
        }

        fastLoop = Task { [weak self] in
            while !Task.isCancelled {
                await self?.refreshFast()
                let seconds = self?.alertSettings.sampleIntervalSeconds ?? 2
                try? await Task.sleep(nanoseconds: UInt64(max(1, seconds) * 1_000_000_000))
            }
        }

        slowLoop = Task { [weak self] in
            await self?.refreshStorage()
            await self?.refreshContainers()
            await self?.refreshApps()

            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 45_000_000_000)
                if self?.alertSettings.autoRefreshStorage == true {
                    await self?.refreshStorage()
                }
                await self?.refreshContainers()
            }
        }
    }

    func stop() {
        fastLoop?.cancel()
        slowLoop?.cancel()
        fastLoop = nil
        slowLoop = nil
    }

    func refreshFast() async {
        cpu = cpuReader.sample()
        memory = MemoryReader.sample()
        processes = Array(processSampler.sample().prefix(160))
        lastRefresh = Date()
        statusMessage = "Live"
        evaluateAlerts()
    }

    func refreshStorage() async {
        guard !isScanningStorage else { return }
        isScanningStorage = true
        statusMessage = "Scanning storage"
        let result = await StorageScanner.scan()
        volumes = result.volumes
        storageBuckets = result.buckets
        isScanningStorage = false
        statusMessage = "Live"
        evaluateAlerts()
    }

    func refreshContainers() async {
        guard !isScanningContainers else { return }
        isScanningContainers = true
        let result = await ContainerScanner.scan()
        runtimes = result.runtimes
        containers = result.containers
        isScanningContainers = false
    }

    func refreshApps() async {
        guard !isScanningApps else { return }
        isScanningApps = true
        statusMessage = "Indexing apps"
        let indexed = await Task.detached(priority: .utility) {
            AppInventory.scan()
        }.value
        apps = indexed
        isScanningApps = false
        statusMessage = "Live"
    }

    func clean(bucket: StorageBucket) async {
        statusMessage = "Moving cleanup items to Trash"
        do {
            _ = try await StorageScanner.clean(bucket: bucket)
            await refreshStorage()
            statusMessage = "Cleanup moved to Trash"
        } catch {
            statusMessage = "Cleanup failed: \(error.localizedDescription)"
        }
    }

    func quit(app: ManagedApp) {
        AppInventory.quit(pid: app.pid)
        Task { await refreshApps() }
    }

    func trash(app: ManagedApp) async {
        do {
            try AppInventory.moveToTrash(path: app.path)
            await refreshApps()
            await refreshStorage()
            statusMessage = "App moved to Trash"
        } catch {
            statusMessage = "Could not move app: \(error.localizedDescription)"
        }
    }

    func snapshot() -> DashboardSnapshot {
        DashboardSnapshot(
            createdAt: Date(),
            cpu: cpu,
            memory: memory,
            processes: processes,
            volumes: volumes,
            storage: storageBuckets,
            runtimes: runtimes,
            containers: containers,
            apps: apps,
            alerts: alertEvents,
            settings: alertSettings
        )
    }

    func clearAlerts() {
        alertEvents = []
        lastAlertTimes = [:]
    }

    func exportReport(to url: URL) throws {
        try ReportWriter.writeMarkdown(snapshot: snapshot(), insights: insights, to: url)
    }

    private func evaluateAlerts() {
        guard alertSettings.enabled else { return }

        var candidates: [(key: String, event: AlertEvent)] = []

        if cpu.usage >= alertSettings.cpuThreshold {
            candidates.append(("cpu", AlertEvent(
                severity: cpu.usage >= 95 ? .critical : .hot,
                title: "CPU above \(Int(alertSettings.cpuThreshold))%",
                detail: "CPU is currently \(cpu.usage.percentString).",
                symbol: "cpu"
            )))
        }

        let memoryPercent = memory.usedRatio * 100
        if memoryPercent >= alertSettings.memoryThreshold {
            candidates.append(("memory", AlertEvent(
                severity: memoryPercent >= 95 ? .critical : memory.pressure,
                title: "Memory above \(Int(alertSettings.memoryThreshold))%",
                detail: "\(memory.usedBytes.bytesString) of \(memory.totalBytes.bytesString) is in use.",
                symbol: "memorychip"
            )))
        }

        if let rootVolume {
            let storagePercent = rootVolume.usedRatio * 100
            if storagePercent >= alertSettings.storageThreshold {
                candidates.append(("storage", AlertEvent(
                    severity: storagePercent >= 95 ? .critical : .hot,
                    title: "Storage above \(Int(alertSettings.storageThreshold))%",
                    detail: "\(rootVolume.availableBytes.bytesString) free on \(rootVolume.name).",
                    symbol: "internaldrive"
                )))
            }
        }

        if let hotProcess = processes.first(where: { $0.cpuPercent >= alertSettings.processCPUThreshold }) {
            candidates.append(("process-\(hotProcess.pid)", AlertEvent(
                severity: .hot,
                title: "Process CPU spike",
                detail: "\(hotProcess.displayName) is using \(hotProcess.cpuPercent.percentString) CPU.",
                symbol: "bolt.horizontal.circle"
            )))
        }

        for candidate in candidates {
            emit(candidate.event, key: candidate.key)
        }
    }

    private func emit(_ event: AlertEvent, key: String) {
        let now = Date()
        if let last = lastAlertTimes[key], now.timeIntervalSince(last) < 180 {
            return
        }
        lastAlertTimes[key] = now
        alertEvents.insert(event, at: 0)
        if alertEvents.count > 80 {
            alertEvents.removeLast(alertEvents.count - 80)
        }
        if alertSettings.notificationsEnabled {
            NotificationService.send(event)
        }
    }
}
