import Foundation

enum LLMOutputSanitizer {
    static func visibleAnswer(from raw: String) -> String {
        var text = raw.replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        var removedReasoning = false

        for tag in ["think", "thinking", "reasoning", "analysis"] {
            let result = removingTaggedBlocks(named: tag, from: text)
            text = result.text
            removedReasoning = removedReasoning || result.removed
        }

        if removedReasoning || hasReasoningCue(text) {
            if let final = lastFinalMarker(in: text) {
                text = String(text[final.upperBound...])
            }
        }

        text = removeDanglingReasoningTags(from: text)
        return collapseOuterWhitespace(text)
    }

    private static func removingTaggedBlocks(named tag: String, from input: String) -> (text: String, removed: Bool) {
        var output = input
        var removed = false
        let openPattern = "<\\s*" + tag + "\\b[^>]*>"
        let closePattern = "</\\s*" + tag + "\\s*>"

        while let open = output.range(of: openPattern, options: [.regularExpression, .caseInsensitive]) {
            removed = true
            if let close = output.range(of: closePattern,
                                        options: [.regularExpression, .caseInsensitive],
                                        range: open.upperBound..<output.endIndex) {
                output.removeSubrange(open.lowerBound..<close.upperBound)
            } else {
                output.removeSubrange(open.lowerBound..<output.endIndex)
                break
            }
        }

        return (output, removed)
    }

    private static func hasReasoningCue(_ text: String) -> Bool {
        let lower = text.lowercased()
        return lower.contains("思考过程") ||
            lower.contains("推理过程") ||
            lower.contains("reasoning") ||
            lower.contains("thinking") ||
            lower.contains("thought process")
    }

    private static func lastFinalMarker(in text: String) -> Range<String.Index>? {
        let patterns = [
            "(^|\\n)\\s*(最终答案|最终回答|正式回答|回答|答案)\\s*[:：]\\s*",
            "(^|\\n)\\s*(final answer|final|answer)\\s*[:：]\\s*"
        ]
        var latest: Range<String.Index>?
        for pattern in patterns {
            var searchStart = text.startIndex
            while searchStart < text.endIndex,
                  let range = text.range(of: pattern,
                                          options: [.regularExpression, .caseInsensitive],
                                          range: searchStart..<text.endIndex) {
                latest = range
                searchStart = range.upperBound
            }
        }
        return latest
    }

    private static func removeDanglingReasoningTags(from input: String) -> String {
        input
            .replacingOccurrences(of: "</?\\s*(think|thinking|reasoning|analysis)\\s*[^>]*>",
                                  with: "",
                                  options: [.regularExpression, .caseInsensitive])
    }

    private static func collapseOuterWhitespace(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.replacingOccurrences(of: "\\n{3,}", with: "\n\n", options: .regularExpression)
    }
}
