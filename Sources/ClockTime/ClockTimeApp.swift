import SwiftUI

@main
struct ClockTimeApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var store = ClockStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .frame(
                    minWidth: store.isPinned ? 224 : 420,
                    minHeight: store.isPinned ? 220 : 260
                )
                .background(WindowConfigurator(isPinned: store.isPinned))
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandMenu("ClockTime") {
                Button("Add Clock") {
                    store.isShowingTimeZonePicker = true
                }
                .keyboardShortcut("n", modifiers: [.command])

                Button(store.layoutAxis == .horizontal ? "Use Vertical Layout" : "Use Horizontal Layout") {
                    store.layoutAxis = store.layoutAxis == .horizontal ? .vertical : .horizontal
                }
                .keyboardShortcut("l", modifiers: [.command])

                Button(store.isPinned ? "Leave Picture in Picture" : "Enter Picture in Picture") {
                    store.isPinned.toggle()
                }
                .keyboardShortcut("p", modifiers: [.command, .shift])
            }
        }
    }
}
