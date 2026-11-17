import AppKit

/// Constructs and owns app-wide services. Features wire themselves in here.
@MainActor
final class AppEnvironment {
    let preferences: PreferencesStore
    let hotkeys = HotkeyManager()
    let appDiscovery = AppDiscoveryService()
    let executor = CommandExecutor()
    let launcher: LauncherWindowController
    let clipboardHistoryStore = ClipboardHistoryStore()
    let clipboardMonitor: ClipboardMonitor

    init(defaults: UserDefaults = .standard) {
        preferences = PreferencesStore(defaults: defaults)
        clipboardMonitor = ClipboardMonitor(historyStore: clipboardHistoryStore, preferences: preferences)

        executor.register(.openSettings) {
            NSApp.activate(ignoringOtherApps: true)
            NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        }
        executor.register(.quit) { NSApp.terminate(nil) }

        let providers: [SearchProvider] = [
            appDiscovery,
            ClipboardHistoryProvider(historyStore: clipboardHistoryStore),
            BuiltinCommandProvider(executor: executor),
        ]
        launcher = LauncherWindowController(discovery: appDiscovery, providers: providers, executor: executor)

        // Register after all stored properties are initialized (self capture requires that).
        executor.register(.clearClipboardHistory) { [weak self] in
            guard let self else { return }
            let alert = NSAlert()
            alert.messageText = "Clear Clipboard History?"
            alert.informativeText = "This will permanently delete all saved clipboard items."
            alert.addButton(withTitle: "Clear")
            alert.addButton(withTitle: "Cancel")
            alert.alertStyle = .warning
            if alert.runModal() == .alertFirstButtonReturn {
                self.clipboardHistoryStore.clearAll()
            }
        }

        // Track our own writes so the clipboard monitor doesn't re-record them.
        executor.onCopyText = { [weak self] changeCount in
            self?.clipboardMonitor.lastOwnWriteChangeCount = changeCount
        }
    }
}
