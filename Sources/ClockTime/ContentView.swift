import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @EnvironmentObject private var store: ClockStore
    @State private var searchText = ""
    @State private var isHoveringPipControls = false

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(spacing: 0) {
                if !store.isPinned {
                    toolbar

                    Divider()
                        .opacity(0.55)
                }

                content
            }
            .background {
                if store.isPinned {
                    Color.clear
                } else {
                    Color(nsColor: .windowBackgroundColor)
                }
            }

            if store.isPinned {
                GeometryReader { proxy in
                    pipControls
                        .position(
                            x: pipControlRightEdge(in: proxy.size) - pipControlsWidth / 2,
                            y: 12 + pipControlsHeight / 2
                        )
                }
            }
        }
        .sheet(isPresented: $store.isShowingTimeZonePicker) {
            TimeZonePickerView(searchText: $searchText)
                .environmentObject(store)
        }
    }

    private var content: some View {
        Group {
            if store.clocks.isEmpty {
                emptyState
            } else {
                GeometryReader { proxy in
                    let padding = clockStackPadding
                    let availableSize = availableClockArea(in: proxy.size, padding: padding)

                    ScrollView(store.layoutAxis.stackAxis, showsIndicators: !store.isPinned && store.clocks.count > 2) {
                        ClockStack(
                            clocks: store.clocks,
                            now: store.now,
                            axis: store.layoutAxis,
                            availableSize: availableSize
                        )
                    }
                    .background {
                        HorizontalWheelScrollSupport(isEnabled: store.layoutAxis == .horizontal)
                    }
                    .padding(padding)
                    .background(store.isPinned ? Color.clear : Color(nsColor: .windowBackgroundColor))
                }
            }
        }
    }

    private var clockStackPadding: EdgeInsets {
        store.isPinned
            ? EdgeInsets(top: 58, leading: 16, bottom: 16, trailing: 16)
            : EdgeInsets(top: 18, leading: 18, bottom: 18, trailing: 18)
    }

    private var pipControlsWidth: CGFloat {
        isHoveringPipControls ? 172 : 28
    }

    private var pipControlsHeight: CGFloat {
        isHoveringPipControls ? 40 : 28
    }

    private func availableClockArea(in size: CGSize, padding: EdgeInsets) -> CGSize {
        CGSize(
            width: max(0, size.width - padding.leading - padding.trailing),
            height: max(0, size.height - padding.top - padding.bottom)
        )
    }

    private func pipControlRightEdge(in size: CGSize) -> CGFloat {
        let padding = clockStackPadding
        let availableSize = availableClockArea(in: size, padding: padding)
        let groupWidth = estimatedClockGroupWidth(in: availableSize)
        let rightEdgeInsideArea = min(availableSize.width, (availableSize.width + groupWidth) / 2)
        return padding.leading + rightEdgeInsideArea
    }

    private func estimatedClockGroupWidth(in availableSize: CGSize) -> CGFloat {
        let count = max(store.clocks.count, 1)

        if store.layoutAxis == .horizontal {
            let totalSpacing = CGFloat(max(0, count - 1)) * 16
            let cardWidth = min(520, max(190, (availableSize.width - totalSpacing) / CGFloat(count)))
            return CGFloat(count) * cardWidth + totalSpacing
        }

        let totalSpacing = CGFloat(max(0, count - 1)) * 16
        let fittedHeight = (availableSize.height - totalSpacing) / CGFloat(count)
        let cardHeight = min(560, max(190, fittedHeight))
        let heightBasedWidth = cardHeight * 1.08
        return min(420, availableSize.width, max(190, heightBasedWidth))
    }

    private var toolbar: some View {
        HStack(spacing: 12) {
            Image(systemName: "clock")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.secondary)

            Text("ClockTime")
                .font(.system(.headline, design: .rounded, weight: .semibold))

            Spacer(minLength: 10)

            Picker("Layout", selection: $store.layoutAxis) {
                Label("Horizontal", systemImage: "rectangle.split.3x1").tag(ClockLayoutAxis.horizontal)
                Label("Vertical", systemImage: "rectangle.split.1x3").tag(ClockLayoutAxis.vertical)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 160)
            .help("Switch between horizontal and vertical clocks")

            Button {
                store.isPinned.toggle()
            } label: {
                Image(systemName: store.isPinned ? "pin.fill" : "pin")
                    .frame(width: 18, height: 18)
            }
            .buttonStyle(.borderless)
            .controlSize(.large)
            .help(store.isPinned ? "Leave Picture in Picture" : "Keep on top as Picture in Picture")

            Button {
                store.isShowingTimeZonePicker = true
            } label: {
                Image(systemName: "plus")
                    .frame(width: 18, height: 18)
            }
            .buttonStyle(.borderless)
            .controlSize(.large)
            .keyboardShortcut("n", modifiers: [.command])
            .help("Add clock")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
        .background(.regularMaterial)
    }

    private var pipControls: some View {
        HStack(spacing: 8) {
            if isHoveringPipControls {
                Toggle("Transparent", isOn: $store.isPipTransparent)
                    .toggleStyle(.switch)
                    .controlSize(.mini)
                    .font(.caption2.weight(.medium))
                    .transition(.move(edge: .trailing).combined(with: .opacity))
                    .help("Toggle transparent or solid Picture in Picture")
            }

            Button {
                store.isPinned = false
            } label: {
                Image(systemName: "pin.slash.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .help("Leave Picture in Picture")
        }
        .frame(width: pipControlsWidth, height: pipControlsHeight, alignment: .trailing)
        .background(isHoveringPipControls ? .regularMaterial : .ultraThinMaterial, in: Capsule())
        .overlay {
            Capsule()
                .strokeBorder(.white.opacity(isHoveringPipControls ? 0.25 : 0.18))
        }
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(.snappy(duration: 0.18)) {
                isHoveringPipControls = hovering
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "clock.badge.questionmark")
                .font(.system(size: 42, weight: .light))
                .foregroundStyle(.secondary)

            Text("No clocks")
                .font(.title3.weight(.semibold))

            Button {
                store.isShowingTimeZonePicker = true
            } label: {
                Label("Add clock", systemImage: "plus")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

private struct ClockStack: View {
    @EnvironmentObject private var store: ClockStore
    @State private var draggingClockID: WorldClock.ID?

    let clocks: [WorldClock]
    let now: Date
    let axis: ClockLayoutAxis
    let availableSize: CGSize

    var body: some View {
        Group {
            if axis == .horizontal {
                HStack(spacing: 16) {
                    clockCards
                }
                .frame(
                    minWidth: max(availableSize.width, widthForHorizontalClocks),
                    minHeight: max(0, availableSize.height)
                )
            } else {
                VStack(spacing: 16) {
                    clockCards
                }
                .frame(
                    minWidth: max(0, availableSize.width),
                    minHeight: max(availableSize.height, heightForVerticalClocks)
                )
            }
        }
    }

    private var clockCards: some View {
        ForEach(clocks) { clock in
            ClockCard(
                clock: clock,
                now: now,
                axis: axis,
                clockCount: clocks.count,
                availableSize: availableSize,
                isDragging: draggingClockID == clock.id
            )
            .onDrag {
                draggingClockID = clock.id
                return NSItemProvider(object: clock.id.uuidString as NSString)
            }
            .onDrop(
                of: [.text],
                delegate: ClockDropDelegate(
                    targetClock: clock,
                    store: store,
                    draggingClockID: $draggingClockID
                )
            )
        }
    }

    private var widthForHorizontalClocks: CGFloat {
        CGFloat(clocks.count) * 190 + CGFloat(max(0, clocks.count - 1)) * 16
    }

    private var heightForVerticalClocks: CGFloat {
        CGFloat(clocks.count) * 190 + CGFloat(max(0, clocks.count - 1)) * 16
    }
}

private struct ClockCard: View {
    @EnvironmentObject private var store: ClockStore

    let clock: WorldClock
    let now: Date
    let axis: ClockLayoutAxis
    let clockCount: Int
    let availableSize: CGSize
    let isDragging: Bool

    var body: some View {
        VStack(spacing: 10) {
            ZStack(alignment: .topTrailing) {
                AnalogClockView(date: now, timeZone: clock.timeZone, isGlass: store.isPinned)
                    .frame(width: clockDiameter, height: clockDiameter)

                if !store.isPinned {
                    Button {
                        store.removeClock(id: clock.id)
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 18))
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Remove clock")
                    .offset(x: 4, y: -4)
                }
            }

            VStack(spacing: 2) {
                Text(clock.title)
                    .font(.system(size: titleSize, weight: .semibold, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)

                Text(digitalTime)
                    .font(.system(size: timeSize, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(16)
        .frame(width: cardWidth, height: cardHeight)
        .background {
            cardBackground
        }
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(store.isPinned ? .white.opacity(0.34) : .white.opacity(0.18))
        }
        .opacity(isDragging ? 0.55 : 1)
        .scaleEffect(isDragging ? 0.985 : 1)
        .animation(.snappy(duration: 0.16), value: isDragging)
    }

    private var cardWidth: CGFloat {
        if axis == .horizontal {
            let totalSpacing = CGFloat(max(0, clockCount - 1)) * 16
            let fitted = (availableSize.width - totalSpacing) / CGFloat(max(clockCount, 1))
            return min(520, max(190, fitted))
        }
        let heightBasedWidth = cardHeight * 1.08
        let availableWidth = max(180, availableSize.width)
        return min(420, availableWidth, max(190, heightBasedWidth))
    }

    private var cardHeight: CGFloat {
        if axis == .vertical {
            let totalSpacing = CGFloat(max(0, clockCount - 1)) * 16
            let fitted = (availableSize.height - totalSpacing) / CGFloat(max(clockCount, 1))
            return min(560, max(190, fitted))
        }
        return min(max(190, availableSize.height), max(230, cardWidth * 1.15))
    }

    private var clockDiameter: CGFloat {
        max(80, min(cardWidth - 28, cardHeight - 58))
    }

    private var titleSize: CGFloat {
        min(20, max(14, clockDiameter * 0.095))
    }

    private var timeSize: CGFloat {
        min(15, max(11, clockDiameter * 0.07))
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(store.isPinned && store.isPipTransparent ? .ultraThinMaterial : .thinMaterial)
            .opacity(store.isPinned && store.isPipTransparent ? 0.52 : 1)
    }

    private var digitalTime: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.timeZone = clock.timeZone
        formatter.dateStyle = .none
        formatter.timeStyle = .medium
        return formatter.string(from: now)
    }
}

private struct ClockDropDelegate: DropDelegate {
    let targetClock: WorldClock
    let store: ClockStore
    @Binding var draggingClockID: WorldClock.ID?

    func dropEntered(info: DropInfo) {
        guard let draggingClockID,
              draggingClockID != targetClock.id,
              let sourceIndex = store.clocks.firstIndex(where: { $0.id == draggingClockID }),
              let targetIndex = store.clocks.firstIndex(where: { $0.id == targetClock.id }) else {
            return
        }

        withAnimation(.snappy(duration: 0.18)) {
            store.moveClock(
                from: IndexSet(integer: sourceIndex),
                to: targetIndex > sourceIndex ? targetIndex + 1 : targetIndex
            )
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        draggingClockID = nil
        return true
    }

    func dropExited(info: DropInfo) {
        guard !info.hasItemsConforming(to: [UTType.text]) else { return }
        draggingClockID = nil
    }
}
