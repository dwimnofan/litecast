import AppKit

/// Constructs and owns app-wide services. Features wire themselves in here.
@MainActor
final class AppEnvironment {
    let preferences: PreferencesStore
    let hotkeys = HotkeyManager()
    let appDiscovery = AppDiscoveryService()
    let executor = CommandExecutor()
    let quicklinks: QuicklinkStore
    let snippets: SnippetStore
    let noteStore: NoteStore
    let windowManager = WindowManager()
    let launcher: LauncherWindowController
    let notch: NotchWindowController
    let settings = SettingsWindowController()
    let clipboardHistoryStore = ClipboardHistoryStore()
    let clipboardMonitor: ClipboardMonitor
    let clipboard: ClipboardWindowController
    let notes: NotesWindowController

    init(defaults: UserDefaults = .standard) {
        preferences = PreferencesStore(defaults: defaults)
        quicklinks = QuicklinkStore()
        snippets = SnippetStore()
        noteStore = NoteStore(defaults: defaults)
        clipboardMonitor = ClipboardMonitor(historyStore: clipboardHistoryStore, preferences: preferences)
        windowManager.gap = preferences.windowGap

        let prefs = preferences
        executor.register(.toggleNotch) { prefs.notchEnabled.toggle() }
        executor.register(.quit) { NSApp.terminate(nil) }

        let providers: [SearchProvider] = [
            appDiscovery,
            ClipboardHistoryProvider(historyStore: clipboardHistoryStore),
            WindowManagementProvider(preferences: preferences, manager: windowManager),
            NotesProvider(preferences: preferences, store: noteStore),
            BuiltinCommandProvider(executor: executor),
            CalculatorProvider(),
            QuicklinkProvider(store: quicklinks),
            SnippetProvider(store: snippets),
        ]
        launcher = LauncherWindowController(discovery: appDiscovery, providers: providers, executor: executor)
        let launcher = launcher
        // Settings opens via our own NSWindow — showSettingsWindow: is unavailable from AppKit on macOS 14+.
        let settings = settings
        let openSettings: @MainActor () -> Void = { settings.show() }
        executor.register(.openSettings, handler: openSettings)
        notch = NotchWindowController(preferences: preferences, openLauncher: { launcher.show() }, openSettings: openSettings)
        let notch = notch
        preferences.onNotchEnabledChange = { notch.applyPreference() }

        let monitor = clipboardMonitor
        clipboard = ClipboardWindowController(historyStore: clipboardHistoryStore) { changeCount in
            monitor.lastOwnWriteChangeCount = changeCount
        }
        let clipboard = clipboard
        executor.register(.openClipboardHistory) {
            guard prefs.clipboardHistoryEnabled else { return }
            launcher.hide()
            clipboard.show()
        }

        notes = NotesWindowController(store: noteStore)
        let notes = notes
        let windowManager = windowManager
        executor.register(.showNotes) {
            guard prefs.notesEnabled else { return }
            launcher.hide()
            notes.toggle()
        }
        executor.register(.createNote) {
            guard prefs.notesEnabled else { return }
            launcher.hide()
            notes.showNew()
        }
        executor.onOpenNote = { url in
            guard prefs.notesEnabled else { return }
            launcher.hide()
            notes.show(select: url)
        }
        executor.onWindowPlacement = { placement in
            guard prefs.windowManagementEnabled else {
                throw CommandExecutor.ExecutionError.unavailableFeature("Window Management")
            }
            if !WindowManager.isTrusted {
                WindowManager.ensureTrusted(prompt: true)
            }
            windowManager.gap = prefs.windowGap
            // Hide launcher first so the previously focused app is frontmost again.
            launcher.hide()
            try? await Task.sleep(nanoseconds: 50_000_000)
            try windowManager.apply(placement)
        }

        // After all stored properties are initialized.
        settings.environment = self
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

    /// Registers (or unregisters, when disabled) the launcher hotkey from preferences.
    func applyLauncherHotkey() throws {
        if preferences.launcherEnabled {
            try hotkeys.register(preferences.launcherHotkey, slot: .launcher) { [weak self] in
                self?.clipboard.hide()
                self?.launcher.toggle()
            }
        } else {
            hotkeys.unregister(.launcher)
        }
    }

    /// Registers (or unregisters) the clipboard-history hotkey when the feature is enabled.
    func applyClipboardHotkey() throws {
        if preferences.clipboardHistoryEnabled {
            try hotkeys.register(preferences.clipboardHotkey, slot: .clipboard) { [weak self] in
                self?.launcher.hide()
                self?.clipboard.toggle()
            }
        } else {
            hotkeys.unregister(.clipboard)
            clipboard.hide()
        }
    }

    /// Switches the hotkey; on failure keeps (and re-registers) the previous one and returns a message.
    func changeLauncherHotkey(to new: Hotkey) -> String? {
        let old = preferences.launcherHotkey
        preferences.launcherHotkey = new
        do { try applyLauncherHotkey(); return nil } catch {
            preferences.launcherHotkey = old
            try? applyLauncherHotkey()
            return "\(new.displayName) is unavailable (another app may use it). Kept \(old.displayName)."
        }
    }

    func changeClipboardHotkey(to new: Hotkey) -> String? {
        let old = preferences.clipboardHotkey
        preferences.clipboardHotkey = new
        do { try applyClipboardHotkey(); return nil } catch {
            preferences.clipboardHotkey = old
            try? applyClipboardHotkey()
            return "\(new.displayName) is unavailable (another app may use it). Kept \(old.displayName)."
        }
    }
}
