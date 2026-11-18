import Foundation

/// One entry in the ⌘K action panel.
struct ResultAction: Identifiable, Hashable {
    let title: String
    let symbol: String
    let action: SearchAction
    var id: String { title }
}

extension SearchResult {
    /// Primary action first, then secondary actions for the ⌘K panel.
    var availableActions: [ResultAction] {
        var actions = [ResultAction(title: action.title, symbol: "return", action: action)]
        switch action {
        case .openApplication(let url):
            actions += [
                ResultAction(title: "Show in Finder", symbol: "folder", action: .revealInFinder(url)),
                ResultAction(title: "Copy Path", symbol: "doc.on.doc", action: .copyText(url.path)),
                ResultAction(title: "Copy Name", symbol: "textformat", action: .copyText(title)),
            ]
        case .openURL(let url):
            actions.append(ResultAction(title: "Copy Link", symbol: "link", action: .copyText(url.absoluteString)))
        case .copyText, .copyImage, .builtin, .revealInFinder:
            break
        }
        return actions
    }
}
