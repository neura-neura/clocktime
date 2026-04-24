import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var iconTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        updateDockIcon()

        let timer = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateDockIcon()
        }
        RunLoop.main.add(timer, forMode: .common)
        iconTimer = timer
    }

    func applicationWillTerminate(_ notification: Notification) {
        iconTimer?.invalidate()
    }

    private func updateDockIcon() {
        NSApp.applicationIconImage = ClockIconRenderer.image(date: Date(), timeZone: .current)
    }
}

private enum ClockIconRenderer {
    static func image(date: Date, timeZone: TimeZone) -> NSImage {
        let size = NSSize(width: 1024, height: 1024)
        let image = NSImage(size: size)

        image.lockFocus()
        defer { image.unlockFocus() }

        NSColor.clear.setFill()
        NSRect(origin: .zero, size: size).fill()

        let rect = NSRect(x: 112, y: 112, width: 800, height: 800)
        let shadow = NSShadow()
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.22)
        shadow.shadowBlurRadius = 34
        shadow.shadowOffset = NSSize(width: 0, height: -18)
        shadow.set()

        NSColor.controlBackgroundColor.setFill()
        let face = NSBezierPath(ovalIn: rect)
        face.fill()

        NSGraphicsContext.current?.cgContext.setShadow(offset: .zero, blur: 0, color: nil)
        NSColor.white.withAlphaComponent(0.72).setStroke()
        face.lineWidth = 10
        face.stroke()

        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let radius = rect.width / 2

        for minute in 0..<60 {
            let isHour = minute % 5 == 0
            let angle = CGFloat(minute) * .pi / 30 - .pi / 2
            let outerRadius = radius - 54
            let innerRadius = outerRadius - (isHour ? 56 : 28)
            let outer = point(center: center, radius: outerRadius, angle: angle)
            let inner = point(center: center, radius: innerRadius, angle: angle)

            let tick = NSBezierPath()
            tick.move(to: inner)
            tick.line(to: outer)
            tick.lineWidth = isHour ? 10 : 5
            tick.lineCapStyle = .round
            NSColor.labelColor.withAlphaComponent(isHour ? 0.74 : 0.34).setStroke()
            tick.stroke()
        }

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let parts = calendar.dateComponents([.hour, .minute, .second], from: date)
        let hour = Double(parts.hour ?? 0)
        let minute = Double(parts.minute ?? 0)
        let second = Double(parts.second ?? 0)

        let hourAngle = CGFloat((Double(Int(hour) % 12) + minute / 60) * .pi / 6 - .pi / 2)
        let minuteAngle = CGFloat((minute + second / 60) * .pi / 30 - .pi / 2)
        let secondAngle = CGFloat(second * .pi / 30 - .pi / 2)

        drawHand(center: center, angle: hourAngle, length: 220, width: 38, color: .labelColor)
        drawHand(center: center, angle: minuteAngle, length: 310, width: 26, color: .labelColor)
        drawHand(center: center, angle: secondAngle, length: 350, width: 8, color: .systemRed)

        NSColor.labelColor.setFill()
        NSBezierPath(ovalIn: NSRect(x: center.x - 28, y: center.y - 28, width: 56, height: 56)).fill()
        NSColor.systemRed.setFill()
        NSBezierPath(ovalIn: NSRect(x: center.x - 13, y: center.y - 13, width: 26, height: 26)).fill()

        return image
    }

    private static func drawHand(center: CGPoint, angle: CGFloat, length: CGFloat, width: CGFloat, color: NSColor) {
        let start = point(center: center, radius: -length * 0.16, angle: angle)
        let end = point(center: center, radius: length, angle: angle)
        let path = NSBezierPath()
        path.move(to: start)
        path.line(to: end)
        path.lineWidth = width
        path.lineCapStyle = .round
        color.setStroke()
        path.stroke()
    }

    private static func point(center: CGPoint, radius: CGFloat, angle: CGFloat) -> CGPoint {
        CGPoint(
            x: center.x + cos(angle) * radius,
            y: center.y - sin(angle) * radius
        )
    }
}
