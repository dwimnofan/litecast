import SwiftUI
import AppKit
import Carbon.HIToolbox

/// Settings tab for clipboard history: enable/disable, hotkey, retention, exclusions, clear.
struct ClipboardSettingsView: View {
    let environment: AppEnvironment
    @Bindable var preferences: PreferencesStore
    @Bindable var historyStore: ClipboardHistoryStore

    @State private var showClearConfirmation = false
    @State private var hotkeyError: String?

    var body: some View {
        Form {
            Section {
                Toggle(isOn: $preferences.clipboardHistoryEnabled) {
                    Text("Enable Clipboard History")
                }
                Text("When enabled, LiteCast records text and images you copy. History is stored locally in ~/Library/Application Support/LiteCast/.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if preferences.clipboardHistoryEnabled {
                Section("Shortcut") {
                    LabeledContent("Open history") {
                        HStack {
                            ShortcutRecorderControl(current: preferences.clipboardHotkey, accessibilityLabel: "Clipboard History shortcut") {
                                hotkeyError = environment.changeClipboardHotkey(to: $0)
                            }
                            Button("Reset") { hotkeyError = environment.changeClipboardHotkey(to: .shiftCommandV) }
                                .disabled(preferences.clipboardHotkey == .shiftCommandV)
                        }
                    }
                    if let hotkeyError {
                        Text(hotkeyError).foregroundStyle(.red).font(.callout)
                    }
                    Text("Paste uses a synthetic ⌘V after the panel hides. If paste never reaches the other app, grant Accessibility to LiteCast in System Settings.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

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

/// Click to record; the next combo with ⌘/⌥/⌃ is captured, Esc cancels.
struct ShortcutRecorderControl: View {
    let current: Hotkey
    var accessibilityLabel: String = "Shortcut"
    let onRecord: (Hotkey) -> Void
    @State private var recorder = Recorder()

    var body: some View {
        Button(recorder.isRecording ? "Type shortcut… (Esc to cancel)" : current.displayName) {
            recorder.isRecording ? recorder.stop() : recorder.start(onRecord)
        }
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(recorder.isRecording ? "Recording" : current.displayName)
        .accessibilityHint("Activate, then press the new key combination")
        .onDisappear { recorder.stop() }
    }

    @MainActor @Observable
    final class Recorder {
        var isRecording = false
        @ObservationIgnored private var monitor: Any?

        func start(_ onRecord: @escaping (Hotkey) -> Void) {
            isRecording = true
            monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                let isEscape = event.keyCode == UInt16(kVK_Escape)
                let hotkey = Hotkey(event: event)
                MainActor.assumeIsolated {
                    if isEscape { self?.stop(); return }
                    guard let hotkey else { NSSound.beep(); return }
                    self?.stop()
                    onRecord(hotkey)
                }
                return nil
            }
        }

        func stop() {
            if let monitor { NSEvent.removeMonitor(monitor) }
            monitor = nil
            isRecording = false
        }
    }
}
