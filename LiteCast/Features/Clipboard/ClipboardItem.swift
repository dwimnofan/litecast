import Foundation

/// A single clipboard history entry.
struct ClipboardItem: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    let text: String
    let date: Date
    /// Bundle ID of the app that was frontmost when the copy occurred (best-effort heuristic).
    let sourceAppBundleID: String?

    init(id: UUID = UUID(), text: String, date: Date = Date(), sourceAppBundleID: String? = nil) {
        self.id = id
        self.text = text
        self.date = date
        self.sourceAppBundleID = sourceAppBundleID
    }
}
