import Foundation

/// Launcher results for notes when the feature is enabled.
@MainActor
final class NotesProvider: SearchProvider {
    private let preferences: PreferencesStore
    private let store: NoteStore

    init(preferences: PreferencesStore, store: NoteStore) {
        self.preferences = preferences
        self.store = store
    }

    func results(for query: String) -> [SearchResult] {
        guard preferences.notesEnabled else { return [] }
        let term = query.trimmingCharacters(in: .whitespacesAndNewlines)
        store.refresh()

        var results: [SearchResult] = []
        if term.isEmpty { return [] }

        // Built-in note commands always rank via fuzzy match on their titles.
        let commands: [(BuiltinCommand, String)] = [
            (.showNotes, "Show Notes"),
            (.createNote, "Create Note"),
        ]
        for (command, title) in commands {
            if let score = FuzzyMatcher.score(query: term, title: title) {
                results.append(SearchResult(
                    id: "notes.command.\(command.rawValue)",
                    title: title,
                    subtitle: "Notes",
                    accessory: "Notes",
                    icon: .symbol(command.symbol),
                    action: .builtin(command),
                    score: score
                ))
            }
        }

        for note in store.notes {
            let title = NoteStore.displayTitle(for: note)
            let haystack = title + " " + note.preview
            if let score = FuzzyMatcher.score(query: term, title: String(haystack.prefix(200))) {
                results.append(SearchResult(
                    id: "notes.file.\(note.url.path)",
                    title: title,
                    subtitle: note.modified.formatted(date: .abbreviated, time: .omitted),
                    accessory: "Note",
                    icon: .symbol("note.text"),
                    action: .openNote(note.url),
                    score: score * 0.95
                ))
            }
        }
        return results.sorted { $0.score > $1.score }
    }
}
