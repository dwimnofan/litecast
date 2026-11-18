import AppKit
import Carbon.HIToolbox
import Observation

@MainActor
@Observable
final class ClipboardModel {
    enum KeyResult {
        case handled, dismiss, passThrough
    }

    var query = ""
    var typeFilter: ClipboardTypeFilter = .all
    var selectedID: ClipboardItem.ID?
    var isShowingActions = false
    var actionIndex = 0
    private(set) var focusToken = 0

    @ObservationIgnored private let historyStore: ClipboardHistoryStore
    @ObservationIgnored private let onOwnWrite: (Int) -> Void
    @ObservationIgnored var onFinish: () -> Void = {}

    init(historyStore: ClipboardHistoryStore, onOwnWrite: @escaping (Int) -> Void) {
        self.historyStore = historyStore
        self.onOwnWrite = onOwnWrite
    }

    var filteredItems: [ClipboardItem] {
        let term = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return historyStore.items.filter { item in
            guard typeFilter.matches(item.kind) else { return false }
            guard !term.isEmpty else { return true }
            switch item.kind {
            case .text, .link:
                return item.text.lowercased().contains(term)
            case .image:
                return item.title.lowercased().contains(term)
            }
        }
    }

    /// Items grouped under relative day headers ("Today", "Yesterday", …).
    var sections: [(title: String, items: [ClipboardItem])] {
        let calendar = Calendar.current
        var buckets: [(title: String, items: [ClipboardItem])] = []
        for item in filteredItems {
            let title = Self.dayHeader(for: item.date, calendar: calendar)
            if let last = buckets.last, last.title == title {
                buckets[buckets.count - 1].items.append(item)
            } else {
                buckets.append((title, [item]))
            }
        }
        return buckets
    }

    var selectedItem: ClipboardItem? {
        let items = filteredItems
        if let selectedID, let match = items.first(where: { $0.id == selectedID }) {
            return match
        }
        return items.first
    }

    var selectedActions: [ClipboardPanelAction] {
        guard let item = selectedItem else { return [] }
        var actions: [ClipboardPanelAction] = [
            .init(title: "Paste", symbol: "return", id: "paste"),
            .init(title: "Copy", symbol: "doc.on.doc", id: "copy"),
        ]
        if item.kind == .link {
            actions.append(.init(title: "Open Link", symbol: "safari", id: "open"))
        }
        actions.append(.init(title: "Delete", symbol: "trash", id: "delete"))
        return actions
    }

    func reset() {
        query = ""
        typeFilter = .all
        isShowingActions = false
        actionIndex = 0
        selectedID = historyStore.items.first?.id
        focusToken += 1
    }

    func select(_ item: ClipboardItem) {
        selectedID = item.id
        isShowingActions = false
        actionIndex = 0
    }

    func moveSelection(by delta: Int) {
        if isShowingActions {
            let count = selectedActions.count
            guard count > 0 else { return }
            actionIndex = min(max(actionIndex + delta, 0), count - 1)
            return
        }
        let items = filteredItems
        guard !items.isEmpty else { return }
        let current = selectedItem.flatMap { item in items.firstIndex(where: { $0.id == item.id }) } ?? 0
        let next = min(max(current + delta, 0), items.count - 1)
        selectedID = items[next].id
    }

    func toggleActions() {
        guard selectedItem != nil else { return }
        isShowingActions.toggle()
        actionIndex = 0
    }

    func closeActions() { isShowingActions = false; actionIndex = 0 }

    func syncSelectionAfterFilterChange() {
        let items = filteredItems
        if let selectedID, items.contains(where: { $0.id == selectedID }) { return }
        selectedID = items.first?.id
        closeActions()
    }

    func confirmPrimary() {
        if isShowingActions {
            runAction(selectedActions[safe: actionIndex] ?? selectedActions.first)
            return
        }
        pasteSelected()
    }

    func runAction(_ action: ClipboardPanelAction?) {
        guard let action, let item = selectedItem else { return }
        switch action.id {
        case "paste":
            pasteSelected()
        case "copy":
            ClipboardPaster.writeToPasteboard(item, imageData: historyStore.imageData(for: item), onOwnWrite: onOwnWrite)
            closeActions()
            onFinish()
        case "open":
            if let url = URL(string: item.text) { NSWorkspace.shared.open(url) }
            closeActions()
            onFinish()
        case "delete":
            historyStore.delete(item)
            selectedID = filteredItems.first?.id
            closeActions()
        default:
            break
        }
    }

    func pasteSelected() {
        guard let item = selectedItem else { return }
        let imageData = historyStore.imageData(for: item)
        onFinish()
        Task { @MainActor in
            await ClipboardPaster.paste(item, imageData: imageData, onOwnWrite: onOwnWrite)
        }
    }

    func handleKey(keyCode: Int, modifiers: NSEvent.ModifierFlags, composing: Bool) -> KeyResult {
        if composing { return .passThrough }
        let cmd = modifiers.contains(.command)
        switch keyCode {
        case kVK_UpArrow:
            moveSelection(by: -1); return .handled
        case kVK_DownArrow:
            moveSelection(by: 1); return .handled
        case kVK_Return, kVK_ANSI_KeypadEnter:
            confirmPrimary(); return .handled
        case kVK_Escape:
            if isShowingActions { closeActions(); return .handled }
            return .dismiss
        case kVK_ANSI_K where cmd:
            toggleActions(); return .handled
        case kVK_Delete where !cmd, kVK_ForwardDelete where !cmd:
            if isShowingActions { return .handled }
            if let item = selectedItem {
                historyStore.delete(item)
                selectedID = filteredItems.first?.id
            }
            return .handled
        default:
            return .passThrough
        }
    }

    func image(for item: ClipboardItem) -> NSImage? { historyStore.image(for: item) }
    func thumbnail(for item: ClipboardItem) -> NSImage? { historyStore.thumbnail(for: item) }

    func sourceAppName(for item: ClipboardItem) -> String? {
        guard let bundleID = item.sourceAppBundleID,
              let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else { return nil }
        return FileManager.default.displayName(atPath: url.path)
    }

    func sourceAppIcon(for item: ClipboardItem) -> NSImage? {
        guard let bundleID = item.sourceAppBundleID,
              let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else { return nil }
        return NSWorkspace.shared.icon(forFile: url.path)
    }

    private static func dayHeader(for date: Date, calendar: Calendar) -> String {
        if calendar.isDateInToday(date) { return "Today" }
        if calendar.isDateInYesterday(date) { return "Yesterday" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}

struct ClipboardPanelAction: Identifiable, Hashable {
    let title: String
    let symbol: String
    let id: String
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
