import Foundation

/// Launcher results for window snap commands. Empty when the feature is disabled.
@MainActor
final class WindowManagementProvider: SearchProvider {
    private let preferences: PreferencesStore
    private let manager: WindowManager

    init(preferences: PreferencesStore, manager: WindowManager) {
        self.preferences = preferences
        self.manager = manager
    }

    func results(for query: String) -> [SearchResult] {
        guard preferences.windowManagementEnabled else { return [] }
        let term = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let candidates = WindowPlacement.allCases.map { placement -> SearchResult in
            SearchResult(
                id: "window.\(placement.rawValue)",
                title: placement.title,
                subtitle: "Window",
                accessory: "Window",
                icon: .symbol(placement.symbol),
                action: .windowPlacement(placement)
            )
        }
        if term.isEmpty { return [] }
        return SearchEngine.rank(query: term, candidates: candidates)
    }
}
