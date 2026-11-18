import Foundation

/// Remembers which results were run, for Suggestions and a small ranking boost (frecency).
@MainActor
final class UsageStore {
    struct Entry: Codable, Equatable {
        var count: Int
        var lastUsed: Date
    }

    private(set) var entries: [String: Entry]
    private let store: JSONFileStore<[String: Entry]>

    init(store: JSONFileStore<[String: Entry]> = JSONFileStore(filename: "usage.json")) {
        self.store = store
        do {
            entries = try store.load() ?? [:]
        } catch {
            // Usage stats are disposable; start fresh rather than block the launcher.
            Log.app.error("Usage history unreadable, starting empty: \(error.localizedDescription)")
            entries = [:]
        }
    }

    func record(_ id: String, now: Date = Date()) {
        var entry = entries[id] ?? Entry(count: 0, lastUsed: now)
        entry.count += 1
        entry.lastUsed = now
        entries[id] = entry
        do { try store.save(entries) } catch {
            Log.app.error("Couldn't save usage history: \(error.localizedDescription)")
        }
    }

    /// 0..<100, so it reorders results within a FuzzyMatcher tier but never across tiers.
    func boost(for id: String, now: Date = Date()) -> Double {
        guard let entry = entries[id] else { return 0 }
        let frequency = min(Double(entry.count), 20) * 3              // up to 60
        let daysAgo = max(0, now.timeIntervalSince(entry.lastUsed) / 86_400)
        let recency = max(0, 30 * (1 - daysAgo / 14))                  // up to 30, gone after 2 weeks
        return frequency + recency
    }
}
