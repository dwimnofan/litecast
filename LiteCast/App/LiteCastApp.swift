import SwiftUI

@main
struct LiteCastApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra("LiteCast", systemImage: "command") {
            Button("Open Launcher  \(Hotkey.optionSpace.displayName)") { appDelegate.environment.launcher.show() }
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
