import Foundation

enum SelectionWebAction {
    enum Mode {
        case search
        case link
    }

    struct Destination {
        let mode: Mode
        let url: URL
    }

    static func destination(for text: String) -> Destination? {
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return nil }
        if let url = linkURL(from: clean) {
            return Destination(mode: .link, url: url)
        }
        guard let url = searchURL(for: clean) else { return nil }
        return Destination(mode: .search, url: url)
    }

    static func mode(for text: String) -> Mode? {
        destination(for: text)?.mode
    }

    private static func linkURL(from text: String) -> URL? {
        guard let candidate = linkCandidate(from: text) else { return nil }
        if let url = URL(string: candidate), isHTTPURL(url) {
            return url
        }

        let prefix = localHost(candidate) ? "http://" : "https://"
        guard looksLikeBareLink(candidate),
              let url = URL(string: prefix + candidate),
              isHTTPURL(url) else { return nil }
        return url
    }

    private static func linkCandidate(from text: String) -> String? {
        var candidate = text.trimmingCharacters(in: .whitespacesAndNewlines)
        candidate = candidate.trimmingCharacters(in: CharacterSet(charactersIn: "<>\"'“”‘’"))
        while let last = candidate.last,
              ".,，。;；!！?？、)）]】}".contains(last) {
            candidate.removeLast()
        }
        guard !candidate.isEmpty,
              candidate.rangeOfCharacter(from: .whitespacesAndNewlines) == nil else { return nil }
        return candidate
    }

    private static func isHTTPURL(_ url: URL) -> Bool {
        guard let scheme = url.scheme?.lowercased(),
              ["http", "https"].contains(scheme),
              let host = url.host,
              !host.isEmpty else { return false }
        return true
    }

    private static func looksLikeBareLink(_ candidate: String) -> Bool {
        guard let host = hostPart(from: candidate) else { return false }
        if localHost(candidate) { return true }
        guard host.contains("."),
              let topLevel = host.split(separator: ".").last,
              topLevel.count >= 2 else { return false }
        return host.range(of: #"^[A-Za-z0-9.-]+$"#, options: .regularExpression) != nil
    }

    private static func localHost(_ candidate: String) -> Bool {
        guard let host = hostPart(from: candidate)?.lowercased() else { return false }
        if host == "localhost" { return true }
        return host.range(of: #"^\d{1,3}(\.\d{1,3}){3}$"#, options: .regularExpression) != nil
    }

    private static func hostPart(from candidate: String) -> String? {
        let withoutPath = candidate.split(separator: "/", maxSplits: 1, omittingEmptySubsequences: false).first
        let host = withoutPath?.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false).first
        let clean = String(host ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return clean.isEmpty ? nil : clean
    }

    private static func searchURL(for text: String) -> URL? {
        let query = String(text.prefix(500))
        var components = URLComponents(string: "https://www.google.com/search")
        components?.queryItems = [URLQueryItem(name: "q", value: query)]
        return components?.url
    }
}
