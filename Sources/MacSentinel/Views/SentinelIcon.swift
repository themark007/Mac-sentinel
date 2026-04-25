import AppKit

enum SentinelIcon {
    static func make(size: CGFloat) -> NSImage {
        let image = NSImage(size: NSSize(width: size, height: size))
        image.lockFocus()
        defer { image.unlockFocus() }

        let rect = NSRect(x: 0, y: 0, width: size, height: size)
        let radius = size * 0.22
        let path = NSBezierPath(roundedRect: rect.insetBy(dx: size * 0.06, dy: size * 0.06), xRadius: radius, yRadius: radius)

        NSColor.black.setFill()
        path.fill()

        let border = NSBezierPath(roundedRect: rect.insetBy(dx: size * 0.08, dy: size * 0.08), xRadius: radius * 0.82, yRadius: radius * 0.82)
        NSColor(calibratedRed: 0.18, green: 0.94, blue: 0.76, alpha: 1).setStroke()
        border.lineWidth = size * 0.025
        border.stroke()

        let center = NSPoint(x: size * 0.5, y: size * 0.5)
        let dial = NSBezierPath()
        dial.appendArc(withCenter: center, radius: size * 0.26, startAngle: 205, endAngle: -25, clockwise: true)
        NSColor(calibratedRed: 0.11, green: 0.72, blue: 1, alpha: 1).setStroke()
        dial.lineWidth = size * 0.045
        dial.lineCapStyle = .round
        dial.stroke()

        let needle = NSBezierPath()
        needle.move(to: center)
        needle.line(to: NSPoint(x: size * 0.66, y: size * 0.62))
        NSColor(calibratedRed: 1, green: 0.78, blue: 0.26, alpha: 1).setStroke()
        needle.lineWidth = size * 0.035
        needle.lineCapStyle = .round
        needle.stroke()

        let core = NSBezierPath(ovalIn: NSRect(x: center.x - size * 0.04, y: center.y - size * 0.04, width: size * 0.08, height: size * 0.08))
        NSColor.white.setFill()
        core.fill()

        return image
    }
}
