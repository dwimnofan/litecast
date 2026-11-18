import AppKit
import SwiftUI

/// Borderless panel that takes key focus without activating LiteCast,
/// so the previously active app stays frontmost when the launcher hides.
private final class LauncherPanel: NSPanel {
    var onCancel: () -> Void = {}
    var onKeyDown: (NSEvent) -> Bool = { _ in false }
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
    override func cancelOperation(_ sender: Any?) { onCancel() }

    // Intercept navigation keys before the text field's editor sees them.
    override func sendEvent(_ event: NSEvent) {
        if event.type == .keyDown, onKeyDown(event) { return }
        super.sendEvent(event)
    }
}

@MainActor
final class LauncherWindowController: NSObject, NSWindowDelegate {
    private static let cardSize = NSSize(width: 750, height: 475)
    /// Transparent margin so the card's shadows aren't clipped by the window.
    static let shadowMargin: CGFloat = 24

    private let model: LauncherModel
    private let discovery: AppDiscoveryService
    private lazy var panel: LauncherPanel = makePanel()

    init(discovery: AppDiscoveryService, providers: [SearchProvider], executor: CommandExecutor) {
        self.discovery = discovery
        model = LauncherModel(providers: providers, executor: executor, usage: UsageStore())
        super.init()
        model.onFinish = { [weak self] in self?.hide() }
        discovery.onUpdate = { [weak model] in model?.updateResults() }
    }

    var isVisible: Bool { panel.isVisible }

    func toggle() { isVisible ? hide() : show() }

    func show() {
        discovery.refreshIfStale()
        model.reset()
        position()
        // Next turn: lets a closing menu-bar menu restore its key window first,
        // otherwise the panel resigns key immediately and hides.
        Task { @MainActor [weak self] in
            guard let self else { return }
            panel.makeKeyAndOrderFront(nil)
            model.requestFocus()
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
        let m = Self.shadowMargin
        let size = NSSize(width: min(Self.cardSize.width + 2 * m, visible.width),
                          height: min(Self.cardSize.height + 2 * m, visible.height))
        panel.setFrame(NSRect(
            x: visible.midX - size.width / 2,
            y: max(visible.minY, visible.maxY - visible.height * 0.18 - size.height + m),
            width: size.width,
            height: size.height
        ), display: false)
    }

    private func makePanel() -> LauncherPanel {
        let panel = LauncherPanel(
            contentRect: NSRect(origin: .zero, size: Self.cardSize),
            styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: true
        )
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .canJoinAllApplications, .fullScreenAuxiliary, .transient]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false // the card draws its own paper shadows
        panel.appearance = NSAppearance(named: .aqua) // Paper / Ink is a light theme
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
        panel.contentView = NSHostingView(rootView: LauncherView(model: model))
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
