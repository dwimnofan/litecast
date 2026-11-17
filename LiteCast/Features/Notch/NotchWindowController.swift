import AppKit
import SwiftUI

/// Never key, never main: hovering the notch must not steal focus from the frontmost app.
private final class NotchPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
    // Borderless windows above the menu bar must be allowed to sit over it.
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect { frameRect }
}

@MainActor
final class NotchWindowController {
    let state = NotchState()
    let nowPlaying = NowPlayingService()
    let battery = BatteryMonitor()
    let shelf = ShelfStore()

    private let preferences: PreferencesStore
    private let openLauncher: @MainActor () -> Void
    private let openSettings: @MainActor () -> Void
    private var panel: NotchPanel?
    private var geometry: NotchGeometry?
    private var monitors: [Any] = []
    private var screenObserver: NSObjectProtocol?

    init(preferences: PreferencesStore, openLauncher: @escaping @MainActor () -> Void, openSettings: @escaping @MainActor () -> Void) {
        self.preferences = preferences
        self.openLauncher = openLauncher
        self.openSettings = openSettings
    }

    func applyPreference() { preferences.notchEnabled ? start() : stop() }

    func start() {
        guard preferences.notchEnabled, panel == nil else { return }
        let panel = makePanel()
        self.panel = panel
        reposition()
        panel.orderFrontRegardless()
        installMonitors()
        battery.start()
        nowPlaying.start()
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
        ) { [weak self] _ in Task { @MainActor in self?.reposition() } }
    }

    func stop() {
        guard let panel else { return }
        monitors.forEach { NSEvent.removeMonitor($0) }
        monitors = []
        if let screenObserver { NotificationCenter.default.removeObserver(screenObserver) }
        screenObserver = nil
        battery.stop()
        nowPlaying.stop()
        state.isExpanded = false
        panel.orderOut(nil)
        self.panel = nil
    }

    private func makePanel() -> NotchPanel {
        let panel = NotchPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.level = NSWindow.Level(rawValue: NSWindow.Level.mainMenu.rawValue + 1)
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
        panel.acceptsMouseMovedEvents = true
        panel.ignoresMouseEvents = true // collapsed: clicks fall through to the menu bar
        let host = NSHostingView(rootView: NotchRootView(
            state: state, nowPlaying: nowPlaying, battery: battery, shelf: shelf, preferences: preferences,
            openLauncher: openLauncher, openSettings: openSettings))
        host.sizingOptions = [] // the panel frame is ours, not SwiftUI's
        panel.contentView = host
        return panel
    }

    private func reposition() {
        guard let panel, let geometry = NotchGeometryProvider.current() else { return }
        self.geometry = geometry
        state.apply(geometry)
        panel.setFrame(geometry.panelFrame(size: NotchLayout.expandedSize), display: true)
    }

    // Global monitors never see events for our own windows, hence the local one for when we are expanded.
    // Drags are included so hovering a file drag over the notch expands it as a drop target.
    private func installMonitors() {
        let mask: NSEvent.EventTypeMask = [.mouseMoved, .leftMouseDragged, .leftMouseUp]
        if let global = NSEvent.addGlobalMonitorForEvents(matching: mask, handler: { [weak self] _ in
            Task { @MainActor in self?.mouseChanged() }
        }) { monitors.append(global) }
        if let local = NSEvent.addLocalMonitorForEvents(matching: mask, handler: { [weak self] event in
            Task { @MainActor in self?.mouseChanged() }
            return event
        }) { monitors.append(local) }
    }

    private func mouseChanged() {
        guard let panel, let geometry else { return }
        let mouse = NSEvent.mouseLocation
        if !state.isExpanded {
            if NotchGeometry.hit(geometry.hoverRect, mouse) { setExpanded(true, panel: panel) }
        } else if !NotchGeometry.hit(panel.frame, mouse), NSEvent.pressedMouseButtons == 0 {
            // Stay open while a button is held so a drag out of the shelf isn't torn down mid-flight.
            setExpanded(false, panel: panel)
        }
    }

    private func setExpanded(_ expanded: Bool, panel: NotchPanel) {
        state.isExpanded = expanded
        panel.ignoresMouseEvents = !expanded
        if expanded { nowPlaying.refresh() }
    }
}
