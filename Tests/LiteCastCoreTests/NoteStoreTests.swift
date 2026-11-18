import XCTest
@testable import LiteCast

@MainActor
final class NoteStoreTests: XCTestCase {
    private func makeStore() throws -> (NoteStore, URL) {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("LiteCastNotes-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let defaults = UserDefaults(suiteName: "litecast.tests.notes.\(UUID().uuidString)")!
        let store = NoteStore(defaults: defaults, defaultDirectory: dir)
        return (store, dir)
    }

    func testCreateAndReadWrite() throws {
        let (store, dir) = try makeStore()
        defer { try? FileManager.default.removeItem(at: dir) }
        let note = try store.createNote()
        XCTAssertEqual(store.notes.count, 1)
        try store.write(note, content: "# Hello\n\nBody")
        XCTAssertEqual(try store.read(note), "# Hello\n\nBody")
        store.refresh()
        XCTAssertEqual(store.notes.first?.preview, "Hello")
    }

    func testUntitledNamesIncrement() throws {
        let (store, dir) = try makeStore()
        defer { try? FileManager.default.removeItem(at: dir) }
        _ = try store.createNote()
        _ = try store.createNote()
        let titles = store.notes.map(\.title).sorted()
        XCTAssertEqual(titles, ["Untitled", "Untitled 2"])
    }

    func testRenameAndDelete() throws {
        let (store, dir) = try makeStore()
        defer { try? FileManager.default.removeItem(at: dir) }
        let note = try store.createNote()
        let renamed = try store.rename(note, to: "Ideas")
        XCTAssertEqual(renamed.title, "Ideas")
        try store.delete(renamed)
        XCTAssertTrue(store.notes.isEmpty)
    }

    func testSanitizeFilename() {
        XCTAssertEqual(NoteStore.sanitizeFilename("  a/b:c  "), "a-b-c")
        XCTAssertEqual(NoteStore.sanitizeFilename("   "), "Untitled")
    }

    func testProviderEmptyWhenDisabled() throws {
        let (store, dir) = try makeStore()
        defer { try? FileManager.default.removeItem(at: dir) }
        _ = try store.createNote(named: "Alpha")
        let defaults = UserDefaults(suiteName: "litecast.tests.notes.prefs.\(UUID().uuidString)")!
        let prefs = PreferencesStore(defaults: defaults)
        XCTAssertFalse(prefs.notesEnabled)
        let provider = NotesProvider(preferences: prefs, store: store)
        XCTAssertTrue(provider.results(for: "Alpha").isEmpty)
        prefs.notesEnabled = true
        XCTAssertFalse(provider.results(for: "Alpha").isEmpty)
    }
}
