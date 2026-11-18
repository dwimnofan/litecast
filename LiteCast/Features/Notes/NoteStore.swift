import Foundation
import Observation

/// One Markdown file in the Notes folder. The file *is* the note — no database.
struct Note: Identifiable, Hashable, Sendable {
    var id: URL { url }
    let url: URL
    var title: String { url.deletingPathExtension().lastPathComponent }
    var modified: Date
    /// First line preview (Untitled notes show this in lists).
    var preview: String
}

/// Plain `.md` files under Application Support/LiteCast/Notes (or a user-chosen folder).
@MainActor
@Observable
final class NoteStore {
    private(set) var notes: [Note] = []

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let defaultDirectory: URL

    private enum Key {
        static let folderBookmark = "notesFolderBookmark"
    }

    var directory: URL {
        didSet { refresh() }
    }

    init(defaults: UserDefaults = .standard,
         defaultDirectory: URL = JSONFileStore<String>.defaultDirectory.appendingPathComponent("Notes", isDirectory: true)) {
        self.defaults = defaults
        self.defaultDirectory = defaultDirectory
        if let data = defaults.data(forKey: Key.folderBookmark) {
            var stale = false
            if let url = try? URL(resolvingBookmarkData: data, options: .withSecurityScope,
                                  relativeTo: nil, bookmarkDataIsStale: &stale) {
                directory = url
            } else {
                directory = defaultDirectory
            }
        } else {
            directory = defaultDirectory
        }
        ensureDirectory()
        refresh()
    }

    func useDefaultFolder() {
        defaults.removeObject(forKey: Key.folderBookmark)
        directory = defaultDirectory
        ensureDirectory()
        refresh()
    }

    func setFolder(_ url: URL) {
        if let data = try? url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil) {
            defaults.set(data, forKey: Key.folderBookmark)
        }
        directory = url
        refresh()
    }

    var isUsingDefaultFolder: Bool {
        directory.standardizedFileURL == defaultDirectory.standardizedFileURL
    }

    func refresh() {
        ensureDirectory()
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.contentModificationDateKey, .isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            notes = []
            return
        }
        notes = files.compactMap { url -> Note? in
            guard url.pathExtension.lowercased() == "md" else { return nil }
            let values = try? url.resourceValues(forKeys: [.contentModificationDateKey, .isRegularFileKey])
            guard values?.isRegularFile == true else { return nil }
            let modified = values?.contentModificationDate ?? .distantPast
            let preview = Self.firstLine(of: url)
            return Note(url: url, modified: modified, preview: preview)
        }
        .sorted { $0.modified > $1.modified }
    }

    @discardableResult
    func createNote(named preferred: String = "Untitled") throws -> Note {
        ensureDirectory()
        let url = uniqueURL(stem: preferred)
        try "".write(to: url, atomically: true, encoding: .utf8)
        refresh()
        return notes.first { $0.url == url } ?? Note(url: url, modified: Date(), preview: "")
    }

    func read(_ note: Note) throws -> String {
        try String(contentsOf: note.url, encoding: .utf8)
    }

    func write(_ note: Note, content: String) throws {
        try content.write(to: note.url, atomically: true, encoding: .utf8)
        refresh()
    }

    func delete(_ note: Note) throws {
        try FileManager.default.trashItem(at: note.url, resultingItemURL: nil)
        refresh()
    }

    func rename(_ note: Note, to newTitle: String) throws -> Note {
        let stem = Self.sanitizeFilename(newTitle)
        guard !stem.isEmpty else { return note }
        let dest = uniqueURL(stem: stem, excluding: note.url)
        guard dest != note.url else { return note }
        try FileManager.default.moveItem(at: note.url, to: dest)
        refresh()
        return notes.first { $0.url == dest } ?? Note(url: dest, modified: Date(), preview: note.preview)
    }

    // MARK: - Helpers

    private func ensureDirectory() {
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    private func uniqueURL(stem: String, excluding: URL? = nil) -> URL {
        let safe = Self.sanitizeFilename(stem)
        var candidate = directory.appendingPathComponent("\(safe).md")
        if candidate == excluding { return candidate }
        var n = 2
        while FileManager.default.fileExists(atPath: candidate.path) {
            if candidate == excluding { return candidate }
            candidate = directory.appendingPathComponent("\(safe) \(n).md")
            n += 1
        }
        return candidate
    }

    static func sanitizeFilename(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let invalid = CharacterSet(charactersIn: "/:\\?%*|\"<>")
        let cleaned = trimmed.components(separatedBy: invalid).joined(separator: "-")
        return cleaned.isEmpty ? "Untitled" : cleaned
    }

    static func firstLine(of url: URL) -> String {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return "" }
        defer { try? handle.close() }
        let data = handle.readData(ofLength: 512)
        let text = String(data: data, encoding: .utf8) ?? ""
        let line = text.split(whereSeparator: \.isNewline).first.map(String.init) ?? ""
        return line.trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: #"^#+\s*"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"\*+"#, with: "", options: .regularExpression)
    }

    /// Display title: filename, or first-line preview when still "Untitled…".
    static func displayTitle(for note: Note) -> String {
        if note.title.lowercased().hasPrefix("untitled"), !note.preview.isEmpty {
            return String(note.preview.prefix(60))
        }
        return note.title
    }
}
