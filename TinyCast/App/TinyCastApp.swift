import SwiftUI

@main
struct TinyCastApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra("TinyCast", systemImage: "command") {
            SettingsLink { Text("Settings…") }
                .keyboardShortcut(",")
            Divider()
            Button("Quit TinyCast") { NSApp.terminate(nil) }
                .keyboardShortcut("q")
        }

        Settings {
            SettingsView(preferences: appDelegate.environment.preferences)
        }
    }
}

struct SettingsView: View {
    @Bindable var preferences: PreferencesStore

    var body: some View {
        Form {
            Toggle("Show TinyCast in the Dock", isOn: $preferences.showInDock)
        }
        .formStyle(.grouped)
        .frame(width: 380)
        .padding()
    }
}
