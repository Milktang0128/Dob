import SwiftUI

enum ContextExcerptFormatter {
    private static let oldMarkerPairs = [
        ("【选中内容开始】", "【选中内容结束】"),
        ("[Selection begins]", "[Selection ends]")
    ]

    static func markdownHighlighted(_ raw: String) -> String {
        var text = raw
        for pair in oldMarkerPairs {
            text = replacingMarkers(in: text, start: pair.0, end: pair.1)
        }
        return text
    }

    static func highlightedAttributedString(_ raw: String) -> AttributedString {
        let text = markdownHighlighted(raw)
        var output = AttributedString()
        var remaining = text[...]
        var highlighted = false

        while let marker = remaining.range(of: "==") {
            output += segment(String(remaining[..<marker.lowerBound]), highlighted: highlighted)
            highlighted.toggle()
            remaining = remaining[marker.upperBound...]
        }

        output += segment(String(remaining), highlighted: highlighted)
        return output
    }

    private static func replacingMarkers(in raw: String, start: String, end: String) -> String {
        var text = raw
        while let startRange = text.range(of: start),
              let endRange = text.range(of: end, range: startRange.upperBound..<text.endIndex) {
            let selected = text[startRange.upperBound..<endRange.lowerBound]
            text.replaceSubrange(startRange.lowerBound..<endRange.upperBound, with: "==\(selected)==")
        }
        return text
    }

    private static func segment(_ text: String, highlighted: Bool) -> AttributedString {
        var segment = AttributedString(text)
        if highlighted {
            segment.backgroundColor = NSColor.systemYellow.withAlphaComponent(0.36)
            segment.foregroundColor = NSColor.labelColor
        }
        return segment
    }
}
