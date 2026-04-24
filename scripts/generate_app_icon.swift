import AppKit
import Foundation

let outputURL = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? "Resources/AppIcon.icns")
let fileManager = FileManager.default
let temporaryDirectory = outputURL.deletingLastPathComponent().appendingPathComponent("AppIcon.iconset")

try? fileManager.removeItem(at: temporaryDirectory)
try fileManager.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
try fileManager.createDirectory(at: outputURL.deletingLastPathComponent(), withIntermediateDirectories: true)

let sizes: [(name: String, pixels: CGFloat)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024)
]

for size in sizes {
    let image = makeClockIcon(size: size.pixels)
    let url = temporaryDirectory.appendingPathComponent(size.name)
    try writePNG(image, to: url)
}

let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
process.arguments = ["-c", "icns", temporaryDirectory.path, "-o", outputURL.path]
try process.run()
process.waitUntilExit()

guard process.terminationStatus == 0 else {
    throw NSError(domain: "ClockTimeIcon", code: Int(process.terminationStatus))
}

try? fileManager.removeItem(at: temporaryDirectory)

func makeClockIcon(size: CGFloat) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()
    defer { image.unlockFocus() }

    NSColor.clear.setFill()
    NSRect(x: 0, y: 0, width: size, height: size).fill()

    let scale = size / 1024
    let rect = NSRect(x: 112 * scale, y: 112 * scale, width: 800 * scale, height: 800 * scale)
    let center = CGPoint(x: size / 2, y: size / 2)
    let radius = rect.width / 2

    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.24)
    shadow.shadowBlurRadius = 34 * scale
    shadow.shadowOffset = NSSize(width: 0, height: -18 * scale)
    shadow.set()

    let face = NSBezierPath(ovalIn: rect)
    NSColor.controlBackgroundColor.setFill()
    face.fill()

    NSGraphicsContext.current?.cgContext.setShadow(offset: .zero, blur: 0, color: nil)
    NSColor.white.withAlphaComponent(0.72).setStroke()
    face.lineWidth = max(1.5, 10 * scale)
    face.stroke()

    for minute in 0..<60 {
        let isHour = minute % 5 == 0
        let angle = CGFloat(minute) * .pi / 30 - .pi / 2
        let outerRadius = radius - 54 * scale
        let innerRadius = outerRadius - (isHour ? 56 : 28) * scale
        let tick = NSBezierPath()
        tick.move(to: point(center: center, radius: innerRadius, angle: angle))
        tick.line(to: point(center: center, radius: outerRadius, angle: angle))
        tick.lineWidth = max(0.75, (isHour ? 10 : 5) * scale)
        tick.lineCapStyle = .round
        NSColor.labelColor.withAlphaComponent(isHour ? 0.74 : 0.34).setStroke()
        tick.stroke()
    }

    // Static Finder icon: 10:10:30, a classic clock pose.
    drawHand(center: center, angle: angle(hour: 10, minute: 10), length: 220 * scale, width: 38 * scale, color: .labelColor)
    drawHand(center: center, angle: angle(minute: 10, second: 30), length: 310 * scale, width: 26 * scale, color: .labelColor)
    drawHand(center: center, angle: CGFloat(30) * .pi / 30 - .pi / 2, length: 350 * scale, width: 8 * scale, color: .systemRed)

    NSColor.labelColor.setFill()
    NSBezierPath(ovalIn: NSRect(x: center.x - 28 * scale, y: center.y - 28 * scale, width: 56 * scale, height: 56 * scale)).fill()
    NSColor.systemRed.setFill()
    NSBezierPath(ovalIn: NSRect(x: center.x - 13 * scale, y: center.y - 13 * scale, width: 26 * scale, height: 26 * scale)).fill()

    return image
}

func angle(hour: Double, minute: Double) -> CGFloat {
    CGFloat((Double(Int(hour) % 12) + minute / 60) * .pi / 6 - .pi / 2)
}

func angle(minute: Double, second: Double) -> CGFloat {
    CGFloat((minute + second / 60) * .pi / 30 - .pi / 2)
}

func drawHand(center: CGPoint, angle: CGFloat, length: CGFloat, width: CGFloat, color: NSColor) {
    let path = NSBezierPath()
    path.move(to: point(center: center, radius: -length * 0.16, angle: angle))
    path.line(to: point(center: center, radius: length, angle: angle))
    path.lineWidth = max(1, width)
    path.lineCapStyle = .round
    color.setStroke()
    path.stroke()
}

func point(center: CGPoint, radius: CGFloat, angle: CGFloat) -> CGPoint {
    CGPoint(x: center.x + cos(angle) * radius, y: center.y - sin(angle) * radius)
}

func writePNG(_ image: NSImage, to url: URL) throws {
    guard let tiff = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiff),
          let png = bitmap.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "ClockTimeIcon", code: 1)
    }
    try png.write(to: url)
}
