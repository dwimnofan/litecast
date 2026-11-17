import Carbon.HIToolbox
import ServiceManagement
import SwiftUI

/// One tab per feature. Features add their own tab here.
struct SettingsView: View {
    let environment: AppEnvironment

    var body: some View {
        TabView {
            GeneralSettingsView(environment: environment)
                .tabItem { Label("General", systemImage: "gearshape") }
        }
        .frame(width: 560, height: 420)
    }
}

struct GeneralSettingsView: View {
    let environment: AppEnvironment
    @State private var hotkeyError: String?
    @State private var loginStatus = SMAppService.mainApp.status
    @State private var loginError: String?

    var body: some View {
        @Bindable var preferences = environment.preferences
        Form {
            Toggle("Show LiteCast in the Dock", isOn: $preferences.showInDock)

            Section("Launcher") {
                Toggle("Enable launcher hotkey", isOn: $preferences.launcherEnabled)
                    .onChange(of: preferences.launcherEnabled) {
                        hotkeyError = nil
                        do { try environment.applyLauncherHotkey() } catch {
                            hotkeyError = "Couldn't register \(preferences.launcherHotkey.displayName)."
                        }
                    }
                LabeledContent("Shortcut") {
                    HStack {
                        ShortcutRecorder(current: preferences.launcherHotkey) { hotkeyError = environment.changeLauncherHotkey(to: $0) }
                        Button("Reset") { hotkeyError = environment.changeLauncherHotkey(to: .optionSpace) }
                            .disabled(preferences.launcherHotkey == .optionSpace)
                            .accessibilityLabel("Reset shortcut to Option Space")
                    }
                }
                .disabled(!preferences.launcherEnabled)
                if let hotkeyError {
                    Text(hotkeyError).foregroundStyle(.red).font(.callout)
                }
            }

            Section("Startup") {
                Toggle("Launch LiteCast at login", isOn: Binding(
                    get: { loginStatus == .enabled || loginStatus == .requiresApproval },
                    set: { setLaunchAtLogin($0) }
                ))
                if loginStatus == .requiresApproval {
                    HStack {
                        Text("Approval needed in System Settings.").font(.callout)
                        Button("Open Login Items") { SMAppService.openSystemSettingsLoginItems() }
                    }
                }
                if let loginError {
                    Text(loginError).foregroundStyle(.red).font(.callout)
                }
            }
        }
        .formStyle(.grouped)
        .onAppear { loginStatus = SMAppService.mainApp.status }
    }

    private func setLaunchAtLogin(_ on: Bool) {
        loginError = nil
        do {
            if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
        } catch {
            loginError = error.localizedDescription
        }
        loginStatus = SMAppService.mainApp.status
    }
}

/// Click to record; the next combo with ⌘/⌥/⌃ is captured, Esc cancels.
private struct ShortcutRecorder: View {
    let current: Hotkey
    let onRecord: (Hotkey) -> Void
    @State private var recorder = Recorder()

    var body: some View {
        Button(recorder.isRecording ? "Type shortcut… (Esc to cancel)" : current.displayName) {
            recorder.isRecording ? recorder.stop() : recorder.start(onRecord)
        }
        .accessibilityLabel("Launcher shortcut")
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
