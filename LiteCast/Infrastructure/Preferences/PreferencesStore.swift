import AppKit
import Observation

@MainActor
@Observable
final class PreferencesStore {
    private enum Key {
        static let showInDock = "showInDock"
    }

    @ObservationIgnored private let defaults: UserDefaults

    var showInDock: Bool {
        didSet {
            defaults.set(showInDock, forKey: Key.showInDock)
            applyActivationPolicy()
        }
    }

    init(defaults: UserDefaults) {
        self.defaults = defaults
        defaults.register(defaults: [Key.showInDock: true])
        showInDock = defaults.bool(forKey: Key.showInDock)
    }

    func applyActivationPolicy() {
        NSApp?.setActivationPolicy(showInDock ? .regular : .accessory)
    }
}
