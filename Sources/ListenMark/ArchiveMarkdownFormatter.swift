import Foundation

enum ArchiveMarkdownFormatter {
    static func body(_ raw: String) -> String {
        let clean = LLMOutputSanitizer.visibleAnswer(from: raw)
        guard !clean.isEmpty else { return "" }
        return readableParagraphs(clean)
    }

    static func quoteBlock(_ raw: String) -> String {
        let body = body(raw)
        guard !body.isEmpty else { return "" }
        return body.components(separatedBy: "\n")
            .map { $0.isEmpty ? ">" : "> \($0)" }
            .joined(separator: "\n")
    }

    private static func readableParagraphs(_ text: String) -> String {
        let normalized = text.replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let explicitParagraphs = normalized.components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        if explicitParagraphs.count > 1 {
            return explicitParagraphs.joined(separator: "\n\n")
        }

        let singleLineParagraphs = normalized.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        if singleLineParagraphs.count > 1 {
            return singleLineParagraphs.joined(separator: "\n\n")
        }

        guard normalized.count > 420 else { return normalized }
        return autoSegment(normalized)
    }

    private static func autoSegment(_ text: String) -> String {
        var paragraphs: [String] = []
        var current = ""
        var lastBreak = text.startIndex

        for index in text.indices {
            current.append(text[index])
            guard isSentenceBoundary(text[index]) else { continue }
            let distance = text.distance(from: lastBreak, to: index)
            if distance >= 220 {
                paragraphs.append(current.trimmingCharacters(in: .whitespacesAndNewlines))
                current = ""
                lastBreak = text.index(after: index)
            }
        }

        let tail = current.trimmingCharacters(in: .whitespacesAndNewlines)
        if !tail.isEmpty {
            if let last = paragraphs.indices.last, tail.count < 80 {
                paragraphs[last] += tail
            } else {
                paragraphs.append(tail)
            }
        }

        return paragraphs.isEmpty ? text : paragraphs.joined(separator: "\n\n")
    }

    private static func isSentenceBoundary(_ character: Character) -> Bool {
        "。！？!?；;.".contains(character)
    }
}
