import XCTest
@testable import LiteCast

@MainActor
final class PreferencesStoreTests: XCTestCase {
    private let suite = "com.dwimnofan.litecast.tests.prefs"

    override func tearDown() {
        UserDefaults().removePersistentDomain(forName: suite)
    }

    func testShowInDockDefaultsToTrueAndPersists() throws {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        let store = PreferencesStore(defaults: defaults)
        XCTAssertTrue(store.showInDock)

        store.showInDock = false
        XCTAssertFalse(PreferencesStore(defaults: defaults).showInDock)
    }
}
