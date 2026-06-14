import Foundation

/// A toolbar action — built-in or user-defined. LLM actions carry a system
/// prompt; `read` (needsLLM == false) just speaks the original text.
struct ActionDef: Identifiable, Codable, Equatable {
    var id: String
    var name: String
    var icon: String
    var enabled: Bool
    var isBuiltin: Bool
    var needsLLM: Bool
    var prompt: String
    var hotKeyCode: Int?
    var hotKeyMods: Int?
    var hotKeyDisplay: String?

    init(id: String, name: String, icon: String, enabled: Bool, isBuiltin: Bool,
         needsLLM: Bool, prompt: String, hotKeyCode: Int? = nil,
         hotKeyMods: Int? = nil, hotKeyDisplay: String? = nil) {
        self.id = id
        self.name = name
        self.icon = icon
        self.enabled = enabled
        self.isBuiltin = isBuiltin
        self.needsLLM = needsLLM
        self.prompt = prompt
        self.hotKeyCode = hotKeyCode
        self.hotKeyMods = hotKeyMods
        self.hotKeyDisplay = hotKeyDisplay
    }
}

/// One archived interaction. `action`/`icon` are stored by value so custom and
/// renamed actions still render correctly in the archive.
struct Entry: Identifiable, Codable {
    var id: UUID = UUID()
    var date: Date = Date()
    var action: String
    var icon: String?
    var sourceApp: String
    var original: String
    var response: String?
    var responseModel: String? = nil
    var comparison: ComparisonRecord? = nil
    var contextUsed: Bool?
    var contextExcerpt: String?
    // Spaced-repetition state (optional → back-compatible with old archives).
    var reviewCount: Int?
    var lastReviewed: Date?
    var mastered: Bool?
}

/// Silent recent-history item. This deliberately omits full-text context so it
/// stays lightweight and separate from intentional archive entries.
struct HistoryEntry: Identifiable, Codable {
    var id: UUID = UUID()
    var date: Date = Date()
    var action: String
    var icon: String?
    var sourceApp: String
    var original: String
    var response: String?
    var responseModel: String? = nil
    var comparison: ComparisonRecord? = nil
}

struct LLMProviderConfig: Identifiable, Equatable {
    var id: String
    var label: String
    var baseURL: String
    var apiKey: String
    var model: String
    var isDefault: Bool = false
}

struct CompareModelResult: Identifiable, Equatable {
    var id: String
    var label: String
    var model: String
    var text: String
    var isLoading: Bool
    var error: String?
}

struct ModelRunResult: Identifiable, Codable, Equatable {
    var id: String
    var label: String
    var model: String
    var status: String
    var response: String?
    var error: String?
}

struct ComparisonRecord: Codable, Equatable {
    var primaryID: String
    var selectedID: String
    var results: [ModelRunResult]
}

/// Lightweight spaced-repetition schedule for 今日回响.
enum ReviewSchedule {
    /// Intervals after each review, in seconds: 1d → 3d → 7d → 16d → 35d → 90d.
    static let intervals: [TimeInterval] = [86_400, 259_200, 604_800, 1_382_400, 3_024_000, 7_776_000]

    static func interval(forCount c: Int) -> TimeInterval {
        intervals[max(0, min(c, intervals.count - 1))]
    }

    /// Baseline a due date is measured from: last review, or creation if never reviewed.
    static func base(_ e: Entry) -> Date { e.lastReviewed ?? e.date }

    static func isDue(_ e: Entry, now: Date) -> Bool {
        if e.mastered == true { return false }
        return now.timeIntervalSince(base(e)) >= interval(forCount: e.reviewCount ?? 0)
    }
}

extension String {
    /// Rough CJK/Kana/Hangul check — used to pick a voice.
    var containsCJK: Bool {
        for s in unicodeScalars {
            let v = s.value
            if (0x4E00...0x9FFF).contains(v) || (0x3040...0x30FF).contains(v) || (0xAC00...0xD7AF).contains(v) {
                return true
            }
        }
        return false
    }

    var preview: String {
        let t = trimmingCharacters(in: .whitespacesAndNewlines)
        return t.count <= 24 ? t : String(t.prefix(24)) + "…"
    }
}

extension JSONDecoder {
    static var iso: JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }
}

extension JSONEncoder {
    static var iso: JSONEncoder {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        e.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return e
    }
}
