import Foundation

/// Scores how well a query matches a title. Higher is better; nil means no match.
enum FuzzyMatcher {
    static func score(query: String, title: String) -> Double? {
        let q = normalize(query)
        let t = normalize(title)
        guard !q.isEmpty else { return 0 }
        guard !t.isEmpty else { return nil }

        // Small length penalty so shorter titles win ties ("Notes" over "Notes Helper").
        let lengthPenalty = Double(t.count) / 1000

        if t == q { return 1000 }
        if t.hasPrefix(q) { return 900 - lengthPenalty }

        let words = t.split(whereSeparator: { !$0.isLetter && !$0.isNumber })
        if words.contains(where: { $0.hasPrefix(q) }) { return 800 - lengthPenalty }

        let initials = String(words.compactMap(\.first))
        if initials.count > 1, initials.hasPrefix(q) { return 700 - lengthPenalty }

        if let range = t.range(of: q) {
            return 600 - Double(t.distance(from: t.startIndex, to: range.lowerBound)) - lengthPenalty
        }

        return subsequenceScore(q, in: t).map { $0 - lengthPenalty }
    }

    /// Every query character appears in order. Rewards consecutive runs.
    private static func subsequenceScore(_ q: String, in t: String) -> Double? {
        var score = 100.0
        var tIndex = t.startIndex
        var previousMatch: String.Index?
        for char in q {
            guard let found = t[tIndex...].firstIndex(of: char) else { return nil }
            if let previousMatch, t.index(after: previousMatch) == found { score += 10 }
            previousMatch = found
            tIndex = t.index(after: found)
        }
        return score
    }

    private static func normalize(_ s: String) -> String {
        s.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
    }
}
