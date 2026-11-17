import XCTest
@testable import LiteCast

final class SnippetTests: XCTestCase {
    // MARK: Placeholders

    func testExpandDateAndTimePlaceholders() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let components = DateComponents(calendar: calendar, timeZone: calendar.timeZone,
                                        year: 2024, month: 6, day: 15, hour: 14, minute: 30)
        let date = calendar.date(from: components)!

        let expanded = Snippet.expandPlaceholders(
            "Signed {date} at {time}",
            date: date,
            calendar: calendar
        )
        XCTAssertTrue(expanded.contains("2024") || expanded.contains("Jun") || expanded.contains("15"),
                      "date should appear: \(expanded)")
        XCTAssertFalse(expanded.contains("{date}"))
        XCTAssertFalse(expanded.contains("{time}"))
        XCTAssertNotEqual(expanded, "Signed {date} at {time}")
    }

    func testSubtitleUsesFirstLineTruncated() {
        XCTAssertEqual(Snippet.subtitle(for: "hello\nworld"), "hello")
        let long = String(repeating: "a", count: 100)
        let sub = Snippet.subtitle(for: long, limit: 80)
        XCTAssertEqual(sub.count, 80)
        XCTAssertTrue(sub.hasSuffix("…"))
    }

    // MARK: Search

    @MainActor
    func testProviderMatchesNameAndKeyword() {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try! FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let fileStore = JSONFileStore<[Snippet]>(filename: "snippets.json", directory: dir)
        let store = SnippetStore(store: fileStore)
        store.add(Snippet(name: "Greeting", keyword: "hi", text: "Hello {date}"))
        store.add(Snippet(name: "Farewell", keyword: "bye", text: "Goodbye"))

        let provider = SnippetProvider(store: store)
        let byName = provider.results(for: "greet")
        XCTAssertEqual(byName.map(\.title), ["Greeting"])
        XCTAssertEqual(byName.first?.accessory, "Snippet")
        XCTAssertEqual(byName.first?.icon, .symbol("text.quote"))
        XCTAssertEqual(byName.first?.subtitle, "Hello {date}")

        let byKeyword = provider.results(for: "hi")
        XCTAssertEqual(byKeyword.map(\.title), ["Greeting"])

        guard case .copyText(let text) = byName[0].action else {
            return XCTFail("expected copyText")
        }
        XCTAssertFalse(text.contains("{date}"))
        XCTAssertTrue(text.hasPrefix("Hello "))
    }

    // MARK: Store round-trip

    @MainActor
    func testStoreRoundTrip() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let fileStore = JSONFileStore<[Snippet]>(filename: "snippets.json", directory: dir)
        let store = SnippetStore(store: fileStore)
        let snippet = Snippet(name: "Sig", keyword: "sig", text: "Best,\nNofan")
        store.add(snippet)

        let reloaded = SnippetStore(store: fileStore)
        XCTAssertEqual(reloaded.items.count, 1)
        XCTAssertEqual(reloaded.items[0].name, "Sig")
        XCTAssertEqual(reloaded.items[0].keyword, "sig")
        XCTAssertEqual(reloaded.items[0].text, "Best,\nNofan")
        XCTAssertEqual(reloaded.items[0].id, snippet.id)
    }

    @MainActor
    func testStoreUpdateAndDelete() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let fileStore = JSONFileStore<[Snippet]>(filename: "snippets.json", directory: dir)
        let store = SnippetStore(store: fileStore)
        var snippet = Snippet(name: "A", text: "a")
        store.add(snippet)
        snippet.name = "B"
        snippet.text = "b"
        store.update(snippet)
        XCTAssertEqual(store.items.first?.name, "B")

        store.delete(id: snippet.id)
        XCTAssertTrue(store.items.isEmpty)
        XCTAssertEqual(try fileStore.load()?.count, 0)
    }

    @MainActor
    func testCorruptFileStartsEmptyWithoutOverwrite() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let url = dir.appendingPathComponent("snippets.json")
        try Data("{{{".utf8).write(to: url)
        let store = SnippetStore(store: JSONFileStore(filename: "snippets.json", directory: dir))
        XCTAssertTrue(store.items.isEmpty)
        XCTAssertEqual(try Data(contentsOf: url), Data("{{{".utf8))
    }
}
