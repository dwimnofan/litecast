import AppKit
import Carbon.HIToolbox
import Observation

@MainActor
@Observable
final class LauncherModel {
    struct Section: Equatable {
        let title: String
        let start: Int
    }

    var query = "" { didSet { updateResults() } }
    private(set) var results: [SearchResult] = []
    private(set) var sections: [Section] = []
    var selectedIndex = 0 { didSet { if oldValue != selectedIndex { closeActions() } } }
    /// Bumped after the panel becomes key so the view refocuses the search field.
    private(set) var focusToken = 0

    // ⌘K action panel
    private(set) var isShowingActions = false
    var actionIndex = 0

    static let suggestionLimit = 6

    @ObservationIgnored private let providers: [SearchProvider]
    @ObservationIgnored private let executor: CommandExecutor
    @ObservationIgnored private let usage: UsageStore
    @ObservationIgnored var onFinish: () -> Void = {}

    init(providers: [SearchProvider], executor: CommandExecutor, usage: UsageStore) {
        self.providers = providers
        self.executor = executor
        self.usage = usage
    }

    var selectedResult: SearchResult? {
        results.indices.contains(selectedIndex) ? results[selectedIndex] : nil
    }

    var selectedActions: [ResultAction] { selectedResult?.availableActions ?? [] }

    func sectionTitle(at index: Int) -> String? {
        sections.first { $0.start == index }?.title
    }

    func reset() {
        query = ""
        closeActions()
        updateResults()
    }

    func requestFocus() { focusToken += 1 }

    func updateResults() {
        let merged = providers.flatMap { $0.results(for: query) }
        if query.trimmingCharacters(in: .whitespaces).isEmpty {
            // Empty query: recently/frequently used first, then everything alphabetically.
            let suggestions = merged
                .filter { usage.entries[$0.id] != nil }
                .sorted { usage.boost(for: $0.id) > usage.boost(for: $1.id) }
                .prefix(Self.suggestionLimit)
            let suggestedIDs = Set(suggestions.map(\.id))
            let rest = merged.filter { !suggestedIDs.contains($0.id) }.sorted(by: Self.byScoreThenTitle)
            results = Array((Array(suggestions) + rest).prefix(50))
            sections = suggestions.isEmpty
                ? [Section(title: "Applications", start: 0)]
                : [Section(title: "Suggestions", start: 0), Section(title: "Applications", start: suggestions.count)]
        } else {
            let boosted = merged.map { result -> SearchResult in
                var result = result
                result.score += usage.boost(for: result.id)
                return result
            }
            results = Array(boosted.sorted(by: Self.byScoreThenTitle).prefix(50))
            sections = [Section(title: "Results", start: 0)]
        }
        if results.isEmpty { sections = [] }
        selectedIndex = 0
    }

    private nonisolated static func byScoreThenTitle(_ a: SearchResult, _ b: SearchResult) -> Bool {
        a.score != b.score ? a.score > b.score : a.title.localizedStandardCompare(b.title) == .orderedAscending
    }

    func moveSelection(by delta: Int) {
        if isShowingActions {
            let count = selectedActions.count
            guard count > 0 else { return }
            actionIndex = min(max(actionIndex + delta, 0), count - 1)
            return
        }
        guard !results.isEmpty else { return }
        selectedIndex = min(max(selectedIndex + delta, 0), results.count - 1)
    }

    func toggleActions() {
        guard selectedResult != nil else { return }
        isShowingActions.toggle()
        actionIndex = 0
    }

    func closeActions() {
        isShowingActions = false
        actionIndex = 0
    }

    /// Return: runs the highlighted action (or the result's primary action).
    func executeSelected() {
        guard let result = selectedResult else { return }
        let actions = result.availableActions
        let action = isShowingActions && actions.indices.contains(actionIndex) ? actions[actionIndex] : actions[0]
        run(action.action, for: result)
    }

    func execute(_ result: SearchResult) {
        run(result.action, for: result)
    }

    private func run(_ action: SearchAction, for result: SearchResult) {
        usage.record(result.id)
        closeActions()
        onFinish()
        Task {
            do {
                try await executor.execute(action)
            } catch {
                Log.app.error("Failed to run \(result.title): \(error.localizedDescription)")
                let alert = NSAlert(error: error)
                alert.messageText = "Couldn't run \(result.title)"
                alert.runModal()
            }
        }
    }

    /// Panel-level key routing so navigation never depends on SwiftUI text-field focus quirks.
    /// Returns true when the key was consumed. `composing` = the input method has marked text.
    func handleKey(keyCode: Int, modifiers: NSEvent.ModifierFlags, composing: Bool) -> KeyOutcome {
        if composing { return .passThrough }
        let command = modifiers.contains(.command)
        switch keyCode {
        case kVK_UpArrow: moveSelection(by: -1); return .handled
        case kVK_DownArrow: moveSelection(by: 1); return .handled
        case kVK_Return, kVK_ANSI_KeypadEnter: executeSelected(); return .handled
        case kVK_Escape:
            if isShowingActions { closeActions(); return .handled }
            return .dismiss
        case kVK_ANSI_K where command: toggleActions(); return .handled
        default: return .passThrough
        }
    }

    enum KeyOutcome { case handled, dismiss, passThrough }
}
