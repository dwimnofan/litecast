import AppKit
import Carbon.HIToolbox

struct Hotkey: Equatable, Sendable {
    let keyCode: UInt32
    let carbonModifiers: UInt32
    let displayName: String

    static let optionSpace = Hotkey(keyCode: UInt32(kVK_Space), carbonModifiers: UInt32(optionKey), displayName: "⌥Space")
    static let shiftCommandV = Hotkey(keyCode: UInt32(kVK_ANSI_V), carbonModifiers: UInt32(shiftKey | cmdKey), displayName: "⇧⌘V")

    static func carbonModifiers(from flags: NSEvent.ModifierFlags) -> UInt32 {
        var m: UInt32 = 0
        if flags.contains(.command) { m |= UInt32(cmdKey) }
        if flags.contains(.option) { m |= UInt32(optionKey) }
        if flags.contains(.control) { m |= UInt32(controlKey) }
        if flags.contains(.shift) { m |= UInt32(shiftKey) }
        return m
    }

    private static func keyName(_ code: UInt32) -> String? {
        switch Int(code) {
        case kVK_Space: "Space"
        case kVK_Return: "Return"
        case kVK_Tab: "Tab"
        case kVK_Delete: "Delete"
        case kVK_ForwardDelete: "Fn Delete"
        case kVK_Escape: "Esc"
        case kVK_LeftArrow: "←"
        case kVK_RightArrow: "→"
        case kVK_UpArrow: "↑"
        case kVK_DownArrow: "↓"
        case kVK_F1: "F1"
        case kVK_F2: "F2"
        case kVK_F3: "F3"
        case kVK_F4: "F4"
        case kVK_F5: "F5"
        case kVK_F6: "F6"
        case kVK_F7: "F7"
        case kVK_F8: "F8"
        case kVK_F9: "F9"
        case kVK_F10: "F10"
        case kVK_F11: "F11"
        case kVK_F12: "F12"
        default: nil
        }
    }

    /// Modifier glyphs in the macOS order ⌃⌥⇧⌘ followed by the key name.
    static func displayName(keyCode: UInt32, carbonModifiers m: UInt32, characters: String?) -> String {
        var s = ""
        if m & UInt32(controlKey) != 0 { s += "⌃" }
        if m & UInt32(optionKey) != 0 { s += "⌥" }
        if m & UInt32(shiftKey) != 0 { s += "⇧" }
        if m & UInt32(cmdKey) != 0 { s += "⌘" }
        return s + (Self.keyName(keyCode) ?? characters?.uppercased() ?? "Key \(keyCode)")
    }

    /// Returns nil unless the combo has ⌘, ⌥ or ⌃ (shift alone would hijack typing).
    init?(event: NSEvent) {
        let m = Self.carbonModifiers(from: event.modifierFlags)
        guard m & UInt32(cmdKey | optionKey | controlKey) != 0 else { return nil }
        self.init(keyCode: UInt32(event.keyCode), carbonModifiers: m,
                  displayName: Self.displayName(keyCode: UInt32(event.keyCode), carbonModifiers: m, characters: event.charactersIgnoringModifiers))
    }

    init(keyCode: UInt32, carbonModifiers: UInt32, displayName: String) {
        self.keyCode = keyCode
        self.carbonModifiers = carbonModifiers
        self.displayName = displayName
    }
}

/// Global shortcuts via Carbon `RegisterEventHotKey`. Needs no Accessibility permission to *register*;
/// pasting via synthetic ⌘V (clipboard panel) may still need Accessibility.
@MainActor
final class HotkeyManager {
    enum Slot: UInt32, Hashable {
        case launcher = 1
        case clipboard = 2
    }

    enum RegistrationError: Error {
        case handlerInstallFailed(OSStatus)
        case registrationFailed(OSStatus)
    }

    // nonisolated(unsafe): only touched on main, plus deinit when no other reference exists.
    nonisolated(unsafe) private var hotKeyRefs: [UInt32: EventHotKeyRef] = [:]
    nonisolated(unsafe) private var handlerRef: EventHandlerRef?
    private var actions: [Slot: () -> Void] = [:]

    func register(_ hotkey: Hotkey, slot: Slot, action: @escaping () -> Void) throws(RegistrationError) {
        try ensureHandlerInstalled()
        unregister(slot)
        actions[slot] = action

        var ref: EventHotKeyRef?
        let id = EventHotKeyID(signature: OSType(0x4C43_4854), id: slot.rawValue) // "LCHT"
        let status = RegisterEventHotKey(
            hotkey.keyCode, hotkey.carbonModifiers, id,
            GetApplicationEventTarget(), OptionBits(kEventHotKeyExclusive), &ref
        )
        guard status == noErr, let ref else {
            actions[slot] = nil
            throw .registrationFailed(status)
        }
        hotKeyRefs[slot.rawValue] = ref
    }

    func unregister(_ slot: Slot) {
        if let ref = hotKeyRefs.removeValue(forKey: slot.rawValue) {
            UnregisterEventHotKey(ref)
        }
        actions[slot] = nil
    }

    func unregisterAll() {
        for slot in actions.keys {
            unregister(slot)
        }
        // Any leftover refs (shouldn't happen)
        for (_, ref) in hotKeyRefs {
            UnregisterEventHotKey(ref)
        }
        hotKeyRefs.removeAll()
        removeHandler()
    }

    /// Backward-compatible alias used by older call sites / terminate.
    func unregister() { unregisterAll() }

    deinit {
        for (_, ref) in hotKeyRefs { UnregisterEventHotKey(ref) }
        if let handlerRef { RemoveEventHandler(handlerRef) }
    }

    private func ensureHandlerInstalled() throws(RegistrationError) {
        guard handlerRef == nil else { return }
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let handlerStatus = InstallEventHandler(
            GetApplicationEventTarget(),
            // Carbon order: (EventHandlerCallRef, EventRef, userData) — event is the 2nd arg.
            { _, event, userData in
                guard let userData, let event else { return noErr }
                var hotKeyID = EventHotKeyID()
                let err = GetEventParameter(
                    event, EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID), nil,
                    MemoryLayout<EventHotKeyID>.size, nil, &hotKeyID
                )
                guard err == noErr else { return noErr }
                // Carbon delivers application-target events on the main thread.
                MainActor.assumeIsolated {
                    let manager = Unmanaged<HotkeyManager>.fromOpaque(userData).takeUnretainedValue()
                    if let slot = Slot(rawValue: hotKeyID.id) {
                        manager.actions[slot]?()
                    }
                }
                return noErr
            },
            1, &eventType, Unmanaged.passUnretained(self).toOpaque(), &handlerRef
        )
        guard handlerStatus == noErr else { throw .handlerInstallFailed(handlerStatus) }
    }

    private func removeHandler() {
        if let handlerRef { RemoveEventHandler(handlerRef) }
        handlerRef = nil
    }
}
