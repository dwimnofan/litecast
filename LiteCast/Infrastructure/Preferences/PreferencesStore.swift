import AppKit
import Observation

@MainActor
@Observable
final class PreferencesStore {
    private enum Key {
        static let showInDock = "showInDock"
        static let clipboardHistoryEnabled = "clipboardHistoryEnabled"
        static let clipboardExcludedApps = "clipboardExcludedApps"
    }

    @ObservationIgnored private let defaults: UserDefaults

    var showInDock: Bool {
        didSet {
            defaults.set(showInDock, forKey: Key.showInDock)
            applyActivationPolicy()
        }
    }

    /// Default OFF — clipboard recording is opt-in since it stores everything the user copies.
    var clipboardHistoryEnabled: Bool {
        didSet { defaults.set(clipboardHistoryEnabled, forKey: Key.clipboardHistoryEnabled) }
    }

    /// Bundle IDs of apps whose clipboard contents should not be recorded.
    var clipboardExcludedApps: [String] {
        didSet { defaults.set(clipboardExcludedApps, forKey: Key.clipboardExcludedApps) }
    }

    init(defaults: UserDefaults) {
        self.defaults = defaults
        defaults.register(defaults: [Key.showInDock: true])
        showInDock = defaults.bool(forKey: Key.showInDock)
        // clipboardHistoryEnabled defaults to false (opt-in) — no register needed.
        clipboardHistoryEnabled = defaults.bool(forKey: Key.clipboardHistoryEnabled)
        clipboardExcludedApps = defaults.stringArray(forKey: Key.clipboardExcludedApps) ?? []
    }

    func applyActivationPolicy() {
        NSApp?.setActivationPolicy(showInDock ? .regular : .accessory)
    }
}
