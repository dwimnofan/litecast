import AppKit
import SwiftUI

/// Hosts `SettingsView` in a regular `NSWindow`.
/// SwiftUI's `SettingsLink` / `showSettingsWindow:` can't be invoked from AppKit
/// callbacks (notch, launcher commands) on macOS 14+, so we own the window.
@MainActor
final class SettingsWindowController {
    weak var environment: AppEnvironment?
    private var window: NSWindow?

    func show() {
        guard let environment else {
            Log.app.error("SettingsWindowController.show() called before environment was set")
            return
        }
        NSApp.activate(ignoringOtherApps: true)
        if let window {
            window.makeKeyAndOrderFront(nil)
            return
        }

        let hosting = NSHostingController(rootView: SettingsView(environment: environment))
        let window = NSWindow(contentViewController: hosting)
        window.title = "LiteCast Settings"
        window.styleMask = [.titled, .closable]
        window.setContentSize(NSSize(width: 560, height: 420))
        window.isReleasedWhenClosed = false
        window.center()
        self.window = window
        window.makeKeyAndOrderFront(nil)
    }
}
