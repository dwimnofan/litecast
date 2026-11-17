import Foundation

/// Fuzzy-matches snippet names and keywords; expands placeholders at copy time.
@MainActor
final class SnippetProvider: SearchProvider {
    private let store: SnippetStore

    init(store: SnippetStore) {
        self.store = store
    }

    func results(for query: String) -> [SearchResult] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        var results: [SearchResult] = []
        for snippet in store.items {
            let nameScore = FuzzyMatcher.score(query: trimmed, title: snippet.name)
            let keywordScore: Double? = snippet.keyword.isEmpty
                ? nil
                : FuzzyMatcher.score(query: trimmed, title: snippet.keyword)
            guard let score = [nameScore, keywordScore].compactMap({ $0 }).max() else { continue }

            let expanded = Snippet.expandPlaceholders(snippet.text)
            results.append(
                SearchResult(
                    id: "snippet.\(snippet.id.uuidString)",
                    title: snippet.name,
                    subtitle: Snippet.subtitle(for: snippet.text),
                    accessory: "Snippet",
                    icon: .symbol("text.quote"),
                    action: .copyText(expanded),
                    score: score
                )
            )
        }
        return results.sorted {
            $0.score != $1.score
                ? $0.score > $1.score
                : $0.title.localizedStandardCompare($1.title) == .orderedAscending
        }
    }
}
