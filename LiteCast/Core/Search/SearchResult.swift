import Foundation

enum SearchIcon: Hashable, Sendable {
    case file(URL)      // icon of an app/file on disk
    case symbol(String) // SF Symbol name
}

/// Built-in commands. A command only shows in search once a handler is registered
/// on `CommandExecutor`, so unimplemented commands never appear.
enum BuiltinCommand: String, CaseIterable, Hashable, Sendable {
    case openSettings, toggleNotch, openClipboardHistory, clearClipboardHistory
    case showNotes, createNote, quit

    var title: String {
        switch self {
        case .openSettings: "Open LiteCast Settings"
        case .toggleNotch: "Toggle Notch"
        case .openClipboardHistory: "Clipboard History"
        case .clearClipboardHistory: "Clear Clipboard History"
        case .showNotes: "Show Notes"
        case .createNote: "Create Note"
        case .quit: "Quit LiteCast"
        }
    }

    var symbol: String {
        switch self {
        case .openSettings: "gearshape"
        case .toggleNotch: "rectangle.topthird.inset.filled"
        case .openClipboardHistory: "doc.on.clipboard"
        case .clearClipboardHistory: "trash"
        case .showNotes: "note.text"
        case .createNote: "square.and.pencil"
        case .quit: "power"
        }
    }
}

/// Everything a result can do. Executed only by `CommandExecutor`.
enum SearchAction: Hashable, Sendable {
    case openApplication(URL)
    case openURL(URL)
    case copyText(String)
    case copyImage(Data)
    case builtin(BuiltinCommand)
    case revealInFinder(URL)
    case windowPlacement(WindowPlacement)
    case openNote(URL)

    var title: String {
        switch self {
        case .openApplication: "Open Application"
        case .openURL: "Open Link"
        case .copyText: "Copy to Clipboard"
        case .copyImage: "Copy Image"
        case .builtin: "Run Command"
        case .revealInFinder: "Show in Finder"
        case .windowPlacement(let placement): placement.title
        case .openNote: "Open Note"
        }
    }
}

struct SearchResult: Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    var subtitle: String? = nil
    /// Right-hand type label, e.g. "Application", "Command".
    let accessory: String
    let icon: SearchIcon
    let action: SearchAction
    var score: Double = 0
}

/// A source of launcher results. Return [] for queries you don't handle.
/// Scores: use FuzzyMatcher (0...1000) for title matches; return > 1000 to pin to the top
/// (e.g. a calculator answer).
@MainActor
protocol SearchProvider: AnyObject {
    func results(for query: String) -> [SearchResult]
}
