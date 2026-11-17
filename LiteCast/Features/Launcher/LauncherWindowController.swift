import AppKit
import SwiftUI

/// Borderless panel that takes key focus without activating LiteCast,
/// so the previously active app stays frontmost when the launcher hides.
private final class LauncherPanel: NSPanel {
    var onCancel: () -> Void = {}
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
    override func cancelOperation(_ sender: Any?) { onCancel() }
}

@MainActor
final class LauncherWindowController: NSObject, NSWindowDelegate {
    private static let size = NSSize(width: 750, height: 475)

    private let model: LauncherModel
    private let discovery: AppDiscoveryService
    private lazy var panel: LauncherPanel = makePanel()

    init(discovery: AppDiscoveryService, providers: [SearchProvider], executor: CommandExecutor) {
        self.discovery = discovery
        model = LauncherModel(providers: providers, executor: executor)
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
        let size = NSSize(width: min(Self.size.width, visible.width), height: min(Self.size.height, visible.height))
        panel.setFrame(NSRect(
            x: visible.midX - size.width / 2,
            y: max(visible.minY, visible.maxY - visible.height * 0.2 - size.height),
            width: size.width,
            height: size.height
        ), display: false)
    }

    private func makePanel() -> LauncherPanel {
        let panel = LauncherPanel(
            contentRect: NSRect(origin: .zero, size: Self.size),
            styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: true
        )
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .canJoinAllApplications, .fullScreenAuxiliary, .transient]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
        panel.contentView = NSHostingView(rootView: LauncherView(model: model))
        panel.delegate = self
        panel.onCancel = { [weak self] in self?.hide() }
        return panel
    }
}
