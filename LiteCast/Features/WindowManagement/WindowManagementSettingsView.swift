import ApplicationServices
import SwiftUI

struct WindowManagementSettingsView: View {
    @Bindable var preferences: PreferencesStore
    let manager: WindowManager
    @State private var trusted = WindowManager.isTrusted

    var body: some View {
        Form {
            Section {
                Toggle("Enable Window Management", isOn: $preferences.windowManagementEnabled)
                Text("Snap the focused window to halves, thirds, quarters, maximize, or center. Uses Accessibility (same permission as paste).")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if preferences.windowManagementEnabled {
                Section("Layout") {
                    Stepper("Gap between windows: \(Int(preferences.windowGap)) pt",
                            value: $preferences.windowGap, in: 0...64, step: 2)
                        .onChange(of: preferences.windowGap) {
                            manager.gap = preferences.windowGap
                        }
                }

                Section("Permission") {
                    LabeledContent("Accessibility") {
                        Text(trusted ? "Allowed" : "Not allowed")
                            .foregroundStyle(trusted ? Color.secondary : Color.red)
                    }
                    if !trusted {
                        Button("Request Accessibility Access…") {
                            WindowManager.ensureTrusted(prompt: true)
                            trusted = WindowManager.isTrusted
                        }
                        Text("System Settings → Privacy & Security → Accessibility → enable LiteCast.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Button("Refresh Status") { trusted = WindowManager.isTrusted }
                    }
                }

                Section("Commands") {
                    Text("Search in the launcher: Left Half, Maximize, First Third, Restore Window, …")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .onAppear {
            trusted = WindowManager.isTrusted
            manager.gap = preferences.windowGap
        }
    }
}
