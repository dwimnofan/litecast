import AppKit
import Observation

@MainActor
@Observable
final class LauncherModel {
    var query = "" { didSet { updateResults() } }
    private(set) var results: [SearchResult] = []
    var selectedIndex = 0
    /// Bumped after the panel becomes key so the view refocuses the search field.
    private(set) var focusToken = 0

    @ObservationIgnored private let providers: [SearchProvider]
    @ObservationIgnored private let executor: CommandExecutor
    @ObservationIgnored var onFinish: () -> Void = {}

    init(providers: [SearchProvider], executor: CommandExecutor) {
        self.providers = providers
        self.executor = executor
    }

    func reset() {
        query = ""
        updateResults()
    }

    func requestFocus() { focusToken += 1 }

    func updateResults() {
        let merged = providers.flatMap { $0.results(for: query) }
        results = Array(merged.sorted {
            $0.score != $1.score
                ? $0.score > $1.score
                : $0.title.localizedStandardCompare($1.title) == .orderedAscending
        }.prefix(50))
        selectedIndex = 0
    }

    func moveSelection(by delta: Int) {
        guard !results.isEmpty else { return }
        selectedIndex = min(max(selectedIndex + delta, 0), results.count - 1)
    }

    func executeSelected() {
        guard results.indices.contains(selectedIndex) else { return }
        execute(results[selectedIndex])
    }

    func execute(_ result: SearchResult) {
        onFinish()
        Task {
            do {
                try await executor.execute(result.action)
            } catch {
                Log.app.error("Failed to open \(result.title): \(error.localizedDescription)")
                let alert = NSAlert(error: error)
                alert.messageText = "Couldn't run \(result.title)"
                alert.runModal()
            }
        }
    }
}
