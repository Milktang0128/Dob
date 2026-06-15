import AppKit
import SwiftUI

func actionTint(_ name: String) -> Color {
    switch name {
    case "朗读", "Read": return .blue
    case "解释", "Explain": return .orange
    case "翻译", "Translate": return .green
    case "提炼", "Summarize": return .purple
    case "背景", "Context": return .pink
    case "摘录", "Clip": return .gray
    default: return .teal
    }
}

/// The "回看" surface — sidebar (filter by action) + searchable card list.
struct ArchiveView: View {
    @ObservedObject private var store = ArchiveStore.shared
    @ObservedObject private var actions = ActionStore.shared
    @State private var query = ""
    @State private var filter: Filter? = .all

    enum Filter: Hashable { case all; case action(String) }

    private var base: [Entry] {
        switch filter ?? .all {
        case .all: return store.entries
        case .action(let name): return store.entries.filter { $0.action == name }
        }
    }

    private var filtered: [Entry] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return base }
        return base.filter {
            $0.original.localizedCaseInsensitiveContains(q) ||
            ($0.response ?? "").localizedCaseInsensitiveContains(q) ||
            ($0.contextExcerpt ?? "").localizedCaseInsensitiveContains(q) ||
            ($0.sourceMetadata?.searchText ?? "").localizedCaseInsensitiveContains(q)
        }
    }

    private func count(_ name: String) -> Int { store.entries.filter { $0.action == name }.count }

    var body: some View {
        NavigationSplitView {
            List(selection: $filter) {
                Section(AppFlavor.text("资源库", "Library")) {
                    Label(AppFlavor.text("全部记录", "All Items"), systemImage: "tray.full")
                        .badge(store.entries.count)
                        .tag(Filter.all)
                }
                Section(AppFlavor.text("按动作", "By Action")) {
                    ForEach(actions.actions) { def in
                        HStack(spacing: 9) {
                            Circle().fill(actionTint(def.name)).frame(width: 8, height: 8)
                            Text(def.name)
                        }
                        .badge(count(def.name))
                        .tag(Filter.action(def.name))
                    }
                }
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 180, ideal: 200, max: 240)
        } detail: {
            detail
        }
        .navigationTitle(AppFlavor.text("档案", "Archive"))
    }

    private var detail: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                HStack(spacing: 7) {
                    Image(systemName: "magnifyingglass").font(.system(size: 12)).foregroundStyle(.secondary)
                    TextField(AppFlavor.text("搜索原文或 AI 回应…", "Search original text or AI responses..."), text: $query)
                        .textFieldStyle(.plain).font(.system(size: 13))
                    if !query.isEmpty {
                        Button { query = "" } label: { Image(systemName: "xmark.circle.fill") }
                            .buttonStyle(.plain).foregroundStyle(.tertiary)
                    }
                }
                .padding(.horizontal, 10).padding(.vertical, 7)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.primary.opacity(0.06)))

                Text(AppFlavor.text("\(filtered.count) 条", "\(filtered.count) items")).font(.system(size: 12)).foregroundStyle(.secondary)

                Divider().frame(height: 18)

                Button {
                    openArchiveInObsidian()
                } label: {
                    Label(AppFlavor.text("打开 Obsidian", "Open Obsidian"), systemImage: "book.closed")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help(AppFlavor.text("用 Obsidian 打开 Markdown 留档", "Open the Markdown archive in Obsidian"))

                Button {
                    revealArchiveFile()
                } label: {
                    Label(AppFlavor.text("在访达中显示", "Show in Finder"), systemImage: "folder")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help(AppFlavor.text("在访达中定位 Markdown 留档文件", "Reveal the Markdown archive file in Finder"))
            }
            .padding(14)
            Divider()

            if filtered.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: store.entries.isEmpty ? "ear" : "magnifyingglass")
                        .font(.system(size: 30)).foregroundStyle(.tertiary)
                    Text(store.entries.isEmpty ? AppFlavor.text("还没有记录\n选中文本，处理后点「留档」", "No saved items yet\nSelect text, run an action, then save it") : AppFlavor.text("没有匹配的记录", "No matching items"))
                        .multilineTextAlignment(.center)
                        .font(.system(size: 13)).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(filtered) { EntryCard(entry: $0) }
                    }
                    .padding(14)
                }
            }
        }
    }

    private func openArchiveInObsidian() {
        ArchiveStore.shared.relocate()
        let fileURL = ArchiveStore.shared.markdownURL
        if let url = obsidianOpenURL(for: fileURL), NSWorkspace.shared.open(url) {
            return
        }
        revealArchiveFile()
    }

    private func revealArchiveFile() {
        ArchiveStore.shared.relocate()
        NSWorkspace.shared.activateFileViewerSelecting([ArchiveStore.shared.markdownURL])
    }

    private func obsidianOpenURL(for fileURL: URL) -> URL? {
        var components = URLComponents()
        components.scheme = "obsidian"
        components.host = "open"
        components.queryItems = [
            URLQueryItem(name: "path", value: fileURL.path)
        ]
        return components.url
    }
}

private struct EntryCard: View {
    let entry: Entry
    @ObservedObject private var store = ArchiveStore.shared
    @State private var hover = false
    @State private var showContext = false

    private static let df: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MM-dd HH:mm"
        return f
    }()

    var body: some View {
        let tint = actionTint(entry.action)
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                HStack(spacing: 4) {
                    Image(systemName: entry.icon ?? "text.bubble").font(.system(size: 10))
                    Text(entry.action).font(.system(size: 11, weight: .medium))
                }
                .foregroundStyle(tint)
                .padding(.horizontal, 8).padding(.vertical, 3)
                .background(Capsule().fill(tint.opacity(0.14)))

                if entry.contextUsed == true {
                    Label(AppFlavor.text("已附带上下文", "Context included"), systemImage: "doc.text.magnifyingglass")
                        .font(.system(size: 10, weight: .medium))
                        .labelStyle(.titleAndIcon)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 7).padding(.vertical, 3)
                        .background(Capsule().fill(Color.primary.opacity(0.07)))
                }

                if entry.comparison != nil {
                    Label(AppFlavor.text("比较", "Compare"), systemImage: "rectangle.split.3x1")
                        .font(.system(size: 10, weight: .medium))
                        .labelStyle(.titleAndIcon)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 7).padding(.vertical, 3)
                        .background(Capsule().fill(Color.primary.opacity(0.07)))
                }

                Text(entry.sourceApp).font(.system(size: 11)).foregroundStyle(.secondary)
                Text(Self.df.string(from: entry.date)).font(.system(size: 11)).foregroundStyle(.tertiary)
                Spacer()
                Button { Speaker.shared.speak(entry.response ?? entry.original) } label: {
                    Image(systemName: "play.circle").font(.system(size: 15))
                }.buttonStyle(.plain).foregroundStyle(hover ? .primary : .secondary).help(AppFlavor.text("重听", "Replay"))
                Button { store.delete(entry) } label: {
                    Image(systemName: "trash").font(.system(size: 13))
                }.buttonStyle(.plain).foregroundStyle(hover ? .secondary : .tertiary).help(AppFlavor.text("删除", "Delete"))
            }

            if let summary = entry.sourceMetadata?.compactSummary {
                HStack(spacing: 6) {
                    Image(systemName: entry.sourceMetadata?.pageURL == nil ? "macwindow" : "link")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                    Text(summary)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    if let url = entry.sourceMetadata?.pageURL {
                        Text(url)
                            .font(.system(size: 11))
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }
            }

            Text(entry.original)
                .font(.system(size: 13))
                .foregroundStyle(entry.response == nil ? .primary : .secondary)
                .lineLimit(3)

            if let r = entry.response, !r.isEmpty {
                Text(r).font(.system(size: 13)).lineLimit(8).textSelection(.enabled)
            }

            if let context = entry.contextExcerpt, !context.isEmpty {
                DisclosureGroup(AppFlavor.text("上下文摘录", "Context excerpt"), isExpanded: $showContext) {
                    Text(ContextExcerptFormatter.highlightedAttributedString(context))
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(8)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Color.primary.opacity(0.045)))
                }
                .font(.system(size: 12, weight: .medium))
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
}
