import Foundation

/// Finds installed apps in the standard folders and caches them.
@MainActor
final class AppDiscoveryService: SearchProvider {
    private(set) var apps: [SearchResult] = []
    private var lastScan: Date?
    private var scanTask: Task<Void, Never>?
    var onUpdate: () -> Void = {}

    nonisolated static let searchRoots: [URL] = [
        URL(fileURLWithPath: "/Applications"),
        URL(fileURLWithPath: "/System/Applications"),
        URL(fileURLWithPath: "/System/Library/CoreServices/Applications"),
        URL(fileURLWithPath: "/System/Cryptexes/App/System/Applications"), // Safari: /Applications/Safari.app is a hidden symlink
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications"),
    ]
    nonisolated static let extraApps = [URL(fileURLWithPath: "/System/Library/CoreServices/Finder.app")]

    func results(for query: String) -> [SearchResult] {
        SearchEngine.rank(query: query, candidates: apps)
    }

    /// Rescans in the background when the cache is older than `maxAge`.
    func refreshIfStale(maxAge: TimeInterval = 60) {
        if let lastScan, Date().timeIntervalSince(lastScan) < maxAge { return }
        guard scanTask == nil else { return }
        scanTask = Task {
            let found = await Task.detached(priority: .utility) { Self.scan() }.value
            apps = found
            lastScan = Date()
            scanTask = nil
            onUpdate()
            Log.app.info("Indexed \(found.count) apps")
        }
    }

    nonisolated static func scan() -> [SearchResult] {
        var urls = extraApps
        for root in searchRoots { collectApps(in: root, depth: 2, into: &urls) }

        var seen = Set<String>()
        return urls.compactMap { url in
            let bundleID = Bundle(url: url)?.bundleIdentifier ?? url.path
            guard seen.insert(bundleID).inserted else { return nil }
            let name = FileManager.default.displayName(atPath: url.path)
            let title = name.hasSuffix(".app") ? String(name.dropLast(4)) : name
            return SearchResult(id: bundleID, title: title, subtitle: url.deletingLastPathComponent().path,
                                accessory: "Application", icon: .file(url), action: .openApplication(url))
        }
    }

    private nonisolated static func collectApps(in dir: URL, depth: Int, into urls: inout [URL]) {
        guard depth > 0, let items = try? FileManager.default.contentsOfDirectory(
            at: dir, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles]
        ) else { return }
        for item in items {
            if item.pathExtension == "app" {
                urls.append(item)
            } else if (try? item.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true {
                collectApps(in: item, depth: depth - 1, into: &urls)
            }
        }
    }
}
