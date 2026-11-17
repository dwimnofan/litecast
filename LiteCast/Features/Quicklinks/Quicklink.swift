import Foundation

struct Quicklink: Codable, Identifiable, Hashable, Sendable {
    var id: UUID
    var name: String
    var urlTemplate: String

    init(id: UUID = UUID(), name: String, urlTemplate: String) {
        self.id = id
        self.name = name
        self.urlTemplate = urlTemplate
    }

    /// True when the template is an http(s) URL (after substituting an empty query).
    static func isValidURLTemplate(_ template: String) -> Bool {
        let sample = expand(template: template, query: "")
        guard let url = URL(string: sample), let scheme = url.scheme?.lowercased() else { return false }
        return scheme == "http" || scheme == "https"
    }

    /// Substitutes `{query}` with a percent-encoded value. Templates without `{query}` are returned as-is.
    static func expand(template: String, query: String) -> String {
        guard template.contains("{query}") else { return template }
        let encoded = query.addingPercentEncoding(withAllowedCharacters: queryEncodingAllowed) ?? query
        return template.replacingOccurrences(of: "{query}", with: encoded)
    }

    /// RFC 3986 unreserved characters — encodes `&`, `=`, spaces, etc. for safe query substitution.
    private static let queryEncodingAllowed: CharacterSet = {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        return allowed
    }()
}
