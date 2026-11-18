import Foundation

/// Kind of clipboard payload we persist.
enum ClipboardContentKind: String, Codable, Sendable, CaseIterable, Hashable {
    case text
    case link
    case image

    var label: String {
        switch self {
        case .text: "Text"
        case .link: "Link"
        case .image: "Image"
        }
    }

    var symbol: String {
        switch self {
        case .text: "doc.text"
        case .link: "link"
        case .image: "photo"
        }
    }

    /// Infer text vs link from a string (http/https only).
    static func inferTextKind(from text: String) -> ClipboardContentKind {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed),
              let scheme = url.scheme?.lowercased(),
              ["http", "https"].contains(scheme),
              url.host != nil else { return .text }
        return .link
    }
}

/// Filter chip in the clipboard panel.
enum ClipboardTypeFilter: String, CaseIterable, Identifiable, Sendable {
    case all
    case text
    case link
    case image

    var id: String { rawValue }

    var label: String {
        switch self {
        case .all: "All Types"
        case .text: "Text"
        case .link: "Link"
        case .image: "Image"
        }
    }

    func matches(_ kind: ClipboardContentKind) -> Bool {
        switch self {
        case .all: true
        case .text: kind == .text
        case .link: kind == .link
        case .image: kind == .image
        }
    }
}

/// A single clipboard history entry.
struct ClipboardItem: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    let kind: ClipboardContentKind
    /// Text / URL body. Empty for pure image items.
    let text: String
    /// Filename under `clipboard-images/` (PNG). Nil for text/link.
    let imageFileName: String?
    let imageWidth: Int?
    let imageHeight: Int?
    /// SHA-256 hex of image bytes — used to de-dupe image copies.
    let contentHash: String?
    let date: Date
    /// Bundle ID of the app that was frontmost when the copy occurred (best-effort heuristic).
    let sourceAppBundleID: String?

    init(
        id: UUID = UUID(),
        kind: ClipboardContentKind? = nil,
        text: String,
        imageFileName: String? = nil,
        imageWidth: Int? = nil,
        imageHeight: Int? = nil,
        contentHash: String? = nil,
        date: Date = Date(),
        sourceAppBundleID: String? = nil
    ) {
        self.id = id
        self.kind = kind ?? ClipboardContentKind.inferTextKind(from: text)
        self.text = text
        self.imageFileName = imageFileName
        self.imageWidth = imageWidth
        self.imageHeight = imageHeight
        self.contentHash = contentHash
        self.date = date
        self.sourceAppBundleID = sourceAppBundleID
    }

    /// Convenience for text/link entries.
    init(id: UUID = UUID(), text: String, date: Date = Date(), sourceAppBundleID: String? = nil) {
        self.init(id: id, kind: .inferTextKind(from: text), text: text, date: date, sourceAppBundleID: sourceAppBundleID)
    }

    var title: String {
        switch kind {
        case .text, .link:
            return text.firstLine(maxLength: 80)
        case .image:
            if let imageWidth, let imageHeight {
                return "Image (\(imageWidth)×\(imageHeight))"
            }
            return "Image"
        }
    }

    var characterCount: Int { text.count }

    // MARK: - Codable (backward compatible with text-only history)

    private enum CodingKeys: String, CodingKey {
        case id, kind, text, imageFileName, imageWidth, imageHeight, contentHash, date, sourceAppBundleID
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        text = try c.decode(String.self, forKey: .text)
        imageFileName = try c.decodeIfPresent(String.self, forKey: .imageFileName)
        imageWidth = try c.decodeIfPresent(Int.self, forKey: .imageWidth)
        imageHeight = try c.decodeIfPresent(Int.self, forKey: .imageHeight)
        contentHash = try c.decodeIfPresent(String.self, forKey: .contentHash)
        date = try c.decode(Date.self, forKey: .date)
        sourceAppBundleID = try c.decodeIfPresent(String.self, forKey: .sourceAppBundleID)
        if let kind = try c.decodeIfPresent(ClipboardContentKind.self, forKey: .kind) {
            self.kind = kind
        } else if imageFileName != nil {
            self.kind = .image
        } else {
            self.kind = .inferTextKind(from: text)
        }
    }
}

extension String {
    /// Returns the first line, trimmed, with a max length.
    func firstLine(maxLength: Int) -> String {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines).prefix { !$0.isNewline }
            .trimmingCharacters(in: .whitespaces)
        if trimmed.count > maxLength {
            return String(trimmed.prefix(maxLength - 1)) + "…"
        }
        return trimmed
    }
}
