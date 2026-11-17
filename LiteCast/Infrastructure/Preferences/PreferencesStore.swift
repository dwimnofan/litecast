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
        static let notchEnabled = "notchEnabled"
        static let notchShowMedia = "notchShowMedia"
        static let notchShowBattery = "notchShowBattery"
        static let notchShowShelf = "notchShowShelf"
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
        defaults.register(defaults: [
            Key.showInDock: true, Key.launcherEnabled: true, Key.notchEnabled: true,
            Key.notchShowMedia: true, Key.notchShowBattery: true, Key.notchShowShelf: true,
        ])
        showInDock = defaults.bool(forKey: Key.showInDock)
        launcherEnabled = defaults.bool(forKey: Key.launcherEnabled)
        if let name = defaults.string(forKey: Key.hotkeyName), defaults.object(forKey: Key.hotkeyCode) != nil {
            launcherHotkey = Hotkey(keyCode: UInt32(defaults.integer(forKey: Key.hotkeyCode)),
                                    carbonModifiers: UInt32(defaults.integer(forKey: Key.hotkeyModifiers)), displayName: name)
        } else {
            launcherHotkey = .optionSpace
        }
        notchEnabled = defaults.bool(forKey: Key.notchEnabled)
        notchShowMedia = defaults.bool(forKey: Key.notchShowMedia)
        notchShowBattery = defaults.bool(forKey: Key.notchShowBattery)
        notchShowShelf = defaults.bool(forKey: Key.notchShowShelf)
        // clipboardHistoryEnabled defaults to false (opt-in) — no register needed.
        clipboardHistoryEnabled = defaults.bool(forKey: Key.clipboardHistoryEnabled)
        clipboardExcludedApps = defaults.stringArray(forKey: Key.clipboardExcludedApps) ?? []
    }

    func applyActivationPolicy() {
        NSApp?.setActivationPolicy(showInDock ? .regular : .accessory)
    }
}
