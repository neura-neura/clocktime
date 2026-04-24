import AppKit
import SwiftUI

struct HorizontalWheelScrollSupport: NSViewRepresentable {
    let isEnabled: Bool

    func makeNSView(context: Context) -> HorizontalWheelScrollView {
        let view = HorizontalWheelScrollView()
        view.isEnabled = isEnabled
        return view
    }

    func updateNSView(_ nsView: HorizontalWheelScrollView, context: Context) {
        nsView.isEnabled = isEnabled
    }
}

final class HorizontalWheelScrollView: NSView {
    var isEnabled = false

    private var monitor: Any?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        updateMonitor()
    }

    deinit {
        if let monitor {
            NSEvent.removeMonitor(monitor)
        }
    }

    private func updateMonitor() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }

        monitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
            self?.handleScrollWheel(event) ?? event
        }
    }

    private func handleScrollWheel(_ event: NSEvent) -> NSEvent? {
        guard isEnabled,
              let window,
              event.window === window,
              abs(event.scrollingDeltaY) > abs(event.scrollingDeltaX),
              let scrollView = enclosingScrollView(),
              isEvent(event, inside: scrollView) else {
            return event
        }

        let documentWidth = scrollView.documentView?.bounds.width ?? 0
        let visibleWidth = scrollView.contentView.bounds.width
        guard documentWidth > visibleWidth else { return event }

        let currentOrigin = scrollView.contentView.bounds.origin
        let maximumX = max(0, documentWidth - visibleWidth)
        let multiplier = event.hasPreciseScrollingDeltas ? 1.0 : 8.0
        let direction = event.isDirectionInvertedFromDevice ? 1.0 : -1.0
        let proposedX = currentOrigin.x + event.scrollingDeltaY * multiplier * direction
        let nextX = min(max(0, proposedX), maximumX)

        guard nextX != currentOrigin.x else { return event }

        scrollView.contentView.scroll(to: NSPoint(x: nextX, y: currentOrigin.y))
        scrollView.reflectScrolledClipView(scrollView.contentView)
        return nil
    }

    private func enclosingScrollView() -> NSScrollView? {
        var current = superview
        while let view = current {
            if let scrollView = view as? NSScrollView {
                return scrollView
            }
            current = view.superview
        }
        return nil
    }

    private func isEvent(_ event: NSEvent, inside scrollView: NSScrollView) -> Bool {
        let point = scrollView.convert(event.locationInWindow, from: nil)
        return scrollView.bounds.contains(point)
    }
}
