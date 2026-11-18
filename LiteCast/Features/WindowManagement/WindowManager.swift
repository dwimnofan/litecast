import AppKit
import ApplicationServices

/// Moves/resizes the focused window via Accessibility (public AX APIs only).
@MainActor
final class WindowManager {
    enum ManagerError: LocalizedError {
        case notTrusted
        case noFocusedWindow
        case notSettable
        case axFailure(AXError)

        var errorDescription: String? {
            switch self {
            case .notTrusted:
                "LiteCast needs Accessibility permission to move windows. Enable it in System Settings → Privacy & Security → Accessibility."
            case .noFocusedWindow:
                "No focused window to move."
            case .notSettable:
                "That window can't be moved or resized."
            case .axFailure(let err):
                "Accessibility error (\(err.rawValue))."
            }
        }
    }

    private struct RestoreKey: Hashable {
        let pid: pid_t
        let windowID: String
    }

    private var restoreFrames: [RestoreKey: CGRect] = [:]
    private let maxRestoreEntries = 64

    var gap: CGFloat = 0

    /// Returns whether the process is trusted; optionally shows the system prompt.
    @discardableResult
    static func ensureTrusted(prompt: Bool) -> Bool {
        // Avoid referencing the non-Sendable CF global under Swift 6; the key string is stable.
        let opts = ["AXTrustedCheckOptionPrompt": prompt] as CFDictionary
        return AXIsProcessTrustedWithOptions(opts)
    }

    static var isTrusted: Bool { AXIsProcessTrusted() }

    func apply(_ placement: WindowPlacement) throws {
        guard Self.isTrusted else { throw ManagerError.notTrusted }
        if placement == .restore {
            try restoreFocused()
            return
        }

        let window = try focusedWindow()
        let current = try frame(of: window)
        let key = try restoreKey(for: window)
        if restoreFrames[key] == nil {
            restoreFrames[key] = current
            trimRestoreIfNeeded()
        }

        let screen = NSScreen.screens.first { $0.frame.intersects(current) }
            ?? NSScreen.main
            ?? NSScreen.screens.first
        guard let visible = screen?.visibleFrame else { throw ManagerError.noFocusedWindow }

        let target = placement.frame(in: visible, gap: gap)
        try setFrame(target, of: window)
    }

    // MARK: - AX helpers

    private func focusedWindow() throws -> AXUIElement {
        guard let app = NSWorkspace.shared.frontmostApplication else { throw ManagerError.noFocusedWindow }
        // Skip ourselves — launcher/settings shouldn't be tiled by accident after an action.
        if app.bundleIdentifier == Bundle.main.bundleIdentifier { throw ManagerError.noFocusedWindow }

        let appElement = AXUIElementCreateApplication(app.processIdentifier)
        var value: CFTypeRef?
        let err = AXUIElementCopyAttributeValue(appElement, kAXFocusedWindowAttribute as CFString, &value)
        guard err == .success, let value else { throw ManagerError.noFocusedWindow }
        return unsafeBitCast(value, to: AXUIElement.self)
    }

    private func restoreKey(for window: AXUIElement) throws -> RestoreKey {
        var pid: pid_t = 0
        AXUIElementGetPid(window, &pid)
        var value: CFTypeRef?
        let err = AXUIElementCopyAttributeValue(window, kAXTitleAttribute as CFString, &value)
        let title = (err == .success ? value as? String : nil) ?? ""
        // Title + pid is imperfect but enough for Restore in a session; AX has no stable public window UUID.
        return RestoreKey(pid: pid, windowID: "\(title.hashValue)")
    }

    private func frame(of window: AXUIElement) throws -> CGRect {
        var posRef: CFTypeRef?
        var sizeRef: CFTypeRef?
        let posErr = AXUIElementCopyAttributeValue(window, kAXPositionAttribute as CFString, &posRef)
        let sizeErr = AXUIElementCopyAttributeValue(window, kAXSizeAttribute as CFString, &sizeRef)
        guard posErr == .success, sizeErr == .success,
              let posRef, let sizeRef else { throw ManagerError.notSettable }

        var position = CGPoint.zero
        var size = CGSize.zero
        // AX uses top-left Cocoa? Actually AX position is top-left in screen coords with y from top.
        guard AXValueGetValue(posRef as! AXValue, .cgPoint, &position),
              AXValueGetValue(sizeRef as! AXValue, .cgSize, &size) else {
            throw ManagerError.notSettable
        }
        // Convert AX (origin top-left, y down from top of primary?) — on macOS AX uses
        // global Cocoa coordinates with origin bottom-left of the primary screen... 
        // Actually: AXUIElement position is in the same coordinate space as NSEvent/CGWindow,
        // which for AX is top-left based on some docs, but AppKit screens use bottom-left.
        // The reliable approach used by many apps: treat AX get/set as the same space without conversion
        // when both read and write go through AX. NSScreen.visibleFrame is bottom-left Cocoa.
        // Convert Cocoa bottom-left rect → AX top-left for set, and reverse for get.
        return Self.axToCocoa(origin: position, size: size)
    }

    private func setFrame(_ cocoa: CGRect, of window: AXUIElement) throws {
        var axOrigin = Self.cocoaToAX(origin: cocoa.origin, size: cocoa.size)
        var axSize = cocoa.size
        guard let pos = AXValueCreate(.cgPoint, &axOrigin),
              let size = AXValueCreate(.cgSize, &axSize) else { throw ManagerError.notSettable }

        let posErr = AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, pos)
        let sizeErr = AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, size)
        // Some windows accept only one of the two; treat either success as progress, both fail as error.
        if posErr != .success && sizeErr != .success {
            throw ManagerError.axFailure(posErr != .success ? posErr : sizeErr)
        }
    }

    private func restoreFocused() throws {
        let window = try focusedWindow()
        let key = try restoreKey(for: window)
        guard let saved = restoreFrames[key] else { throw ManagerError.noFocusedWindow }
        try setFrame(saved, of: window)
    }

    private func trimRestoreIfNeeded() {
        while restoreFrames.count > maxRestoreEntries {
            if let first = restoreFrames.keys.first {
                restoreFrames.removeValue(forKey: first)
            }
        }
    }

    /// AX reports top-left origin with y growing downward from the top of the main screen's
    /// global space. AppKit `NSScreen` uses bottom-left. Convert using the primary screen height.
    nonisolated private static var primaryHeight: CGFloat {
        // NSScreen is MainActor-isolated in Swift 6; read via MainActor.assumeIsolated only from main.
        // For unit tests / helpers, fall back to a fixed conversion using CGMainDisplay bounds.
        CGFloat(CGDisplayPixelsHigh(CGMainDisplayID()))
    }

    nonisolated static func axToCocoa(origin: CGPoint, size: CGSize) -> CGRect {
        let y = primaryHeight - origin.y - size.height
        return CGRect(x: origin.x, y: y, width: size.width, height: size.height)
    }

    nonisolated static func cocoaToAX(origin: CGPoint, size: CGSize) -> CGPoint {
        CGPoint(x: origin.x, y: primaryHeight - origin.y - size.height)
    }
}
