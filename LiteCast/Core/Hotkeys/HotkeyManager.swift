import Carbon.HIToolbox

struct Hotkey: Equatable, Sendable {
    let keyCode: UInt32
    let carbonModifiers: UInt32
    let displayName: String

    static let optionSpace = Hotkey(keyCode: UInt32(kVK_Space), carbonModifiers: UInt32(optionKey), displayName: "⌥Space")
}

/// Global shortcut via Carbon RegisterEventHotKey. Needs no Accessibility permission.
@MainActor
final class HotkeyManager {
    enum RegistrationError: Error {
        case handlerInstallFailed(OSStatus)
        case registrationFailed(OSStatus)
    }

    // nonisolated(unsafe): only touched on main, plus deinit when no other reference exists.
    nonisolated(unsafe) private var hotKeyRef: EventHotKeyRef?
    nonisolated(unsafe) private var handlerRef: EventHandlerRef?
    private var action: (() -> Void)?

    func register(_ hotkey: Hotkey, action: @escaping () -> Void) throws(RegistrationError) {
        unregister()
        self.action = action

        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let handlerStatus = InstallEventHandler(
            GetApplicationEventTarget(),
            { _, _, userData in
                guard let userData else { return noErr }
                // Carbon delivers application-target events on the main thread.
                MainActor.assumeIsolated {
                    Unmanaged<HotkeyManager>.fromOpaque(userData).takeUnretainedValue().action?()
                }
                return noErr
            },
            1, &eventType, Unmanaged.passUnretained(self).toOpaque(), &handlerRef
        )
        guard handlerStatus == noErr else { throw .handlerInstallFailed(handlerStatus) }

        let id = EventHotKeyID(signature: OSType(0x4C43_4854), id: 1) // "LCHT"
        let status = RegisterEventHotKey(hotkey.keyCode, hotkey.carbonModifiers, id, GetApplicationEventTarget(), OptionBits(kEventHotKeyExclusive), &hotKeyRef)
        guard status == noErr else {
            unregister()
            throw .registrationFailed(status)
        }
    }

    deinit {
        if let hotKeyRef { UnregisterEventHotKey(hotKeyRef) }
        if let handlerRef { RemoveEventHandler(handlerRef) }
    }

    func unregister() {
        if let hotKeyRef { UnregisterEventHotKey(hotKeyRef) }
        if let handlerRef { RemoveEventHandler(handlerRef) }
        hotKeyRef = nil
        handlerRef = nil
        action = nil
    }
}
