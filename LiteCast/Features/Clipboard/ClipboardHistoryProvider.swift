import AppKit

/// Search provider for clipboard history items.
///
/// ## Query prefix behaviour
/// - `clip ` or `cb ` prefix: searches history text with up to 50 results.
/// - No prefix: fuzzy-matches item text, capped at 5 results to avoid flooding app search.
///
/// Results use modest scores (below apps) unless the prefix is used (which boosts them).
@MainActor
final class ClipboardHistoryProvider: SearchProvider {
    private let historyStore: ClipboardHistoryStore

    init(historyStore: ClipboardHistoryStore) {
        self.historyStore = historyStore
    }

    func results(for query: String) -> [SearchResult] {
        let lower = query.lowercased()
        let prefixed = ["clip ", "cb "].first { lower.hasPrefix($0) }
        let term = (prefixed.map { String(query.dropFirst($0.count)) } ?? query)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let limit = prefixed == nil ? 5 : 50

        if term.isEmpty {
            // Bare prefix lists the newest items; a bare empty query matches nothing.
            return prefixed == nil ? [] : historyStore.items.prefix(limit).map { makeResult(for: $0, score: 500) }
        }

        // Fuzzy-match the (bounded) full text, not the truncated title. Unprefixed results are
        // scaled down so they sit below typical app matches.
        let scale = prefixed == nil ? 0.3 : 1.0
        let scored: [SearchResult] = historyStore.items.compactMap { item in
            FuzzyMatcher.score(query: term, title: String(item.text.prefix(500))).map {
                makeResult(for: item, score: $0 * scale)
            }
        }
        // Stable on ties: items are already newest first.
        return Array(scored.enumerated()
            .sorted { $0.element.score != $1.element.score ? $0.element.score > $1.element.score : $0.offset < $1.offset }
            .prefix(limit).map(\.element))
    }

    private func makeResult(for item: ClipboardItem, score: Double) -> SearchResult {
        SearchResult(
            id: "clipboard.\(item.id.uuidString)",
            title: item.text.firstLine(maxLength: 80),
            subtitle: Self.subtitle(for: item),
            accessory: "Clipboard",
            icon: .symbol("doc.on.clipboard"),
            action: .copyText(item.text),
            score: score
        )
    }

    static func subtitle(for item: ClipboardItem) -> String {
        let relativeDate = Self.relativeDate(item.date)
        if let bundleID = item.sourceAppBundleID,
           let appName = Self.appName(for: bundleID) {
            return "\(relativeDate) · \(appName)"
        }
        return relativeDate
    }

    private static func relativeDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    private static func appName(for bundleID: String) -> String? {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else { return nil }
        return FileManager.default.displayName(atPath: url.path)
    }
}

// MARK: - String helpers

private extension String {
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
