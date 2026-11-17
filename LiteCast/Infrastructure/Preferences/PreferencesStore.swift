import AppKit
import Observation

@MainActor
@Observable
final class PreferencesStore {
    private enum Key {
        static let showInDock = "showInDock"
        static let notchEnabled = "notchEnabled"
        static let notchShowMedia = "notchShowMedia"
        static let notchShowBattery = "notchShowBattery"
        static let notchShowShelf = "notchShowShelf"
    }

    @ObservationIgnored private let defaults: UserDefaults

    var showInDock: Bool {
        didSet {
            defaults.set(showInDock, forKey: Key.showInDock)
            applyActivationPolicy()
        }
    }

    /// Notch on/off is independent of the launcher; the notch controller hooks in here.
    @ObservationIgnored var onNotchEnabledChange: (() -> Void)?

    var notchEnabled: Bool {
        didSet {
            defaults.set(notchEnabled, forKey: Key.notchEnabled)
            onNotchEnabledChange?()
        }
    }
    var notchShowMedia: Bool { didSet { defaults.set(notchShowMedia, forKey: Key.notchShowMedia) } }
    var notchShowBattery: Bool { didSet { defaults.set(notchShowBattery, forKey: Key.notchShowBattery) } }
    var notchShowShelf: Bool { didSet { defaults.set(notchShowShelf, forKey: Key.notchShowShelf) } }

    init(defaults: UserDefaults) {
        self.defaults = defaults
        defaults.register(defaults: [
            Key.showInDock: true, Key.notchEnabled: true,
            Key.notchShowMedia: true, Key.notchShowBattery: true, Key.notchShowShelf: true,
        ])
        showInDock = defaults.bool(forKey: Key.showInDock)
        notchEnabled = defaults.bool(forKey: Key.notchEnabled)
        notchShowMedia = defaults.bool(forKey: Key.notchShowMedia)
        notchShowBattery = defaults.bool(forKey: Key.notchShowBattery)
        notchShowShelf = defaults.bool(forKey: Key.notchShowShelf)
    }

    func applyActivationPolicy() {
        NSApp?.setActivationPolicy(showInDock ? .regular : .accessory)
    }
}
