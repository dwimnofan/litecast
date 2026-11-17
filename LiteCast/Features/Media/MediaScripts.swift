import AppKit

enum MediaSource: String, CaseIterable, Sendable {
    case music, spotify

    var bundleID: String {
        switch self {
        case .music: "com.apple.Music"
        case .spotify: "com.spotify.client"
        }
    }

    var playerNotification: Notification.Name {
        switch self {
        case .music: Notification.Name("com.apple.Music.playerInfo")
        case .spotify: Notification.Name("com.spotify.client.PlaybackStateChanged")
        }
    }

    /// `application id` + the running check in the service means we never launch the app by querying it.
    var infoScript: String {
        let artwork = self == .spotify ? "(artwork url of t)" : "\"\""
        return """
        set sep to (ASCII character 31)
        tell application id "\(bundleID)"
            set s to player state as text
            if s is "stopped" then return s
            set t to current track
            return s & sep & (name of t) & sep & (artist of t) & sep & (album of t) & sep & \(artwork)
        end tell
        """
    }

    func commandScript(_ command: String) -> String {
        "tell application id \"\(bundleID)\" to \(command)"
    }

    /// Music.app only; Spotify artwork comes from a URL instead.
    static let musicArtworkScript = "tell application id \"com.apple.Music\" to return data of artwork 1 of current track"
}

struct NowPlayingInfo: Equatable, Sendable {
    var source: MediaSource
    var title: String
    var artist: String
    var album: String
    var isPlaying: Bool
    var artworkURL: URL?
}

enum MediaScriptParser {
    static let separator: Character = "\u{1F}"

    /// Parses `state<US>title<US>artist<US>album<US>artworkURL`. nil when stopped or malformed.
    static func parse(_ output: String, source: MediaSource) -> NowPlayingInfo? {
        let fields = output.split(separator: separator, omittingEmptySubsequences: false).map(String.init)
        guard fields.count >= 4 else { return nil }
        let isPlaying: Bool
        switch fields[0].lowercased() {
        case "playing": isPlaying = true
        case "paused": isPlaying = false
        default: return nil
        }
        guard !fields[1].isEmpty else { return nil }
        let url = fields.count > 4 ? URL(string: fields[4]) : nil
        let safeURL = url.flatMap { ["http", "https"].contains($0.scheme?.lowercased() ?? "") ? $0 : nil }
        return NowPlayingInfo(source: source, title: fields[1], artist: fields[2], album: fields[3],
                              isPlaying: isPlaying, artworkURL: safeURL)
    }
}

struct ScriptOutput: Sendable {
    var string: String?
    var data: Data?
}

/// NSAppleScript isn't thread-safe: scripts are compiled and run one at a time on a private queue, off the main thread.
enum AppleScriptRunner {
    private static let queue = DispatchQueue(label: "com.dwimnofan.litecast.applescript", qos: .utility)

    /// nil on any error, including Automation permission denied (-1743): callers degrade to "no media".
    static func run(_ source: String) async -> ScriptOutput? {
        await withCheckedContinuation { continuation in
            queue.async {
                var error: NSDictionary?
                guard let descriptor = NSAppleScript(source: source)?.executeAndReturnError(&error), error == nil else {
                    continuation.resume(returning: nil)
                    return
                }
                continuation.resume(returning: ScriptOutput(string: descriptor.stringValue, data: descriptor.data))
            }
        }
    }
}
