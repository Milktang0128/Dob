import SwiftUI
import UniformTypeIdentifiers

/// Manage toolbar actions: reorder, enable/disable, edit prompts, and add up to
/// 4 custom actions with their own generation prompts (e.g. 拆解句法 / 记单词).
struct ActionsConfigView: View {
    @ObservedObject private var store = ActionStore.shared
    @State private var editing: EditTarget?
    @State private var draggingID: String?
    @State private var dropTargetID: String?

    struct EditTarget: Identifiable {
        let id = UUID()
        var def: ActionDef
        var isNew: Bool
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            listBody
        }
        .frame(minWidth: 480, minHeight: 520)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(AppFlavor.text("技能", "Actions"))
                .font(.system(size: 24, weight: .semibold))
            Text(AppFlavor.text("管理工具条技能：拖动排序、开关启用、编辑提示词，并可添加自定义技能。",
                                "Manage panel actions: reorder, toggle, edit prompts, and add your own."))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.top, 6)
        .padding(.bottom, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var listBody: some View {
        List {
            Section {
                ForEach(store.actions) { def in
                    row(def)
                        .onDrop(of: [.text],
                                delegate: ActionDropDelegate(targetID: def.id,
                                                             draggingID: $draggingID,
                                                             dropTargetID: $dropTargetID,
                                                             store: store))
                        .listRowInsets(EdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8))
                        .listRowBackground(Color.clear)
                }
            } header: {
                Text(AppFlavor.text("拖动把手调整顺序。朗读固定第一，工具条最多显示前 5 个启用技能。", "Drag handles to reorder actions. Read stays first; the panel shows up to 5 enabled actions."))
            }

            Section {
	                Button {
                    let newID = UUID().uuidString
	                    editing = EditTarget(
	                        def: ActionDef(id: newID, name: AppFlavor.text("新技能", "New Action"), icon: "wand.and.stars",
	                                       enabled: true, isBuiltin: false, needsLLM: true,
	                                       prompt: AppFlavor.text("用简洁的简体中文，对下面的文本做……（在这里写你想要的处理方式）", "In concise natural English, process the selected text as follows...")),
	                        isNew: true)
                } label: {
                    Label(AppFlavor.text("新增自定义技能（\(store.customCount)/\(ActionStore.maxCustom)）", "Add Custom Action (\(store.customCount)/\(ActionStore.maxCustom))"), systemImage: "plus.circle.fill")
                }
                .disabled(!store.canAddCustom)

                Button(AppFlavor.text("恢复默认技能", "Restore Default Actions"), role: .destructive) { store.resetToDefaults() }
            } footer: {
                Text(AppFlavor.text("技能快捷键可直接处理选中文本。自定义技能会按你的提示词生成结果。", "Action hotkeys process selected text directly. Custom actions use your prompt to generate a result."))
            }
        }
        .listStyle(.inset)
	        .sheet(item: $editing) { target in
	            ActionEditor(target: target,
                             initialProviderID: Settings.actionLLMProviderID(for: target.def.id) ?? Settings.defaultLLMProvider.id,
	                         onSave: { result, providerID in
	                             if target.isNew {
	                                 store.addCustom(result)
	                             } else {
	                                 store.update(result)
	                             }
                                 Settings.setActionLLMProviderID(providerID == Settings.defaultLLMProvider.id ? nil : providerID,
                                                                 for: result.id)
	                             editing = nil
	                         },
                         onCancel: { editing = nil })
        }
    }

    private func row(_ def: ActionDef) -> some View {
        let isDragging = draggingID == def.id
        let isDropTarget = dropTargetID == def.id && draggingID != nil && draggingID != def.id

        return HStack(spacing: 10) {
            dragHandle(def)
            Toggle("", isOn: Binding(get: { def.enabled }, set: { store.setEnabled(def.id, $0) }))
                .labelsHidden().controlSize(.small)
            Image(systemName: def.icon).frame(width: 22).foregroundStyle(.secondary)
            Text(def.name)
            if def.isBuiltin {
                Text(AppFlavor.text("内置", "Built-in")).font(.caption2)
                    .padding(.horizontal, 5).padding(.vertical, 1)
                    .background(Capsule().fill(Color.primary.opacity(0.08)))
                    .foregroundStyle(.tertiary)
            }
            if def.needsLLM {
                Text(providerLabel(for: def))
                    .font(.caption2)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(Capsule().fill(Color.primary.opacity(0.06)))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
            Spacer()
            HotkeyRecorder(display: Binding(get: { def.hotKeyDisplay ?? AppFlavor.text("未设置", "Not Set") }, set: { _ in })) { code, mods, disp in
                store.setHotKey(def.id, code: Int(code), mods: carbonModifiers(mods), display: disp)
            }
            .frame(width: 122, height: 22)
            .help(AppFlavor.text("设置此技能的全局快捷键", "Set global hotkey for this action"))
            if def.hotKeyDisplay != nil {
                Button {
                    store.setHotKey(def.id, code: nil, mods: nil, display: nil)
                } label: {
                    Image(systemName: "xmark.circle.fill")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.tertiary)
                .help(AppFlavor.text("清除快捷键", "Clear hotkey"))
            }
            Button(AppFlavor.text("编辑", "Edit")) { editing = EditTarget(def: def, isNew: false) }
                .buttonStyle(.link)
            if !def.isBuiltin {
                Button { store.delete(def.id) } label: { Image(systemName: "trash") }
                    .buttonStyle(.plain).foregroundStyle(.secondary).help(AppFlavor.text("删除", "Delete"))
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .background {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(rowFill(isDragging: isDragging, isDropTarget: isDropTarget))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .strokeBorder(rowStroke(isDragging: isDragging, isDropTarget: isDropTarget), lineWidth: isDragging || isDropTarget ? 1 : 0.5)
        }
        .overlay(alignment: .top) {
            if isDropTarget {
                Capsule()
                    .fill(Color.accentColor.opacity(0.55))
                    .frame(height: 2)
                    .padding(.horizontal, 8)
            }
        }
        .shadow(color: isDragging ? Color.black.opacity(0.16) : .clear, radius: 14, x: 0, y: 7)
        .scaleEffect(isDragging ? 1.012 : 1)
        .zIndex(isDragging ? 10 : 0)
        .animation(.easeOut(duration: 0.16), value: draggingID)
        .animation(.easeOut(duration: 0.12), value: dropTargetID)
    }

    @ViewBuilder private func dragHandle(_ def: ActionDef) -> some View {
        if def.id == "read" {
            Image(systemName: "pin.fill")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.tertiary)
                .frame(width: 18)
                .help(AppFlavor.text("朗读固定第一，不参与排序", "Read stays first and cannot be reordered"))
        } else {
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 24, height: 26)
                .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(Color.primary.opacity(0.055)))
                .contentShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                .help(AppFlavor.text("拖动排序", "Drag to reorder"))
                .onDrag {
                    draggingID = def.id
                    return NSItemProvider(object: def.id as NSString)
                } preview: {
                    ActionDragPreview(def: def)
                }
        }
    }

    private func rowFill(isDragging: Bool, isDropTarget: Bool) -> Color {
        if isDragging { return Color(nsColor: .controlBackgroundColor).opacity(0.98) }
        if isDropTarget { return Color.accentColor.opacity(0.08) }
        return Color.primary.opacity(0.025)
    }

    private func rowStroke(isDragging: Bool, isDropTarget: Bool) -> Color {
        if isDragging { return Color.primary.opacity(0.18) }
        if isDropTarget { return Color.accentColor.opacity(0.34) }
        return Color.primary.opacity(0.06)
    }

    private func providerLabel(for def: ActionDef) -> String {
        guard let id = Settings.actionLLMProviderID(for: def.id),
              let provider = Settings.llmServiceProviders.first(where: { $0.id == id }) else {
            return AppFlavor.text("默认模型", "Default")
        }
        return provider.label
    }
}

private struct ActionDropDelegate: DropDelegate {
    let targetID: String
    @Binding var draggingID: String?
    @Binding var dropTargetID: String?
    let store: ActionStore

    func dropEntered(info: DropInfo) {
        guard let draggingID, draggingID != targetID else { return }
        dropTargetID = targetID
        withAnimation(.easeOut(duration: 0.14)) {
            store.move(draggingID, before: targetID)
        }
    }

    func dropExited(info: DropInfo) {
        if dropTargetID == targetID {
            dropTargetID = nil
        }
    }

    func performDrop(info: DropInfo) -> Bool {
        withAnimation(.easeOut(duration: 0.16)) {
            draggingID = nil
            dropTargetID = nil
        }
        return true
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }
}

private struct ActionDragPreview: View {
    let def: ActionDef

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 24, height: 26)
                .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(Color.primary.opacity(0.07)))
            Image(systemName: def.enabled ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(def.enabled ? Color.accentColor : Color.secondary)
            Image(systemName: def.icon)
                .frame(width: 22)
                .foregroundStyle(.secondary)
            Text(def.name)
                .font(.system(size: 13, weight: .medium))
                .lineLimit(1)
            if def.isBuiltin {
                Text(AppFlavor.text("内置", "Built-in"))
                    .font(.caption2)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(Capsule().fill(Color.primary.opacity(0.08)))
                    .foregroundStyle(.tertiary)
            }
            Spacer(minLength: 18)
            Text(def.hotKeyDisplay ?? AppFlavor.text("未设置", "Not Set"))
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .frame(width: 430, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.14), lineWidth: 0.5)
        }
        .shadow(color: Color.black.opacity(0.20), radius: 18, x: 0, y: 10)
    }
}

private struct ActionEditor: View {
    @State var target: ActionsConfigView.EditTarget
    @State private var selectedProviderID: String
    @State private var optimizingPrompt = false
    @State private var optimizeError: String?
    @State private var promptBeforeOptimization: String?
    var onSave: (ActionDef, String) -> Void
    var onCancel: () -> Void

    init(target: ActionsConfigView.EditTarget,
         initialProviderID: String,
         onSave: @escaping (ActionDef, String) -> Void,
         onCancel: @escaping () -> Void) {
        _target = State(initialValue: target)
        _selectedProviderID = State(initialValue: initialProviderID)
        self.onSave = onSave
        self.onCancel = onCancel
    }

    private let icons = [
        "speaker.wave.2.fill", "lightbulb.fill", "globe", "list.bullet.rectangle.fill", "sparkles",
        "text.bubble", "character.book.closed", "book", "quote.bubble", "textformat",
        "brain.head.profile", "graduationcap.fill", "wand.and.stars", "questionmark.circle", "highlighter",
        "scroll", "character.cursor.ibeam", "bubble.left.and.text.bubble.right"
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(target.isNew ? AppFlavor.text("新增自定义技能", "Add Custom Action") : AppFlavor.text("编辑技能", "Edit Action"))
                .font(.headline)

            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(AppFlavor.text("名称", "Name")).font(.caption).foregroundStyle(.secondary)
                    TextField(AppFlavor.text("如：拆解句法", "e.g. Sentence Structure"), text: $target.def.name).frame(width: 160)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(AppFlavor.text("图标", "Icon")).font(.caption).foregroundStyle(.secondary)
                    Picker("", selection: $target.def.icon) {
                        ForEach(icons, id: \.self) { ic in
                            Image(systemName: ic).tag(ic)
                        }
                    }
                    .labelsHidden().frame(width: 80)
                }
                Spacer()
                Image(systemName: target.def.icon).font(.system(size: 22)).foregroundStyle(Color.accentColor)
            }

            HStack(spacing: 10) {
                Text(AppFlavor.text("快捷键", "Hotkey")).font(.caption).foregroundStyle(.secondary)
                Spacer()
                HotkeyRecorder(display: Binding(get: { target.def.hotKeyDisplay ?? AppFlavor.text("未设置", "Not Set") },
                                                set: { target.def.hotKeyDisplay = $0 })) { code, mods, disp in
                    target.def.hotKeyCode = Int(code)
                    target.def.hotKeyMods = carbonModifiers(mods)
                    target.def.hotKeyDisplay = disp
                }
                .frame(width: 146, height: 24)
                if target.def.hotKeyDisplay != nil {
                    Button(AppFlavor.text("清除", "Clear")) {
                        target.def.hotKeyCode = nil
                        target.def.hotKeyMods = nil
                        target.def.hotKeyDisplay = nil
                    }
                }
            }

            if target.def.needsLLM {
                VStack(alignment: .leading, spacing: 4) {
                    Text(AppFlavor.text("模型服务", "Model service")).font(.caption).foregroundStyle(.secondary)
                    Picker("", selection: $selectedProviderID) {
                        Text(AppFlavor.text("跟随默认", "Follow Default")).tag(Settings.defaultLLMProvider.id)
                        ForEach(Settings.enabledLLMServiceProviders) { provider in
                            Text(provider.label).tag(provider.id)
                        }
                    }
                    .labelsHidden()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    Text(AppFlavor.text("不选择时使用默认模型。", "Uses the default model when none is selected."))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(AppFlavor.text("提示词", "Prompt"))
                            .font(.caption).foregroundStyle(.secondary)
                        Spacer()
                        Button {
                            Task { await optimizePrompt() }
                        } label: {
                            if optimizingPrompt {
                                ProgressView().controlSize(.small)
                            } else {
                                Label(AppFlavor.text("AI 优化", "AI Optimize"), systemImage: "wand.and.stars")
                            }
                        }
                        .controlSize(.small)
                        .disabled(optimizingPrompt || target.def.prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .help(AppFlavor.text("用当前 AI 模型优化这个技能提示词", "Optimize this action prompt with the current AI model"))
                        if let previous = promptBeforeOptimization {
                            Button {
                                target.def.prompt = previous
                                promptBeforeOptimization = nil
                            } label: {
                                Image(systemName: "arrow.uturn.backward")
                            }
                            .controlSize(.small)
                            .disabled(optimizingPrompt)
                            .help(AppFlavor.text("撤回上次 AI 优化", "Undo last AI optimization"))
                        }
                    }
                    TextEditor(text: $target.def.prompt)
                        .font(.system(size: 12))
                        .frame(height: 130)
                        .padding(6)
                        .overlay(RoundedRectangle(cornerRadius: 7).stroke(Color.primary.opacity(0.15), lineWidth: 0.5))
                }
            }

            HStack {
                Spacer()
                Button(AppFlavor.text("取消", "Cancel")) { onCancel() }
                Button(target.isNew ? AppFlavor.text("添加", "Add") : AppFlavor.text("保存", "Save")) { onSave(finalDef(), selectedProviderID) }
                    .keyboardShortcut(.defaultAction)
                    .disabled(target.def.name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(20)
        .frame(width: 440)
        .alert(AppFlavor.text("AI 优化失败", "AI Optimization Failed"), isPresented: Binding(get: { optimizeError != nil },
                                              set: { if !$0 { optimizeError = nil } })) {
            Button(AppFlavor.text("好", "OK")) { optimizeError = nil }
        } message: {
            Text(optimizeError ?? "")
        }
    }

    private func finalDef() -> ActionDef {
        var d = target.def
        d.name = d.name.trimmingCharacters(in: .whitespaces)
        return d
    }

    @MainActor
    private func optimizePrompt() async {
        let name = target.def.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let current = target.def.prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !current.isEmpty else { return }
        let provider = Settings.llmProvider(id: selectedProviderID)
        guard !provider.apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            optimizeError = AppFlavor.text("请先在设置里填写 AI 接口 API Key。", "Add your AI API key in Settings first.")
            return
        }

        optimizingPrompt = true
        defer { optimizingPrompt = false }

        do {
            let optimized = try await LLMClient.complete(prompt: Self.promptOptimizerSystemPrompt,
                                                        text: """
                                                        \(AppFlavor.text("技能名称", "Action name"))：\(name.isEmpty ? AppFlavor.text("未命名技能", "Unnamed action") : name)

                                                        \(AppFlavor.text("当前提示词", "Current prompt"))：
                                                        \(current)

                                                        \(AppFlavor.text("请返回一条可直接保存的新提示词。", "Return one new prompt that can be saved directly."))
                                                        """,
                                                        provider: provider)
            let cleaned = cleanOptimizedPrompt(optimized)
            guard !cleaned.isEmpty else {
                optimizeError = AppFlavor.text("模型没有返回可用的提示词。", "The model did not return a usable prompt.")
                return
            }
            if cleaned != current {
                promptBeforeOptimization = current
            }
            target.def.prompt = cleaned
        } catch {
            optimizeError = Self.describe(error)
        }
    }

    private func cleanOptimizedPrompt(_ value: String) -> String {
        var text = value
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        var lines = text.components(separatedBy: "\n")
        if lines.first?.trimmingCharacters(in: .whitespaces).hasPrefix("```") == true {
            lines.removeFirst()
        }
        if lines.last?.trimmingCharacters(in: .whitespaces).hasPrefix("```") == true {
            lines.removeLast()
        }
        text = lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)

        let prefixes = [
            "优化后的提示词：", "优化后提示词：", "新提示词：", "提示词：",
            "Optimized prompt:", "New prompt:", "Prompt:"
        ]
        var didStripPrefix = true
        while didStripPrefix {
            didStripPrefix = false
            for prefix in prefixes where text.lowercased().hasPrefix(prefix.lowercased()) {
                text = String(text.dropFirst(prefix.count)).trimmingCharacters(in: .whitespacesAndNewlines)
                didStripPrefix = true
            }
        }

        for pair in [("“", "”"), ("\"", "\""), ("'", "'"), ("「", "」")] where text.hasPrefix(pair.0) && text.hasSuffix(pair.1) {
            text.removeFirst(pair.0.count)
            text.removeLast(pair.1.count)
            text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        text = text.replacingOccurrences(of: #"(?m)^\s*[-*•]\s*"#,
                                         with: "",
                                         options: .regularExpression)
        text = text.replacingOccurrences(of: #"(?m)^\s*\d+[\.)、]\s*"#,
                                         with: "",
                                         options: .regularExpression)
        return text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static var promptOptimizerSystemPrompt: String {
        AppFlavor.text(
            """
            你是 Dob 的技能提示词架构师。Dob 会把这条提示词作为系统提示词，用来处理用户当前选中的文本；有时还会附带来源信息或全文上下文。

            请把用户现有提示词重写成一条可直接保存的新版提示词。必须保留原任务，不新增新任务；明确处理对象是「选中内容」；说明上下文只用于理解选中内容，除非原任务要求处理全文；写清输出形态、风格、边界和禁止项。结果要适合语音朗读：要求自然纯文本，不要 Markdown、标题、表格、列表符号、客套话、思考过程或解释优化过程。

            输出一段完整提示词，通常 2 到 5 句。只输出提示词本身，不要标题、引号、说明或代码围栏。
            """,
            """
            You are the Dob action prompt architect. Dob will save this as a system prompt for processing the user's currently selected text. Source metadata or full-text context may also be attached.

            Rewrite the existing prompt into one directly saveable prompt. Preserve the original task and do not add a new task. Make clear that the object is the selected text. State that context is only reference material for understanding the selection unless the original task asks to process the whole document. Specify the output shape, style, boundaries, and forbidden behavior. The result should be suitable for speech: natural plain text, no Markdown, headings, tables, bullet symbols, pleasantries, hidden reasoning, or explanation of the optimization.

            Output one complete prompt, usually two to five sentences. Return only the prompt itself: no title, quotes, explanation, or code fence.
            """
        )
    }

    private static func describe(_ error: Error) -> String {
        if let e = error as? LLMError {
            switch e {
            case .noKey: return AppFlavor.text("请先在设置里填写 AI 接口 API Key。", "Add your AI API key in Settings first.")
            case .badURL: return AppFlavor.text("AI 接口地址无效。", "The AI endpoint URL is invalid.")
            case .http(let code, let msg): return AppFlavor.text("AI 请求失败：HTTP \(code) \(msg.prefix(120))", "AI request failed: HTTP \(code) \(msg.prefix(120))")
            case .badResponse: return AppFlavor.text("AI 响应解析失败。", "Could not parse the AI response.")
            }
        }
        return error.localizedDescription
    }
}
