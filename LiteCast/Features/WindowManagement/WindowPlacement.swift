import CoreGraphics
import Foundation

/// Where to put the focused window on its current display's visible frame.
enum WindowPlacement: String, CaseIterable, Sendable, Hashable {
    case leftHalf, rightHalf, topHalf, bottomHalf
    case topLeftQuarter, topRightQuarter, bottomLeftQuarter, bottomRightQuarter
    case firstThird, centerThird, lastThird, firstTwoThirds, lastTwoThirds
    case maximize, center, centerHalf
    case restore

    var title: String {
        switch self {
        case .leftHalf: "Left Half"
        case .rightHalf: "Right Half"
        case .topHalf: "Top Half"
        case .bottomHalf: "Bottom Half"
        case .topLeftQuarter: "Top Left Quarter"
        case .topRightQuarter: "Top Right Quarter"
        case .bottomLeftQuarter: "Bottom Left Quarter"
        case .bottomRightQuarter: "Bottom Right Quarter"
        case .firstThird: "First Third"
        case .centerThird: "Center Third"
        case .lastThird: "Last Third"
        case .firstTwoThirds: "First Two Thirds"
        case .lastTwoThirds: "Last Two Thirds"
        case .maximize: "Maximize"
        case .center: "Center"
        case .centerHalf: "Center Half"
        case .restore: "Restore Window"
        }
    }

    var symbol: String {
        switch self {
        case .leftHalf: "rectangle.lefthalf.filled"
        case .rightHalf: "rectangle.righthalf.filled"
        case .topHalf: "rectangle.topthird.inset.filled"
        case .bottomHalf: "rectangle.bottomthird.inset.filled"
        case .topLeftQuarter, .topRightQuarter, .bottomLeftQuarter, .bottomRightQuarter:
            "square.split.2x2"
        case .firstThird, .centerThird, .lastThird, .firstTwoThirds, .lastTwoThirds:
            "rectangle.split.3x1"
        case .center, .centerHalf: "rectangle.center.inset.filled"
        case .maximize: "arrow.up.left.and.arrow.down.right"
        case .restore: "arrow.uturn.backward"
        }
    }

    /// Placements that compute a new frame (everything except restore).
    static var layoutCases: [WindowPlacement] {
        allCases.filter { $0 != .restore }
    }

    /// Target frame inside `visible` (already excludes menu bar / Dock).
    /// `gap` insets from screen edges; shared edges between tiles use half gap so two
    /// side-by-side windows leave exactly one gap between them.
    func frame(in visible: CGRect, gap: CGFloat) -> CGRect {
        let g = max(0, gap)
        let work = visible.insetBy(dx: g, dy: g)
        let midGap = g / 2

        func column(index: Int, of count: Int, span: Int = 1) -> CGRect {
            // Divide work width into `count` columns; take `span` starting at `index`.
            let widths = Self.split(work.width, into: count)
            let x = work.minX + widths.prefix(index).reduce(0, +)
            let width = widths[index..<(index + span)].reduce(0, +)
            // Outer edges already have full gap via `work`; between columns insert midGap each side.
            var rect = CGRect(x: x, y: work.minY, width: width, height: work.height)
            if index > 0 { rect.origin.x += midGap; rect.size.width -= midGap }
            if index + span < count { rect.size.width -= midGap }
            return rect.integral
        }

        func row(index: Int, of count: Int, span: Int = 1) -> CGRect {
            let heights = Self.split(work.height, into: count)
            // CGRect y grows up; index 0 = top visually = highest y.
            let fromTop = index
            let yBottomIndex = count - fromTop - span
            let y = work.minY + heights.prefix(yBottomIndex).reduce(0, +)
            let height = heights[yBottomIndex..<(yBottomIndex + span)].reduce(0, +)
            var rect = CGRect(x: work.minX, y: y, width: work.width, height: height)
            if yBottomIndex > 0 { rect.origin.y += midGap; rect.size.height -= midGap }
            if yBottomIndex + span < count { rect.size.height -= midGap }
            return rect.integral
        }

        func cell(col: Int, rowFromTop: Int, cols: Int = 2, rows: Int = 2) -> CGRect {
            let c = column(index: col, of: cols)
            let r = row(index: rowFromTop, of: rows)
            return CGRect(x: c.minX, y: r.minY, width: c.width, height: r.height).integral
        }

        switch self {
        case .leftHalf: return column(index: 0, of: 2)
        case .rightHalf: return column(index: 1, of: 2)
        case .topHalf: return row(index: 0, of: 2)
        case .bottomHalf: return row(index: 1, of: 2)
        case .topLeftQuarter: return cell(col: 0, rowFromTop: 0)
        case .topRightQuarter: return cell(col: 1, rowFromTop: 0)
        case .bottomLeftQuarter: return cell(col: 0, rowFromTop: 1)
        case .bottomRightQuarter: return cell(col: 1, rowFromTop: 1)
        case .firstThird: return column(index: 0, of: 3)
        case .centerThird: return column(index: 1, of: 3)
        case .lastThird: return column(index: 2, of: 3)
        case .firstTwoThirds: return column(index: 0, of: 3, span: 2)
        case .lastTwoThirds: return column(index: 1, of: 3, span: 2)
        case .maximize: return work.integral
        case .center:
            let w = min(work.width * 0.6, 1025)
            let h = min(work.height * 0.6, 900)
            return CGRect(x: work.midX - w / 2, y: work.midY - h / 2, width: w, height: h).integral
        case .centerHalf:
            let w = work.width / 2
            return CGRect(x: work.midX - w / 2, y: work.minY, width: w, height: work.height).integral
        case .restore:
            return .zero
        }
    }

    /// Split a length into `count` parts that sum exactly (largest remainder method).
    static func split(_ length: CGFloat, into count: Int) -> [CGFloat] {
        precondition(count > 0)
        let base = floor(length / CGFloat(count))
        var parts = Array(repeating: base, count: count)
        let remainder = Int(length - base * CGFloat(count))
        for i in 0..<remainder { parts[i] += 1 }
        return parts
    }
}
