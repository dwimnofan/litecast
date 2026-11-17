import Foundation
import Observation

struct ShelfItem: Codable, Identifiable, Equatable, Sendable {
    var id = UUID()
    var path: String
    var bookmark: Data?
}

/// Files kept on the notch shelf. Stores a bookmark (survives moves/renames) plus the path as fallback.
@MainActor
@Observable
final class ShelfStore {
    private(set) var items: [ShelfItem] = []
    @ObservationIgnored private let store: JSONFileStore<[ShelfItem]>

    init(store: JSONFileStore<[ShelfItem]> = JSONFileStore(filename: "shelf.json")) {
        self.store = store
        do { items = try store.load() ?? [] } catch { Log.app.error("Shelf load failed: \(String(describing: error))") }
    }

    func add(_ urls: [URL]) {
        for url in urls where url.isFileURL && !items.contains(where: { $0.path == url.path }) {
            items.append(ShelfItem(path: url.path, bookmark: try? url.bookmarkData()))
        }
        save()
    }

    func remove(_ item: ShelfItem) {
        items.removeAll { $0.id == item.id }
        save()
    }

    /// Current location of the file, or nil if it was deleted.
    func resolve(_ item: ShelfItem) -> URL? {
        if let bookmark = item.bookmark {
            var stale = false
            if let url = try? URL(resolvingBookmarkData: bookmark, options: [], relativeTo: nil, bookmarkDataIsStale: &stale),
               FileManager.default.fileExists(atPath: url.path) { return url }
        }
        return FileManager.default.fileExists(atPath: item.path) ? URL(fileURLWithPath: item.path) : nil
    }

    private func save() {
        do { try store.save(items) } catch { Log.app.error("Shelf save failed: \(String(describing: error))") }
    }
}
