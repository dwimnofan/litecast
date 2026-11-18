import AppKit
import SwiftUI

/// Borderless panel that takes key focus without activating LiteCast,
/// so the previously active app stays frontmost for paste-via-⌘V.
private final class ClipboardPanel: NSPanel {
    var onCancel: () -> Void = {}
    var onKeyDown: (NSEvent) -> Bool = { _ in false }
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
    override func cancelOperation(_ sender: Any?) { onCancel() }

    override func sendEvent(_ event: NSEvent) {
        if event.type == .keyDown, onKeyDown(event) { return }
        super.sendEvent(event)
    }
}

@MainActor
final class ClipboardWindowController: NSObject, NSWindowDelegate {
    private static let cardSize = NSSize(width: 820, height: 520)

    private let model: ClipboardModel
    private lazy var panel: ClipboardPanel = makePanel()

    init(historyStore: ClipboardHistoryStore, onOwnWrite: @escaping (Int) -> Void) {
        model = ClipboardModel(historyStore: historyStore, onOwnWrite: onOwnWrite)
        super.init()
        model.onFinish = { [weak self] in self?.hide() }
    }

    var isVisible: Bool { panel.isVisible }

    func toggle() { isVisible ? hide() : show() }

    func show() {
        model.reset()
        position()
        Task { @MainActor [weak self] in
            guard let self else { return }
            panel.makeKeyAndOrderFront(nil)
        }
    }

    func hide() {
        panel.orderOut(nil)
    }

    func windowDidResignKey(_ notification: Notification) {
        hide()
    }

    private func position() {
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) } ?? NSScreen.main
        guard let visible = screen?.visibleFrame else { return }
        let m = LauncherWindowController.shadowMargin
        let size = NSSize(width: min(Self.cardSize.width + 2 * m, visible.width),
                          height: min(Self.cardSize.height + 2 * m, visible.height))
        panel.setFrame(NSRect(
            x: visible.midX - size.width / 2,
            y: max(visible.minY, visible.midY - size.height / 2),
            width: size.width,
            height: size.height
        ), display: false)
    }

    private func makePanel() -> ClipboardPanel {
        let panel = ClipboardPanel(
            contentRect: NSRect(origin: .zero, size: Self.cardSize),
            styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: true
        )
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .canJoinAllApplications, .fullScreenAuxiliary, .transient]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.appearance = NSAppearance(named: .aqua)
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
        panel.contentView = NSHostingView(rootView: ClipboardView(model: model))
        panel.delegate = self
        panel.onCancel = { [weak self] in self?.hide() }
        panel.onKeyDown = { [weak self, weak panel] event in
            guard let self else { return false }
            let composing = (panel?.firstResponder as? NSTextView)?.hasMarkedText() ?? false
            switch model.handleKey(keyCode: Int(event.keyCode), modifiers: event.modifierFlags, composing: composing) {
            case .handled: return true
            case .dismiss: hide(); return true
            case .passThrough: return false
            }
        }
        return panel
    }
}
