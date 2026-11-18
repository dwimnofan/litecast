import AppKit

/// Single path through which every selected result is executed.
@MainActor
final class CommandExecutor {
    enum ExecutionError: LocalizedError {
        case unsupportedURL(URL)
        case unavailableCommand(BuiltinCommand)

        var errorDescription: String? {
            switch self {
            case .unsupportedURL(let url): "LiteCast can't open \(url.absoluteString)."
            case .unavailableCommand(let command): "\(command.title) isn't available."
            }
        }
    }

    private var builtinHandlers: [BuiltinCommand: () -> Void] = [:]

    /// Called after the executor writes text to the pasteboard, with the new changeCount.
    /// Used by ClipboardMonitor to skip our own writes.
    var onCopyText: ((Int) -> Void)?

    /// Features register the built-in commands they implement.
    func register(_ command: BuiltinCommand, handler: @escaping () -> Void) {
        builtinHandlers[command] = handler
    }

    var availableCommands: [BuiltinCommand] {
        BuiltinCommand.allCases.filter { builtinHandlers[$0] != nil }
    }

    func execute(_ action: SearchAction) async throws {
        switch action {
        case .openApplication(let url):
            let configuration = NSWorkspace.OpenConfiguration()
            configuration.allowsRunningApplicationSubstitution = false
            _ = try await NSWorkspace.shared.openApplication(at: url, configuration: configuration)
        case .openURL(let url):
            // Only web/mail links; never file:// or script schemes from user data.
            guard let scheme = url.scheme?.lowercased(), ["http", "https", "mailto"].contains(scheme) else {
                throw ExecutionError.unsupportedURL(url)
            }
            NSWorkspace.shared.open(url)
        case .copyText(let text):
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(text, forType: .string)
            onCopyText?(NSPasteboard.general.changeCount)
        case .copyImage(let data):
            NSPasteboard.general.clearContents()
            if let image = NSImage(data: data), let tiff = image.tiffRepresentation {
                NSPasteboard.general.setData(tiff, forType: .tiff)
            }
            NSPasteboard.general.setData(data, forType: .png)
            onCopyText?(NSPasteboard.general.changeCount)
        case .revealInFinder(let url):
            NSWorkspace.shared.activateFileViewerSelecting([url])
        case .builtin(let command):
            guard let handler = builtinHandlers[command] else { throw ExecutionError.unavailableCommand(command) }
            handler()
        }
    }
}

/// Lists the built-in commands that currently have a handler.
@MainActor
final class BuiltinCommandProvider: SearchProvider {
    private let executor: CommandExecutor

    init(executor: CommandExecutor) {
        self.executor = executor
    }

    func results(for query: String) -> [SearchResult] {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else { return [] }
        let candidates = executor.availableCommands.map {
            SearchResult(id: "command.\($0.rawValue)", title: $0.title, accessory: "Command",
                         icon: .symbol($0.symbol), action: .builtin($0))
        }
        return SearchEngine.rank(query: query, candidates: candidates)
    }
}
