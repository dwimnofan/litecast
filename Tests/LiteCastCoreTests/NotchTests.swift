import XCTest
@testable import LiteCast

@MainActor
final class NotchTests: XCTestCase {
    func testNotchRectFromAuxiliaryAreas() {
        // 1512pt wide screen, 656pt aux areas each side -> 200pt notch. Non-zero origin: only aux widths are used.
        let frame = CGRect(x: 100, y: 50, width: 1512, height: 982)
        let g = NotchGeometry(metrics: NotchScreenMetrics(
            frame: frame, safeAreaTop: 32,
            auxiliaryTopLeft: CGRect(x: 0, y: 950, width: 656, height: 32),
            auxiliaryTopRight: CGRect(x: 856, y: 950, width: 656, height: 32)))
        XCTAssertTrue(g.hasNotch)
        XCTAssertEqual(g.notchRect, CGRect(x: 756, y: 1000, width: 200, height: 32))
        XCTAssertEqual(g.panelFrame(size: CGSize(width: 520, height: 190)), CGRect(x: 596, y: 842, width: 520, height: 190))
    }

    func testFallbackPillWithoutNotch() {
        let frame = CGRect(x: 0, y: 0, width: 1920, height: 1080)
        let g = NotchGeometry(metrics: NotchScreenMetrics(frame: frame, safeAreaTop: 0, auxiliaryTopLeft: nil, auxiliaryTopRight: nil))
        XCTAssertFalse(g.hasNotch)
        XCTAssertEqual(g.notchRect, CGRect(x: 890, y: 1056, width: 140, height: 24))
    }

    func testHitIsInclusiveAtTopEdge() {
        let rect = CGRect(x: 0, y: 0, width: 10, height: 10)
        XCTAssertTrue(NotchGeometry.hit(rect, CGPoint(x: 5, y: 10)))
        XCTAssertFalse(NotchGeometry.hit(rect, CGPoint(x: 5, y: 10.5)))
    }

    func testParsePlayingTrack() {
        let out = ["playing", "Song", "Artist", "Album", "https://example.com/a.jpg"].joined(separator: "\u{1F}")
        let info = MediaScriptParser.parse(out, source: .spotify)
        XCTAssertEqual(info?.title, "Song")
        XCTAssertEqual(info?.artist, "Artist")
        XCTAssertEqual(info?.isPlaying, true)
        XCTAssertEqual(info?.artworkURL, URL(string: "https://example.com/a.jpg"))
    }

    func testParsePausedAndRejectsStoppedMalformedOrUnsafeArtwork() {
        let paused = MediaScriptParser.parse(["paused", "T", "A", "B", ""].joined(separator: "\u{1F}"), source: .music)
        XCTAssertEqual(paused?.isPlaying, false)
        XCTAssertNil(paused?.artworkURL)
        XCTAssertNil(MediaScriptParser.parse("stopped", source: .music))
        XCTAssertNil(MediaScriptParser.parse("playing\u{1F}\u{1F}A\u{1F}B", source: .music))
        let file = MediaScriptParser.parse(["playing", "T", "A", "B", "file:///etc/passwd"].joined(separator: "\u{1F}"), source: .music)
        XCTAssertNil(file?.artworkURL)
    }

    func testShelfRoundTripAndMissingFile() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let file = dir.appendingPathComponent("note.txt")
        try "hi".write(to: file, atomically: true, encoding: .utf8)

        let shelf = ShelfStore(store: JSONFileStore(filename: "shelf.json", directory: dir))
        shelf.add([file, file])
        XCTAssertEqual(shelf.items.count, 1, "duplicates are ignored")

        let reloaded = ShelfStore(store: JSONFileStore(filename: "shelf.json", directory: dir))
        let item = try XCTUnwrap(reloaded.items.first)
        XCTAssertEqual(reloaded.resolve(item)?.resolvingSymlinksInPath(), file.resolvingSymlinksInPath())

        try FileManager.default.removeItem(at: file)
        XCTAssertNil(reloaded.resolve(item))
        reloaded.remove(item)
        XCTAssertTrue(ShelfStore(store: JSONFileStore(filename: "shelf.json", directory: dir)).items.isEmpty)
    }

    func testBatteryStatusParsing() {
        let d: [String: Any] = ["Type": "InternalBattery", "Current Capacity": 42, "Max Capacity": 100,
                                "Is Charging": true, "Power Source State": "AC Power"]
        let s = BatteryStatus(description: d)
        XCTAssertEqual(s?.level, 42)
        XCTAssertEqual(s?.isCharging, true)
        XCTAssertEqual(s?.isPluggedIn, true)
        XCTAssertNil(BatteryStatus(description: ["Type": "UPS", "Current Capacity": 1, "Max Capacity": 2]))
    }
}
