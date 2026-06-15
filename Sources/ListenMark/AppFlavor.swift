import Foundation

enum AppFlavor {
    static var rawValue: String {
        Bundle.main.object(forInfoDictionaryKey: "LMAppFlavor") as? String ?? "zh"
    }

    static var isInternational: Bool { rawValue == "international" }

    static var brandName: String { "Dob" }
    static var appName: String { isInternational ? "Dob International" : "Dob" }
    static var tagline: String {
        text("过耳不忘的 AI 读写工具", "An AI reading and writing tool with context, speech, and memory.")
    }

    // Bridge release: keep the old bundle identifiers and support folders so
    // existing users retain Accessibility permission, settings, and archives.
    static var bundleIdentifier: String { isInternational ? "com.listenmark.international" : "com.listenmark.app" }
    static var supportFolderName: String { isInternational ? "ListenMark International" : "ListenMark" }
    static var releaseTagPrefix: String { isInternational ? "listenmark-v" : "v" }
    static var usesPrereleaseUpdateChannel: Bool { isInternational }

    static func text(_ zh: String, _ en: String) -> String {
        isInternational ? en : zh
    }
}
