import Foundation

/// Small Codable file store under ~/Library/Application Support/LiteCast.
// shortcut: JSON files, not SQLite; fine for hundreds of items, move to SQLite if a store needs queries or grows large.
struct JSONFileStore<Value: Codable>: Sendable {
    let url: URL

    init(filename: String, directory: URL = JSONFileStore.defaultDirectory) {
        url = directory.appendingPathComponent(filename)
    }

    static var defaultDirectory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("LiteCast", isDirectory: true)
    }

    /// nil when the file doesn't exist yet. Throws on corrupt data so callers don't overwrite it silently.
    func load() throws -> Value? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        return try JSONDecoder().decode(Value.self, from: Data(contentsOf: url))
    }

    func save(_ value: Value) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(value).write(to: url, options: .atomic)
    }
}
