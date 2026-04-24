import SwiftUI

struct AnalogClockView: View {
    @Environment(\.colorScheme) private var colorScheme

    let date: Date
    let timeZone: TimeZone
    var isGlass = false

    var body: some View {
        Canvas { context, size in
            let side = min(size.width, size.height)
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let radius = side / 2
            let inset = side * 0.045
            let faceRect = CGRect(
                x: center.x - radius + inset,
                y: center.y - radius + inset,
                width: (radius - inset) * 2,
                height: (radius - inset) * 2
            )

            let shadowRect = faceRect.offsetBy(dx: 0, dy: side * 0.018)
            context.fill(Path(ellipseIn: shadowRect), with: .color(.black.opacity(isGlass ? 0.08 : 0.13)))

            let facePath = Path(ellipseIn: faceRect)
            let faceColor = clockFaceColor
            context.fill(facePath, with: .color(faceColor))
            context.stroke(facePath, with: .color(.white.opacity(isGlass ? 0.72 : 0.65)), lineWidth: max(1, side * 0.006))

            drawTicks(context: &context, center: center, radius: radius - inset * 1.75, side: side)

            let parts = timeParts
            let hour = Double(parts.hour ?? 0)
            let minute = Double(parts.minute ?? 0)
            let second = Double(parts.second ?? 0)
            let nanosecond = Double(parts.nanosecond ?? 0)

            let secondProgress = second + nanosecond / 1_000_000_000.0
            let minuteProgress = minute + second / 60.0
            let hourProgress = Double(Int(hour) % 12) + minute / 60.0

            let secondAngle = Angle.degrees(secondProgress * 6.0)
            let minuteAngle = Angle.degrees(minuteProgress * 6.0)
            let hourAngle = Angle.degrees(hourProgress * 30.0)

            drawHand(
                context: &context,
                center: center,
                angle: hourAngle,
                length: side * 0.235,
                width: side * 0.03,
                color: Color(nsColor: .labelColor)
            )

            drawHand(
                context: &context,
                center: center,
                angle: minuteAngle,
                length: side * 0.335,
                width: side * 0.02,
                color: Color(nsColor: .labelColor)
            )

            drawHand(
                context: &context,
                center: center,
                angle: secondAngle,
                length: side * 0.37,
                width: max(1.2, side * 0.0065),
                color: .red
            )

            context.fill(
                Path(ellipseIn: CGRect(
                    x: center.x - side * 0.025,
                    y: center.y - side * 0.025,
                    width: side * 0.05,
                    height: side * 0.05
                )),
                with: .color(Color(nsColor: .labelColor))
            )

            context.fill(
                Path(ellipseIn: CGRect(
                    x: center.x - side * 0.012,
                    y: center.y - side * 0.012,
                    width: side * 0.024,
                    height: side * 0.024
                )),
                with: .color(.red)
            )
        }
        .drawingGroup()
        .accessibilityLabel(accessibilityTime)
    }

    private var clockFaceColor: Color {
        guard isGlass else {
            return Color(nsColor: .controlBackgroundColor)
        }

        return colorScheme == .dark
            ? Color.black.opacity(0.32)
            : Color.white.opacity(0.30)
    }

    private var timeParts: DateComponents {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar.dateComponents([.hour, .minute, .second, .nanosecond], from: date)
    }

    private var accessibilityTime: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.timeZone = timeZone
        formatter.dateStyle = .none
        formatter.timeStyle = .medium
        return formatter.string(from: date)
    }

    private func drawTicks(context: inout GraphicsContext, center: CGPoint, radius: CGFloat, side: CGFloat) {
        for minute in 0..<60 {
            let isHour = minute % 5 == 0
            let length = isHour ? side * 0.045 : side * 0.022
            let width = isHour ? side * 0.009 : side * 0.004
            let angle = Angle.degrees(Double(minute) * 6.0)
            let outer = point(center: center, radius: radius, angle: angle)
            let inner = point(center: center, radius: radius - length, angle: angle)
            var path = Path()
            path.move(to: inner)
            path.addLine(to: outer)
            context.stroke(
                path,
                with: .color(Color(nsColor: .labelColor).opacity(isHour ? 0.72 : 0.32)),
                style: StrokeStyle(lineWidth: max(1, width), lineCap: .round)
            )
        }
    }

    private func drawHand(
        context: inout GraphicsContext,
        center: CGPoint,
        angle: Angle,
        length: CGFloat,
        width: CGFloat,
        color: Color
    ) {
        let counterWeight = length * 0.16
        let end = point(center: center, radius: length, angle: angle)
        let start = point(center: center, radius: -counterWeight, angle: angle)

        var path = Path()
        path.move(to: start)
        path.addLine(to: end)

        context.stroke(
            path,
            with: .color(color),
            style: StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round)
        )
    }

    private func point(center: CGPoint, radius: CGFloat, angle: Angle) -> CGPoint {
        let radians = angle.radians - .pi / 2
        return CGPoint(
            x: center.x + cos(radians) * radius,
            y: center.y + sin(radians) * radius
        )
    }
}
