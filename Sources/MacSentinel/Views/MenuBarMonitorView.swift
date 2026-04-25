import AppKit
import SwiftUI

struct MenuBarMonitorView: View {
    @EnvironmentObject private var sampler: SystemSampler

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(nsImage: SentinelIcon.make(size: 34))
                    .resizable()
                    .frame(width: 34, height: 34)
                VStack(alignment: .leading, spacing: 2) {
                    Text("MacSentinel")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                    Text(sampler.health.rawValue)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Palette.color(for: sampler.health))
                }
                Spacer()
                Button {
                    Task { await sampler.refreshFast() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
                .help("Refresh")
            }

            VStack(spacing: 10) {
                MenuMetric(label: "CPU", value: sampler.cpu.usage / 100, text: sampler.cpu.usage.percentString, tint: Palette.cyan)
                MenuMetric(label: "RAM", value: sampler.memory.usedRatio, text: "\(Int(sampler.memory.usedRatio * 100))%", tint: Palette.mint)
                if let root = sampler.rootVolume {
                    MenuMetric(label: "SSD", value: root.usedRatio, text: "\(Int(root.usedRatio * 100))%", tint: Palette.amber)
                }
            }

            if let insight = sampler.insights.first {
                VStack(alignment: .leading, spacing: 5) {
                    Text(insight.title)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Palette.text)
                        .lineLimit(1)
                    Text(insight.detail)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Palette.secondary)
                        .lineLimit(2)
                }
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.white.opacity(0.05))
                )
            }

            Divider().overlay(Color.white.opacity(0.08))

            HStack {
                Button("Open Dashboard") {
                    NSApp.activate(ignoringOtherApps: true)
                    NSApp.windows.first?.makeKeyAndOrderFront(nil)
                }
                .buttonStyle(.borderedProminent)

                Button("Export Report") {
                    exportReport()
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(14)
        .frame(width: 320)
        .background(Palette.background)
    }

    private func exportReport() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.plainText]
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

private struct MenuMetric: View {
    var label: String
    var value: Double
    var text: String
    var tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(label)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Palette.secondary)
                Spacer()
                Text(text)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(tint)
            }
            ProgressLine(value: value, tint: tint)
                .frame(height: 6)
        }
    }
}
