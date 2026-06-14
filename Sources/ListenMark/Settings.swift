import Foundation
import AVFoundation
import Carbon.HIToolbox

/// Thin UserDefaults wrapper. Shared with the SwiftUI settings view via
/// matching @AppStorage keys.
enum Settings {
    private static let d = UserDefaults.standard

    // MARK: Text actions — OpenAI-compatible chat completions

    static let recommendedLLMBaseURL = "https://api.deepseek.com"
    static let recommendedLLMModel = "deepseek-v4-flash"

    static var llmBaseURL: String {
        get {
            d.string(forKey: "llmBaseURL") ?? recommendedLLMBaseURL
        }
        set { d.set(newValue, forKey: "llmBaseURL") }
    }

    static var llmAPIKey: String {
        get { d.string(forKey: "deepseekKey") ?? "" }
        set { d.set(newValue, forKey: "deepseekKey") }
    }

    static var llmModel: String {
        get {
            let m = d.string(forKey: "deepseekModel") ?? ""
            return m.isEmpty ? recommendedLLMModel : m
        }
        set { d.set(newValue, forKey: "deepseekModel") }
    }

    static var llmChatCompletionsURL: URL? {
        let raw = llmBaseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { return nil }
        let normalized = raw.hasSuffix("/") ? String(raw.dropLast()) : raw
        if normalized.lowercased().hasSuffix("/chat/completions") {
            return URL(string: normalized)
        }
        return URL(string: normalized + "/chat/completions")
    }

    static var defaultLLMProvider: LLMProviderConfig {
        LLMProviderConfig(id: "default", label: AppFlavor.text("默认", "Default"),
                          baseURL: llmBaseURL, apiKey: llmAPIKey, model: llmModel,
                          isDefault: true)
    }

    static var compareProviders: [LLMProviderConfig] {
        var providers = [defaultLLMProvider]
        if compareProvider1Enabled {
            providers.append(LLMProviderConfig(id: "compare1",
                                               label: nonEmpty(compareProvider1Label, fallback: AppFlavor.text("备选 A", "Alt A")),
                                               baseURL: nonEmpty(compareProvider1BaseURL, fallback: llmBaseURL),
                                               apiKey: compareProvider1APIKey,
                                               model: compareProvider1Model))
        }
        if compareProvider2Enabled {
            providers.append(LLMProviderConfig(id: "compare2",
                                               label: nonEmpty(compareProvider2Label, fallback: AppFlavor.text("备选 B", "Alt B")),
                                               baseURL: nonEmpty(compareProvider2BaseURL, fallback: llmBaseURL),
                                               apiKey: compareProvider2APIKey,
                                               model: compareProvider2Model))
        }
        return Array(providers.prefix(3))
    }

    private static func nonEmpty(_ value: String, fallback: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? fallback : trimmed
    }

    static var deepseekKey: String {
        get { llmAPIKey }
        set { llmAPIKey = newValue }
    }

    static var deepseekModel: String {
        get { llmModel }
        set { llmModel = newValue }
    }

    static var useFullContext: Bool {
        get { d.object(forKey: "useFullContext") == nil ? true : d.bool(forKey: "useFullContext") }
        set { d.set(newValue, forKey: "useFullContext") }
    }

    static var autoSpeakAI: Bool {
        get { d.object(forKey: "autoSpeakAI") == nil ? true : d.bool(forKey: "autoSpeakAI") }
        set { d.set(newValue, forKey: "autoSpeakAI") }
    }

    static var panelTextSizeDelta: Int {
        get { d.integer(forKey: "panelTextSizeDelta") }
        set { d.set(max(-2, min(6, newValue)), forKey: "panelTextSizeDelta") }
    }

    static var compareProvider1Enabled: Bool {
        get { d.bool(forKey: "compareProvider1Enabled") }
        set { d.set(newValue, forKey: "compareProvider1Enabled") }
    }

    static var compareProvider1Label: String {
        get { d.string(forKey: "compareProvider1Label") ?? AppFlavor.text("备选 A", "Alt A") }
        set { d.set(newValue, forKey: "compareProvider1Label") }
    }

    static var compareProvider1BaseURL: String {
        get {
            let value = d.string(forKey: "compareProvider1BaseURL") ?? ""
            return value.isEmpty ? recommendedLLMBaseURL : value
        }
        set { d.set(newValue, forKey: "compareProvider1BaseURL") }
    }

    static var compareProvider1APIKey: String {
        get { d.string(forKey: "compareProvider1APIKey") ?? "" }
        set { d.set(newValue, forKey: "compareProvider1APIKey") }
    }

    static var compareProvider1Model: String {
        get { d.string(forKey: "compareProvider1Model") ?? "" }
        set { d.set(newValue, forKey: "compareProvider1Model") }
    }

    static var compareProvider2Enabled: Bool {
        get { d.bool(forKey: "compareProvider2Enabled") }
        set { d.set(newValue, forKey: "compareProvider2Enabled") }
    }

    static var compareProvider2Label: String {
        get { d.string(forKey: "compareProvider2Label") ?? AppFlavor.text("备选 B", "Alt B") }
        set { d.set(newValue, forKey: "compareProvider2Label") }
    }

    static var compareProvider2BaseURL: String {
        get {
            let value = d.string(forKey: "compareProvider2BaseURL") ?? ""
            return value.isEmpty ? recommendedLLMBaseURL : value
        }
        set { d.set(newValue, forKey: "compareProvider2BaseURL") }
    }

    static var compareProvider2APIKey: String {
        get { d.string(forKey: "compareProvider2APIKey") ?? "" }
        set { d.set(newValue, forKey: "compareProvider2APIKey") }
    }

    static var compareProvider2Model: String {
        get { d.string(forKey: "compareProvider2Model") ?? "" }
        set { d.set(newValue, forKey: "compareProvider2Model") }
    }

    // MARK: Speech engine

    /// "volcano" (火山引擎, recommended) or "local" (macOS).
    static var ttsEngine: String {
        get {
            let e = d.string(forKey: "ttsEngine") ?? ""
            return e.isEmpty ? AppFlavor.text("volcano", "local") : e
        }
        set { d.set(newValue, forKey: "ttsEngine") }
    }

    static var volcAppId: String {
        get { d.string(forKey: "volcAppId") ?? "" }
        set { d.set(newValue, forKey: "volcAppId") }
    }

    static var volcToken: String {
        get { d.string(forKey: "volcToken") ?? "" }
        set { d.set(newValue, forKey: "volcToken") }
    }

    static var volcCluster: String {
        get {
            let c = d.string(forKey: "volcCluster") ?? ""
            return c.isEmpty ? "volcano_tts" : c
        }
        set { d.set(newValue, forKey: "volcCluster") }
    }

    static var volcVoice: String {
        get {
            let v = d.string(forKey: "volcVoice") ?? ""
            return v.isEmpty ? AppFlavor.text("zh_female_cancan_uranus_bigtts", "en_female_dacey_uranus_bigtts") : v
        }
        set { d.set(newValue, forKey: "volcVoice") }
    }

    static var volcSpeed: Double {
        get { d.object(forKey: "volcSpeed") == nil ? 1.0 : d.double(forKey: "volcSpeed") }
        set { d.set(newValue, forKey: "volcSpeed") }
    }

    static var volcConfigured: Bool { !volcAppId.isEmpty && !volcToken.isEmpty }

    // MARK: Archive

    /// Auto-save every interaction. Default OFF — user archives on demand.
    static var autoArchive: Bool {
        get { d.bool(forKey: "autoArchive") }
        set { d.set(newValue, forKey: "autoArchive") }
    }

    /// User-chosen folder for the human-readable Markdown archive (e.g. an
    /// Obsidian vault). Empty → default Application Support folder.
    static var archiveFolder: String {
        get { d.string(forKey: "archiveFolder") ?? "" }
        set { d.set(newValue, forKey: "archiveFolder") }
    }

    static var historyEnabled: Bool {
        get { d.object(forKey: "historyEnabled") == nil ? true : d.bool(forKey: "historyEnabled") }
        set { d.set(newValue, forKey: "historyEnabled") }
    }

    /// Local AVSpeechUtterance rate (0.0–1.0; ~0.5 is the natural default).
    static var speechRate: Float {
        get {
            if d.object(forKey: "rate") == nil { return AVSpeechUtteranceDefaultSpeechRate }
            return d.float(forKey: "rate")
        }
        set { d.set(newValue, forKey: "rate") }
    }

    // MARK: Trigger

    static var autoPop: Bool {
        get { d.object(forKey: "autoPop") == nil ? true : d.bool(forKey: "autoPop") }
        set { d.set(newValue, forKey: "autoPop") }
    }

    static var autoPopCopyFallback: Bool {
        get { d.object(forKey: "autoPopCopyFallback") == nil ? true : d.bool(forKey: "autoPopCopyFallback") }
        set { d.set(newValue, forKey: "autoPopCopyFallback") }
    }

    static var hotKeyCode: Int {
        get { d.object(forKey: "hkCode") == nil ? 15 : d.integer(forKey: "hkCode") }
        set { d.set(newValue, forKey: "hkCode") }
    }

    static var hotKeyMods: Int {
        get { d.object(forKey: "hkMods") == nil ? (256 | 2048) : d.integer(forKey: "hkMods") }
        set { d.set(newValue, forKey: "hkMods") }
    }

    static var hotKeyDisplay: String {
        get {
            let s = d.string(forKey: "hkDisplay") ?? ""
            return s.isEmpty ? "⌥⌘R" : s
        }
        set { d.set(newValue, forKey: "hkDisplay") }
    }

    static var ocrHotKeyCode: Int {
        get { d.object(forKey: "ocrHkCode") == nil ? Int(kVK_ANSI_O) : d.integer(forKey: "ocrHkCode") }
        set { d.set(newValue, forKey: "ocrHkCode") }
    }

    static var ocrHotKeyMods: Int {
        get { d.object(forKey: "ocrHkMods") == nil ? (controlKey | shiftKey) : d.integer(forKey: "ocrHkMods") }
        set { d.set(newValue, forKey: "ocrHkMods") }
    }

    static var ocrHotKeyDisplay: String {
        get {
            let s = d.string(forKey: "ocrHkDisplay") ?? ""
            return s.isEmpty ? "⌃⇧O" : s
        }
        set { d.set(newValue, forKey: "ocrHkDisplay") }
    }

    static var silentOCRHotKeyCode: Int {
        get { d.object(forKey: "silentOcrHkCode") == nil ? Int(kVK_ANSI_C) : d.integer(forKey: "silentOcrHkCode") }
        set { d.set(newValue, forKey: "silentOcrHkCode") }
    }

    static var silentOCRHotKeyMods: Int {
        get { d.object(forKey: "silentOcrHkMods") == nil ? (controlKey | shiftKey) : d.integer(forKey: "silentOcrHkMods") }
        set { d.set(newValue, forKey: "silentOcrHkMods") }
    }

    static var silentOCRHotKeyDisplay: String {
        get {
            let s = d.string(forKey: "silentOcrHkDisplay") ?? ""
            return s.isEmpty ? "⌃⇧C" : s
        }
        set { d.set(newValue, forKey: "silentOcrHkDisplay") }
    }

    static var inputHotKeyCode: Int {
        get { d.object(forKey: "inputHkCode") == nil ? Int(kVK_ANSI_I) : d.integer(forKey: "inputHkCode") }
        set { d.set(newValue, forKey: "inputHkCode") }
    }

    static var inputHotKeyMods: Int {
        get { d.object(forKey: "inputHkMods") == nil ? (controlKey | shiftKey) : d.integer(forKey: "inputHkMods") }
        set { d.set(newValue, forKey: "inputHkMods") }
    }

    static var inputHotKeyDisplay: String {
        get {
            let s = d.string(forKey: "inputHkDisplay") ?? ""
            return s.isEmpty ? "⌃⇧I" : s
        }
        set { d.set(newValue, forKey: "inputHkDisplay") }
    }

    static var ocrAutoRunLastAction: Bool {
        get { d.object(forKey: "ocrAutoRunLastAction") == nil ? true : d.bool(forKey: "ocrAutoRunLastAction") }
        set { d.set(newValue, forKey: "ocrAutoRunLastAction") }
    }

    static var lastActionID: String {
        get { d.string(forKey: "lastActionID") ?? "" }
        set { d.set(newValue, forKey: "lastActionID") }
    }
}

/// Posted whenever the trigger config (hotkey / auto-pop) changes.
extension Notification.Name {
    static let gebwConfigChanged = Notification.Name("GEBWConfigChanged")
    static let gebwOpenSettings = Notification.Name("GEBWOpenSettings")
    static let gebwOpenActions = Notification.Name("GEBWOpenActions")
    static let gebwOpenServices = Notification.Name("GEBWOpenServices")
}
