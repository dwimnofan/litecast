import Foundation
import Observation

@MainActor
@Observable
final class QuicklinkStore {
    private let fileStore: JSONFileStore<[Quicklink]>
    private(set) var items: [Quicklink] = []

    static let defaults: [Quicklink] = [
        Quicklink(name: "Google", urlTemplate: "https://www.google.com/search?q={query}"),
        Quicklink(name: "GitHub", urlTemplate: "https://github.com/search?q={query}"),
    ]

    init(store: JSONFileStore<[Quicklink]> = JSONFileStore(filename: "quicklinks.json")) {
        fileStore = store
        do {
            if let loaded = try store.load() {
                items = loaded
            } else {
                items = Self.defaults
                try store.save(items)
            }
        } catch {
            Log.app.error("Failed to load quicklinks: \(error.localizedDescription, privacy: .public)")
            items = []
        }
    }

    func add(_ link: Quicklink) {
        items.append(link)
        persist()
    }

    func update(_ link: Quicklink) {
        guard let index = items.firstIndex(where: { $0.id == link.id }) else { return }
        items[index] = link
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
            Log.app.error("Failed to save quicklinks: \(error.localizedDescription, privacy: .public)")
        }
    }
}
