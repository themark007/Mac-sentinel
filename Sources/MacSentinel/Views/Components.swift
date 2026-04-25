import SwiftUI

enum Palette {
    static let background = Color(hex: 0x050506)
    static let panel = Color(hex: 0x111113)
    static let panelRaised = Color(hex: 0x17181B)
    static let border = Color.white.opacity(0.08)
    static let text = Color(hex: 0xF2F5F4)
    static let secondary = Color(hex: 0x9EA5A3)
    static let muted = Color(hex: 0x6D7370)
    static let mint = Color(hex: 0x3AF2C4)
    static let cyan = Color(hex: 0x38BDF8)
    static let amber = Color(hex: 0xF6C85F)
    static let orange = Color(hex: 0xFF8A4C)
    static let red = Color(hex: 0xFF5A6C)
    static let violet = Color(hex: 0xB68CFF)

    static func color(for health: HealthLevel) -> Color {
        switch health {
        case .good: return mint
        case .watch: return amber
        case .hot: return orange
        case .critical: return red
        }
    }

    static func color(for category: StorageCategory) -> Color {
        switch category {
        case .user: return cyan
        case .cache: return amber
        case .developer: return violet
        case .container: return mint
        case .application: return Color(hex: 0xD8E35F)
        case .media: return Color(hex: 0xFF7AB6)
        case .system: return Color(hex: 0xAAB2B0)
        case .trash: return red
        }
    }
}

extension Color {
    init(hex: UInt, alpha: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xff) / 255,
            green: Double((hex >> 8) & 0xff) / 255,
            blue: Double(hex & 0xff) / 255,
            opacity: alpha
        )
    }
}

struct PanelBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Palette.panel)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Palette.border, lineWidth: 1)
            )
    }
}

extension View {
    func panel() -> some View {
        modifier(PanelBackground())
    }
}

struct IconButton: View {
    var symbol: String
    var tint: Color = Palette.secondary
    var help: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .semibold))
                .frame(width: 30, height: 30)
                .foregroundStyle(tint)
        }
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.white.opacity(0.045))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.white.opacity(0.07), lineWidth: 1)
        )
        .help(help)
    }
}

struct StatusPill: View {
    var text: String
    var color: Color
    var symbol: String? = nil

    var body: some View {
        HStack(spacing: 6) {
            if let symbol {
                Image(systemName: symbol)
                    .font(.system(size: 10, weight: .bold))
            }
            Text(text)
                .font(.system(size: 11, weight: .semibold))
        }
        .foregroundStyle(color)
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(
            Capsule(style: .continuous)
                .fill(color.opacity(0.12))
        )
        .overlay(
            Capsule(style: .continuous)
                .stroke(color.opacity(0.35), lineWidth: 1)
        )
    }
}

struct MetricTile: View {
    var title: String
    var value: String
    var subtitle: String
    var symbol: String
    var tint: Color
    var progress: Double?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: symbol)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(tint)
                    .frame(width: 28, height: 28)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(tint.opacity(0.12))
                    )
                Spacer()
                if let progress {
                    Text(String(format: "%.0f%%", max(0, min(1, progress)) * 100))
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(tint)
                }
            }
            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Palette.secondary)
                Text(value)
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundStyle(Palette.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                Text(subtitle)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Palette.muted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            if let progress {
                ProgressLine(value: progress, tint: tint)
            }
        }
        .padding(16)
        .frame(minHeight: 150)
        .panel()
    }
}

struct ProgressLine: View {
    var value: Double
    var tint: Color

    var body: some View {
        GeometryReader { proxy in
            let width = max(0, min(1, value)) * proxy.size.width
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.07))
                Capsule().fill(tint).frame(width: width)
            }
        }
        .frame(height: 8)
    }
}

struct RingGauge: View {
    var value: Double
    var label: String
    var caption: String
    var tint: Color

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.08), lineWidth: 12)
            Circle()
                .trim(from: 0, to: max(0.02, min(1, value)))
                .stroke(tint, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                .rotationEffect(.degrees(-90))
            VStack(spacing: 2) {
                Text(label)
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundStyle(Palette.text)
                    .minimumScaleFactor(0.75)
                Text(caption)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Palette.secondary)
            }
        }
        .frame(width: 138, height: 138)
    }
}

struct Sparkline: View {
    var values: [Double]
    var tint: Color

    var body: some View {
        GeometryReader { proxy in
            let normalized = normalize(values)
            Path { path in
                guard !normalized.isEmpty else { return }
                for index in normalized.indices {
                    let x = proxy.size.width * Double(index) / Double(max(1, normalized.count - 1))
                    let y = proxy.size.height * (1 - normalized[index])
                    let point = CGPoint(x: x, y: y)
                    if index == normalized.startIndex {
                        path.move(to: point)
                    } else {
                        path.addLine(to: point)
                    }
                }
            }
            .stroke(tint, style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
        }
    }

    private func normalize(_ values: [Double]) -> [Double] {
        guard values.count > 1 else { return values.map { _ in 0.5 } }
        let low = values.min() ?? 0
        let high = values.max() ?? 1
        let span = max(0.01, high - low)
        return values.map { ($0 - low) / span }
    }
}

struct EmptyPanel: View {
    var symbol: String
    var title: String
    var subtitle: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(Palette.secondary)
            Text(title)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Palette.text)
            Text(subtitle)
                .font(.system(size: 12))
                .foregroundStyle(Palette.muted)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 320)
        }
        .frame(maxWidth: .infinity, minHeight: 180)
        .panel()
    }
}
