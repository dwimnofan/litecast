import AppKit
import Observation

/// Now Playing from Music.app and Spotify via AppleScript (public APIs only).
/// Event-driven: distributed player notifications and notch expansion trigger a refresh; there is no timer.
/// shortcut: no progress bar/seek; add it with a >= 2s timer that runs only while expanded.
@MainActor
@Observable
final class NowPlayingService {
    private(set) var info: NowPlayingInfo?
    private(set) var artwork: NSImage?

    @ObservationIgnored private var observers: [NSObjectProtocol] = []
    @ObservationIgnored private var generation = 0
    @ObservationIgnored private var artworkKey: String?
    @ObservationIgnored private var artworkTask: Task<Void, Never>?

    /// - Parameter refreshImmediately: when `false` (notch idle start), only attach listeners —
    ///   avoids AppleScript round-trips at launch until the notch expands or a player fires.
    func start(refreshImmediately: Bool = true) {
        guard observers.isEmpty else { return }
        observers = MediaSource.allCases.map { source in
            DistributedNotificationCenter.default().addObserver(
                forName: source.playerNotification, object: nil, queue: .main
            ) { [weak self] _ in
                // Delivered on the main queue — no Task allocation per notification.
                MainActor.assumeIsolated { self?.refresh() }
            }
        }
        if refreshImmediately { refresh() }
    }

    func stop() {
        observers.forEach { DistributedNotificationCenter.default().removeObserver($0) }
        observers = []
        generation += 1
        artworkTask?.cancel()
        info = nil
        artwork = nil
        artworkKey = nil
    }

    func refresh() {
        // Query only running apps: an Apple event to a closed app would launch it.
        let running = MediaSource.allCases.filter {
            !NSRunningApplication.runningApplications(withBundleIdentifier: $0.bundleID).isEmpty
        }
        generation += 1
        let current = generation
        guard !running.isEmpty else { apply(nil); return }
        Task {
            var found: [NowPlayingInfo] = []
            for source in running {
                if let out = await AppleScriptRunner.run(source.infoScript)?.string,
                   let parsed = MediaScriptParser.parse(out, source: source) { found.append(parsed) }
            }
            guard current == generation else { return } // a newer refresh superseded this one
            apply(found.first { $0.isPlaying } ?? found.first)
        }
    }

    func playPause() { send("playpause") }
    func next() { send("next track") }
    func previous() { send("previous track") }

    private func send(_ command: String) {
        guard let source = info?.source else { return }
        Task {
            _ = await AppleScriptRunner.run(source.commandScript(command))
            refresh() // the notification usually beats this; harmless duplicate
        }
    }

    private func apply(_ new: NowPlayingInfo?) {
        if info != new { info = new }
        guard let new else { artwork = nil; artworkKey = nil; return }
        let key = "\(new.source.rawValue)|\(new.title)|\(new.artist)|\(new.album)"
        guard key != artworkKey else { return }
        artworkKey = key
        artwork = nil
        artworkTask?.cancel()
        artworkTask = Task {
            let data: Data?
            switch new.source {
            case .spotify:
                if let url = new.artworkURL { data = try? await URLSession.shared.data(from: url).0 } else { data = nil }
            case .music:
                data = await AppleScriptRunner.run(MediaSource.musicArtworkScript)?.data
            }
            guard !Task.isCancelled, artworkKey == key, let data else { return }
            artwork = NSImage(data: data) // nil if the bytes aren't a plain image; the UI shows a placeholder
        }
    }
}
