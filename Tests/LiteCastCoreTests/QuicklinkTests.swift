import XCTest
@testable import LiteCast

final class QuicklinkTests: XCTestCase {
    // MARK: Template expansion

    func testExpandInsertsPercentEncodedQuery() {
        let template = "https://www.google.com/search?q={query}"
        let expanded = Quicklink.expand(template: template, query: "swift actors")
        XCTAssertEqual(expanded, "https://www.google.com/search?q=swift%20actors")
    }

    func testExpandEncodesReservedCharacters() {
        let expanded = Quicklink.expand(
            template: "https://example.com/?q={query}",
            query: "a&b=c"
        )
        XCTAssertEqual(expanded, "https://example.com/?q=a%26b%3Dc")
    }

    func testExpandWithoutPlaceholderLeavesTemplate() {
        let template = "https://github.com"
        XCTAssertEqual(Quicklink.expand(template: template, query: "ignored"), template)
    }

    func testURLTemplateValidation() {
        XCTAssertTrue(Quicklink.isValidURLTemplate("https://www.google.com/search?q={query}"))
        XCTAssertTrue(Quicklink.isValidURLTemplate("http://example.com"))
        XCTAssertFalse(Quicklink.isValidURLTemplate("file:///etc/passwd"))
        XCTAssertFalse(Quicklink.isValidURLTemplate("javascript:alert(1)"))
        XCTAssertFalse(Quicklink.isValidURLTemplate("not a url"))
    }

    // MARK: Name matching

    func testBestMatchUsesLeadingWordsAndLeavesRemainder() {
        let words = ["google", "swift", "actors"]
        let match = QuicklinkProvider.bestMatch(words: words, name: "Google")
        XCTAssertEqual(match?.remaining, "swift actors")
        XCTAssertEqual(match?.score, 1000)
    }

    func testBestMatchPrefersLongerPrefixForMultiWordNames() {
        let match = QuicklinkProvider.bestMatch(words: ["github", "swift"], name: "GitHub")
        XCTAssertEqual(match?.remaining, "swift")
        XCTAssertNotNil(match?.score)
    }

    func testBestMatchReturnsNilWhenNoFuzzyHit() {
        XCTAssertNil(QuicklinkProvider.bestMatch(words: ["zzz"], name: "Google"))
    }

    // MARK: Provider + store

    @MainActor
    func testProviderBuildsOpenURLAction() {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try! FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let fileStore = JSONFileStore<[Quicklink]>(filename: "quicklinks.json", directory: dir)
        try! fileStore.save([
            Quicklink(name: "Google", urlTemplate: "https://www.google.com/search?q={query}"),
        ])
        let store = QuicklinkStore(store: fileStore)
        let provider = QuicklinkProvider(store: store)
        let results = provider.results(for: "google swift actors")
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].title, "Google")
        XCTAssertEqual(results[0].accessory, "Quicklink")
        XCTAssertEqual(results[0].icon, .symbol("link"))
        guard case .openURL(let url) = results[0].action else {
            return XCTFail("expected openURL")
        }
        XCTAssertEqual(url.absoluteString, "https://www.google.com/search?q=swift%20actors")
    }

    @MainActor
    func testStoreSeedsDefaultsOnlyWhenFileMissing() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let fileStore = JSONFileStore<[Quicklink]>(filename: "quicklinks.json", directory: dir)
        let store = QuicklinkStore(store: fileStore)
        XCTAssertEqual(store.items.map(\.name), ["Google", "GitHub"])
        XCTAssertNotNil(try fileStore.load())

        // Existing file is not overwritten with defaults.
        try fileStore.save([Quicklink(name: "Custom", urlTemplate: "https://example.com/{query}")])
        let reloaded = QuicklinkStore(store: fileStore)
        XCTAssertEqual(reloaded.items.map(\.name), ["Custom"])
    }

    @MainActor
    func testStoreCorruptDataStartsEmptyWithoutOverwrite() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let url = dir.appendingPathComponent("quicklinks.json")
        try Data("not-json".utf8).write(to: url)
        let store = QuicklinkStore(store: JSONFileStore(filename: "quicklinks.json", directory: dir))
        XCTAssertTrue(store.items.isEmpty)
        XCTAssertEqual(try Data(contentsOf: url), Data("not-json".utf8))
    }
}
