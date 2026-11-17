import Foundation
import Observation

enum NotchLayout {
    /// Also the panel size: the panel is only this big while expanded content is worth hovering.
    static let expandedSize = CGSize(width: 520, height: 190)
}

@MainActor
@Observable
final class NotchState {
    var isExpanded = false
    var hasNotch = false
    var collapsedSize = NotchGeometry.fallbackSize

    func apply(_ geometry: NotchGeometry) {
        hasNotch = geometry.hasNotch
        collapsedSize = geometry.notchRect.size
    }
}
