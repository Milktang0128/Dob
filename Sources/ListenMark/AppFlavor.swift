import Foundation

enum AppFlavor {
    // MARK: Build stamp & distribution identity (single unified build)

    /// The LMAppFlavor stamp baked into Info.plist — always "zh" now. Kept only
    /// so the in-app updater can verify a downloaded bundle carries the expected
    /// stamp (see GitHubReleaseUpdater.validateCandidateApp); already-shipped
    /// users' updaters require future builds to keep stamping "zh".
    static var rawValue: String {
        Bundle.main.object(forInfoDictionaryKey: "LMAppFlavor") as? String ?? "zh"
    }

    // One bundle id / support folder / release-tag prefix. (The retired
    // "international" build had its own identity; it is no longer produced.)
    static var bundleIdentifier: String { "com.listenmark.app" }
    static var supportFolderName: String { "ListenMark" }
    static var releaseTagPrefix: String { "v" }

    // MARK: Branding (unified — one name regardless of build or language)

    static var brandName: String { "Dob" }
    static var appName: String { "Dob" }
    static var tagline: String {
        text("过耳不忘的 AI 读写工具", "An AI reading and writing tool with context, speech, and memory.")
    }

    // MARK: UI language (runtime — follows system locale, overridable in Settings)

    /// "system" | "zh" | "en"
    static var languagePreference: String {
        UserDefaults.standard.string(forKey: "appLanguage") ?? "system"
    }

    static var systemPrefersChinese: Bool {
        (Locale.preferredLanguages.first ?? "en").lowercased().hasPrefix("zh")
    }

    /// The single switch every piece of localized copy (and the translate target)
    /// reads. Changing the override or the system language flips the whole app.
    static var uiLanguageIsEnglish: Bool {
        switch languagePreference {
        case "en": return true
        case "zh": return false
        default:   return !systemPrefersChinese   // "system"
        }
    }

    static func text(_ zh: String, _ en: String) -> String {
        uiLanguageIsEnglish ? en : zh
    }
}
