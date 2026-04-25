import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @EnvironmentObject private var sampler: SystemSampler
    @State private var selected: DashboardSection = .overview
    @State private var cpuHistory: [Double] = Array(repeating: 0, count: 40)
    @State private var memoryHistory: [Double] = Array(repeating: 0, count: 40)

    var body: some View {
        ZStack {
            Palette.background.ignoresSafeArea()
            HStack(spacing: 0) {
                Sidebar(selected: $selected)
                    .environmentObject(sampler)

                Rectangle()
                    .fill(Color.white.opacity(0.06))
                    .frame(width: 1)

                VStack(spacing: 0) {
                    HeaderBar(selected: selected)
                        .environmentObject(sampler)

                    ScrollView {
                        Group {
                            switch selected {
                            case .overview:
                                OverviewView(cpuHistory: cpuHistory, memoryHistory: memoryHistory)
                                    .environmentObject(sampler)
                            case .insights:
                                InsightsView()
                                    .environmentObject(sampler)
                            case .processes:
                                ProcessesView()
                                    .environmentObject(sampler)
                            case .storage:
                                StorageView()
                                    .environmentObject(sampler)
                            case .containers:
                                ContainersView()
                                    .environmentObject(sampler)
                            case .apps:
                                AppsView()
                                    .environmentObject(sampler)
                            case .alerts:
                                AlertsView()
                                    .environmentObject(sampler)
                            case .sources:
                                SourcesView()
                                    .environmentObject(sampler)
                            }
                        }
                        .padding(22)
                    }
                }
            }
        }
        .onChange(of: sampler.cpu.usage) { _, newValue in
            append(&cpuHistory, newValue)
        }
        .onChange(of: sampler.memory.usedRatio) { _, newValue in
            append(&memoryHistory, newValue * 100)
        }
    }

    private func append(_ values: inout [Double], _ value: Double) {
        values.append(value)
        if values.count > 44 {
            values.removeFirst(values.count - 44)
        }
    }
}

private struct Sidebar: View {
    @EnvironmentObject private var sampler: SystemSampler
    @Binding var selected: DashboardSection

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 12) {
                Image(nsImage: SentinelIcon.make(size: 40))
                    .resizable()
                    .frame(width: 40, height: 40)
                VStack(alignment: .leading, spacing: 2) {
                    Text("MacSentinel")
                        .font(.system(size: 19, weight: .bold, design: .rounded))
                        .foregroundStyle(Palette.text)
                    Text(Host.current().localizedName ?? "Local Mac")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Palette.secondary)
                }
            }
            .padding(.top, 16)

            StatusPill(
                text: sampler.health.rawValue,
                color: Palette.color(for: sampler.health),
                symbol: "heart.text.square"
            )

            VStack(spacing: 6) {
                ForEach(DashboardSection.allCases) { section in
                    Button {
                        selected = section
                    } label: {
                        HStack(spacing: 11) {
                            Image(systemName: section.symbol)
                                .font(.system(size: 14, weight: .semibold))
                                .frame(width: 22)
                            Text(section.rawValue)
                                .font(.system(size: 13, weight: .semibold))
                            Spacer()
                        }
                        .foregroundStyle(selected == section ? Palette.text : Palette.secondary)
                        .padding(.horizontal, 12)
                        .frame(height: 38)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(selected == section ? Color.white.opacity(0.08) : Color.clear)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }

            Spacer()

            VStack(alignment: .leading, spacing: 10) {
                MiniLine(label: "CPU", value: sampler.cpu.usage / 100, tint: Palette.cyan)
                MiniLine(label: "RAM", value: sampler.memory.usedRatio, tint: Palette.mint)
                if let root = sampler.rootVolume {
                    MiniLine(label: "SSD", value: root.usedRatio, tint: Palette.amber)
                }
            }
            .padding(12)
            .panel()

            Text(sampler.statusMessage)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Palette.muted)
                .padding(.bottom, 16)
        }
        .padding(.horizontal, 16)
        .frame(width: 228)
        .background(Color(hex: 0x080809))
    }
}

private struct MiniLine: View {
    var label: String
    var value: Double
    var tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(label)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Palette.secondary)
                Spacer()
                Text(String(format: "%.0f%%", value * 100))
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(tint)
            }
            ProgressLine(value: value, tint: tint)
                .frame(height: 6)
        }
    }
}

private struct HeaderBar: View {
    @EnvironmentObject private var sampler: SystemSampler
    var selected: DashboardSection

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                Text(selected.rawValue)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(Palette.text)
                Text("Updated \(sampler.lastRefresh.formatted(date: .omitted, time: .standard))")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Palette.secondary)
            }

            Spacer()

            StatusPill(
                text: "\(sampler.processes.count) processes",
                color: Palette.cyan,
                symbol: "cpu"
            )

            IconButton(symbol: "arrow.clockwise", tint: Palette.mint, help: "Refresh") {
                Task {
                    await sampler.refreshFast()
                    await sampler.refreshStorage()
                    await sampler.refreshContainers()
                }
            }
        }
        .padding(.horizontal, 22)
        .frame(height: 72)
        .background(Color(hex: 0x080809))
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.white.opacity(0.06))
                .frame(height: 1)
        }
    }
}

private struct OverviewView: View {
    @EnvironmentObject private var sampler: SystemSampler
    var cpuHistory: [Double]
    var memoryHistory: [Double]

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 14), count: 4), spacing: 14) {
                MetricTile(
                    title: "CPU",
                    value: sampler.cpu.usage.percentString,
                    subtitle: "\(sampler.cpu.coreCount) cores · \(sampler.cpu.thermalState)",
                    symbol: "cpu",
                    tint: Palette.cyan,
                    progress: sampler.cpu.usage / 100
                )
                MetricTile(
                    title: "Memory",
                    value: sampler.memory.usedBytes.bytesString,
                    subtitle: "\(sampler.memory.totalBytes.bytesString) total · \(sampler.memory.pressure.rawValue)",
                    symbol: "memorychip",
                    tint: Palette.color(for: sampler.memory.pressure),
                    progress: sampler.memory.usedRatio
                )
                MetricTile(
                    title: "Storage",
                    value: sampler.rootVolume?.availableBytes.bytesString ?? "Scanning",
                    subtitle: "available on \(sampler.rootVolume?.name ?? "root")",
                    symbol: "internaldrive",
                    tint: Palette.amber,
                    progress: sampler.rootVolume?.usedRatio
                )
                MetricTile(
                    title: "Flags",
                    value: "\(sampler.flaggedProcesses.count)",
                    subtitle: "hot, stuck, or oversized",
                    symbol: "exclamationmark.triangle",
                    tint: sampler.flaggedProcesses.isEmpty ? Palette.mint : Palette.red,
                    progress: sampler.flaggedProcesses.isEmpty ? 0 : min(1, Double(sampler.flaggedProcesses.count) / 8)
                )
            }

            HStack(alignment: .top, spacing: 14) {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        RingGauge(
                            value: sampler.cpu.usage / 100,
                            label: sampler.cpu.usage.percentString,
                            caption: "CPU",
                            tint: Palette.cyan
                        )
                        VStack(alignment: .leading, spacing: 12) {
                            ChartPanel(title: "CPU Trend", values: cpuHistory, tint: Palette.cyan)
                            HStack(spacing: 8) {
                                StatusPill(text: "User \(sampler.cpu.user.percentString)", color: Palette.cyan)
                                StatusPill(text: "System \(sampler.cpu.system.percentString)", color: Palette.violet)
                                StatusPill(text: "Idle \(sampler.cpu.idle.percentString)", color: Palette.secondary)
                            }
                        }
                    }

                    Divider().overlay(Color.white.opacity(0.08))

                    HStack {
                        RingGauge(
                            value: sampler.memory.usedRatio,
                            label: String(format: "%.0f%%", sampler.memory.usedRatio * 100),
                            caption: "RAM",
                            tint: Palette.color(for: sampler.memory.pressure)
                        )
                        VStack(alignment: .leading, spacing: 12) {
                            ChartPanel(title: "Memory Trend", values: memoryHistory, tint: Palette.mint)
                            MemoryBreakdown(memory: sampler.memory)
                        }
                    }
                }
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
                .panel()

                VStack(alignment: .leading, spacing: 12) {
                    SectionTitle("Pressure List", symbol: "waveform.path.ecg")
                    if sampler.flaggedProcesses.isEmpty {
                        EmptyPanel(symbol: "checkmark.seal", title: "No hot processes", subtitle: "Live sampler has not flagged any local process.")
                    } else {
                        ForEach(sampler.flaggedProcesses) { process in
                            ProcessMiniCard(process: process)
                        }
                    }
                }
                .frame(width: 360)
            }

            StorageStrip()
                .environmentObject(sampler)
        }
    }
}

private struct ChartPanel: View {
    var title: String
    var values: [Double]
    var tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Palette.secondary)
            Sparkline(values: values, tint: tint)
                .frame(height: 58)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.white.opacity(0.035))
        )
    }
}

private struct MemoryBreakdown: View {
    var memory: MemorySnapshot

    var body: some View {
        VStack(spacing: 8) {
            MemoryLine(label: "App", value: memory.appBytes, total: memory.totalBytes, tint: Palette.cyan)
            MemoryLine(label: "Wired", value: memory.wiredBytes, total: memory.totalBytes, tint: Palette.violet)
            MemoryLine(label: "Compressed", value: memory.compressedBytes, total: memory.totalBytes, tint: Palette.amber)
            MemoryLine(label: "Free", value: memory.freeBytes, total: memory.totalBytes, tint: Palette.mint)
        }
    }
}

private struct MemoryLine: View {
    var label: String
    var value: UInt64
    var total: UInt64
    var tint: Color

    var body: some View {
        HStack(spacing: 10) {
            Text(label)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Palette.secondary)
                .frame(width: 86, alignment: .leading)
            ProgressLine(value: total > 0 ? Double(value) / Double(total) : 0, tint: tint)
            Text(value.bytesString)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(Palette.text)
                .frame(width: 80, alignment: .trailing)
        }
        .frame(height: 20)
    }
}

private struct ProcessMiniCard: View {
    var process: ProcessSample

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "bolt.horizontal.circle")
                .foregroundStyle(process.flags.contains(.highCPU) ? Palette.red : Palette.amber)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 3) {
                Text(process.displayName)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Palette.text)
                    .lineLimit(1)
                Text(process.flags.map(\.rawValue).joined(separator: ", "))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Palette.secondary)
                    .lineLimit(1)
            }
            Spacer()
            Text(process.memoryBytes.bytesString)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(Palette.mint)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Palette.panelRaised)
        )
    }
}

private struct StorageStrip: View {
    @EnvironmentObject private var sampler: SystemSampler

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle("Big Storage Buckets", symbol: "chart.bar.xaxis")
            ForEach(Array(sampler.storageBuckets.prefix(7))) { bucket in
                HStack(spacing: 12) {
                    StatusPill(text: bucket.category.rawValue, color: Palette.color(for: bucket.category))
                        .frame(width: 116, alignment: .leading)
                    VStack(alignment: .leading, spacing: 5) {
                        HStack {
                            Text(bucket.title)
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(Palette.text)
                            Spacer()
                            Text(bucket.sizeBytes.bytesString)
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundStyle(Palette.text)
                        }
                        ProgressLine(value: storageRatio(bucket), tint: Palette.color(for: bucket.category))
                    }
                }
                .frame(height: 38)
            }
        }
        .padding(16)
        .panel()
    }

    private func storageRatio(_ bucket: StorageBucket) -> Double {
        guard let max = sampler.storageBuckets.first?.sizeBytes, max > 0 else { return 0 }
        return Double(bucket.sizeBytes) / Double(max)
    }
}

private enum ProcessSort: String, CaseIterable, Identifiable {
    case cpu = "CPU"
    case memory = "Memory"
    case threads = "Threads"
    case flags = "Flags"
    var id: String { rawValue }
}

private struct ProcessesView: View {
    @EnvironmentObject private var sampler: SystemSampler
    @State private var query = ""
    @State private var sort: ProcessSort = .cpu
    @State private var pendingTerminate: ProcessSample?

    private var filtered: [ProcessSample] {
        let base = query.isEmpty ? sampler.processes : sampler.processes.filter {
            $0.displayName.localizedCaseInsensitiveContains(query) ||
                $0.user.localizedCaseInsensitiveContains(query) ||
                "\($0.pid)".contains(query)
        }
        switch sort {
        case .cpu:
            return base.sorted { $0.cpuPercent > $1.cpuPercent }
        case .memory:
            return base.sorted { $0.memoryBytes > $1.memoryBytes }
        case .threads:
            return base.sorted { $0.threads > $1.threads }
        case .flags:
            return base.sorted { $0.flags.count > $1.flags.count }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ControlRow(
                query: $query,
                placeholder: "Search process, user, pid",
                isBusy: false,
                refresh: { Task { await sampler.refreshFast() } }
            ) {
                Picker("Sort", selection: $sort) {
                    ForEach(ProcessSort.allCases) { option in
                        Text(option.rawValue).tag(option)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 300)
            }

            VStack(spacing: 0) {
                ProcessHeader()
                ForEach(Array(filtered.prefix(120))) { process in
                    ProcessRow(process: process) {
                        pendingTerminate = process
                    }
                }
            }
            .panel()
        }
        .alert("Terminate process?", isPresented: Binding(
            get: { pendingTerminate != nil },
            set: { if !$0 { pendingTerminate = nil } }
        )) {
            Button("Terminate", role: .destructive) {
                if let pendingTerminate {
                    ProcessActions.terminate(pid: pendingTerminate.pid)
                    Task { await sampler.refreshFast() }
                }
                pendingTerminate = nil
            }
            Button("Cancel", role: .cancel) {
                pendingTerminate = nil
            }
        } message: {
            Text(pendingTerminate?.displayName ?? "")
        }
    }
}

private struct ProcessHeader: View {
    var body: some View {
        HStack(spacing: 12) {
            Text("Process").frame(maxWidth: .infinity, alignment: .leading)
            Text("PID").frame(width: 68, alignment: .trailing)
            Text("CPU").frame(width: 70, alignment: .trailing)
            Text("RAM").frame(width: 88, alignment: .trailing)
            Text("Threads").frame(width: 76, alignment: .trailing)
            Text("State").frame(width: 92, alignment: .leading)
            Text("").frame(width: 76)
        }
        .font(.system(size: 11, weight: .bold))
        .foregroundStyle(Palette.muted)
        .padding(.horizontal, 14)
        .frame(height: 38)
        .background(Color.white.opacity(0.025))
    }
}

private struct ProcessRow: View {
    var process: ProcessSample
    var terminate: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Text(process.displayName)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Palette.text)
                        .lineLimit(1)
                    if process.isFlagged {
                        Image(systemName: "flag.fill")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Palette.red)
                    }
                }
                Text(shortPath(process.path.isEmpty ? process.user : process.path))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Palette.muted)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text("\(process.pid)").frame(width: 68, alignment: .trailing)
            Text(process.cpuPercent.percentString).frame(width: 70, alignment: .trailing)
            Text(process.memoryBytes.bytesString).frame(width: 88, alignment: .trailing)
            Text("\(process.threads)").frame(width: 76, alignment: .trailing)
            Text(process.state).frame(width: 92, alignment: .leading)
            HStack(spacing: 6) {
                IconButton(symbol: "arrow.forward.square", tint: Palette.cyan, help: "Reveal executable") {
                    ProcessActions.reveal(path: process.path)
                }
                IconButton(symbol: "xmark", tint: Palette.red, help: "Terminate") {
                    terminate()
                }
            }
            .frame(width: 76)
        }
        .font(.system(size: 12, weight: .medium, design: .rounded))
        .foregroundStyle(Palette.secondary)
        .padding(.horizontal, 14)
        .frame(height: 58)
        .background(process.isFlagged ? Palette.red.opacity(0.045) : Color.clear)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.white.opacity(0.05)).frame(height: 1)
        }
    }
}

private struct StorageView: View {
    @EnvironmentObject private var sampler: SystemSampler
    @State private var pendingClean: StorageBucket?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ControlRow(
                query: .constant(""),
                placeholder: "",
                isBusy: sampler.isScanningStorage,
                refresh: { Task { await sampler.refreshStorage() } },
                trailing: { EmptyView() }
            )

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 14), count: 3), spacing: 14) {
                ForEach(sampler.volumes) { volume in
                    VolumeCard(volume: volume)
                }
            }

            VStack(spacing: 0) {
                StorageHeader()
                ForEach(sampler.storageBuckets) { bucket in
                    StorageRow(bucket: bucket, maxSize: sampler.storageBuckets.first?.sizeBytes ?? 1) {
                        pendingClean = bucket
                    }
                }
            }
            .panel()
        }
        .alert("Move contents to Trash?", isPresented: Binding(
            get: { pendingClean != nil },
            set: { if !$0 { pendingClean = nil } }
        )) {
            Button("Clean", role: .destructive) {
                if let pendingClean {
                    Task { await sampler.clean(bucket: pendingClean) }
                }
                pendingClean = nil
            }
            Button("Cancel", role: .cancel) {
                pendingClean = nil
            }
        } message: {
            Text(pendingClean?.path ?? "")
        }
    }
}

private struct VolumeCard: View {
    var volume: DiskVolume

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: volume.isInternal ? "internaldrive" : "externaldrive")
                    .foregroundStyle(Palette.amber)
                    .font(.system(size: 18, weight: .semibold))
                Spacer()
                Text(String(format: "%.0f%%", volume.usedRatio * 100))
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(Palette.amber)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(volume.name)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Palette.text)
                    .lineLimit(1)
                Text(shortPath(volume.mountPath))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Palette.secondary)
            }
            ProgressLine(value: volume.usedRatio, tint: Palette.amber)
            HStack {
                Text("\(volume.usedBytes.bytesString) used")
                Spacer()
                Text("\(volume.availableBytes.bytesString) free")
            }
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(Palette.muted)
        }
        .padding(16)
        .panel()
    }
}

private struct StorageHeader: View {
    var body: some View {
        HStack(spacing: 12) {
            Text("Bucket").frame(maxWidth: .infinity, alignment: .leading)
            Text("Type").frame(width: 118, alignment: .leading)
            Text("Size").frame(width: 100, alignment: .trailing)
            Text("").frame(width: 76)
        }
        .font(.system(size: 11, weight: .bold))
        .foregroundStyle(Palette.muted)
        .padding(.horizontal, 14)
        .frame(height: 38)
        .background(Color.white.opacity(0.025))
    }
}

private struct StorageRow: View {
    var bucket: StorageBucket
    var maxSize: UInt64
    var clean: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text(bucket.title)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Palette.text)
                    Text(bucket.note)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Palette.muted)
                        .lineLimit(1)
                }
                ProgressLine(value: maxSize > 0 ? Double(bucket.sizeBytes) / Double(maxSize) : 0, tint: Palette.color(for: bucket.category))
                    .frame(height: 6)
                Text(shortPath(bucket.path))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Palette.muted)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            StatusPill(text: bucket.category.rawValue, color: Palette.color(for: bucket.category))
                .frame(width: 118, alignment: .leading)
            Text(bucket.sizeBytes.bytesString)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(Palette.text)
                .frame(width: 100, alignment: .trailing)
            HStack(spacing: 6) {
                IconButton(symbol: "arrow.forward.square", tint: Palette.cyan, help: "Reveal") {
                    AppInventory.reveal(path: bucket.path)
                }
                if bucket.cleanable {
                    IconButton(symbol: "trash", tint: Palette.red, help: "Clean to Trash") {
                        clean()
                    }
                }
            }
            .frame(width: 76)
        }
        .padding(.horizontal, 14)
        .frame(height: 68)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.white.opacity(0.05)).frame(height: 1)
        }
    }
}

private struct ContainersView: View {
    @EnvironmentObject private var sampler: SystemSampler

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ControlRow(
                query: .constant(""),
                placeholder: "",
                isBusy: sampler.isScanningContainers,
                refresh: { Task { await sampler.refreshContainers() } },
                trailing: { EmptyView() }
            )

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 14), count: 5), spacing: 14) {
                ForEach(sampler.runtimes) { runtime in
                    RuntimeCard(runtime: runtime)
                }
            }

            if sampler.containers.isEmpty {
                EmptyPanel(symbol: "shippingbox", title: "No containers reported", subtitle: "Docker and Podman collectors are idle or unavailable.")
            } else {
                VStack(spacing: 0) {
                    ContainerHeader()
                    ForEach(sampler.containers) { item in
                        ContainerRow(item: item)
                    }
                }
                .panel()
            }
        }
    }
}

private struct RuntimeCard: View {
    var runtime: ContainerRuntime

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: runtime.installed ? "checkmark.hexagon" : "minus.circle")
                    .foregroundStyle(runtime.installed ? Palette.mint : Palette.muted)
                Spacer()
            }
            Text(runtime.name)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Palette.text)
            Text(runtime.status)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Palette.secondary)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
        }
        .padding(14)
        .frame(minHeight: 118, alignment: .topLeading)
        .panel()
    }
}

private struct ContainerHeader: View {
    var body: some View {
        HStack(spacing: 12) {
            Text("Name").frame(maxWidth: .infinity, alignment: .leading)
            Text("Runtime").frame(width: 100, alignment: .leading)
            Text("Image").frame(width: 260, alignment: .leading)
            Text("Status").frame(width: 220, alignment: .leading)
            Text("Size").frame(width: 130, alignment: .trailing)
        }
        .font(.system(size: 11, weight: .bold))
        .foregroundStyle(Palette.muted)
        .padding(.horizontal, 14)
        .frame(height: 38)
        .background(Color.white.opacity(0.025))
    }
}

private struct ContainerRow: View {
    var item: ContainerItem

    var body: some View {
        HStack(spacing: 12) {
            Text(item.name).frame(maxWidth: .infinity, alignment: .leading)
            Text(item.runtime).frame(width: 100, alignment: .leading)
            Text(item.image).frame(width: 260, alignment: .leading)
            Text(item.status).frame(width: 220, alignment: .leading)
            Text(item.size).frame(width: 130, alignment: .trailing)
        }
        .font(.system(size: 12, weight: .medium))
        .foregroundStyle(Palette.secondary)
        .lineLimit(1)
        .padding(.horizontal, 14)
        .frame(height: 48)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.white.opacity(0.05)).frame(height: 1)
        }
    }
}

private struct AppsView: View {
    @EnvironmentObject private var sampler: SystemSampler
    @State private var query = ""
    @State private var pendingTrash: ManagedApp?

    private var filtered: [ManagedApp] {
        query.isEmpty ? sampler.apps : sampler.apps.filter {
            $0.name.localizedCaseInsensitiveContains(query) ||
                $0.path.localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ControlRow(
                query: $query,
                placeholder: "Search installed apps",
                isBusy: sampler.isScanningApps,
                refresh: { Task { await sampler.refreshApps() } },
                trailing: { EmptyView() }
            )

            VStack(spacing: 0) {
                AppHeader()
                ForEach(filtered) { app in
                    AppRow(app: app) {
                        sampler.quit(app: app)
                    } trash: {
                        pendingTrash = app
                    }
                }
            }
            .panel()
        }
        .alert("Move app to Trash?", isPresented: Binding(
            get: { pendingTrash != nil },
            set: { if !$0 { pendingTrash = nil } }
        )) {
            Button("Trash", role: .destructive) {
                if let pendingTrash {
                    Task { await sampler.trash(app: pendingTrash) }
                }
                pendingTrash = nil
            }
            Button("Cancel", role: .cancel) {
                pendingTrash = nil
            }
        } message: {
            Text(pendingTrash?.path ?? "")
        }
    }
}

private struct AppHeader: View {
    var body: some View {
        HStack(spacing: 12) {
            Text("Application").frame(maxWidth: .infinity, alignment: .leading)
            Text("Size").frame(width: 100, alignment: .trailing)
            Text("Status").frame(width: 92, alignment: .leading)
            Text("Modified").frame(width: 128, alignment: .leading)
            Text("").frame(width: 112)
        }
        .font(.system(size: 11, weight: .bold))
        .foregroundStyle(Palette.muted)
        .padding(.horizontal, 14)
        .frame(height: 38)
        .background(Color.white.opacity(0.025))
    }
}

private struct AppRow: View {
    var app: ManagedApp
    var quit: () -> Void
    var trash: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(app.name)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Palette.text)
                Text(shortPath(app.path))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Palette.muted)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(app.sizeBytes.bytesString)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .frame(width: 100, alignment: .trailing)
            StatusPill(text: app.isRunning ? "Running" : "Idle", color: app.isRunning ? Palette.mint : Palette.secondary)
                .frame(width: 92, alignment: .leading)
            Text(app.modifiedAt?.formatted(date: .abbreviated, time: .omitted) ?? "Unknown")
                .frame(width: 128, alignment: .leading)

            HStack(spacing: 6) {
                IconButton(symbol: "arrow.forward.square", tint: Palette.cyan, help: "Reveal") {
                    AppInventory.reveal(path: app.path)
                }
                if app.isRunning {
                    IconButton(symbol: "power", tint: Palette.amber, help: "Quit") {
                        quit()
                    }
                }
                if !app.isSystemApp {
                    IconButton(symbol: "trash", tint: Palette.red, help: "Move to Trash") {
                        trash()
                    }
                }
            }
            .frame(width: 112)
        }
        .font(.system(size: 12, weight: .medium))
        .foregroundStyle(Palette.secondary)
        .padding(.horizontal, 14)
        .frame(height: 58)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.white.opacity(0.05)).frame(height: 1)
        }
    }
}

private struct SourcesView: View {
    @EnvironmentObject private var sampler: SystemSampler

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 14), count: 3), spacing: 14) {
                SourceCard(title: "Local Mac", status: "Active", symbol: "desktopcomputer", tint: Palette.mint)
                SourceCard(title: "Snapshot JSON", status: "Ready", symbol: "doc.badge.arrow.up", tint: Palette.cyan) {
                    exportSnapshot()
                }
                SourceCard(title: "Health Report", status: "Markdown", symbol: "doc.text.magnifyingglass", tint: Palette.amber) {
                    exportReport()
                }
                SourceCard(title: "Remote Macs", status: "Not configured", symbol: "network", tint: Palette.violet)
                SourceCard(title: "SSH Agent", status: "Queued", symbol: "terminal", tint: Palette.amber)
                SourceCard(title: "File Sync", status: "Queued", symbol: "arrow.triangle.2.circlepath", tint: Palette.orange)
                SourceCard(title: "Alert Rules", status: "\(Int(sampler.alertSettings.cpuThreshold))% CPU guardrail", symbol: "bell.badge", tint: Palette.red)
            }

            VStack(alignment: .leading, spacing: 12) {
                SectionTitle("Current Dataset", symbol: "server.rack")
                DatasetLine(label: "Processes", value: "\(sampler.processes.count)")
                DatasetLine(label: "Storage Buckets", value: "\(sampler.storageBuckets.count)")
                DatasetLine(label: "Apps", value: "\(sampler.apps.count)")
                DatasetLine(label: "Containers", value: "\(sampler.containers.count)")
            }
            .padding(16)
            .panel()
        }
    }

    private func exportSnapshot() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "macsentinel-\(Int(Date().timeIntervalSince1970)).json"
        panel.canCreateDirectories = true

        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(sampler.snapshot())
            try data.write(to: url, options: .atomic)
        } catch {
            NSSound.beep()
        }
    }

    private func exportReport() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [UTType(filenameExtension: "md") ?? .plainText]
        panel.nameFieldStringValue = "macsentinel-report-\(Int(Date().timeIntervalSince1970)).md"
        panel.canCreateDirectories = true

        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            try sampler.exportReport(to: url)
        } catch {
            NSSound.beep()
        }
    }
}

private struct SourceCard: View {
    var title: String
    var status: String
    var symbol: String
    var tint: Color
    var action: (() -> Void)? = nil

    var body: some View {
        Button {
            action?()
        } label: {
            VStack(alignment: .leading, spacing: 13) {
                HStack {
                    Image(systemName: symbol)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(tint)
                    Spacer()
                    Image(systemName: action == nil ? "circle" : "arrow.up.doc")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(action == nil ? Palette.muted : tint)
                }
                Text(title)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Palette.text)
                Text(status)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(tint)
            }
            .padding(16)
            .frame(minHeight: 132, alignment: .topLeading)
            .panel()
        }
        .buttonStyle(.plain)
        .disabled(action == nil)
    }
}

private struct DatasetLine: View {
    var label: String
    var value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Palette.secondary)
            Spacer()
            Text(value)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(Palette.text)
        }
        .padding(.vertical, 5)
    }
}

private struct ControlRow<Trailing: View>: View {
    @Binding var query: String
    var placeholder: String
    var isBusy: Bool
    var refresh: () -> Void
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        HStack(spacing: 12) {
            if !placeholder.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(Palette.muted)
                    TextField(placeholder, text: $query)
                        .textFieldStyle(.plain)
                        .foregroundStyle(Palette.text)
                }
                .padding(.horizontal, 12)
                .frame(height: 38)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.white.opacity(0.045))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color.white.opacity(0.07), lineWidth: 1)
                )
                .frame(maxWidth: 420)
            }

            trailing()
            Spacer()

            if isBusy {
                ProgressView()
                    .controlSize(.small)
                    .frame(width: 30, height: 30)
            }

            IconButton(symbol: "arrow.clockwise", tint: Palette.mint, help: "Refresh", action: refresh)
        }
    }
}

private struct SectionTitle: View {
    var title: String
    var symbol: String

    init(_ title: String, symbol: String) {
        self.title = title
        self.symbol = symbol
    }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Palette.mint)
            Text(title)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Palette.text)
            Spacer()
        }
    }
}

private func shortPath(_ path: String) -> String {
    let home = FileManager.default.homeDirectoryForCurrentUser.path
    if path.hasPrefix(home) {
        return path.replacingOccurrences(of: home, with: "~")
    }
    return path
}
