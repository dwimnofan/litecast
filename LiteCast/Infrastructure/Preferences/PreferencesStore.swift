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
        static let clipboardHotkeyCode = "clipboardHotkeyKeyCode"
        static let clipboardHotkeyModifiers = "clipboardHotkeyModifiers"
        static let clipboardHotkeyName = "clipboardHotkeyName"
        static let windowManagementEnabled = "windowManagementEnabled"
        static let windowGap = "windowGap"
        static let notesEnabled = "notesEnabled"
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

    var clipboardHotkey: Hotkey {
        didSet {
            defaults.set(Int(clipboardHotkey.keyCode), forKey: Key.clipboardHotkeyCode)
            defaults.set(Int(clipboardHotkey.carbonModifiers), forKey: Key.clipboardHotkeyModifiers)
            defaults.set(clipboardHotkey.displayName, forKey: Key.clipboardHotkeyName)
        }
    }

    /// Bundle IDs of apps whose clipboard contents should not be recorded.
    var clipboardExcludedApps: [String] {
        didSet { defaults.set(clipboardExcludedApps, forKey: Key.clipboardExcludedApps) }
    }

    /// Opt-in window snap/resize via Accessibility.
    var windowManagementEnabled: Bool {
        didSet { defaults.set(windowManagementEnabled, forKey: Key.windowManagementEnabled) }
    }

    var windowGap: CGFloat {
        didSet { defaults.set(Double(windowGap), forKey: Key.windowGap) }
    }

    /// Opt-in Markdown notes folder + floating editor.
    var notesEnabled: Bool {
        didSet { defaults.set(notesEnabled, forKey: Key.notesEnabled) }
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
        if let name = defaults.string(forKey: Key.clipboardHotkeyName), defaults.object(forKey: Key.clipboardHotkeyCode) != nil {
            clipboardHotkey = Hotkey(keyCode: UInt32(defaults.integer(forKey: Key.clipboardHotkeyCode)),
                                     carbonModifiers: UInt32(defaults.integer(forKey: Key.clipboardHotkeyModifiers)),
                                     displayName: name)
        } else {
            clipboardHotkey = .shiftCommandV
        }
        clipboardExcludedApps = defaults.stringArray(forKey: Key.clipboardExcludedApps) ?? []
        windowManagementEnabled = defaults.bool(forKey: Key.windowManagementEnabled)
        let gap = defaults.object(forKey: Key.windowGap) as? Double ?? 0
        windowGap = CGFloat(gap)
        notesEnabled = defaults.bool(forKey: Key.notesEnabled)
    }

    func applyActivationPolicy() {
        NSApp?.setActivationPolicy(showInDock ? .regular : .accessory)
    }
}
