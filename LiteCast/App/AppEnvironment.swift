import AppKit

/// Constructs and owns app-wide services. Features wire themselves in here.
@MainActor
final class AppEnvironment {
    let preferences: PreferencesStore
    let hotkeys = HotkeyManager()
    let appDiscovery = AppDiscoveryService()
    let executor = CommandExecutor()
    let launcher: LauncherWindowController

    init(defaults: UserDefaults = .standard) {
        preferences = PreferencesStore(defaults: defaults)

        executor.register(.openSettings) {
            NSApp.activate(ignoringOtherApps: true)
            NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        }
        executor.register(.quit) { NSApp.terminate(nil) }

        let providers: [SearchProvider] = [
            appDiscovery,
            BuiltinCommandProvider(executor: executor),
        ]
        launcher = LauncherWindowController(discovery: appDiscovery, providers: providers, executor: executor)
    }
}
