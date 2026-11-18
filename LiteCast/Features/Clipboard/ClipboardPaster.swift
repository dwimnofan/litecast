import AppKit
import Carbon.HIToolbox

/// Writes an item to the general pasteboard and optionally synthesizes ⌘V.
///
/// Callers must hide any LiteCast key window first and wait a short beat, otherwise
/// the synthetic paste lands in our own UI.
enum ClipboardPaster {
    /// Delay after hiding the panel before posting ⌘V.
    static let pasteDelayNanoseconds: UInt64 = 80_000_000

    @MainActor
    static func writeToPasteboard(_ item: ClipboardItem, imageData: Data?, onOwnWrite: ((Int) -> Void)?) {
        let pb = NSPasteboard.general
        pb.clearContents()
        switch item.kind {
        case .text, .link:
            pb.setString(item.text, forType: .string)
        case .image:
            if let imageData {
                // Prefer TIFF for broad paste targets; also offer PNG.
                if let image = NSImage(data: imageData), let tiff = image.tiffRepresentation {
                    pb.setData(tiff, forType: .tiff)
                }
                pb.setData(imageData, forType: .png)
            }
        }
        onOwnWrite?(pb.changeCount)
    }

    /// Posts ⌘V via `CGEvent`. May require Accessibility permission on locked-down Macs.
    static func postCommandV() {
        let source = CGEventSource(stateID: .hidSystemState)
        let down = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: true)
        down?.flags = .maskCommand
        let up = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: false)
        up?.flags = .maskCommand
        down?.post(tap: .cghidEventTap)
        up?.post(tap: .cghidEventTap)
    }

    @MainActor
    static func paste(_ item: ClipboardItem, imageData: Data?, onOwnWrite: ((Int) -> Void)?) async {
        writeToPasteboard(item, imageData: imageData, onOwnWrite: onOwnWrite)
        try? await Task.sleep(nanoseconds: pasteDelayNanoseconds)
        postCommandV()
    }
}
