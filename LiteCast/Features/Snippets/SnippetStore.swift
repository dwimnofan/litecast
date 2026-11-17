import Foundation
import Observation

@MainActor
@Observable
final class SnippetStore {
    private let fileStore: JSONFileStore<[Snippet]>
    private(set) var items: [Snippet] = []

    init(store: JSONFileStore<[Snippet]> = JSONFileStore(filename: "snippets.json")) {
        fileStore = store
        do {
            if let loaded = try store.load() {
                items = loaded
            } else {
                items = []
            }
        } catch {
            Log.app.error("Failed to load snippets: \(error.localizedDescription, privacy: .public)")
            items = []
        }
    }

    func add(_ snippet: Snippet) {
        items.append(snippet)
        persist()
    }

    func update(_ snippet: Snippet) {
        guard let index = items.firstIndex(where: { $0.id == snippet.id }) else { return }
        items[index] = snippet
        persist()
    }

    func delete(id: UUID) {
        items.removeAll { $0.id == id }
        persist()
    }

    private func persist() {
        do {
            try fileStore.save(items)
        } catch {
            Log.app.error("Failed to save snippets: \(error.localizedDescription, privacy: .public)")
        }
    }
}
