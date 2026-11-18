import SwiftUI

@main
struct LiteCastApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra("LiteCast", systemImage: "command") {
            if appDelegate.environment.preferences.launcherEnabled {
                Button("Open Launcher  \(appDelegate.environment.preferences.launcherHotkey.displayName)") { appDelegate.environment.launcher.show() }
            }
            if appDelegate.environment.preferences.clipboardHistoryEnabled {
                Button("Clipboard History  \(appDelegate.environment.preferences.clipboardHotkey.displayName)") {
                    appDelegate.environment.launcher.hide()
                    appDelegate.environment.clipboard.show()
                }
            }
            if appDelegate.environment.preferences.notesEnabled {
                Button("Notes") {
                    appDelegate.environment.launcher.hide()
                    appDelegate.environment.notes.toggle()
                }
            }
            Button("Toggle Notch") { appDelegate.environment.preferences.notchEnabled.toggle() }
            Divider()
            Button("Settings…") { appDelegate.environment.settings.show() }
                .keyboardShortcut(",")
            Divider()
            Button("Quit LiteCast") { NSApp.terminate(nil) }
                .keyboardShortcut("q")
        }
    }
}
