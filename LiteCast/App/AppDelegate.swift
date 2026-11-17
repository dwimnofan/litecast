import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let environment = AppEnvironment()

    static let isRunningTests = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Unit tests host the app; skip global side effects (hotkey, alerts) so a running LiteCast isn't disturbed.
        guard !Self.isRunningTests else { return }
        environment.preferences.applyActivationPolicy()
        environment.appDiscovery.refreshIfStale()
        registerLauncherHotkey()
        environment.notch.start()
        startClipboardMonitorIfEnabled()
        observeClipboardToggle()
        Log.app.info("LiteCast launched")
    }

    func applicationWillTerminate(_ notification: Notification) {
        environment.hotkeys.unregister()
        environment.launcher.hide()
        environment.notch.stop()
        environment.clipboardMonitor.stop()
        Log.app.info("LiteCast terminating")
    }

    private func registerLauncherHotkey() {
        let hotkey = environment.preferences.launcherHotkey
        do {
            try environment.applyLauncherHotkey()
        } catch {
            Log.app.error("Hotkey \(hotkey.displayName) registration failed: \(String(describing: error))")
            let alert = NSAlert()
            alert.messageText = "Couldn't register \(hotkey.displayName)"
            alert.informativeText = "Another app may already use this shortcut. You can still open the launcher from the LiteCast menu bar icon."
            alert.runModal()
        }
    }

    private func startClipboardMonitorIfEnabled() {
        if environment.preferences.clipboardHistoryEnabled {
            environment.clipboardMonitor.start()
        }
    }

    private func observeClipboardToggle() {
        // withObservationTracking fires once; re-arm by calling this method again from MainActor.
        withObservationTracking {
            _ = environment.preferences.clipboardHistoryEnabled
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if self.environment.preferences.clipboardHistoryEnabled {
                    self.environment.clipboardMonitor.start()
                } else {
                    self.environment.clipboardMonitor.stop()
                }
                self.observeClipboardToggle()
            }
        }
    }
}
