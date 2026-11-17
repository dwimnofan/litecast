import AppKit

/// The numbers from NSScreen that notch placement depends on, so the math is testable without a display.
struct NotchScreenMetrics: Equatable, Sendable {
    var frame: CGRect
    var safeAreaTop: CGFloat
    var auxiliaryTopLeft: CGRect?
    var auxiliaryTopRight: CGRect?
}

/// Where the notch (or the fallback pill on notch-less screens) sits, in global AppKit coordinates.
struct NotchGeometry: Equatable, Sendable {
    static let fallbackSize = CGSize(width: 140, height: 24)

    let hasNotch: Bool
    let notchRect: CGRect

    init(metrics m: NotchScreenMetrics) {
        // Only the aux *widths* are used: whether those rects are global or screen-local is ambiguous.
        if m.safeAreaTop > 0, let left = m.auxiliaryTopLeft, let right = m.auxiliaryTopRight,
           m.frame.width - left.width - right.width > 0 {
            hasNotch = true
            notchRect = CGRect(x: m.frame.minX + left.width, y: m.frame.maxY - m.safeAreaTop,
                               width: m.frame.width - left.width - right.width, height: m.safeAreaTop)
        } else {
            hasNotch = false
            let size = Self.fallbackSize
            notchRect = CGRect(x: m.frame.midX - size.width / 2, y: m.frame.maxY - size.height,
                               width: size.width, height: size.height)
        }
    }

    /// Panel hung from the top edge, centred on the notch.
    func panelFrame(size: CGSize) -> CGRect {
        CGRect(x: notchRect.midX - size.width / 2, y: notchRect.maxY - size.height, width: size.width, height: size.height)
    }

    /// Mouse area that triggers expansion; slightly wider than the notch for an easier target.
    var hoverRect: CGRect { notchRect.insetBy(dx: -6, dy: 0) }

    /// Inclusive on all edges: the mouse sits exactly on maxY at the top of the screen, which CGRect.contains rejects.
    static func hit(_ rect: CGRect, _ point: CGPoint) -> Bool {
        point.x >= rect.minX && point.x <= rect.maxX && point.y >= rect.minY && point.y <= rect.maxY
    }
}

enum NotchGeometryProvider {
    /// Prefers a screen with a notch, otherwise the menu-bar screen (first in NSScreen.screens).
    @MainActor
    static func current() -> NotchGeometry? {
        let screen = NSScreen.screens.first { $0.safeAreaInsets.top > 0 } ?? NSScreen.screens.first
        guard let screen else { return nil }
        return NotchGeometry(metrics: NotchScreenMetrics(
            frame: screen.frame, safeAreaTop: screen.safeAreaInsets.top,
            auxiliaryTopLeft: screen.auxiliaryTopLeftArea, auxiliaryTopRight: screen.auxiliaryTopRightArea))
    }
}
