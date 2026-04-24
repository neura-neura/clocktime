import SwiftUI

struct TimeZonePickerView: View {
    @EnvironmentObject private var store: ClockStore
    @Environment(\.dismiss) private var dismiss

    @Binding var searchText: String
    @State private var isShowingCustomClockEditor = false

    private var filteredOptions: [TimeZoneOption] {
        let query = searchText.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
        guard !query.isEmpty else {
            return store.timeZoneOptions
        }
        return store.timeZoneOptions.filter { $0.searchText.contains(query) }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)

                TextField("Search city, country, or time zone", text: $searchText)
                    .textFieldStyle(.plain)

                Button {
                    isShowingCustomClockEditor = true
                } label: {
                    Image(systemName: "pencil.and.list.clipboard")
                        .frame(width: 18, height: 18)
                }
                .buttonStyle(.plain)
                .help("Create custom clock")
            }
            .padding(10)
            .background(.quaternary.opacity(0.55), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .padding(16)

            Divider()

            List(filteredOptions) { option in
                HStack(spacing: 8) {
                    Button {
                        store.addClock(option.clock)
                        searchText = ""
                        dismiss()
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "globe.americas.fill")
                                .font(.system(size: 17))
                                .foregroundStyle(.secondary)
                                .frame(width: 24)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(option.title)
                                    .font(.body.weight(.medium))
                                    .foregroundStyle(.primary)

                                Text(option.subtitle)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }

                            Spacer()

                            Text(option.offset)
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(isAlreadyAdded(option))
                    .opacity(isAlreadyAdded(option) ? 0.42 : 1)

                    if option.id.hasPrefix("user:") {
                        Button {
                            store.removeCustomClock(optionID: option.id)
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 16))
                                .symbolRenderingMode(.hierarchical)
                                .foregroundStyle(.secondary)
                                .frame(width: 22, height: 22)
                        }
                        .buttonStyle(.plain)
                        .help("Delete custom clock")
                    }
                }
            }
            .listStyle(.inset)
        }
        .frame(width: 520, height: 560)
        .background(.regularMaterial)
        .sheet(isPresented: $isShowingCustomClockEditor) {
            CustomClockEditorView()
                .environmentObject(store)
        }
    }

    private func isAlreadyAdded(_ option: TimeZoneOption) -> Bool {
        store.clocks.contains {
            $0.timeZoneIdentifier == option.timeZoneIdentifier && $0.title == option.title
        }
    }
}

private struct CustomClockEditorView: View {
    @EnvironmentObject private var store: ClockStore
    @Environment(\.dismiss) private var dismiss

    @State private var clockName = ""
    @State private var zoneSearchText = ""
    @State private var selectedTimeZoneIdentifier = TimeZone.current.identifier

    private var filteredTimeZones: [TimeZoneOption] {
        let query = zoneSearchText.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
        guard !query.isEmpty else {
            return store.systemTimeZoneOptions
        }
        return store.systemTimeZoneOptions.filter { $0.searchText.contains(query) }
    }

    private var canSave: Bool {
        !clockName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Custom Clock")
                    .font(.title3.weight(.semibold))

                TextField("Display name", text: $clockName)
                    .textFieldStyle(.roundedBorder)

                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)

                    TextField("Search time zone", text: $zoneSearchText)
                        .textFieldStyle(.plain)
                }
                .padding(10)
                .background(.quaternary.opacity(0.55), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .padding(16)

            Divider()

            List(filteredTimeZones) { option in
                Button {
                    selectedTimeZoneIdentifier = option.timeZoneIdentifier
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: selectedTimeZoneIdentifier == option.timeZoneIdentifier ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 16))
                            .foregroundStyle(selectedTimeZoneIdentifier == option.timeZoneIdentifier ? .blue : .secondary)
                            .frame(width: 22)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(option.title)
                                .font(.body.weight(.medium))
                                .foregroundStyle(.primary)

                            Text(option.subtitle)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }

                        Spacer()

                        Text(option.offset)
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .listStyle(.inset)

            Divider()

            HStack {
                Button("Cancel") {
                    dismiss()
                }

                Spacer()

                Button("Add Custom Clock") {
                    store.addCustomClock(
                        title: clockName,
                        timeZoneIdentifier: selectedTimeZoneIdentifier
                    )
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!canSave)
            }
            .padding(16)
        }
        .frame(width: 520, height: 620)
        .background(.regularMaterial)
    }
}
