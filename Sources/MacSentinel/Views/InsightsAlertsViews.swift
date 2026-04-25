import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct InsightsView: View {
    @EnvironmentObject private var sampler: SystemSampler

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 14) {
                MetricTile(
                    title: "Health",
                    value: sampler.health.rawValue,
                    subtitle: "\(sampler.insights.count) active recommendations",
                    symbol: "heart.text.square",
                    tint: Palette.color(for: sampler.health),
                    progress: Double(sampler.health.rank + 1) / 4
                )
                MetricTile(
                    title: "Report",
                    value: "Ready",
                    subtitle: "Markdown export for support or sharing",
                    symbol: "doc.text.magnifyingglass",
                    tint: Palette.cyan,
                    progress: 1
                )
                MetricTile(
                    title: "Guardrails",
                    value: sampler.alertSettings.enabled ? "On" : "Off",
                    subtitle: "CPU, RAM, disk, process alerts",
                    symbol: "bell.badge",
                    tint: sampler.alertSettings.enabled ? Palette.mint : Palette.muted,
                    progress: sampler.alertSettings.enabled ? 1 : 0
                )
            }

            HStack {
                ExtraTitle("Action Plan", symbol: "sparkles")
                Spacer()
                Button {
                    exportReport()
                } label: {
                    Label("Export Report", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(.borderedProminent)
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 14), count: 2), spacing: 14) {
                ForEach(sampler.insights) { insight in
                    InsightCard(insight: insight)
                }
            }

            VStack(alignment: .leading, spacing: 12) {
                ExtraTitle("Ship-Ready Modes", symbol: "shippingbox.and.arrow.backward")
                HStack(spacing: 12) {
                    CapabilityCard(
                        title: "Full Control",
                        detail: "Direct distribution build keeps process termination, deep storage scanning, and local cleanup.",
                        symbol: "switch.2",
                        tint: Palette.mint
                    )
                    CapabilityCard(
                        title: "App Store Safe",
                        detail: "Sandboxed build should gate deep disk access behind user selection and narrow control actions.",
                        symbol: "app.badge.checkmark",
                        tint: Palette.cyan
                    )
                    CapabilityCard(
                        title: "Team Sharing",
                        detail: "Snapshot JSON and Markdown reports make it easy to compare Mac health across machines.",
                        symbol: "point.3.connected.trianglepath.dotted",
                        tint: Palette.violet
                    )
                }
            }
            .padding(16)
            .panel()
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

private struct InsightCard: View {
    var insight: SystemInsight

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                Image(systemName: insight.symbol)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Palette.color(for: insight.severity))
                    .frame(width: 34, height: 34)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Palette.color(for: insight.severity).opacity(0.12))
                    )
                Spacer()
                StatusPill(text: insight.metric, color: Palette.color(for: insight.severity))
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(insight.title)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Palette.text)
                Text(insight.detail)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Palette.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(insight.recommendation)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Palette.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .frame(minHeight: 190, alignment: .topLeading)
        .panel()
    }
}

struct AlertsView: View {
    @EnvironmentObject private var sampler: SystemSampler

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 14) {
                ToggleCard(
                    title: "Alert Engine",
                    detail: "Evaluate CPU, RAM, SSD, and runaway process thresholds.",
                    symbol: "bell.badge",
                    isOn: binding(\.enabled),
                    tint: Palette.mint
                )
                ToggleCard(
                    title: "Notifications",
                    detail: "Ask macOS to show alerts when guardrails trip.",
                    symbol: "message.badge",
                    isOn: binding(\.notificationsEnabled),
                    tint: Palette.cyan
                )
                ToggleCard(
                    title: "Storage Refresh",
                    detail: "Periodically rescan storage buckets in the background.",
                    symbol: "arrow.triangle.2.circlepath",
                    isOn: binding(\.autoRefreshStorage),
                    tint: Palette.amber
                )
            }

            VStack(alignment: .leading, spacing: 16) {
                ExtraTitle("Thresholds", symbol: "slider.horizontal.3")
                ThresholdSlider(title: "CPU", value: binding(\.cpuThreshold), range: 40...98, suffix: "%", tint: Palette.cyan)
                ThresholdSlider(title: "Memory", value: binding(\.memoryThreshold), range: 50...98, suffix: "%", tint: Palette.mint)
                ThresholdSlider(title: "Storage", value: binding(\.storageThreshold), range: 60...98, suffix: "%", tint: Palette.amber)
                ThresholdSlider(title: "Process CPU", value: binding(\.processCPUThreshold), range: 50...250, suffix: "%", tint: Palette.red)
                ThresholdSlider(title: "Sample Interval", value: binding(\.sampleIntervalSeconds), range: 1...10, suffix: "s", tint: Palette.violet)
            }
            .padding(16)
            .panel()

            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    ExtraTitle("Recent Alerts", symbol: "clock.badge.exclamationmark")
                    Spacer()
                    Button {
                        sampler.clearAlerts()
                    } label: {
                        Label("Clear", systemImage: "xmark.circle")
                    }
                    .buttonStyle(.bordered)
                    .disabled(sampler.alertEvents.isEmpty)
                }

                if sampler.alertEvents.isEmpty {
                    EmptyPanel(symbol: "checkmark.seal", title: "No alerts yet", subtitle: "MacSentinel will keep a local session timeline when thresholds are crossed.")
                } else {
                    VStack(spacing: 0) {
                        ForEach(sampler.alertEvents) { alert in
                            AlertEventRow(alert: alert)
                        }
                    }
                    .panel()
                }
            }
        }
    }

    private func binding(_ keyPath: WritableKeyPath<AlertSettings, Bool>) -> Binding<Bool> {
        Binding {
            sampler.alertSettings[keyPath: keyPath]
        } set: { newValue in
            sampler.alertSettings[keyPath: keyPath] = newValue
        }
    }

    private func binding(_ keyPath: WritableKeyPath<AlertSettings, Double>) -> Binding<Double> {
        Binding {
            sampler.alertSettings[keyPath: keyPath]
        } set: { newValue in
            sampler.alertSettings[keyPath: keyPath] = newValue
        }
    }
}

private struct ToggleCard: View {
    var title: String
    var detail: String
    var symbol: String
    @Binding var isOn: Bool
    var tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: symbol)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(tint)
                Spacer()
                Toggle("", isOn: $isOn)
                    .toggleStyle(.switch)
                    .labelsHidden()
            }
            Text(title)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Palette.text)
            Text(detail)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Palette.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 138, alignment: .topLeading)
        .panel()
    }
}

private struct ThresholdSlider: View {
    var title: String
    @Binding var value: Double
    var range: ClosedRange<Double>
    var suffix: String
    var tint: Color

    var body: some View {
        HStack(spacing: 14) {
            Text(title)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Palette.text)
                .frame(width: 118, alignment: .leading)
            Slider(value: $value, in: range, step: 1)
                .tint(tint)
            Text("\(Int(value))\(suffix)")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(tint)
                .frame(width: 64, alignment: .trailing)
        }
    }
}

private struct AlertEventRow: View {
    var alert: AlertEvent

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: alert.symbol)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Palette.color(for: alert.severity))
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 3) {
                Text(alert.title)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Palette.text)
                Text(alert.detail)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Palette.secondary)
                    .lineLimit(1)
            }
            Spacer()
            Text(alert.createdAt.formatted(date: .omitted, time: .standard))
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(Palette.muted)
        }
        .padding(.horizontal, 14)
        .frame(height: 56)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.white.opacity(0.05)).frame(height: 1)
        }
    }
}

private struct CapabilityCard: View {
    var title: String
    var detail: String
    var symbol: String
    var tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(tint)
            Text(title)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Palette.text)
            Text(detail)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Palette.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 138, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.white.opacity(0.04))
        )
    }
}

private struct ExtraTitle: View {
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
        }
    }
}
