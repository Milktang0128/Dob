import Foundation
import Combine

/// The product's spine: interactions persist as JSON (source of truth, kept
/// internally) plus a human-readable Markdown file the user can point at any
/// folder — e.g. an Obsidian vault — so it's always viewable and agent-managed.
final class ArchiveStore: ObservableObject {
    static let shared = ArchiveStore()

    @Published private(set) var entries: [Entry] = []

    private let jsonURL: URL
    let internalFolder: URL

    init() {
        let base = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(AppFlavor.supportFolderName, isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        internalFolder = base
        jsonURL = base.appendingPathComponent("archive.json")
        load()
    }

    /// Where the readable Markdown lives — user's folder if set, else internal.
    var markdownURL: URL {
        let folder = Settings.archiveFolder
        if !folder.isEmpty {
            return URL(fileURLWithPath: folder, isDirectory: true).appendingPathComponent("\(AppFlavor.appName).md")
        }
        return internalFolder.appendingPathComponent("\(AppFlavor.appName).md")
    }

    var revealFolder: URL {
        let folder = Settings.archiveFolder
        return folder.isEmpty ? internalFolder : URL(fileURLWithPath: folder, isDirectory: true)
    }

    func load() {
        guard let data = try? Data(contentsOf: jsonURL),
              let list = try? JSONDecoder.iso.decode([Entry].self, from: data) else { return }
        entries = list
        exportMarkdown()
    }

    func add(_ entry: Entry) {
        entries.insert(entry, at: 0)
        save()
    }

    func delete(_ entry: Entry) {
        entries.removeAll { $0.id == entry.id }
        save()
    }

    /// Replace an entry by id, or add it if absent. Lets a growing conversation
    /// thread update its single archive entry instead of piling up copies.
    func update(_ entry: Entry) {
        if let i = entries.firstIndex(where: { $0.id == entry.id }) {
            entries[i] = entry
            save()
        } else {
            add(entry)
        }
    }

    /// Re-export to a (possibly newly chosen) Markdown location.
    func relocate() { exportMarkdown() }

    // MARK: 今日回响 (spaced review)

    func dueForReview(limit: Int = 8, now: Date = Date()) -> [Entry] {
        Array(entries.filter { ReviewSchedule.isDue($0, now: now) }
            .sorted { ReviewSchedule.base($0) < ReviewSchedule.base($1) }
            .prefix(limit))
    }

    func oldestForReview(limit: Int = 8) -> [Entry] {
        Array(entries.filter { $0.mastered != true && $0.conversationTurns == nil }
            .sorted { ReviewSchedule.base($0) < ReviewSchedule.base($1) }
            .prefix(limit))
    }

    var dueCount: Int { entries.filter { ReviewSchedule.isDue($0, now: Date()) }.count }

    func markReviewed(_ id: UUID) {
        guard let i = entries.firstIndex(where: { $0.id == id }) else { return }
        entries[i].reviewCount = (entries[i].reviewCount ?? 0) + 1
        entries[i].lastReviewed = Date()
        save()
    }

    func setMastered(_ id: UUID, _ on: Bool) {
        guard let i = entries.firstIndex(where: { $0.id == id }) else { return }
        entries[i].mastered = on
        save()
    }

    func resetReview(_ id: UUID) {
        guard let i = entries.firstIndex(where: { $0.id == id }) else { return }
        entries[i].reviewCount = 0
        entries[i].lastReviewed = nil
        entries[i].mastered = false
        save()
    }

    private func save() {
        if let data = try? JSONEncoder.iso.encode(entries) {
            try? data.write(to: jsonURL, options: .atomic)
        }
        exportMarkdown()
    }

    private func exportMarkdown() {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd HH:mm"
        var md = "# \(AppFlavor.text("Dob · 档案", "Dob Archive"))\n\n"
        for e in entries {
            md += "## \(e.action) · \(df.string(from: e.date)) · \(e.sourceApp)\n\n"
            if let source = e.sourceMetadata?.markdownBlock {
                md += "\(source)\n\n"
            }
            if e.contextUsed == true {
                md += "_\(AppFlavor.text("已附带上下文", "Context included"))_\n\n"
            }
            let quotedOriginal = ArchiveMarkdownFormatter.quoteBlock(e.original)
            if !quotedOriginal.isEmpty {
                md += "\(quotedOriginal)\n\n"
            }
            if let turns = e.conversationTurns, !turns.isEmpty {
                for turn in turns {
                    let speaker = turn.role == .user
                        ? AppFlavor.text("你", "You")
                        : AppFlavor.text("AI", "AI")
                    md += "### \(speaker)\n\n"
                    let clean = turn.role == .user
                        ? turn.text.trimmingCharacters(in: .whitespacesAndNewlines)
                        : ArchiveMarkdownFormatter.body(turn.text)
                    if !clean.isEmpty {
                        md += "\(clean)\n\n"
                    }
                }
            } else if let comparison = e.comparison {
                for result in comparison.results {
                    md += "### \(result.label) · \(result.model)\n\n"
                    if let response = result.response {
                        let clean = ArchiveMarkdownFormatter.body(response)
                        if !clean.isEmpty {
                            md += "\(clean)\n\n"
                        }
                    } else if let error = result.error, !error.isEmpty {
                        md += "_\(AppFlavor.text("出错", "Error"))：\(error)_\n\n"
                    }
                }
            } else if let r = e.response {
                let clean = ArchiveMarkdownFormatter.body(r)
                if !clean.isEmpty {
                    md += "\(clean)\n\n"
                }
            }
            if let context = e.contextExcerpt, !context.isEmpty {
                md += "<details>\n<summary>\(AppFlavor.text("上下文摘录", "Context excerpt"))</summary>\n\n"
                md += "\(ContextExcerptFormatter.markdownHighlighted(context))\n\n"
                md += "</details>\n\n"
            }
            md += "---\n\n"
        }
        let url = markdownURL
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                                 withIntermediateDirectories: true)
        try? md.write(to: url, atomically: true, encoding: .utf8)
    }
}
