import SwiftUI
import AVFoundation

struct SettingsView: View {
    private static let volcanoVoiceListURL = URL(string: "https://www.volcengine.com/docs/6561/1257544?lang=zh")!

    @AppStorage("autoPop") private var autoPop = true
    @AppStorage("hkDisplay") private var hkDisplay = "⌥⌘R"
    @AppStorage("ocrHkDisplay") private var ocrHkDisplay = "⌃⇧O"
    @AppStorage("autoArchive") private var autoArchive = false
    @AppStorage("archiveFolder") private var archiveFolder = ""

    @AppStorage("deepseekKey") private var deepseekKey = ""
    @AppStorage("deepseekModel") private var deepseekModel = "deepseek-v4-flash"
    @AppStorage("useFullContext") private var useFullContext = true

    @AppStorage("ttsEngine") private var ttsEngine = "volcano"
    @AppStorage("volcAppId") private var volcAppId = ""
    @AppStorage("volcToken") private var volcToken = ""
    @AppStorage("volcCluster") private var volcCluster = "volcano_tts"
    @AppStorage("volcVoice") private var volcVoice = "zh_female_cancan_uranus_bigtts"
    @AppStorage("volcSpeed") private var volcSpeed = 1.0
    @AppStorage("rate") private var rate = Double(AVSpeechUtteranceDefaultSpeechRate)

    private var volcUnconfigured: Bool {
        ttsEngine == "volcano" && (volcAppId.isEmpty || volcToken.isEmpty)
    }

    var body: some View {
        Form {
            Section("触发方式") {
                Toggle("划词后自动弹出（推荐）", isOn: $autoPop)
                    .onChange(of: autoPop) { _, _ in
                        NotificationCenter.default.post(name: .gebwConfigChanged, object: nil)
                    }
                HStack {
                    Text("弹出面板快捷键")
                    Spacer()
                    HotkeyRecorder(display: $hkDisplay) { code, mods, disp in
                        Settings.hotKeyCode = Int(code)
                        Settings.hotKeyMods = carbonModifiers(mods)
                        Settings.hotKeyDisplay = disp
                        hkDisplay = disp
                        NotificationCenter.default.post(name: .gebwConfigChanged, object: nil)
                    }
                    .frame(width: 176, height: 22)
                }
            }

            Section("高级取词") {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("屏幕选框 OCR")
                        Text("无法直接取词时，按快捷键框选屏幕区域，识别出的文字会进入同一个处理面板。")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    HotkeyRecorder(display: $ocrHkDisplay) { code, mods, disp in
                        Settings.ocrHotKeyCode = Int(code)
                        Settings.ocrHotKeyMods = carbonModifiers(mods)
                        Settings.ocrHotKeyDisplay = disp
                        ocrHkDisplay = disp
                        NotificationCenter.default.post(name: .gebwConfigChanged, object: nil)
                    }
                    .frame(width: 176, height: 22)
                }
            }

            Section("留档") {
                Toggle("自动留档（每次动作都保存）", isOn: $autoArchive)
                Text("默认关闭——结果卡上点「留档」才保存。")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Section("留存位置（可读 Markdown）") {
                HStack {
                    Text(archiveFolder.isEmpty ? "默认（应用支持目录）" : archiveFolder)
                        .font(.system(size: 12)).foregroundStyle(.secondary)
                        .lineLimit(1).truncationMode(.middle)
                    Spacer()
                    Button("选择…") { pickFolder() }
                }
                HStack {
                    Button("在访达中显示") { NSWorkspace.shared.open(ArchiveStore.shared.revealFolder) }
                    if !archiveFolder.isEmpty {
                        Button("用默认") { archiveFolder = ""; ArchiveStore.shared.relocate() }
                    }
                }
                Text("可读的档案 Markdown 会写到这里——放进 Obsidian 库即可随时查看、供后续 agent 管理。")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Section("技能") {
                HStack {
                    Text("排序、设置快捷键、禁用、或新增最多 4 个自定义技能。技能快捷键会直接处理当前选中文本。")
                        .font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Button("编辑技能…") {
                        NotificationCenter.default.post(name: .gebwOpenActions, object: nil)
                    }
                }
                Text("朗读固定在第一位；浮窗显示前 5 个启用技能，其余收在更多菜单。")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Section("解释 / 翻译模型（DeepSeek）") {
                Toggle("默认使用全文上下文", isOn: $useFullContext)
                Text("开启后，解释、翻译、提炼、背景和自定义技能会尽量读取当前文本控件或页面的可访问上下文，只把它作为选中内容的参考；拿不到时自动回退。")
                    .font(.caption).foregroundStyle(.secondary)
                SecureField("DeepSeek API Key（sk-…）", text: $deepseekKey)
                TextField("模型", text: $deepseekModel)
                Text("默认 deepseek-v4-flash（快）；也可填 deepseek-chat / deepseek-reasoner。")
                    .font(.caption).foregroundStyle(.secondary)
                Link("前往 DeepSeek 获取 API Key ↗", destination: URL(string: "https://platform.deepseek.com/api_keys")!)
                    .font(.caption)
            }

            Section("语音合成") {
                Picker("引擎", selection: $ttsEngine) {
                    Text("火山引擎 · 推荐").tag("volcano")
                    Text("本地（macOS）").tag("local")
                }
                .pickerStyle(.segmented)

                if ttsEngine == "volcano" {
                    Link("没有账号？前往火山引擎语音控制台开通、获取 App ID / Token ↗",
                         destination: URL(string: "https://console.volcengine.com/speech/app")!)
                        .font(.caption)
                    SecureField("App ID", text: $volcAppId)
                    SecureField("Access Token", text: $volcToken)
                    Picker("音色", selection: $volcVoice) {
                        ForEach(VolcanoVoices.all) { voice in
                            Text(voice.name).tag(voice.id)
                        }
                        if !VolcanoVoices.all.contains(where: { $0.id == volcVoice }) {
                            Text("自定义（\(volcVoice)）").tag(volcVoice)
                        }
                    }
                    Link("查看官方完整音色列表，复制 voice_type 填到下方 ↗",
                         destination: Self.volcanoVoiceListURL)
                        .font(.caption)
                    TextField("自定义 voice_type（可选）", text: $volcVoice)
                    TextField("Cluster", text: $volcCluster)
                    HStack {
                        Text("语速")
                        Slider(value: $volcSpeed, in: 0.5...2.0)
                        Text(String(format: "%.1fx", volcSpeed)).font(.caption).foregroundStyle(.secondary)
                    }
                    if volcUnconfigured {
                        Text("未填 App ID / Access Token，暂时回退本地语音。")
                            .font(.caption).foregroundStyle(.orange)
                    }
                    Text("音色需在火山控制台开通；下拉只列常用大模型音色，完整列表以官方文档为准。")
                        .font(.caption).foregroundStyle(.secondary)
                } else {
                    HStack {
                        Text("本地语速")
                        Slider(value: $rate, in: 0.3...0.7)
                    }
                }

                Button("试听") {
                    Settings.speechRate = Float(rate)
                    Speaker.shared.speak("过耳不忘，这是当前语音的试听效果。")
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 470, height: 620)
    }

    private func pickFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "选择"
        if panel.runModal() == .OK, let url = panel.url {
            archiveFolder = url.path
            ArchiveStore.shared.relocate()
        }
    }
}
