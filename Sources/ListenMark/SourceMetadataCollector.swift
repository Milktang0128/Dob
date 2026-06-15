import AppKit
import ApplicationServices
import Foundation

enum SourceMetadataCollector {
    static func current(contextSource: SelectionGrabber.ContextSource? = nil,
                        fallbackName: String? = nil,
                        allowBrowserScripting: Bool = false) -> SourceMetadata {
        let app = NSWorkspace.shared.frontmostApplication
        let appName = clean(app?.localizedName) ?? clean(fallbackName) ?? AppFlavor.text("未知来源", "Unknown Source")
        let bundleID = clean(app?.bundleIdentifier)
        let windowTitle = bestWindowTitle(contextSource: contextSource)

        var pageURL = bestAXWebURL(contextSource: contextSource)
        var pageTitle: String?
        if isBrowser(bundleID) {
            pageTitle = windowTitle
            if allowBrowserScripting, let app, pageURL == nil {
                let page = activeBrowserPage(app: app)
                pageURL = page.url
                pageTitle = clean(page.title) ?? pageTitle
            }
        }

        return SourceMetadata(appName: appName,
                              bundleIdentifier: bundleID,
                              windowTitle: windowTitle,
                              pageTitle: pageTitle,
                              pageURL: sanitizeWebURL(pageURL))
    }

    static func sanitizedWebURL(_ raw: String?) -> String? {
        sanitizeWebURL(raw)
    }

    private static func bestWindowTitle(contextSource: SelectionGrabber.ContextSource?) -> String? {
        if let window = contextSource?.window, let title = stringAttribute(kAXTitleAttribute, from: window) {
            return title
        }
        if let focused = contextSource?.focused {
            for element in elementLineage(startingAt: focused, extra: contextSource?.window) {
                if let title = stringAttribute(kAXTitleAttribute, from: element), !title.isEmpty {
                    return title
                }
            }
        }
        return nil
    }

    private static func bestAXWebURL(contextSource: SelectionGrabber.ContextSource?) -> String? {
        guard let focused = contextSource?.focused else { return nil }
        for element in elementLineage(startingAt: focused, extra: contextSource?.window) {
            for attr in ["AXURL", "AXDocument"] {
                if let value = urlLikeAttribute(attr, from: element),
                   let sanitized = sanitizeWebURL(value) {
                    return sanitized
                }
            }
        }
        return nil
    }

    private static func elementLineage(startingAt element: AXUIElement, extra: AXUIElement?) -> [AXUIElement] {
        var result: [AXUIElement] = [element]
        var seen = Set<CFHashCode>([CFHash(element)])
        var current = element
        for _ in 0..<8 {
            guard let parent = parent(of: current) else { break }
            let key = CFHash(parent)
            if seen.insert(key).inserted { result.append(parent) }
            current = parent
        }
        if let extra {
            let key = CFHash(extra)
            if seen.insert(key).inserted { result.append(extra) }
        }
        return result
    }

    private static func parent(of element: AXUIElement) -> AXUIElement? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXParentAttribute as CFString, &value) == .success,
              let value else { return nil }
        return (value as! AXUIElement)
    }

    private static func stringAttribute(_ attribute: String, from element: AXUIElement) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success,
              let value else { return nil }
        if let string = value as? String { return clean(string) }
        if let attributed = value as? NSAttributedString { return clean(attributed.string) }
        return nil
    }

    private static func urlLikeAttribute(_ attribute: String, from element: AXUIElement) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success,
              let value else { return nil }
        if let url = value as? URL { return url.absoluteString }
        if let string = value as? String { return string }
        return nil
    }

    private static func activeBrowserPage(app: NSRunningApplication) -> (title: String?, url: String?) {
        guard let bundleID = app.bundleIdentifier else { return (nil, nil) }
        let script: String
        if bundleID == "com.apple.Safari" || bundleID == "com.apple.SafariTechnologyPreview" {
            script = """
            tell application id "\(bundleID)"
                if (count of windows) = 0 then return ""
                set theTitle to name of current tab of front window
                set theURL to URL of current tab of front window
                return theTitle & linefeed & theURL
            end tell
            """
        } else {
            script = """
            tell application id "\(bundleID)"
                if (count of windows) = 0 then return ""
                set theTab to active tab of front window
                set theTitle to title of theTab
                set theURL to URL of theTab
                return theTitle & linefeed & theURL
            end tell
            """
        }

        var error: NSDictionary?
        guard let output = NSAppleScript(source: script)?.executeAndReturnError(&error).stringValue else {
            return (nil, nil)
        }
        let lines = output.components(separatedBy: .newlines)
        return (clean(lines.first), lines.dropFirst().first.flatMap(clean))
    }

    private static func sanitizeWebURL(_ raw: String?) -> String? {
        guard let raw = clean(raw),
              let url = URL(string: raw),
              let scheme = url.scheme?.lowercased(),
              ["http", "https"].contains(scheme),
              url.host != nil else { return nil }

        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        components?.scheme = scheme
        components?.query = nil
        components?.fragment = nil
        return components?.url?.absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }

    private static func isBrowser(_ bundleID: String?) -> Bool {
        guard let bundleID else { return false }
        return [
            "com.apple.Safari",
            "com.apple.SafariTechnologyPreview",
            "com.google.Chrome",
            "com.google.Chrome.canary",
            "org.chromium.Chromium",
            "com.microsoft.edgemac",
            "com.microsoft.edgemac.Canary",
            "com.microsoft.edgemac.Dev",
            "com.brave.Browser",
            "company.thebrowser.Browser",
            "com.vivaldi.Vivaldi",
            "com.operasoftware.Opera"
        ].contains(bundleID)
    }

    private static func clean(_ value: String?) -> String? {
        let clean = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return clean.isEmpty ? nil : clean
    }
}
