import AppKit
import ApplicationServices

/// Reads the current selection. Tries the Accessibility API first (direct,
/// no clipboard side-effect); falls back to synthesizing ⌘C and reading the
/// pasteboard for apps that don't expose AX selected text. Both paths need
/// Accessibility permission.
enum SelectionGrabber {
    struct ContextSource {
        let focused: AXUIElement?
        let window: AXUIElement?
    }

    static var isTrusted: Bool { AXIsProcessTrusted() }

    /// Coax Chromium/Electron apps (Claude, VS Code, 飞书…) into exposing their
    /// accessibility tree so AXSelectedText works for auto-pop.
    static func enableAccessibility(for pid: pid_t) {
        let app = AXUIElementCreateApplication(pid)
        AXUIElementSetAttributeValue(app, "AXManualAccessibility" as CFString, kCFBooleanTrue)
    }

    /// Direct read via the focused UI element's AXSelectedText. Cheap; used for
    /// auto-pop on every mouse-up.
    static func axSelectedText() -> String? {
        guard let element = focusedElement() else { return nil }
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXSelectedTextAttribute as CFString, &value) == .success,
              let s = value as? String else { return nil }
        let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? nil : t
    }

    /// Best-effort context for actions like 背景. Many apps expose the focused
    /// text area or web area through Accessibility; some only expose selection.
    static func axContextText(for selectedText: String, source: ContextSource? = nil, limit: Int = 12_000) -> String? {
        let selected = selectedText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !selected.isEmpty, let focused = source?.focused ?? focusedElement() else { return nil }

        for element in contextCandidates(startingAt: focused, focusedWindow: source?.window) {
            var visited = Set<CFHashCode>()
            let text = cleanedContext(collectText(from: element, depth: 0, limit: limit, visited: &visited))
            guard isUsefulContext(text, selected: selected) else { continue }
            return trimmedContext(text, around: selected, limit: limit)
        }
        return nil
    }

    static func contextSource() -> ContextSource {
        ContextSource(focused: focusedElement(), window: focusedWindow())
    }

    static func selectedTextBounds(source: ContextSource? = nil) -> CGRect? {
        guard let focused = source?.focused ?? focusedElement() else { return nil }
        let focusedWindow = source?.window ?? focusedWindow()
        for element in contextCandidates(startingAt: focused, focusedWindow: focusedWindow) {
            guard let rect = selectedTextBounds(in: element) else { continue }
            return normalizedScreenRect(fromAccessibilityRect: rect)
        }
        return nil
    }

    static func grabAsync(allowCopyFallback: Bool = true, _ completion: @escaping (String?) -> Void) {
        if let ax = axSelectedText() { completion(ax); return }
        guard allowCopyFallback else { completion(nil); return }
        copySelectedTextAsync(completion)
    }

    static func copySelectedTextAsync(_ completion: @escaping (String?) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let text = copyGrab()
            DispatchQueue.main.async { completion(text) }
        }
    }

    private static func copyGrab() -> String? {
        let pb = NSPasteboard.general
        let snapshot = PasteboardSnapshot(pb)
        let before = pb.changeCount

        sendCopy()

        var captured: String?
        let deadline = Date().addingTimeInterval(0.6)
        while Date() < deadline {
            if pb.changeCount != before {
                captured = pb.string(forType: .string)
                break
            }
            usleep(15_000)
        }

        snapshot.restore(to: pb)
        return captured?.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private struct PasteboardSnapshot {
        let items: [[NSPasteboard.PasteboardType: Data]]

        init(_ pasteboard: NSPasteboard) {
            items = (pasteboard.pasteboardItems ?? []).compactMap { item in
                var dataByType: [NSPasteboard.PasteboardType: Data] = [:]
                for type in item.types {
                    if let data = item.data(forType: type) {
                        dataByType[type] = data
                    }
                }
                return dataByType.isEmpty ? nil : dataByType
            }
        }

        func restore(to pasteboard: NSPasteboard) {
            pasteboard.clearContents()
            let restoredItems = items.map { dataByType in
                let item = NSPasteboardItem()
                for (type, data) in dataByType {
                    item.setData(data, forType: type)
                }
                return item
            }
            if !restoredItems.isEmpty {
                pasteboard.writeObjects(restoredItems)
            }
        }
    }

    private static func sendCopy() {
        let src = CGEventSource(stateID: .combinedSessionState)
        let cKey: CGKeyCode = 0x08 // ANSI 'C'
        let down = CGEvent(keyboardEventSource: src, virtualKey: cKey, keyDown: true)
        down?.flags = .maskCommand
        let up = CGEvent(keyboardEventSource: src, virtualKey: cKey, keyDown: false)
        up?.flags = .maskCommand
        down?.post(tap: .cghidEventTap)
        up?.post(tap: .cghidEventTap)
    }

    private static func focusedElement() -> AXUIElement? {
        let system = AXUIElementCreateSystemWide()
        var focused: CFTypeRef?
        guard AXUIElementCopyAttributeValue(system, kAXFocusedUIElementAttribute as CFString, &focused) == .success,
              let focused else { return nil }
        return (focused as! AXUIElement)
    }

    private static func focusedWindow() -> AXUIElement? {
        let system = AXUIElementCreateSystemWide()
        var window: CFTypeRef?
        guard AXUIElementCopyAttributeValue(system, kAXFocusedWindowAttribute as CFString, &window) == .success,
              let window else { return nil }
        return (window as! AXUIElement)
    }

    private static func contextCandidates(startingAt element: AXUIElement, focusedWindow: AXUIElement?) -> [AXUIElement] {
        var result: [AXUIElement] = [element]
        var seen = Set<CFHashCode>([CFHash(element)])
        var current = element

        for _ in 0..<8 {
            guard let parent = parent(of: current) else { break }
            let key = CFHash(parent)
            if seen.insert(key).inserted { result.append(parent) }
            current = parent
        }

        if let window = focusedWindow {
            let key = CFHash(window)
            if seen.insert(key).inserted { result.append(window) }
        }
        return result
    }

    private static func parent(of element: AXUIElement) -> AXUIElement? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXParentAttribute as CFString, &value) == .success,
              let value else { return nil }
        return (value as! AXUIElement)
    }

    private static func selectedTextBounds(in element: AXUIElement) -> CGRect? {
        var rangeValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, &rangeValue) == .success,
              let rangeValue,
              CFGetTypeID(rangeValue) == AXValueGetTypeID() else { return nil }

        let rangeAXValue = rangeValue as! AXValue
        guard AXValueGetType(rangeAXValue) == .cfRange else { return nil }
        var range = CFRange()
        guard AXValueGetValue(rangeAXValue, .cfRange, &range),
              range.length > 0 else { return nil }

        var boundsValue: CFTypeRef?
        guard AXUIElementCopyParameterizedAttributeValue(element,
                                                         kAXBoundsForRangeParameterizedAttribute as CFString,
                                                         rangeAXValue,
                                                         &boundsValue) == .success,
              let boundsValue,
              CFGetTypeID(boundsValue) == AXValueGetTypeID() else { return nil }

        let boundsAXValue = boundsValue as! AXValue
        guard AXValueGetType(boundsAXValue) == .cgRect else { return nil }
        var rect = CGRect.zero
        guard AXValueGetValue(boundsAXValue, .cgRect, &rect),
              rect.isFinite,
              rect.width > 1,
              rect.height > 1 else { return nil }
        return rect
    }

    private static func normalizedScreenRect(fromAccessibilityRect rect: CGRect) -> CGRect? {
        let mouse = NSEvent.mouseLocation
        var candidates: [CGRect] = []
        for screen in NSScreen.screens {
            let frame = screen.frame
            let raw = rect
            let flipped = CGRect(x: rect.origin.x,
                                 y: frame.maxY - rect.maxY + frame.minY,
                                 width: rect.width,
                                 height: rect.height)
            if raw.intersects(frame.insetBy(dx: -200, dy: -200)) { candidates.append(raw) }
            if flipped.intersects(frame.insetBy(dx: -200, dy: -200)) { candidates.append(flipped) }
        }
        guard !candidates.isEmpty else { return nil }
        return candidates.min { lhs, rhs in
            distanceSquared(lhs.center, mouse) < distanceSquared(rhs.center, mouse)
        }
    }

    private static func distanceSquared(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        let dx = a.x - b.x
        let dy = a.y - b.y
        return dx * dx + dy * dy
    }

    private static func collectText(from element: AXUIElement, depth: Int, limit: Int, visited: inout Set<CFHashCode>) -> String {
        guard depth <= 7, limit > 0 else { return "" }
        let key = CFHash(element)
        guard visited.insert(key).inserted else { return "" }

        var parts: [String] = []
        for attr in [kAXValueAttribute, kAXTitleAttribute, kAXDescriptionAttribute] {
            if let text = stringAttribute(attr, from: element), !text.isEmpty {
                parts.append(text)
            }
        }

        var remaining = limit - parts.reduce(0) { $0 + $1.count }
        guard remaining > 0 else { return parts.joined(separator: "\n") }

        for child in children(of: element).prefix(90) {
            let text = collectText(from: child, depth: depth + 1, limit: remaining, visited: &visited)
            if !text.isEmpty {
                parts.append(text)
                remaining -= text.count
                if remaining <= 0 { break }
            }
        }
        return parts.joined(separator: "\n")
    }

    private static func stringAttribute(_ attribute: String, from element: AXUIElement) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success,
              let value else { return nil }
        if let string = value as? String {
            return string.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let attributed = value as? NSAttributedString {
            return attributed.string.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return nil
    }

    private static func children(of element: AXUIElement) -> [AXUIElement] {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &value) == .success,
              let value else { return [] }
        return value as? [AXUIElement] ?? []
    }

    private static func cleanedContext(_ text: String) -> String {
        var seen = Set<String>()
        let lines = text
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        var result: [String] = []
        for line in lines {
            guard seen.insert(line).inserted else { continue }
            result.append(line)
        }
        return result.joined(separator: "\n")
    }

    private static func isUsefulContext(_ text: String, selected: String) -> Bool {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard t.count > max(selected.count + 40, 160) else { return false }
        let selectedCompact = compactForMatch(selected)
        guard selectedCompact.count >= 6 else { return t.count > 240 }
        return compactForMatch(t).contains(selectedCompact)
    }

    private static func trimmedContext(_ text: String, around selected: String, limit: Int) -> String {
        guard text.count > limit else { return text }
        if let range = text.range(of: selected, options: [.caseInsensitive, .diacriticInsensitive]) {
            let half = max(0, limit / 2)
            let start = text.index(range.lowerBound, offsetBy: -half, limitedBy: text.startIndex) ?? text.startIndex
            let end = text.index(range.upperBound, offsetBy: half, limitedBy: text.endIndex) ?? text.endIndex
            return String(text[start..<end]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return String(text.prefix(limit)).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func compactForMatch(_ text: String) -> String {
        let scalars = text.lowercased().unicodeScalars.filter {
            !CharacterSet.whitespacesAndNewlines.contains($0)
        }
        return String(String.UnicodeScalarView(scalars))
    }
}

private extension CGRect {
    var center: CGPoint { CGPoint(x: midX, y: midY) }

    var isFinite: Bool {
        origin.x.isFinite &&
        origin.y.isFinite &&
        size.width.isFinite &&
        size.height.isFinite
    }
}
