import XCTest
@testable import LiteCast

@MainActor
final class CommandExecutorTests: XCTestCase {
    func testRejectsNonWebURLs() async {
        let executor = CommandExecutor()
        for raw in ["file:///etc/passwd", "javascript:alert(1)", "ssh://host"] {
            do {
                try await executor.execute(.openURL(URL(string: raw)!))
                XCTFail("\(raw) should be rejected")
            } catch {}
        }
    }

    func testCommandProviderListsOnlyRegisteredCommands() {
        let executor = CommandExecutor()
        let provider = BuiltinCommandProvider(executor: executor)
        XCTAssertTrue(provider.results(for: "quit").isEmpty)

        executor.register(.quit) {}
        XCTAssertEqual(provider.results(for: "quit").map(\.action), [.builtin(.quit)])
        XCTAssertTrue(provider.results(for: "").isEmpty)
    }

    func testRunsRegisteredCommand() async throws {
        let executor = CommandExecutor()
        var ran = false
        executor.register(.openSettings) { ran = true }
        try await executor.execute(.builtin(.openSettings))
        XCTAssertTrue(ran)
    }
}
