import AppKit
import Observation

@MainActor
@Observable
final class PreferencesStore {
    private enum Key {
        static let showInDock = "showInDock"
        static let launcherEnabled = "launcherEnabled"
        static let hotkeyCode = "launcherHotkeyKeyCode"
        static let hotkeyModifiers = "launcherHotkeyModifiers"
        static let hotkeyName = "launcherHotkeyName"
    }

    @ObservationIgnored private let defaults: UserDefaults

    var showInDock: Bool {
        didSet {
            defaults.set(showInDock, forKey: Key.showInDock)
            applyActivationPolicy()
        }
    }

    var launcherEnabled: Bool {
        didSet { defaults.set(launcherEnabled, forKey: Key.launcherEnabled) }
    }

    var launcherHotkey: Hotkey {
        didSet {
            defaults.set(Int(launcherHotkey.keyCode), forKey: Key.hotkeyCode)
            defaults.set(Int(launcherHotkey.carbonModifiers), forKey: Key.hotkeyModifiers)
            defaults.set(launcherHotkey.displayName, forKey: Key.hotkeyName)
        }
    }

    init(defaults: UserDefaults) {
        self.defaults = defaults
        defaults.register(defaults: [Key.showInDock: true, Key.launcherEnabled: true])
        showInDock = defaults.bool(forKey: Key.showInDock)
        launcherEnabled = defaults.bool(forKey: Key.launcherEnabled)
        if let name = defaults.string(forKey: Key.hotkeyName), defaults.object(forKey: Key.hotkeyCode) != nil {
            launcherHotkey = Hotkey(keyCode: UInt32(defaults.integer(forKey: Key.hotkeyCode)),
                                    carbonModifiers: UInt32(defaults.integer(forKey: Key.hotkeyModifiers)), displayName: name)
        } else {
            launcherHotkey = .optionSpace
        }
    }

    func applyActivationPolicy() {
        NSApp?.setActivationPolicy(showInDock ? .regular : .accessory)
    }
}
