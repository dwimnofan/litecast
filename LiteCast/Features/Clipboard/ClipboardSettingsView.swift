import SwiftUI
import AppKit

/// Settings tab for clipboard history: enable/disable, retention, exclusions, clear.
struct ClipboardSettingsView: View {
    @Bindable var preferences: PreferencesStore
    @Bindable var historyStore: ClipboardHistoryStore

    @State private var showClearConfirmation = false

    var body: some View {
        Form {
            Section {
                Toggle(isOn: $preferences.clipboardHistoryEnabled) {
                    Text("Enable Clipboard History")
                }
                Text("When enabled, LiteCast records text you copy to the clipboard. History is stored locally in ~/Library/Application Support/LiteCast/.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if preferences.clipboardHistoryEnabled {
                Section("Retention") {
                    Stepper("Maximum items: \(historyStore.maxItemCount)",
                            value: $historyStore.maxItemCount,
                            in: 10...10000,
                            step: 50)
                    Picker("Keep history for:", selection: $historyStore.retentionAge) {
                        ForEach(ClipboardHistoryStore.RetentionAge.allCases, id: \.self) { age in
                            Text(age.label).tag(age)
                        }
                    }
                }

                Section("Excluded Apps") {
                    Text("Copies from these apps will not be recorded.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    ForEach(preferences.clipboardExcludedApps, id: \.self) { bundleID in
                        HStack {
                            if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
                                Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                                    .resizable()
                                    .frame(width: 20, height: 20)
                                Text(FileManager.default.displayName(atPath: url.path))
                            } else {
                                Text(bundleID)
                            }
                            Spacer()
                            Button(role: .destructive) {
                                preferences.clipboardExcludedApps.removeAll { $0 == bundleID }
                            } label: {
                                Image(systemName: "minus.circle.fill")
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    Button("Add App…") {
                        addExcludedApp()
                    }
                }

                Section {
                    Button("Clear Clipboard History", role: .destructive) {
                        showClearConfirmation = true
                    }
                    .alert("Clear Clipboard History?",
                           isPresented: $showClearConfirmation) {
                        Button("Clear", role: .destructive) {
                            historyStore.clearAll()
                        }
                        Button("Cancel", role: .cancel) {}
                    } message: {
                        Text("This will permanently delete all saved clipboard items.")
                    }
                }
            }
        }
        .formStyle(.grouped)
    }

    private func addExcludedApp() {
        let panel = NSOpenPanel()
        panel.title = "Choose an application to exclude"
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.allowedContentTypes = [.application]
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            if let bundle = Bundle(url: url), let bundleID = bundle.bundleIdentifier {
                MainActor.assumeIsolated {
                    if !preferences.clipboardExcludedApps.contains(bundleID) {
                        preferences.clipboardExcludedApps.append(bundleID)
                    }
                }
            }
        }
    }
}
