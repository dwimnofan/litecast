import AppKit
import Observation

/// Owns the clipboard history list. Newest items first.
///
/// ## Retention policy
/// - Maximum item count (default 200).
/// - Maximum age: 1 day, 7 days, 30 days, or forever.
/// - Pruning runs on every insert and on load.
///
/// ## Persistence
/// Uses `JSONFileStore<[ClipboardItem]>` via Application Support/LiteCast/clipboard-history.json.
/// If the file is corrupt the store logs the error and starts empty **without overwriting** the file.
@MainActor
@Observable
final class ClipboardHistoryStore {
    /// Retention-age options surfaced in Settings.
    enum RetentionAge: Int, CaseIterable, Sendable {
        case oneDay = 1
        case sevenDays = 7
        case thirtyDays = 30
        case forever = 0

        var label: String {
            switch self {
            case .oneDay: "1 day"
            case .sevenDays: "7 days"
            case .thirtyDays: "30 days"
            case .forever: "Forever"
            }
        }
    }

    private(set) var items: [ClipboardItem] = []

    @ObservationIgnored private let store: JSONFileStore<[ClipboardItem]>
    @ObservationIgnored private var corruptFileDetected = false

    @ObservationIgnored private let defaults: UserDefaults

    var maxItemCount: Int {
        didSet {
            defaults.set(maxItemCount, forKey: "clipboardMaxItems")
            prune()
            saveToDisk()
        }
    }
    var retentionAge: RetentionAge {
        didSet {
            defaults.set(retentionAge.rawValue, forKey: "clipboardRetentionDays")
            prune()
            saveToDisk()
        }
    }

    init(store: JSONFileStore<[ClipboardItem]> = JSONFileStore(filename: "clipboard-history.json"),
         defaults: UserDefaults = .standard) {
        self.store = store
        self.defaults = defaults
        let count = defaults.integer(forKey: "clipboardMaxItems")
        maxItemCount = count > 0 ? count : 200
        retentionAge = RetentionAge(rawValue: defaults.object(forKey: "clipboardRetentionDays") as? Int ?? 7) ?? .sevenDays
        loadFromDisk()
    }

    // MARK: - Mutations

    /// Adds a text entry. De-duplicates: if the same text already exists, the old entry is removed
    /// and a new one placed at the top.
    func add(text: String, sourceAppBundleID: String? = nil, date: Date = Date()) {
        items.removeAll { $0.text == text }
        let item = ClipboardItem(text: text, date: date, sourceAppBundleID: sourceAppBundleID)
        items.insert(item, at: 0)
        prune(now: date)
        saveToDisk()
    }

    /// Removes all items and persists immediately.
    func clearAll() {
        items.removeAll()
        saveToDisk()
    }

    // MARK: - Pruning

    /// Prune by count and by age. Called on every insert.
    func prune(now: Date = Date()) {
        if items.count > maxItemCount {
            items = Array(items.prefix(maxItemCount))
        }
        if retentionAge != .forever {
            let cutoff = now.addingTimeInterval(-Double(retentionAge.rawValue) * 86400)
            items.removeAll { $0.date < cutoff }
        }
    }

    // MARK: - Persistence

    private func loadFromDisk() {
        do {
            items = try store.load() ?? []
            prune()
        } catch {
            Log.app.error("Clipboard history file is corrupt — starting empty. Error: \(String(describing: error))")
            items = []
            corruptFileDetected = true
            // Do NOT overwrite the corrupt file.
        }
    }

    private func saveToDisk() {
        if corruptFileDetected {
            // First write after a corrupt load: keep the bad file aside instead of destroying it.
            let backup = store.url.appendingPathExtension("corrupt")
            try? FileManager.default.removeItem(at: backup)
            try? FileManager.default.moveItem(at: store.url, to: backup)
            corruptFileDetected = false
        }
        do {
            try store.save(items)
        } catch {
            Log.app.error("Failed to save clipboard history: \(String(describing: error))")
        }
    }
}
