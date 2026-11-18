import AppKit
import SwiftUI

private final class NotesPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

@MainActor
final class NotesWindowController: NSObject, NSWindowDelegate {
    private static let cardSize = NSSize(width: 520, height: 560)

    private let store: NoteStore
    private let model: NotesModel
    private lazy var panel: NotesPanel = makePanel()

    init(store: NoteStore) {
        self.store = store
        model = NotesModel(store: store)
        super.init()
        model.onHide = { [weak self] in self?.hide() }
    }

    var isVisible: Bool { panel.isVisible }

    func toggle() { isVisible ? hide() : show() }

    func show(select url: URL? = nil) {
        model.openLastOrEmpty()
        if let url, let note = store.notes.first(where: { $0.url == url }) {
            model.select(note)
        }
        position()
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func showNew() {
        show()
        model.create()
    }

    func hide() {
        model.flushSave()
        panel.orderOut(nil)
    }

    func windowWillClose(_ notification: Notification) {
        model.flushSave()
    }

    private func position() {
        if panel.setFrameUsingName("LiteCastNotes") { return }
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) } ?? NSScreen.main
        guard let visible = screen?.visibleFrame else { return }
        let m = LauncherWindowController.shadowMargin
        let size = NSSize(width: min(Self.cardSize.width + 2 * m, visible.width),
                          height: min(Self.cardSize.height + 2 * m, visible.height))
        panel.setFrame(NSRect(
            x: visible.maxX - size.width - 24,
            y: visible.maxY - size.height - 24,
            width: size.width,
            height: size.height
        ), display: false)
    }

    private func makePanel() -> NotesPanel {
        let panel = NotesPanel(
            contentRect: NSRect(origin: .zero, size: Self.cardSize),
            styleMask: [.titled, .closable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: true
        )
        panel.title = "Notes"
        panel.titlebarAppearsTransparent = true
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.appearance = NSAppearance(named: .aqua)
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
        panel.setFrameAutosaveName("LiteCastNotes")
        panel.contentView = NSHostingView(rootView: NotesView(model: model))
        panel.delegate = self
        panel.minSize = NSSize(width: 360, height: 280)
        return panel
    }
}
