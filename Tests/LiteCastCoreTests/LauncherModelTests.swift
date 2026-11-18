import Carbon.HIToolbox
import XCTest
@testable import LiteCast

@MainActor
final class LauncherModelTests: XCTestCase {
    private final class FakeProvider: SearchProvider {
        let items: [SearchResult]
        init(_ titles: [String]) {
            items = titles.map {
                SearchResult(id: $0, title: $0, accessory: "Application", icon: .symbol("app"),
                             action: .openApplication(URL(fileURLWithPath: "/Applications/\($0).app")))
            }
        }
        func results(for query: String) -> [SearchResult] { SearchEngine.rank(query: query, candidates: items) }
    }

    private let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: tempDir)
    }

    private func makeUsage() -> UsageStore {
        UsageStore(store: JSONFileStore(filename: "usage.json", directory: tempDir))
    }

    func testUsageBoostStaysBelowOneTier() {
        let usage = makeUsage()
        for _ in 0..<100 { usage.record("Safari") }
        XCTAssertLessThan(usage.boost(for: "Safari"), 100)
        XCTAssertEqual(usage.boost(for: "Unknown"), 0)
        // Recency fades after two weeks; frequency remains.
        let later = Date().addingTimeInterval(30 * 86_400)
        XCTAssertEqual(usage.boost(for: "Safari", now: later), 60, accuracy: 0.001)
    }

    func testUsagePersists() {
        makeUsage().record("Notes")
        XCTAssertEqual(makeUsage().entries["Notes"]?.count, 1)
    }

    func testEmptyQueryShowsSuggestionsFirst() {
        let usage = makeUsage()
        usage.record("Zed")
        let model = LauncherModel(providers: [FakeProvider(["About This Mac", "Notes", "Zed"])],
                                  executor: CommandExecutor(), usage: usage)
        model.reset()
        XCTAssertEqual(model.results.map(\.title), ["Zed", "About This Mac", "Notes"])
        XCTAssertEqual(model.sections.map(\.title), ["Suggestions", "Applications"])
        XCTAssertEqual(model.sectionTitle(at: 1), "Applications")
    }

    func testUsageReordersWithinTier() {
        let usage = makeUsage()
        usage.record("Notes Helper")
        let model = LauncherModel(providers: [FakeProvider(["Notes", "Notes Helper"])],
                                  executor: CommandExecutor(), usage: usage)
        model.query = "no"
        XCTAssertEqual(model.results.first?.title, "Notes Helper")
        XCTAssertEqual(model.sections.map(\.title), ["Results"])
    }

    func testKeyRoutingAndActionPanel() {
        let model = LauncherModel(providers: [FakeProvider(["Alpha", "Beta"])], executor: CommandExecutor(), usage: makeUsage())
        model.reset()
        XCTAssertEqual(model.handleKey(keyCode: kVK_DownArrow, modifiers: [], composing: false), .handled)
        XCTAssertEqual(model.selectedIndex, 1)
        XCTAssertEqual(model.handleKey(keyCode: kVK_DownArrow, modifiers: [], composing: true), .passThrough)

        XCTAssertEqual(model.handleKey(keyCode: kVK_ANSI_K, modifiers: .command, composing: false), .handled)
        XCTAssertTrue(model.isShowingActions)
        XCTAssertEqual(model.selectedActions.map(\.title), ["Open Application", "Show in Finder", "Copy Path", "Copy Name"])
        _ = model.handleKey(keyCode: kVK_DownArrow, modifiers: [], composing: false)
        XCTAssertEqual(model.actionIndex, 1)
        XCTAssertEqual(model.selectedIndex, 1, "arrows move inside the action panel while it's open")

        XCTAssertEqual(model.handleKey(keyCode: kVK_Escape, modifiers: [], composing: false), .handled)
        XCTAssertFalse(model.isShowingActions)
        XCTAssertEqual(model.handleKey(keyCode: kVK_Escape, modifiers: [], composing: false), .dismiss)
        XCTAssertEqual(model.handleKey(keyCode: kVK_ANSI_K, modifiers: [], composing: false), .passThrough, "plain k is typing")
    }
}
