import Carbon.HIToolbox
import XCTest
@testable import LiteCast

@MainActor
final class HotkeyTests: XCTestCase {
    private let suite = "com.dwimnofan.litecast.tests.hotkey"

    override func tearDown() {
        UserDefaults().removePersistentDomain(forName: suite)
    }

    func testModifierConversion() {
        XCTAssertEqual(Hotkey.carbonModifiers(from: [.command, .shift]), UInt32(cmdKey | shiftKey))
        XCTAssertEqual(Hotkey.carbonModifiers(from: [.option, .control, .capsLock]), UInt32(optionKey | controlKey))
        XCTAssertEqual(Hotkey.carbonModifiers(from: []), 0)
    }

    func testDisplayName() {
        XCTAssertEqual(Hotkey.displayName(keyCode: UInt32(kVK_Space), carbonModifiers: UInt32(optionKey), characters: " "), "⌥Space")
        let all = UInt32(cmdKey | optionKey | controlKey | shiftKey)
        XCTAssertEqual(Hotkey.displayName(keyCode: UInt32(kVK_ANSI_K), carbonModifiers: all, characters: "k"), "⌃⌥⇧⌘K")
        XCTAssertEqual(Hotkey.displayName(keyCode: UInt32(kVK_F5), carbonModifiers: UInt32(cmdKey), characters: nil), "⌘F5")
    }

    func testHotkeyPersistsAndDefaults() throws {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        let store = PreferencesStore(defaults: defaults)
        XCTAssertEqual(store.launcherHotkey, .optionSpace)
        XCTAssertTrue(store.launcherEnabled)

        let custom = Hotkey(keyCode: UInt32(kVK_ANSI_K), carbonModifiers: UInt32(cmdKey | shiftKey), displayName: "⇧⌘K")
        store.launcherHotkey = custom
        store.launcherEnabled = false

        let reloaded = PreferencesStore(defaults: defaults)
        XCTAssertEqual(reloaded.launcherHotkey, custom)
        XCTAssertFalse(reloaded.launcherEnabled)
    }
}
