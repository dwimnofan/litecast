import Foundation

/// Fuzzy-matches quicklink names against the leading words of the query.
@MainActor
final class QuicklinkProvider: SearchProvider {
    private let store: QuicklinkStore

    init(store: QuicklinkStore) {
        self.store = store
    }

    func results(for query: String) -> [SearchResult] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        let words = trimmed.split(whereSeparator: \.isWhitespace).map(String.init)
        guard !words.isEmpty else { return [] }

        var results: [SearchResult] = []
        for link in store.items {
            guard let match = Self.bestMatch(words: words, name: link.name) else { continue }
            let expanded = Quicklink.expand(template: link.urlTemplate, query: match.remaining)
            guard let url = URL(string: expanded),
                  let scheme = url.scheme?.lowercased(),
                  scheme == "http" || scheme == "https"
            else { continue }

            let subtitle = match.remaining.isEmpty ? link.urlTemplate : expanded
            results.append(
                SearchResult(
                    id: "quicklink.\(link.id.uuidString)",
                    title: link.name,
                    subtitle: subtitle,
                    accessory: "Quicklink",
                    icon: .symbol("link"),
                    action: .openURL(url),
                    score: match.score
                )
            )
        }
        return results.sorted {
            $0.score != $1.score
                ? $0.score > $1.score
                : $0.title.localizedStandardCompare($1.title) == .orderedAscending
        }
    }

    /// Matches successive leading-word prefixes against `name`. Highest fuzzy score wins;
    /// on a tie, the longer prefix wins so multi-word names consume their words.
    nonisolated static func bestMatch(words: [String], name: String) -> (score: Double, remaining: String)? {
        var best: (score: Double, prefixCount: Int)?
        for count in 1...words.count {
            let prefix = words[0..<count].joined(separator: " ")
            guard let score = FuzzyMatcher.score(query: prefix, title: name) else { continue }
            if let current = best {
                if score > current.score || (score == current.score && count > current.prefixCount) {
                    best = (score, count)
                }
            } else {
                best = (score, count)
            }
        }
        guard let best else { return nil }
        let remaining = words[best.prefixCount...].joined(separator: " ")
        return (best.score, remaining)
    }
}
