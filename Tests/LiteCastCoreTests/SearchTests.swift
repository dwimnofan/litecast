import XCTest
@testable import LiteCast

final class SearchTests: XCTestCase {
    private func score(_ q: String, _ t: String) -> Double? { FuzzyMatcher.score(query: q, title: t) }

    private func result(_ title: String) -> SearchResult {
        SearchResult(id: title, title: title, accessory: "Application", icon: .symbol("app"), action: .openApplication(URL(fileURLWithPath: "/\(title).app")))
    }

    // MARK: FuzzyMatcher

    func testTierOrdering() throws {
        let exact = try XCTUnwrap(score("notes", "Notes"))
        let prefix = try XCTUnwrap(score("note", "Notes"))
        let wordPrefix = try XCTUnwrap(score("notes", "My Notes"))
        let initials = try XCTUnwrap(score("vsc", "Visual Studio Code"))
        let substring = try XCTUnwrap(score("ode", "Visual Studio Code"))
        let subsequence = try XCTUnwrap(score("vsd", "Visual Studio Code"))
        let all = [exact, prefix, wordPrefix, initials, substring, subsequence]
        XCTAssertEqual(all, all.sorted(by: >))
        XCTAssertEqual(Set(all).count, all.count)
    }

    func testNoMatchReturnsNil() {
        XCTAssertNil(score("xyz", "Safari"))
        XCTAssertNil(score("abc", ""))
    }

    func testCaseAndDiacriticInsensitive() {
        XCTAssertEqual(score("cafe", "Café"), 1000)
        XCTAssertEqual(score("CAFÉ", "cafe"), 1000)
    }

    func testEmptyQueryScoresZero() {
        XCTAssertEqual(score("", "Safari"), 0)
        XCTAssertEqual(score("   ", "Safari"), 0)
    }

    func testShorterTitleWinsTie() throws {
        let short = try XCTUnwrap(score("notes", "Notes"))
        let long = try XCTUnwrap(score("notes", "Notes Helper"))
        XCTAssertGreaterThan(short, long)
        let a = try XCTUnwrap(score("not", "Notes"))
        let b = try XCTUnwrap(score("not", "Notes Helper"))
        XCTAssertGreaterThan(a, b)
    }

    // MARK: SearchEngine

    func testRankOrdersByTierAndFiltersNonMatches() {
        let candidates = ["Notes Helper", "My Notes", "Notes", "Safari", "Terminal"].map(result)
        let ranked = SearchEngine.rank(query: "notes", candidates: candidates)
        // exact, then prefix (900) beats word-prefix (800)
        XCTAssertEqual(ranked.map(\.title), ["Notes", "Notes Helper", "My Notes"])
    }

    func testEmptyQueryReturnsAllAlphabetically() {
        let candidates = ["Terminal", "Safari", "Notes", "App 10", "App 2"].map(result)
        let ranked = SearchEngine.rank(query: "  ", candidates: candidates)
        XCTAssertEqual(ranked.map(\.title), ["App 2", "App 10", "Notes", "Safari", "Terminal"])
    }

    func testLimitIsRespected() {
        let candidates = (0..<20).map { result("App \($0)") }
        XCTAssertEqual(SearchEngine.rank(query: "", candidates: candidates, limit: 5).count, 5)
        XCTAssertEqual(SearchEngine.rank(query: "app", candidates: candidates, limit: 3).count, 3)
    }

    func testRankSetsScore() {
        let ranked = SearchEngine.rank(query: "safari", candidates: [result("Safari")])
        XCTAssertEqual(ranked.first?.score, 1000)
    }

    // MARK: AppDiscoveryService

    func testScanFindsRealApps() {
        let apps = AppDiscoveryService.scan()
        XCTAssertFalse(apps.isEmpty)
        XCTAssertTrue(apps.contains { $0.title == "Finder" })
        XCTAssertTrue(apps.contains { $0.title == "Safari" })
    }

    func testScanIdsAreUniqueAndTitlesHaveNoAppSuffix() {
        let apps = AppDiscoveryService.scan()
        XCTAssertEqual(Set(apps.map(\.id)).count, apps.count)
        XCTAssertTrue(apps.allSatisfy { !$0.title.hasSuffix(".app") })
    }
}
