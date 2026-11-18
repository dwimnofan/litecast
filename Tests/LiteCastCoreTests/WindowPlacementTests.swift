import XCTest
@testable import LiteCast

final class WindowPlacementTests: XCTestCase {
    private let visible = CGRect(x: 100, y: 50, width: 1000, height: 800)

    func testSplitSumsExactly() {
        let parts = WindowPlacement.split(1000, into: 3)
        XCTAssertEqual(parts.count, 3)
        XCTAssertEqual(parts.reduce(0, +), 1000)
    }

    func testLeftRightHalvesFillWidthWithGap() {
        let gap: CGFloat = 10
        let left = WindowPlacement.leftHalf.frame(in: visible, gap: gap)
        let right = WindowPlacement.rightHalf.frame(in: visible, gap: gap)
        XCTAssertEqual(left.minX, visible.minX + gap, accuracy: 0.5)
        XCTAssertEqual(right.maxX, visible.maxX - gap, accuracy: 0.5)
        // One gap between them (half from each side).
        XCTAssertEqual(right.minX - left.maxX, gap, accuracy: 1.5)
        XCTAssertEqual(left.height + gap * 2, visible.height, accuracy: 1.5)
    }

    func testThirdsDoNotOverlap() {
        let frames = [WindowPlacement.firstThird, .centerThird, .lastThird]
            .map { $0.frame(in: visible, gap: 0) }
        XCTAssertEqual(frames[0].maxX, frames[1].minX, accuracy: 1)
        XCTAssertEqual(frames[1].maxX, frames[2].minX, accuracy: 1)
        XCTAssertEqual(frames[2].maxX, visible.maxX, accuracy: 1)
    }

    func testMaximizeUsesInsetWorkArea() {
        let gap: CGFloat = 8
        let frame = WindowPlacement.maximize.frame(in: visible, gap: gap)
        XCTAssertEqual(frame, visible.insetBy(dx: gap, dy: gap).integral)
    }

    func testCenterIsBounded() {
        let frame = WindowPlacement.center.frame(in: visible, gap: 0)
        XCTAssertLessThanOrEqual(frame.width, 1025)
        XCTAssertLessThanOrEqual(frame.height, 900)
        XCTAssertEqual(frame.midX, visible.midX, accuracy: 1)
    }

    func testQuartersCoverWorkArea() {
        let gap: CGFloat = 0
        let frames = [
            WindowPlacement.topLeftQuarter,
            .topRightQuarter,
            .bottomLeftQuarter,
            .bottomRightQuarter,
        ].map { $0.frame(in: visible, gap: gap) }
        let union = frames.reduce(CGRect.null) { $0.union($1) }
        XCTAssertEqual(union.minX, visible.minX, accuracy: 1)
        XCTAssertEqual(union.maxX, visible.maxX, accuracy: 1)
        XCTAssertEqual(union.minY, visible.minY, accuracy: 1)
        XCTAssertEqual(union.maxY, visible.maxY, accuracy: 1)
    }

    func testAxCocoaRoundTrip() {
        // Primary height conversion: origin bottom-left ↔ AX top-left.
        let cocoa = CGRect(x: 40, y: 100, width: 200, height: 150)
        let axOrigin = WindowManager.cocoaToAX(origin: cocoa.origin, size: cocoa.size)
        let back = WindowManager.axToCocoa(origin: axOrigin, size: cocoa.size)
        XCTAssertEqual(back.origin.x, cocoa.origin.x, accuracy: 0.5)
        XCTAssertEqual(back.origin.y, cocoa.origin.y, accuracy: 0.5)
        XCTAssertEqual(back.size.width, cocoa.size.width, accuracy: 0.5)
        XCTAssertEqual(back.size.height, cocoa.size.height, accuracy: 0.5)
    }
}
