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
    let launcher: LauncherWindowController
    let notch: NotchWindowController

    init(defaults: UserDefaults = .standard) {
        preferences = PreferencesStore(defaults: defaults)
        quicklinks = QuicklinkStore()
        snippets = SnippetStore()

        let openSettings: @MainActor () -> Void = {
            NSApp.activate(ignoringOtherApps: true)
            NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        }
        executor.register(.openSettings, handler: openSettings)
        let prefs = preferences
        executor.register(.toggleNotch) { prefs.notchEnabled.toggle() }
        executor.register(.quit) { NSApp.terminate(nil) }

        let providers: [SearchProvider] = [
            appDiscovery,
            BuiltinCommandProvider(executor: executor),
            CalculatorProvider(),
            QuicklinkProvider(store: quicklinks),
            SnippetProvider(store: snippets),
        ]
        launcher = LauncherWindowController(discovery: appDiscovery, providers: providers, executor: executor)
        let launcher = launcher
        notch = NotchWindowController(preferences: preferences, openLauncher: { launcher.show() }, openSettings: openSettings)
        let notch = notch
        preferences.onNotchEnabledChange = { notch.applyPreference() }
    }

    /// Registers (or unregisters, when disabled) the launcher hotkey from preferences.
    func applyLauncherHotkey() throws {
        guard preferences.launcherEnabled else { hotkeys.unregister(); return }
        try hotkeys.register(preferences.launcherHotkey) { [weak self] in self?.launcher.toggle() }
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
}
