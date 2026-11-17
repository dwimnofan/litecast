import Foundation

struct Snippet: Codable, Identifiable, Hashable, Sendable {
    var id: UUID
    var name: String
    /// Optional short trigger; searched alongside `name`.
    var keyword: String
    var text: String

    init(id: UUID = UUID(), name: String, keyword: String = "", text: String) {
        self.id = id
        self.name = name
        self.keyword = keyword
        self.text = text
    }

    /// Expands `{date}` and `{time}` using the given instant (defaults to now).
    static func expandPlaceholders(_ text: String, date: Date = Date(), calendar: Calendar = .current) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.calendar = calendar
        dateFormatter.locale = .current
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .none

        let timeFormatter = DateFormatter()
        timeFormatter.calendar = calendar
        timeFormatter.locale = .current
        timeFormatter.dateStyle = .none
        timeFormatter.timeStyle = .short

        return text
            .replacingOccurrences(of: "{date}", with: dateFormatter.string(from: date))
            .replacingOccurrences(of: "{time}", with: timeFormatter.string(from: date))
    }

    /// First line of `text`, truncated for list subtitles.
    static func subtitle(for text: String, limit: Int = 80) -> String {
        let firstLine = text.split(separator: "\n", maxSplits: 1, omittingEmptySubsequences: false)
            .first
            .map(String.init) ?? text
        let trimmed = firstLine.trimmingCharacters(in: .whitespaces)
        guard trimmed.count > limit else { return trimmed }
        return String(trimmed.prefix(limit - 1)) + "…"
    }
}
