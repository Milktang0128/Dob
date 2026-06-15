import SwiftUI

struct SettingsView: View {
    @AppStorage("autoPop") private var autoPop = true
    @AppStorage("autoPopCopyFallback") private var autoPopCopyFallback = true
    @AppStorage("hkDisplay") private var hkDisplay = "⌥⌘R"
    @AppStorage("ocrHkDisplay") private var ocrHkDisplay = "⌃⇧O"
    @AppStorage("silentOcrHkDisplay") private var silentOcrHkDisplay = "⌃⇧C"
    @AppStorage("inputHkDisplay") private var inputHkDisplay = "⌃⇧I"
    @AppStorage("ocrAutoRunLastAction") private var ocrAutoRunLastAction = true

    @AppStorage("useFullContext") private var useFullContext = true
    @AppStorage("autoSpeakAI") private var autoSpeakAI = true
    @AppStorage("autoArchive") private var autoArchive = false
    @AppStorage("historyEnabled") private var historyEnabled = true
    @AppStorage("archiveFolder") private var archiveFolder = ""

    @AppStorage("deepseekKey") private var llmAPIKey = ""
    @AppStorage("deepseekModel") private var llmModel = Settings.recommendedLLMModel
    @AppStorage("compareProvider1Enabled") private var compareProvider1Enabled = false
    @AppStorage("compareProvider2Enabled") private var compareProvider2Enabled = false
    @AppStorage("ttsEngine") private var ttsEngine = AppFlavor.text("volcano", "local")
    @AppStorage("volcAppId") private var volcAppId = ""
    @AppStorage("volcToken") private var volcToken = ""

    private var compareCount: Int {
        (compareProvider1Enabled ? 1 : 0) + (compareProvider2Enabled ? 1 : 0)
    }

    private var speechStatus: String {
        switch ttsEngine {
        case "local":
            return AppFlavor.text("本地语音", "Local Speech")
        case "volcano":
            return Settings.volcConfigured ? AppFlavor.text("火山引擎", "Volcengine") : AppFlavor.text("火山未配置，回退本地", "Volcengine missing, falls back")
        case "microsoft":
            return Settings.microsoftTTSConfigured ? AppFlavor.text("Microsoft 语音", "Microsoft Speech") : AppFlavor.text("Microsoft 未配置，回退本地", "Microsoft missing, falls back")
        case "google":
            return Settings.googleTTSConfigured ? AppFlavor.text("Google 语音", "Google Speech") : AppFlavor.text("Google 未配置，回退本地", "Google missing, falls back")
        case "tencent":
            return Settings.tencentTTSConfigured ? AppFlavor.text("腾讯云语音", "Tencent TTS") : AppFlavor.text("腾讯云未配置，回退本地", "Tencent missing, falls back")
        default:
            return AppFlavor.text("本地语音", "Local Speech")
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                quickLinks
                captureSection
                fallbackSection
                behaviorSection
                archiveSection
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(width: 540)
        .frame(minHeight: 660)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(AppFlavor.text("设置", "Settings"))
                .font(.system(size: 24, weight: .semibold))
            Text(AppFlavor.text("这里管理使用偏好和工作流。模型、OCR、语音等供应商配置集中放在服务管理中。",
                                "Manage preferences and workflows here. Model, OCR, and speech providers live in Services."))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var quickLinks: some View {
        SettingsSection(title: AppFlavor.text("核心入口", "Core Entrypoints"),
                        subtitle: AppFlavor.text("高频配置尽量保持在单独窗口，避免一个设置页承担所有事情。",
                                                 "High-impact configuration stays in dedicated windows so this page remains focused.")) {
            HStack(spacing: 10) {
                SettingsNavButton(title: AppFlavor.text("服务管理", "Services"),
                                  subtitle: serviceSummary,
                                  icon: "server.rack") {
                    NotificationCenter.default.post(name: .gebwOpenServices, object: nil)
                }
                SettingsNavButton(title: AppFlavor.text("编辑技能", "Edit Actions"),
                                  subtitle: AppFlavor.text("排序、快捷键、提示词", "Order, hotkeys, prompts"),
                                  icon: "slider.horizontal.3") {
                    NotificationCenter.default.post(name: .gebwOpenActions, object: nil)
                }
            }
        }
    }

    private var captureSection: some View {
        SettingsSection(title: AppFlavor.text("触发与自动弹出", "Trigger and Auto-Pop"),
                        subtitle: AppFlavor.text("决定工具条何时出现，以及取词失败时是否启用兼容方案。",
                                                 "Controls when the panel appears and whether compatibility capture is allowed.")) {
            SettingToggle(title: AppFlavor.text("划词后自动弹出", "Show after selection"),
                          subtitle: AppFlavor.text("选中文本后自动显示工具条。", "Show the panel automatically after selecting text."),
                          isOn: $autoPop) {
                NotificationCenter.default.post(name: .gebwConfigChanged, object: nil)
            }
            SettingToggle(title: AppFlavor.text("兼容模式：临时复制取词", "Compatibility mode: temporary copy"),
                          subtitle: AppFlavor.text("用于微信内置浏览器等不暴露标准选区的界面。会尽量恢复原剪贴板。",
                                                   "Helps in WebViews that do not expose standard selection. The clipboard is restored when possible."),
                          isOn: $autoPopCopyFallback)
                .disabled(!autoPop)
            HotkeySetting(title: AppFlavor.text("弹出工具条", "Show panel"),
                          subtitle: AppFlavor.text("手动处理当前选中文本。", "Manually process the current selection."),
                          display: $hkDisplay) { code, mods, disp in
                Settings.hotKeyCode = Int(code)
                Settings.hotKeyMods = carbonModifiers(mods)
                Settings.hotKeyDisplay = disp
                hkDisplay = disp
                NotificationCenter.default.post(name: .gebwConfigChanged, object: nil)
            }
        }
    }

    private var fallbackSection: some View {
        SettingsSection(title: AppFlavor.text("输入与 OCR 兜底", "Input and OCR Fallbacks"),
                        subtitle: AppFlavor.text("处理无法直接取词、无法复制、或想手动输入内容的场景。",
                                                 "For apps where direct capture fails, copying is blocked, or you want to type manually.")) {
            HotkeySetting(title: AppFlavor.text("输入面板", "Input panel"),
                          subtitle: AppFlavor.text("打开工具条和文本框，可粘贴或输入任意内容再处理。",
                                                   "Open the toolbar with a text box, then paste or type any text."),
                          display: $inputHkDisplay) { code, mods, disp in
                Settings.inputHotKeyCode = Int(code)
                Settings.inputHotKeyMods = carbonModifiers(mods)
                Settings.inputHotKeyDisplay = disp
                inputHkDisplay = disp
                NotificationCenter.default.post(name: .gebwConfigChanged, object: nil)
            }
            HotkeySetting(title: AppFlavor.text("屏幕选框 OCR", "Screen selection OCR"),
                          subtitle: AppFlavor.text("框选屏幕区域识别文字，识别后打开工具条。",
                                                   "Select a screen region for OCR, then open the panel."),
                          display: $ocrHkDisplay) { code, mods, disp in
                Settings.ocrHotKeyCode = Int(code)
                Settings.ocrHotKeyMods = carbonModifiers(mods)
                Settings.ocrHotKeyDisplay = disp
                ocrHkDisplay = disp
                NotificationCenter.default.post(name: .gebwConfigChanged, object: nil)
            }
            SettingToggle(title: AppFlavor.text("OCR 后执行最近一次技能", "Run last action after OCR"),
                          subtitle: AppFlavor.text("适合连续 OCR 翻译、解释或朗读。", "Useful for repeated OCR translate, explain, or read flows."),
                          isOn: $ocrAutoRunLastAction)
            HotkeySetting(title: AppFlavor.text("静默 OCR 复制", "Silent OCR copy"),
                          subtitle: AppFlavor.text("框选后直接复制识别结果，不显示工具条。", "Copy recognized text directly without showing the panel."),
                          display: $silentOcrHkDisplay) { code, mods, disp in
                Settings.silentOCRHotKeyCode = Int(code)
                Settings.silentOCRHotKeyMods = carbonModifiers(mods)
                Settings.silentOCRHotKeyDisplay = disp
                silentOcrHkDisplay = disp
                NotificationCenter.default.post(name: .gebwConfigChanged, object: nil)
            }
        }
    }

    private var behaviorSection: some View {
        SettingsSection(title: AppFlavor.text("结果行为", "Result Behavior"),
                        subtitle: AppFlavor.text("控制 AI 技能如何使用上下文，以及生成后是否自动朗读。",
                                                 "Controls context use and whether AI results are spoken automatically.")) {
            SettingToggle(title: AppFlavor.text("默认使用全文上下文", "Use full-text context by default"),
                          subtitle: AppFlavor.text("能拿到全文时，把选中内容和上下文一起交给模型；拿不到时自动回退。",
                                                   "When available, send both selection and surrounding context to the model; otherwise fall back."),
                          isOn: $useFullContext)
            SettingToggle(title: AppFlavor.text("AI 技能完成后自动朗读", "Auto-read AI results"),
                          subtitle: AppFlavor.text("关闭后，解释、翻译、提炼等结果默认只显示不朗读；朗读技能不受影响。",
                                                   "When off, Explain, Translate, and similar results show without speaking. Read is unaffected."),
                          isOn: $autoSpeakAI)
        }
    }

    private var archiveSection: some View {
        SettingsSection(title: AppFlavor.text("留档与历史", "Archive and History"),
                        subtitle: AppFlavor.text("主动留档适合长期复习；静默历史适合临时回看。",
                                                 "Archive is for long-term review; silent history is for lightweight lookup.")) {
            SettingToggle(title: AppFlavor.text("自动留档每次动作", "Auto-save every action"),
                          subtitle: AppFlavor.text("默认关闭。通常点击结果卡上的留档更可控。", "Off by default. Saving from the result card is usually more deliberate."),
                          isOn: $autoArchive)
            SettingToggle(title: AppFlavor.text("静默历史记录最近 500 条", "Silent history, latest 500"),
                          subtitle: AppFlavor.text("保存原文、结果、动作和来源，不保存全文上下文，也不参与今日回响。",
                                                   "Stores source text, result, action, and app only. No full context and no Review scheduling."),
                          isOn: $historyEnabled)
            Divider()
            VStack(alignment: .leading, spacing: 8) {
                Text(AppFlavor.text("Markdown 留存位置", "Markdown archive location"))
                    .font(.system(size: 13, weight: .semibold))
                HStack {
                    Text(archiveFolder.isEmpty ? AppFlavor.text("默认：应用支持目录", "Default: Application Support") : archiveFolder)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer()
                    Button(AppFlavor.text("选择…", "Choose…")) { pickFolder() }
                }
                HStack {
                    Button(AppFlavor.text("在访达中显示", "Show in Finder")) {
                        NSWorkspace.shared.open(ArchiveStore.shared.revealFolder)
                    }
                    if !archiveFolder.isEmpty {
                        Button(AppFlavor.text("用默认", "Use Default")) {
                            archiveFolder = ""
                            ArchiveStore.shared.relocate()
                        }
                    }
                }
            }
        }
    }

    private var serviceSummary: String {
        let ai = llmAPIKey.isEmpty ? AppFlavor.text("AI 未配置", "AI missing") : AppFlavor.text("AI 已配置", "AI ready")
        let compare = compareCount == 0 ? AppFlavor.text("无比较模型", "No compare") : AppFlavor.text("\(compareCount) 个比较模型", "\(compareCount) compare")
        return "\(ai) · \(compare) · \(speechStatus)"
    }

    private func pickFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = AppFlavor.text("选择", "Choose")
        if panel.runModal() == .OK, let url = panel.url {
            archiveFolder = url.path
            ArchiveStore.shared.relocate()
        }
    }
}

private struct SettingsSection<Content: View>: View {
    let title: String
    let subtitle: String
    let content: Content

    init(title: String, subtitle: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.subtitle = subtitle
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            VStack(alignment: .leading, spacing: 12) {
                content
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Color.primary.opacity(0.035)))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.06), lineWidth: 0.5)
        }
    }
}

private struct SettingsNavButton: View {
    let title: String
    let subtitle: String
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 26)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 13, weight: .semibold))
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(10)
            .frame(maxWidth: .infinity, minHeight: 66, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Color.primary.opacity(0.04)))
        }
        .buttonStyle(.plain)
    }
}

private struct SettingToggle: View {
    let title: String
    let subtitle: String
    @Binding var isOn: Bool
    var onChange: (() -> Void)?

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .onChange(of: isOn) { _, _ in onChange?() }
        }
    }
}

private struct HotkeySetting: View {
    let title: String
    let subtitle: String
    @Binding var display: String
    var onRecord: (UInt16, NSEvent.ModifierFlags, String) -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            HotkeyRecorder(display: $display, onRecord: onRecord)
                .frame(width: 176, height: 22)
        }
    }
}
