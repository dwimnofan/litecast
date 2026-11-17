import Foundation

/// Ranks candidates for a query. Independent of UI.
enum SearchEngine {
    static func rank(query: String, candidates: [SearchResult], limit: Int = 50) -> [SearchResult] {
        let scored: [SearchResult]
        if query.trimmingCharacters(in: .whitespaces).isEmpty {
            scored = candidates
        } else {
            scored = candidates.compactMap { candidate in
                guard let score = FuzzyMatcher.score(query: query, title: candidate.title) else { return nil }
                var result = candidate
                result.score = score
                return result
            }
        }
        return Array(scored.sorted {
            $0.score != $1.score
                ? $0.score > $1.score
                : $0.title.localizedStandardCompare($1.title) == .orderedAscending
        }.prefix(limit))
    }
}
