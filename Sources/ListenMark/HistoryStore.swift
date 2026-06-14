import Foundation
import Combine

final class HistoryStore: ObservableObject {
    static let shared = HistoryStore()
    static let limit = 500

    @Published private(set) var entries: [HistoryEntry] = []

    private let jsonURL: URL

    init() {
        let base = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(AppFlavor.supportFolderName, isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        jsonURL = base.appendingPathComponent("history.json")
        load()
    }

    func load() {
        guard let data = try? Data(contentsOf: jsonURL),
              let list = try? JSONDecoder.iso.decode([HistoryEntry].self, from: data) else { return }
        entries = Array(list.prefix(Self.limit))
    }

    func add(_ entry: HistoryEntry) {
        guard Settings.historyEnabled else { return }
        entries.insert(entry, at: 0)
        if entries.count > Self.limit {
            entries = Array(entries.prefix(Self.limit))
        }
        save()
    }

    func delete(_ entry: HistoryEntry) {
        entries.removeAll { $0.id == entry.id }
        save()
    }

    func clear() {
        entries.removeAll()
        save()
    }

    private func save() {
        if let data = try? JSONEncoder.iso.encode(entries) {
            try? data.write(to: jsonURL, options: .atomic)
        }
    }
}
