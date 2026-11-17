import AppKit

/// Constructs and owns app-wide services. Features wire themselves in here.
@MainActor
final class AppEnvironment {
    let preferences: PreferencesStore
    let hotkeys = HotkeyManager()
    let appDiscovery = AppDiscoveryService()
    let executor = CommandExecutor()
    let launcher: LauncherWindowController
    let notch: NotchWindowController

    init(defaults: UserDefaults = .standard) {
        preferences = PreferencesStore(defaults: defaults)

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
        ]
        launcher = LauncherWindowController(discovery: appDiscovery, providers: providers, executor: executor)
        let launcher = launcher
        notch = NotchWindowController(preferences: preferences, openLauncher: { launcher.show() }, openSettings: openSettings)
        let notch = notch
        preferences.onNotchEnabledChange = { notch.applyPreference() }
    }
}
