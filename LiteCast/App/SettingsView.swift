import ServiceManagement
import SwiftUI

/// One tab per feature. Features add their own tab here.
struct SettingsView: View {
    let environment: AppEnvironment

    var body: some View {
        TabView {
            GeneralSettingsView(environment: environment)
                .tabItem { Label("General", systemImage: "gearshape") }
            NotchSettingsView(preferences: environment.preferences)
                .tabItem { Label("Notch", systemImage: "rectangle.topthird.inset.filled") }
            QuicklinksSettingsView(store: environment.quicklinks)
                .tabItem { Label("Quicklinks", systemImage: "link") }
            SnippetsSettingsView(store: environment.snippets)
                .tabItem { Label("Snippets", systemImage: "text.quote") }
            ClipboardSettingsView(environment: environment,
                                  preferences: environment.preferences,
                                  historyStore: environment.clipboardHistoryStore)
                .tabItem { Label("Clipboard", systemImage: "doc.on.clipboard") }
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
                        ShortcutRecorderControl(current: preferences.launcherHotkey, accessibilityLabel: "Launcher shortcut") {
                            hotkeyError = environment.changeLauncherHotkey(to: $0)
                        }
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

struct NotchSettingsView: View {
    @Bindable var preferences: PreferencesStore

    var body: some View {
        Form {
            Toggle("Enable notch", isOn: $preferences.notchEnabled)
            Section("Widgets") {
                Toggle("Now Playing (Music, Spotify)", isOn: $preferences.notchShowMedia)
                Toggle("Battery", isOn: $preferences.notchShowBattery)
                Toggle("File shelf", isOn: $preferences.notchShowShelf)
            }
            .disabled(!preferences.notchEnabled)
            Text("Now Playing asks for Automation permission the first time Music or Spotify is playing.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .formStyle(.grouped)
    }
}
