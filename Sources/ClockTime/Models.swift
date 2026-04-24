import AppKit
import Combine
import Foundation
import SwiftUI

struct WorldClock: Identifiable, Codable, Equatable {
    var id: UUID
    var timeZoneIdentifier: String
    var title: String

    init(id: UUID = UUID(), timeZoneIdentifier: String, title: String) {
        self.id = id
        self.timeZoneIdentifier = timeZoneIdentifier
        self.title = title
    }

    var timeZone: TimeZone {
        TimeZone(identifier: timeZoneIdentifier) ?? .current
    }
}

enum ClockLayoutAxis: String, Codable, CaseIterable, Identifiable {
    case horizontal
    case vertical

    var id: String { rawValue }

    var stackAxis: Axis.Set {
        self == .horizontal ? .horizontal : .vertical
    }
}

struct TimeZoneOption: Identifiable, Hashable {
    let id: String
    let timeZoneIdentifier: String
    let title: String
    let subtitle: String
    let searchText: String
    let offset: String

    var clock: WorldClock {
        WorldClock(timeZoneIdentifier: timeZoneIdentifier, title: title)
    }
}

@MainActor
final class ClockStore: ObservableObject {
    @Published var clocks: [WorldClock] {
        didSet { save() }
    }

    @Published var customClocks: [WorldClock] {
        didSet { save() }
    }

    @Published var layoutAxis: ClockLayoutAxis {
        didSet { save() }
    }

    @Published var isPinned: Bool {
        didSet { save() }
    }

    @Published var isPipTransparent: Bool {
        didSet { save() }
    }

    @Published var now = Date()
    @Published var isShowingTimeZonePicker = false

    let systemTimeZoneOptions: [TimeZoneOption]

    var timeZoneOptions: [TimeZoneOption] {
        Self.makeBuiltInTimeZoneOptions()
            + customClocks.compactMap(Self.makePersistedCustomTimeZoneOption)
            + systemTimeZoneOptions
    }

    private let defaultsKey = "ClockTime.State.v1"
    private var timer: Timer?

    init() {
        self.systemTimeZoneOptions = Self.makeSystemTimeZoneOptions()

        if let data = UserDefaults.standard.data(forKey: defaultsKey),
           let state = try? JSONDecoder().decode(PersistedState.self, from: data) {
            self.clocks = state.clocks.isEmpty ? Self.defaultClocks() : state.clocks
            self.customClocks = state.customClocks
            self.layoutAxis = state.layoutAxis
            self.isPinned = state.isPinned
            self.isPipTransparent = state.isPipTransparent
        } else {
            self.clocks = Self.defaultClocks()
            self.customClocks = []
            self.layoutAxis = .horizontal
            self.isPinned = false
            self.isPipTransparent = true
        }

        let timer = Timer(timeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.now = Date()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    deinit {
        timer?.invalidate()
    }

    func addClock(_ clock: WorldClock) {
        guard !clocks.contains(where: {
            $0.timeZoneIdentifier == clock.timeZoneIdentifier && $0.title == clock.title
        }) else { return }
        clocks.append(clock)
    }

    func addCustomClock(title: String, timeZoneIdentifier: String) {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty,
              TimeZone(identifier: timeZoneIdentifier) != nil else {
            return
        }

        let clock = WorldClock(timeZoneIdentifier: timeZoneIdentifier, title: trimmedTitle)
        if !customClocks.contains(where: {
            $0.timeZoneIdentifier == clock.timeZoneIdentifier && $0.title == clock.title
        }) {
            customClocks.append(clock)
        }
        addClock(clock)
    }

    func removeClock(id: WorldClock.ID) {
        clocks.removeAll { $0.id == id }
    }

    func removeCustomClock(optionID: String) {
        guard optionID.hasPrefix("user:"),
              let id = UUID(uuidString: String(optionID.dropFirst("user:".count))),
              let customClock = customClocks.first(where: { $0.id == id }) else {
            return
        }

        customClocks.removeAll { $0.id == id }
        clocks.removeAll {
            $0.timeZoneIdentifier == customClock.timeZoneIdentifier && $0.title == customClock.title
        }
    }

    func moveClock(from source: IndexSet, to destination: Int) {
        clocks.move(fromOffsets: source, toOffset: destination)
    }

    private func save() {
        let state = PersistedState(
            clocks: clocks,
            customClocks: customClocks,
            layoutAxis: layoutAxis,
            isPinned: isPinned,
            isPipTransparent: isPipTransparent
        )
        if let data = try? JSONEncoder().encode(state) {
            UserDefaults.standard.set(data, forKey: defaultsKey)
        }
    }

    private static func defaultClocks() -> [WorldClock] {
        [
            WorldClock(timeZoneIdentifier: TimeZone.current.identifier, title: "Local"),
            WorldClock(timeZoneIdentifier: "America/New_York", title: "New York"),
            WorldClock(timeZoneIdentifier: "Europe/London", title: "London"),
            WorldClock(timeZoneIdentifier: "Asia/Tokyo", title: "Tokyo")
        ]
    }

    private static func makeSystemTimeZoneOptions() -> [TimeZoneOption] {
        let countryNamesByZone = makeCountryNamesByZone()
        let englishLocale = Locale(identifier: "en_US")

        return TimeZone.knownTimeZoneIdentifiers
            .compactMap { identifier -> TimeZoneOption? in
                guard let timeZone = TimeZone(identifier: identifier) else { return nil }

                let city = identifier
                    .split(separator: "/")
                    .last
                    .map(String.init)?
                    .replacingOccurrences(of: "_", with: " ") ?? identifier

                let region = identifier.split(separator: "/").first.map(String.init) ?? ""
                let countryInfo = countryNamesByZone[identifier]
                let countryName = countryInfo?.displayName ?? ""
                let countrySearchName = countryInfo?.searchName ?? ""
                let localizedName = timeZone.localizedName(for: .generic, locale: .current) ?? ""
                let englishLocalizedName = timeZone.localizedName(for: .generic, locale: englishLocale) ?? ""
                let seconds = timeZone.secondsFromGMT(for: Date())
                let offset = Self.formatGMTOffset(seconds)
                let title = city
                let detail = [countryName, localizedName, identifier, offset]
                    .filter { !$0.isEmpty }
                    .joined(separator: " - ")
                let subtitle = detail.isEmpty ? "\(region) - \(identifier) - \(offset)" : detail
                let searchText = "\(title) \(region) \(countryName) \(countrySearchName) \(localizedName) \(englishLocalizedName) \(identifier) \(offset)"
                    .localizedCaseInsensitiveFolded

                return TimeZoneOption(
                    id: identifier,
                    timeZoneIdentifier: identifier,
                    title: title,
                    subtitle: subtitle,
                    searchText: searchText,
                    offset: offset
                )
            }
            .sorted {
                if $0.title == $1.title { return $0.id < $1.id }
                return $0.title < $1.title
            }
    }

    private static func makeBuiltInTimeZoneOptions() -> [TimeZoneOption] {
        [
            makeCustomTimeZoneOption(
                id: "custom:local",
                title: "Local",
                country: "Local Time",
                timeZoneIdentifier: TimeZone.current.identifier
            ),
            makeCustomTimeZoneOption(
                id: "custom:hunan-china",
                title: "Hunan",
                country: "China",
                timeZoneIdentifier: "Asia/Shanghai"
            ),
            makeCustomTimeZoneOption(
                id: "custom:durango-mexico",
                title: "Durango",
                country: "Mexico",
                timeZoneIdentifier: "America/Monterrey"
            )
        ].compactMap { $0 }
    }

    private static func makePersistedCustomTimeZoneOption(_ clock: WorldClock) -> TimeZoneOption? {
        makeCustomTimeZoneOption(
            id: "user:\(clock.id.uuidString)",
            title: clock.title,
            country: "Custom",
            timeZoneIdentifier: clock.timeZoneIdentifier
        )
    }

    private static func makeCustomTimeZoneOption(
        id: String,
        title: String,
        country: String,
        timeZoneIdentifier: String
    ) -> TimeZoneOption? {
        guard let timeZone = TimeZone(identifier: timeZoneIdentifier) else { return nil }

        let localizedName = timeZone.localizedName(for: .generic, locale: .current) ?? ""
        let offset = Self.formatGMTOffset(timeZone.secondsFromGMT(for: Date()))
        let detail = [country, localizedName, timeZoneIdentifier, offset]
            .filter { !$0.isEmpty }
            .joined(separator: " - ")

        return TimeZoneOption(
            id: id,
            timeZoneIdentifier: timeZoneIdentifier,
            title: title,
            subtitle: detail,
            searchText: "\(title) \(country) \(timeZoneIdentifier) \(localizedName) \(offset)"
                .localizedCaseInsensitiveFolded,
            offset: offset
        )
    }

    private static func makeCountryNamesByZone() -> [String: (displayName: String, searchName: String)] {
        let possiblePaths = [
            "/var/db/timezone/zoneinfo/zone.tab",
            "/usr/share/zoneinfo/zone.tab"
        ]

        guard let path = possiblePaths.first(where: { FileManager.default.fileExists(atPath: $0) }),
              let contents = try? String(contentsOfFile: path, encoding: .utf8) else {
            return [:]
        }

        let englishLocale = Locale(identifier: "en_US")
        var countriesByZone: [String: (displayName: String, searchName: String)] = [:]

        for line in contents.split(separator: "\n") {
            guard !line.hasPrefix("#") else { continue }
            let columns = line.split(separator: "\t", omittingEmptySubsequences: false)
            guard columns.count >= 3 else { continue }

            let countryCode = String(columns[0])
            let zoneIdentifier = String(columns[2])
            let englishCountryName = englishLocale.localizedString(forRegionCode: countryCode) ?? countryCode
            let countryName = Locale.current.localizedString(forRegionCode: countryCode)
                ?? englishCountryName

            countriesByZone[zoneIdentifier] = (countryName, "\(countryName) \(englishCountryName) \(countryCode)")
        }

        return countriesByZone
    }

    private static func formatGMTOffset(_ seconds: Int) -> String {
        let sign = seconds >= 0 ? "+" : "-"
        let absolute = abs(seconds)
        let hours = absolute / 3600
        let minutes = (absolute % 3600) / 60
        return String(format: "GMT%@%02d:%02d", sign, hours, minutes)
    }
}

private struct PersistedState: Codable {
    var clocks: [WorldClock]
    var customClocks: [WorldClock]
    var layoutAxis: ClockLayoutAxis
    var isPinned: Bool
    var isPipTransparent: Bool

    private enum CodingKeys: String, CodingKey {
        case clocks
        case customClocks
        case layoutAxis
        case isPinned
        case isPipTransparent
    }

    init(
        clocks: [WorldClock],
        customClocks: [WorldClock],
        layoutAxis: ClockLayoutAxis,
        isPinned: Bool,
        isPipTransparent: Bool
    ) {
        self.clocks = clocks
        self.customClocks = customClocks
        self.layoutAxis = layoutAxis
        self.isPinned = isPinned
        self.isPipTransparent = isPipTransparent
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        clocks = try container.decode([WorldClock].self, forKey: .clocks)
        customClocks = try container.decodeIfPresent([WorldClock].self, forKey: .customClocks) ?? []
        layoutAxis = try container.decode(ClockLayoutAxis.self, forKey: .layoutAxis)
        isPinned = try container.decode(Bool.self, forKey: .isPinned)
        isPipTransparent = try container.decodeIfPresent(Bool.self, forKey: .isPipTransparent) ?? true
    }
}

private extension String {
    var localizedCaseInsensitiveFolded: String {
        folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
    }
}

struct WindowConfigurator: NSViewRepresentable {
    let isPinned: Bool

    func makeNSView(context: Context) -> WindowConfigurationView {
        let view = WindowConfigurationView()
        DispatchQueue.main.async {
            configure(view.window)
        }
        return view
    }

    func updateNSView(_ nsView: WindowConfigurationView, context: Context) {
        DispatchQueue.main.async {
            configure(nsView.window)
        }
    }

    private func configure(_ window: NSWindow?) {
        guard let window else { return }
        window.title = "ClockTime"
        window.titleVisibility = .hidden
        window.toolbarStyle = .unifiedCompact
        window.isMovableByWindowBackground = false
        window.titlebarAppearsTransparent = isPinned

        let minimumSize = isPinned ? NSSize(width: 224, height: 220) : NSSize(width: 420, height: 260)
        preserveTopLeftCornerIfNeeded(for: window, minimumSize: minimumSize)
        window.minSize = minimumSize
        window.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        window.isOpaque = !isPinned
        window.backgroundColor = isPinned ? .clear : .windowBackgroundColor
        window.hasShadow = true

        [
            NSWindow.ButtonType.closeButton,
            .miniaturizeButton,
            .zoomButton
        ].forEach { buttonType in
            window.standardWindowButton(buttonType)?.isHidden = isPinned
        }

        if isPinned {
            window.level = .floating
            window.collectionBehavior = [
                .canJoinAllSpaces,
                .fullScreenAuxiliary,
                .stationary,
                .ignoresCycle
            ]
        } else {
            window.level = .normal
            window.collectionBehavior = [
                .fullScreenAuxiliary
            ]
        }
    }

    private func preserveTopLeftCornerIfNeeded(for window: NSWindow, minimumSize: NSSize) {
        let frame = window.frame
        let newWidth = max(frame.width, minimumSize.width)
        let newHeight = max(frame.height, minimumSize.height)

        guard newWidth != frame.width || newHeight != frame.height else { return }

        let topLeftY = frame.maxY
        let resizedFrame = NSRect(
            x: frame.minX,
            y: topLeftY - newHeight,
            width: newWidth,
            height: newHeight
        )
        window.setFrame(resizedFrame, display: true, animate: false)
    }
}

final class WindowConfigurationView: NSView {
    private var mouseMovedMonitor: Any?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        updateMouseMovedMonitor()
    }

    deinit {
        if let mouseMovedMonitor {
            NSEvent.removeMonitor(mouseMovedMonitor)
        }
    }

    private func updateMouseMovedMonitor() {
        if let mouseMovedMonitor {
            NSEvent.removeMonitor(mouseMovedMonitor)
            self.mouseMovedMonitor = nil
        }

        mouseMovedMonitor = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved]) { [weak self] event in
            self?.updateResizeCursor(for: event)
            return event
        }
    }

    private func updateResizeCursor(for event: NSEvent) {
        guard let window,
              event.window === window,
              window.styleMask.contains(.resizable) else {
            return
        }

        let point = event.locationInWindow
        let size = window.frame.size
        let thickness: CGFloat = 7
        let isNearLeft = point.x <= thickness
        let isNearRight = point.x >= size.width - thickness
        let isNearBottom = point.y <= thickness
        let isNearTop = point.y >= size.height - thickness

        if isNearLeft || isNearRight {
            NSCursor.resizeLeftRight.set()
        } else if isNearTop || isNearBottom {
            NSCursor.resizeUpDown.set()
        } else {
            NSCursor.arrow.set()
        }
    }
}

struct GlassBackgroundView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        view.isEmphasized = true
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
        nsView.state = .active
    }
}
