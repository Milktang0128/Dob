import SwiftUI

struct HistoryView: View {
    @ObservedObject private var store = HistoryStore.shared
    @State private var query = ""

    private var filtered: [HistoryEntry] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return store.entries }
        return store.entries.filter {
            $0.original.localizedCaseInsensitiveContains(q) ||
            ($0.response ?? "").localizedCaseInsensitiveContains(q) ||
            $0.action.localizedCaseInsensitiveContains(q) ||
            $0.sourceApp.localizedCaseInsensitiveContains(q)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                HStack(spacing: 7) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                    TextField(AppFlavor.text("搜索历史…", "Search history..."), text: $query)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13))
                    if !query.isEmpty {
                        Button { query = "" } label: { Image(systemName: "xmark.circle.fill") }
                            .buttonStyle(.plain)
                            .foregroundStyle(.tertiary)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.primary.opacity(0.06)))

                VStack(alignment: .leading, spacing: 1) {
                    Text(AppFlavor.text("\(filtered.count) 条", "\(filtered.count) items"))
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                    Text(AppFlavor.text("最近 500 条，不含上下文", "Latest 500, no context"))
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                }
                Spacer()
                Button(role: .destructive) { store.clear() } label: {
                    Label(AppFlavor.text("清空", "Clear"), systemImage: "trash")
                }
                .disabled(store.entries.isEmpty)
            }
            .padding(14)
            Divider()

            if filtered.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: store.entries.isEmpty ? "clock.arrow.circlepath" : "magnifyingglass")
                        .font(.system(size: 30))
                        .foregroundStyle(.tertiary)
                    Text(store.entries.isEmpty ? AppFlavor.text("还没有历史记录", "No history yet") : AppFlavor.text("没有匹配的历史记录", "No matching history"))
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(filtered) { HistoryEntryCard(entry: $0) }
                    }
                    .padding(14)
                }
            }
        }
        .navigationTitle(AppFlavor.text("历史记录", "History"))
    }
}

private struct HistoryEntryCard: View {
    let entry: HistoryEntry
    @ObservedObject private var store = HistoryStore.shared
    @State private var hover = false

    private static let df: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MM-dd HH:mm"
        return f
    }()

    private var responseText: String? {
        guard let response = entry.response else { return nil }
        let clean = LLMOutputSanitizer.visibleAnswer(from: response)
        return clean.isEmpty ? nil : clean
    }

    private var playableText: String {
        responseText ?? entry.original
    }

    var body: some View {
        let tint = actionTint(entry.action)
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                HStack(spacing: 4) {
                    Image(systemName: entry.icon ?? "text.bubble")
                        .font(.system(size: 10))
                    Text(entry.action)
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundStyle(tint)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Capsule().fill(tint.opacity(0.14)))

                Text(entry.sourceApp)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                if entry.comparison != nil {
                    Label(AppFlavor.text("比较", "Compare"), systemImage: "rectangle.split.3x1")
                        .font(.system(size: 10, weight: .medium))
                        .labelStyle(.titleAndIcon)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(Color.primary.opacity(0.07)))
                }
                Text(Self.df.string(from: entry.date))
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                Spacer()
                Button { Speaker.shared.speak(playableText) } label: {
                    Image(systemName: "play.circle")
                        .font(.system(size: 15))
                }
                .buttonStyle(.plain)
                .foregroundStyle(hover ? .primary : .secondary)
                .help(AppFlavor.text("重听", "Replay"))
                Button { copy(playableText) } label: {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 13))
                }
                .buttonStyle(.plain)
                .foregroundStyle(hover ? .secondary : .tertiary)
                .help(AppFlavor.text("复制", "Copy"))
                Button { store.delete(entry) } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 13))
                }
                .buttonStyle(.plain)
                .foregroundStyle(hover ? .secondary : .tertiary)
                .help(AppFlavor.text("删除", "Delete"))
            }

            Text(entry.original)
                .font(.system(size: 13))
                .foregroundStyle(responseText == nil ? .primary : .secondary)
                .lineLimit(3)
                .textSelection(.enabled)

            if let response = responseText {
                Text(response)
                    .font(.system(size: 13))
                    .lineLimit(8)
                    .textSelection(.enabled)
            }
        }
        .padding(13)
        .background(RoundedRectangle(cornerRadius: 11, style: .continuous).fill(Color(nsColor: .controlBackgroundColor)))
        .overlay(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .strokeBorder(Color.primary.opacity(hover ? 0.12 : 0.06), lineWidth: 0.5)
        )
        .onHover { hover = $0 }
    }

    private func copy(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
}
