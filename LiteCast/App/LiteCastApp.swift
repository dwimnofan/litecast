import SwiftUI

@main
struct LiteCastApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra("LiteCast", systemImage: "command") {
            if appDelegate.environment.preferences.launcherEnabled {
                Button("Open Launcher  \(appDelegate.environment.preferences.launcherHotkey.displayName)") { appDelegate.environment.launcher.show() }
            }
            Button("Toggle Notch") { appDelegate.environment.preferences.notchEnabled.toggle() }
            Divider()
            SettingsLink { Text("Settings…") }
                .keyboardShortcut(",")
            Divider()
            Button("Quit LiteCast") { NSApp.terminate(nil) }
                .keyboardShortcut("q")
        }

        Settings {
            SettingsView(environment: appDelegate.environment)
        }
    }
}
