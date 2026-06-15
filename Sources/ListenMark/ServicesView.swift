import SwiftUI
import AVFoundation

struct ServicesView: View {
    private static var volcanoVoiceListURL: URL {
        URL(string: AppFlavor.text("https://www.volcengine.com/docs/6561/1257544?lang=zh",
                                   "https://www.volcengine.com/docs/6561/1257544"))!
    }
    private static let microsoftSpeechDocsURL = URL(string: "https://learn.microsoft.com/azure/ai-services/speech-service/language-support")!
    private static let googleSpeechDocsURL = URL(string: "https://cloud.google.com/text-to-speech/docs/list-voices-and-types")!
    private static let tencentSpeechDocsURL = URL(string: "https://cloud.tencent.com/document/product/1073/92668")!

    private enum Category: String, CaseIterable, Identifiable, Hashable {
        case text
        case recognition
        case speech

        var id: String { rawValue }

        var title: String {
            switch self {
            case .text: return AppFlavor.text("文本处理", "Text")
            case .recognition: return AppFlavor.text("文本识别", "OCR")
            case .speech: return AppFlavor.text("语音合成", "Speech")
            }
        }

        var icon: String {
            switch self {
            case .text: return "sparkles"
            case .recognition: return "viewfinder"
            case .speech: return "speaker.wave.2.fill"
            }
        }
    }

    private enum Selection: Hashable {
        case defaultModel
        case llmProvider(String)
        case systemOCR
        case localSpeech
        case volcanoSpeech
        case microsoftSpeech
        case googleSpeech
        case tencentSpeech
    }

    private struct ServiceTestResult: Equatable {
        var succeeded: Bool
        var message: String
    }

    @State private var category: Category = .text
    @State private var selection: Selection = .defaultModel
    @State private var llmProviders: [LLMServiceProvider] = Settings.llmServiceProviders
    @State private var testingServices = Set<String>()
    @State private var serviceTestResults: [String: ServiceTestResult] = [:]

    @AppStorage("llmBaseURL") private var llmBaseURL = Settings.recommendedLLMBaseURL
    @AppStorage("deepseekKey") private var llmAPIKey = ""
    @AppStorage("deepseekModel") private var llmModel = Settings.recommendedLLMModel

    @AppStorage("ocrAutoRunLastAction") private var ocrAutoRunLastAction = true
    @AppStorage("ocrHkDisplay") private var ocrHkDisplay = "⌃⇧O"
    @AppStorage("silentOcrHkDisplay") private var silentOcrHkDisplay = "⌃⇧C"

    @AppStorage("ttsEngine") private var ttsEngine = AppFlavor.text("volcano", "local")
    @AppStorage("volcAppId") private var volcAppId = ""
    @AppStorage("volcToken") private var volcToken = ""
    @AppStorage("volcCluster") private var volcCluster = "volcano_tts"
    @AppStorage("volcVoice") private var volcVoice = AppFlavor.text("zh_female_cancan_uranus_bigtts", "en_female_dacey_uranus_bigtts")
    @AppStorage("volcSpeed") private var volcSpeed = 1.0
    @AppStorage("microsoftTTSKey") private var microsoftTTSKey = ""
    @AppStorage("microsoftTTSRegion") private var microsoftTTSRegion = "eastasia"
    @AppStorage("microsoftTTSVoice") private var microsoftTTSVoice = "zh-CN-XiaoxiaoNeural"
    @AppStorage("googleTTSKey") private var googleTTSKey = ""
    @AppStorage("googleTTSVoice") private var googleTTSVoice = "cmn-CN-Standard-A"
    @AppStorage("googleTTSSpeed") private var googleTTSSpeed = 1.0
    @AppStorage("tencentTTSSecretId") private var tencentTTSSecretId = ""
    @AppStorage("tencentTTSSecretKey") private var tencentTTSSecretKey = ""
    @AppStorage("tencentTTSHost") private var tencentTTSHost = AppFlavor.text("tts.tencentcloudapi.com", "tts.intl.tencentcloudapi.com")
    @AppStorage("tencentTTSRegion") private var tencentTTSRegion = "ap-guangzhou"
    @AppStorage("tencentTTSVoice") private var tencentTTSVoice = AppFlavor.text("1001", "1050")
    @AppStorage("tencentTTSSpeed") private var tencentTTSSpeed = 0.0
    @AppStorage("rate") private var rate = Double(AVSpeechUtteranceDefaultSpeechRate)

    private var compareCount: Int {
        llmProviders.filter { $0.enabled && $0.compareEnabled }.count
    }

    private var volcanoConfigured: Bool {
        !volcAppId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !volcToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var microsoftConfigured: Bool {
        !microsoftTTSKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !microsoftTTSRegion.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !microsoftTTSVoice.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var googleConfigured: Bool {
        !googleTTSKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !googleTTSVoice.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var tencentConfigured: Bool {
        !tencentTTSSecretId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !tencentTTSSecretKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !tencentTTSHost.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !tencentTTSRegion.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            categoryPicker
            Divider()
            HStack(spacing: 0) {
                serviceList
                    .frame(width: 286)
                Divider()
                detail
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(minWidth: 860, minHeight: 600)
        .onAppear {
            llmProviders = Settings.llmServiceProviders
        }
        .onChange(of: category) { _, newValue in
            selection = defaultSelection(for: newValue)
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(AppFlavor.text("服务管理", "Services"))
                    .font(.system(size: 24, weight: .semibold))
                Text(AppFlavor.text("添加模型、OCR 和语音服务，用于技能、比较和朗读。",
                                    "Add model, OCR, and speech services for actions, compare, and reading."))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                NotificationCenter.default.post(name: .gebwOpenSettings, object: nil)
            } label: {
                Label(AppFlavor.text("偏好设置", "Preferences"), systemImage: "slider.horizontal.3")
            }
        }
        .padding(.horizontal, 22)
        .padding(.top, 18)
        .padding(.bottom, 14)
    }

    private var categoryPicker: some View {
        Picker("", selection: $category) {
            ForEach(Category.allCases) { item in
                Label(item.title, systemImage: item.icon).tag(item)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .padding(.horizontal, 22)
        .padding(.bottom, 16)
    }

    private var serviceList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                switch category {
	                case .text:
	                    row(title: AppFlavor.text("默认模型", "Default Model"),
	                        subtitle: llmModel.isEmpty ? Settings.recommendedLLMModel : llmModel,
	                        icon: "sparkles",
	                        badge: llmAPIKey.isEmpty ? AppFlavor.text("未配置", "Missing Key") : AppFlavor.text("启用", "Enabled"),
	                        selected: selection == .defaultModel) {
	                        selection = .defaultModel
	                    }
                        ForEach(llmProviders) { provider in
                            row(title: provider.label,
                                subtitle: provider.model.isEmpty ? AppFlavor.text("未填写模型名", "Model is missing") : provider.model,
                                icon: "rectangle.2.swap",
                                badge: provider.compareEnabled ? AppFlavor.text("比较", "Compare") : providerStatus(provider),
                                enabled: compareBinding(for: provider.id),
                                selected: selection == .llmProvider(provider.id)) {
                                selection = .llmProvider(provider.id)
                            }
                        }
                        HStack(spacing: 8) {
                            Button {
                                addLLMProvider()
                            } label: {
                                Label(AppFlavor.text("新增服务", "Add Service"), systemImage: "plus")
                            }
                            Button {
                                deleteSelectedLLMProvider()
                            } label: {
                                Label(AppFlavor.text("删除", "Delete"), systemImage: "minus")
                            }
                            .disabled(selectedLLMProviderID == nil)
                        }
                        .controlSize(.small)
                        .padding(.top, 4)
	                case .recognition:
                    row(title: AppFlavor.text("系统 OCR", "System OCR"),
                        subtitle: AppFlavor.text("Apple Vision，本地识别", "Apple Vision, local"),
                        icon: "viewfinder",
                        badge: AppFlavor.text("内置", "Built-in"),
                        selected: selection == .systemOCR) {
                        selection = .systemOCR
                    }
                case .speech:
                    row(title: AppFlavor.text("macOS 本地语音", "macOS Speech"),
                        subtitle: AppFlavor.text("离线可用，质量取决于系统声音", "Offline, uses system voices"),
                        icon: "macwindow",
                        badge: ttsEngine == "local" ? AppFlavor.text("正在使用", "Active") : AppFlavor.text("备用", "Fallback"),
                        selected: selection == .localSpeech) {
                        selection = .localSpeech
                    }
                    row(title: AppFlavor.text("火山引擎 TTS", "Volcengine TTS"),
                        subtitle: volcVoice,
                        icon: "waveform",
                        badge: speechBadge(engine: "volcano", configured: volcanoConfigured),
                        recommended: true,
                        selected: selection == .volcanoSpeech) {
                        selection = .volcanoSpeech
                    }
                    row(title: AppFlavor.text("Microsoft 语音合成", "Microsoft Speech"),
                        subtitle: microsoftTTSVoice,
                        icon: "square.grid.2x2",
                        badge: speechBadge(engine: "microsoft", configured: microsoftConfigured),
                        selected: selection == .microsoftSpeech) {
                        selection = .microsoftSpeech
                    }
                    row(title: AppFlavor.text("Google 语音合成", "Google Text-to-Speech"),
                        subtitle: googleTTSVoice,
                        icon: "g.circle",
                        badge: speechBadge(engine: "google", configured: googleConfigured),
                        selected: selection == .googleSpeech) {
                        selection = .googleSpeech
                    }
                    row(title: AppFlavor.text("腾讯云语音合成", "Tencent Cloud TTS"),
                        subtitle: tencentTTSVoice,
                        icon: "cloud",
                        badge: speechBadge(engine: "tencent", configured: tencentConfigured),
                        selected: selection == .tencentSpeech) {
                        selection = .tencentSpeech
                    }
                }
            }
            .padding(16)
        }
        .background(.bar)
    }

    @ViewBuilder
    private var detail: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
	                switch selection {
	                case .defaultModel:
	                    defaultModelDetail
                    case .llmProvider(let id):
                        llmProviderDetail(id: id)
	                case .systemOCR:
                    ocrDetail
                case .localSpeech:
                    localSpeechDetail
                case .volcanoSpeech:
                    volcanoSpeechDetail
                case .microsoftSpeech:
                    microsoftSpeechDetail
                case .googleSpeech:
                    googleSpeechDetail
                case .tencentSpeech:
                    tencentSpeechDetail
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var defaultModelDetail: some View {
        VStack(alignment: .leading, spacing: 18) {
            detailHeader(title: AppFlavor.text("默认模型", "Default Model"),
                         subtitle: AppFlavor.text("解释、翻译、提炼、自定义技能和提示词优化会优先使用它。",
                                                  "Explain, Translate, Summarize, custom actions, and prompt optimization use this first."),
                         icon: "sparkles",
                         status: llmAPIKey.isEmpty ? AppFlavor.text("未配置", "Missing Key") : AppFlavor.text("已配置", "Configured"))
            presetGrid { preset in
                llmBaseURL = preset.baseURL
                llmModel = preset.model
            }
            serviceFields {
                TextField(AppFlavor.text("Base URL，例如 https://api.deepseek.com 或 https://api.openai.com/v1",
                                         "Base URL, e.g. https://api.deepseek.com or https://api.openai.com/v1"),
                          text: $llmBaseURL)
                SecureField(AppFlavor.text("API Key（Bearer Token）", "API Key (Bearer token)"), text: $llmAPIKey)
                TextField(AppFlavor.text("模型名", "Model"), text: $llmModel)
            }
            connectionTestRow(key: "llm-default",
                              title: AppFlavor.text("检测连接", "Test Connection"),
                              disabled: !isLLMConfigReady(baseURL: llmBaseURL, apiKey: llmAPIKey, model: llmModel)) {
                testLLMConnection(
                    key: "llm-default",
                    provider: LLMProviderConfig(id: "default-test",
                                                label: AppFlavor.text("默认模型", "Default Model"),
                                                baseURL: llmBaseURL,
                                                apiKey: llmAPIKey,
                                                model: llmModel)
                )
            }
            HStack {
                Link(AppFlavor.text("前往 DeepSeek 获取 API Key ↗", "Get a DeepSeek API Key ↗"),
                     destination: URL(string: "https://platform.deepseek.com/api_keys")!)
                    .font(.caption)
                Spacer()
                Button(AppFlavor.text("恢复 DeepSeek 推荐", "Use DeepSeek Defaults")) {
                    llmBaseURL = Settings.recommendedLLMBaseURL
                    llmModel = Settings.recommendedLLMModel
                }
            }
            helperText(AppFlavor.text("也可以填写任何 OpenAI Chat Completions 兼容接口；完整 /chat/completions 地址可直接使用。",
                                      "Any OpenAI Chat Completions-compatible endpoint works; a full /chat/completions URL can be used as-is."))
        }
    }

    @ViewBuilder private func llmProviderDetail(id: String) -> some View {
        if let provider = llmProviders.first(where: { $0.id == id }) {
            VStack(alignment: .leading, spacing: 18) {
                detailHeader(title: provider.label.isEmpty ? AppFlavor.text("未命名服务", "Unnamed Service") : provider.label,
                             subtitle: AppFlavor.text("可指定给某个技能，也可加入比较。",
                                                      "Use it for specific actions or model comparison."),
                             icon: "rectangle.2.swap",
                             status: providerStatus(provider))
                presetGrid { preset in
                    updateLLMProvider(id) {
                        $0.label = preset.name
                        $0.baseURL = preset.baseURL
                        $0.model = preset.model
                        $0.presetID = preset.id
                        $0.enabled = true
                    }
                }
                VStack(alignment: .leading, spacing: 10) {
                    Toggle(AppFlavor.text("启用此服务", "Enable this service"), isOn: providerBoolBinding(id: id, keyPath: \.enabled))
                        .toggleStyle(.switch)
                    Toggle(AppFlavor.text("参与比较", "Use for Compare"), isOn: providerBoolBinding(id: id, keyPath: \.compareEnabled))
                        .toggleStyle(.switch)
                        .disabled(!provider.enabled)
                    helperText(AppFlavor.text("比较时最多同时显示三个模型结果。",
                                              "Compare can show up to three model results at once."))
                }
                .padding(14)
                .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Color.primary.opacity(0.035)))
                serviceFields {
                    TextField(AppFlavor.text("显示名称", "Display name"), text: providerStringBinding(id: id, keyPath: \.label))
                    TextField(AppFlavor.text("Base URL", "Base URL"), text: providerStringBinding(id: id, keyPath: \.baseURL))
                    SecureField(AppFlavor.text("API Key（Bearer Token）", "API Key (Bearer token)"), text: providerStringBinding(id: id, keyPath: \.apiKey))
                    TextField(AppFlavor.text("模型名", "Model"), text: providerStringBinding(id: id, keyPath: \.model))
                }
                connectionTestRow(key: "llm-\(id)",
                                  title: AppFlavor.text("检测连接", "Test Connection"),
                                  disabled: !provider.isConfigured) {
                    testLLMConnection(key: "llm-\(id)", provider: provider.runtimeConfig)
                }
                HStack {
                    if let preset = LLMServicePresets.all.first(where: { $0.id == provider.presetID }), let url = preset.keyURL {
                        Link(AppFlavor.text("获取 API Key ↗", "Get API Key ↗"), destination: url)
                            .font(.caption)
                    }
                    Spacer()
                    Button(AppFlavor.text("设为默认", "Set as Default")) {
                        setProviderAsDefault(provider)
                    }
                    .disabled(!provider.isConfigured)
                }
                helperText(AppFlavor.text("设为默认后，未指定模型的技能会使用此服务。",
                                          "After setting as default, actions without a chosen model use this service."))
            }
        } else {
            ContentUnavailableView(AppFlavor.text("服务不存在", "Service Not Found"),
                                   systemImage: "rectangle.2.swap",
                                   description: Text(AppFlavor.text("这个服务可能已被删除。", "This service may have been deleted.")))
        }
    }

    private var ocrDetail: some View {
        VStack(alignment: .leading, spacing: 18) {
            detailHeader(title: AppFlavor.text("系统 OCR", "System OCR"),
                         subtitle: AppFlavor.text("使用 macOS Apple Vision 在本机识别屏幕选区，适合无法直接取词或禁止复制的场景。",
                                                  "Uses macOS Apple Vision locally for screen-region OCR when direct capture or copying is unavailable."),
                         icon: "viewfinder",
                         status: AppFlavor.text("内置", "Built-in"))
            VStack(alignment: .leading, spacing: 12) {
                factRow(AppFlavor.text("屏幕 OCR 快捷键", "Screen OCR hotkey"), value: ocrHkDisplay)
                factRow(AppFlavor.text("静默 OCR 复制", "Silent OCR copy"), value: silentOcrHkDisplay)
                Toggle(AppFlavor.text("OCR 后自动执行最近一次技能", "Run the most recent action after OCR"), isOn: $ocrAutoRunLastAction)
                    .toggleStyle(.switch)
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Color.primary.opacity(0.035)))
            helperText(AppFlavor.text("OCR 不需要密钥。快捷键和自动执行也可以在「偏好」里调整。",
                                      "OCR needs no key. Hotkeys and auto-run can also be changed in Preferences."))
        }
    }

    private var localSpeechDetail: some View {
        VStack(alignment: .leading, spacing: 18) {
            detailHeader(title: AppFlavor.text("macOS 本地语音", "macOS Speech"),
                         subtitle: AppFlavor.text("不需要网络或密钥。火山引擎未配置或失败时，也会回退到本地语音。",
                                                  "No network or key required. This is also the fallback when Volcengine is not configured or fails."),
                         icon: "macwindow",
                         status: ttsEngine == "local" ? AppFlavor.text("正在使用", "Active") : AppFlavor.text("备用", "Fallback"))
            Button {
                ttsEngine = "local"
            } label: {
                Label(AppFlavor.text("设为当前语音服务", "Use as current speech service"), systemImage: "checkmark.circle")
            }
            .disabled(ttsEngine == "local")
            HStack {
                Text(AppFlavor.text("语速", "Speed"))
                Slider(value: $rate, in: 0.3...0.7)
                Text(String(format: "%.2f", rate))
                    .foregroundStyle(.secondary)
                    .frame(width: 46, alignment: .trailing)
            }
            Button(AppFlavor.text("试听", "Test Voice")) {
                Settings.speechRate = Float(rate)
                Speaker.shared.speak(AppFlavor.text("Dob，这是本地语音的试听效果。", "Dob. This is the local speech voice."))
            }
        }
    }

    private var volcanoSpeechDetail: some View {
        VStack(alignment: .leading, spacing: 18) {
            detailHeader(title: AppFlavor.text("火山引擎 TTS", "Volcengine TTS"),
                         subtitle: AppFlavor.text("适合中文朗读质量要求更高的场景。需要在火山控制台开通语音服务并填写 App ID 与 Token。",
                                                  "Useful when higher-quality speech is needed. Requires Volcengine speech service, App ID, and Token."),
                         icon: "waveform",
                         status: volcanoConfigured ? AppFlavor.text("已配置", "Configured") : AppFlavor.text("未配置", "Missing Key"))
            Button {
                ttsEngine = "volcano"
            } label: {
                Label(AppFlavor.text("设为当前语音服务", "Use as current speech service"), systemImage: "checkmark.circle")
            }
            .disabled(ttsEngine == "volcano" || !volcanoConfigured)
            serviceFields {
                SecureField("App ID", text: $volcAppId)
                SecureField("Access Token", text: $volcToken)
                Picker(AppFlavor.text("常用音色", "Common voice"), selection: $volcVoice) {
                    ForEach(VolcanoVoices.all) { voice in
                        Text(voice.name).tag(voice.id)
                    }
                    if !VolcanoVoices.all.contains(where: { $0.id == volcVoice }) {
                        Text(AppFlavor.text("自定义（\(volcVoice)）", "Custom (\(volcVoice))")).tag(volcVoice)
                    }
                }
                TextField(AppFlavor.text("自定义 voice_type（可选）", "Custom voice_type (optional)"), text: $volcVoice)
                TextField("Cluster", text: $volcCluster)
                HStack {
                    Text(AppFlavor.text("语速", "Speed"))
                    Slider(value: $volcSpeed, in: 0.5...2.0)
                    Text(String(format: "%.1fx", volcSpeed))
                        .foregroundStyle(.secondary)
                        .frame(width: 44, alignment: .trailing)
                }
            }
            connectionTestRow(key: "tts-volcano",
                              title: AppFlavor.text("检测接口", "Test API"),
                              disabled: !volcanoConfigured) {
                testSpeechConnection(key: "tts-volcano", provider: .volcano)
            }
            HStack {
                Link(AppFlavor.text("火山语音控制台 ↗", "Volcengine speech console ↗"),
                     destination: URL(string: "https://console.volcengine.com/speech/app")!)
                Spacer()
                Link(AppFlavor.text("官方完整音色列表 ↗", "Full official voice list ↗"),
                     destination: Self.volcanoVoiceListURL)
            }
            .font(.caption)
            if !volcanoConfigured {
                helperText(AppFlavor.text("未填 App ID / Token 时，朗读会自动回退到 macOS 本地语音。",
                                          "When App ID or Token is missing, reading automatically falls back to macOS Speech."))
                    .foregroundStyle(.orange)
            }
            Button(AppFlavor.text("试听", "Test Voice")) {
                ttsEngine = "volcano"
                Settings.speechRate = Float(rate)
                Speaker.shared.speak(AppFlavor.text("Dob，这是当前火山音色的试听效果。", "Dob. This is the current Volcengine voice."))
            }
            .disabled(!volcanoConfigured)
        }
    }

    private var microsoftSpeechDetail: some View {
        VStack(alignment: .leading, spacing: 18) {
            detailHeader(title: AppFlavor.text("Microsoft 语音合成", "Microsoft Speech"),
                         subtitle: AppFlavor.text("通过 Azure AI Speech REST API 合成 MP3。Region 可填写 eastasia，也可粘贴 Speech 资源 Endpoint。",
                                                  "Uses Azure AI Speech REST API to synthesize MP3. Region can be eastasia, or paste a Speech resource endpoint."),
                         icon: "square.grid.2x2",
                         status: speechBadge(engine: "microsoft", configured: microsoftConfigured))
            Button {
                ttsEngine = "microsoft"
            } label: {
                Label(AppFlavor.text("设为当前语音服务", "Use as current speech service"), systemImage: "checkmark.circle")
            }
            .disabled(ttsEngine == "microsoft" || !microsoftConfigured)
            serviceFields {
                SecureField("Key", text: $microsoftTTSKey)
                TextField(AppFlavor.text("Region 或 Endpoint，例如 eastasia", "Region or endpoint, e.g. eastasia"),
                          text: $microsoftTTSRegion)
                Picker(AppFlavor.text("常用音色", "Common voice"), selection: $microsoftTTSVoice) {
                    ForEach(MicrosoftVoices.all) { voice in
                        Text(voice.displayName).tag(voice.id)
                    }
                    if !MicrosoftVoices.all.contains(where: { $0.id == microsoftTTSVoice }) {
                        Text(AppFlavor.text("自定义（\(microsoftTTSVoice)）", "Custom (\(microsoftTTSVoice))")).tag(microsoftTTSVoice)
                    }
                }
                TextField(AppFlavor.text("Voice，例如 zh-CN-XiaoxiaoNeural", "Voice, e.g. en-US-JennyNeural"),
                          text: $microsoftTTSVoice)
            }
            connectionTestRow(key: "tts-microsoft",
                              title: AppFlavor.text("检测接口", "Test API"),
                              disabled: !microsoftConfigured) {
                testSpeechConnection(key: "tts-microsoft", provider: .microsoft)
            }
            HStack {
                Link(AppFlavor.text("官方音色列表 ↗", "Official voice list ↗"), destination: Self.microsoftSpeechDocsURL)
                    .font(.caption)
                Spacer()
                Button(AppFlavor.text("试听", "Test Voice")) {
                    ttsEngine = "microsoft"
                    Speaker.shared.speak(AppFlavor.text("Dob，这是 Microsoft 语音合成的试听效果。", "Dob. This is the Microsoft Speech voice."))
                }
                .disabled(!microsoftConfigured)
            }
            if !microsoftConfigured {
                helperText(AppFlavor.text("需要填写 Key、Region/Endpoint 和 Voice 后才能启用。",
                                          "Key, Region/Endpoint, and Voice are required before this service can be enabled."))
                    .foregroundStyle(.orange)
            }
        }
    }

    private var googleSpeechDetail: some View {
        VStack(alignment: .leading, spacing: 18) {
            detailHeader(title: AppFlavor.text("Google 语音合成", "Google Text-to-Speech"),
                         subtitle: AppFlavor.text("通过 Cloud Text-to-Speech REST API 合成 MP3。支持 API Key；如果你填 Bearer Token，也会按授权头发送。",
                                                  "Uses Cloud Text-to-Speech REST API to synthesize MP3. API keys are supported; Bearer tokens are sent as Authorization."),
                         icon: "g.circle",
                         status: speechBadge(engine: "google", configured: googleConfigured))
            Button {
                ttsEngine = "google"
            } label: {
                Label(AppFlavor.text("设为当前语音服务", "Use as current speech service"), systemImage: "checkmark.circle")
            }
            .disabled(ttsEngine == "google" || !googleConfigured)
            serviceFields {
                SecureField(AppFlavor.text("API Key 或 Bearer Token", "API key or Bearer token"), text: $googleTTSKey)
                Picker(AppFlavor.text("常用音色", "Common voice"), selection: $googleTTSVoice) {
                    ForEach(GoogleVoices.all) { voice in
                        Text(voice.displayName).tag(voice.id)
                    }
                    if !GoogleVoices.all.contains(where: { $0.id == googleTTSVoice }) {
                        Text(AppFlavor.text("自定义（\(googleTTSVoice)）", "Custom (\(googleTTSVoice))")).tag(googleTTSVoice)
                    }
                }
                TextField(AppFlavor.text("Voice，例如 cmn-CN-Standard-A", "Voice, e.g. en-US-Neural2-F"),
                          text: $googleTTSVoice)
                HStack {
                    Text(AppFlavor.text("语速", "Speed"))
                    Slider(value: $googleTTSSpeed, in: 0.25...4.0)
                    Text(String(format: "%.2fx", googleTTSSpeed))
                        .foregroundStyle(.secondary)
                        .frame(width: 54, alignment: .trailing)
                }
            }
            connectionTestRow(key: "tts-google",
                              title: AppFlavor.text("检测接口", "Test API"),
                              disabled: !googleConfigured) {
                testSpeechConnection(key: "tts-google", provider: .google)
            }
            HStack {
                Link(AppFlavor.text("官方音色列表 ↗", "Official voice list ↗"), destination: Self.googleSpeechDocsURL)
                    .font(.caption)
                Spacer()
                Button(AppFlavor.text("试听", "Test Voice")) {
                    ttsEngine = "google"
                    Speaker.shared.speak(AppFlavor.text("Dob，这是 Google 语音合成的试听效果。", "Dob. This is the Google Text-to-Speech voice."))
                }
                .disabled(!googleConfigured)
            }
            if !googleConfigured {
                helperText(AppFlavor.text("需要填写 API Key/Bearer Token 和 Voice 后才能启用。",
                                          "API key/Bearer token and Voice are required before this service can be enabled."))
                    .foregroundStyle(.orange)
            }
        }
    }

    private var tencentSpeechDetail: some View {
        VStack(alignment: .leading, spacing: 18) {
            detailHeader(title: AppFlavor.text("腾讯云语音合成", "Tencent Cloud TTS"),
                         subtitle: AppFlavor.text("通过腾讯云 TextToVoice API 合成 MP3。长文本会自动切成小段顺序播放。",
                                                  "Uses Tencent Cloud TextToVoice API to synthesize MP3. Long text is split into sequential chunks."),
                         icon: "cloud",
                         status: speechBadge(engine: "tencent", configured: tencentConfigured))
            Button {
                ttsEngine = "tencent"
            } label: {
                Label(AppFlavor.text("设为当前语音服务", "Use as current speech service"), systemImage: "checkmark.circle")
            }
            .disabled(ttsEngine == "tencent" || !tencentConfigured)
            serviceFields {
                SecureField("SecretId", text: $tencentTTSSecretId)
                SecureField("SecretKey", text: $tencentTTSSecretKey)
                TextField("Host", text: $tencentTTSHost)
                TextField(AppFlavor.text("Region，例如 ap-guangzhou", "Region, e.g. ap-guangzhou"), text: $tencentTTSRegion)
                Picker(AppFlavor.text("常用音色", "Common voice"), selection: $tencentTTSVoice) {
                    ForEach(TencentVoices.all) { voice in
                        Text(voice.displayName).tag(voice.id)
                    }
                    if !TencentVoices.all.contains(where: { $0.id == tencentTTSVoice }) {
                        Text(AppFlavor.text("自定义（\(tencentTTSVoice)）", "Custom (\(tencentTTSVoice))")).tag(tencentTTSVoice)
                    }
                }
                TextField(AppFlavor.text("VoiceType，例如 1001", "VoiceType, e.g. 1050"),
                          text: $tencentTTSVoice)
                HStack {
                    Text(AppFlavor.text("语速", "Speed"))
                    Slider(value: $tencentTTSSpeed, in: -2.0...6.0)
                    Text(String(format: "%.1f", tencentTTSSpeed))
                        .foregroundStyle(.secondary)
                        .frame(width: 42, alignment: .trailing)
                }
            }
            connectionTestRow(key: "tts-tencent",
                              title: AppFlavor.text("检测接口", "Test API"),
                              disabled: !tencentConfigured) {
                testSpeechConnection(key: "tts-tencent", provider: .tencent)
            }
            HStack {
                Link(AppFlavor.text("官方音色列表 ↗", "Official voice list ↗"), destination: Self.tencentSpeechDocsURL)
                    .font(.caption)
                Spacer()
                Button(AppFlavor.text("试听", "Test Voice")) {
                    ttsEngine = "tencent"
                    Speaker.shared.speak(AppFlavor.text("Dob，这是腾讯云语音合成的试听效果。", "Dob. This is the Tencent Cloud TTS voice."))
                }
                .disabled(!tencentConfigured)
            }
            if !tencentConfigured {
                helperText(AppFlavor.text("需要填写 SecretId、SecretKey、Host 和 Region 后才能启用。",
                                          "SecretId, SecretKey, Host, and Region are required before this service can be enabled."))
                    .foregroundStyle(.orange)
            }
        }
    }

    private func row(title: String,
                     subtitle: String,
                     icon: String,
                     badge: String,
                     enabled: Binding<Bool>? = nil,
                     recommended: Bool = false,
                     selected: Bool,
                     action: @escaping () -> Void) -> some View {
        HStack(spacing: 10) {
            Button(action: action) {
                HStack(spacing: 10) {
                    Image(systemName: icon)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(selected ? Color.accentColor : Color.secondary)
                        .frame(width: 24)
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 5) {
                            Text(title)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                                .truncationMode(.tail)
                            if recommended {
                                Text(AppFlavor.text("推荐", "Recommended"))
                                    .font(.system(size: 9, weight: .semibold))
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 1)
                                    .background(Capsule().fill(Color.accentColor.opacity(selected ? 0.20 : 0.12)))
                                    .foregroundStyle(Color.accentColor)
                                    .fixedSize(horizontal: true, vertical: true)
                            }
                        }
                        .lineLimit(1)
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    .layoutPriority(1)
                    Spacer()
                    Text(badge)
                        .font(.caption2.weight(.medium))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(selected ? Color.accentColor.opacity(0.16) : Color.primary.opacity(0.07)))
                        .foregroundStyle(selected ? Color.accentColor : Color.secondary)
                        .fixedSize(horizontal: true, vertical: true)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            if let enabled {
                Toggle("", isOn: enabled)
                    .labelsHidden()
                    .controlSize(.small)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(selected ? Color.accentColor.opacity(0.10) : Color.primary.opacity(0.035)))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(selected ? Color.accentColor.opacity(0.28) : Color.primary.opacity(0.06), lineWidth: 0.5)
        }
    }

    private func detailHeader(title: String, subtitle: String, icon: String, status: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(Color.accentColor)
                .frame(width: 34)
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 8) {
                    Text(title)
                        .font(.title2.weight(.semibold))
                    Text(status)
                        .font(.caption.weight(.medium))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(Color.primary.opacity(0.08)))
                        .foregroundStyle(.secondary)
                }
                Text(subtitle)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func serviceFields<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            content()
        }
        .textFieldStyle(.roundedBorder)
    }

    private func presetGrid(onApply: @escaping (LLMServicePreset) -> Void) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(AppFlavor.text("服务商预设", "Provider Presets"))
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                Menu {
                    ForEach(LLMServicePresets.all) { preset in
                        if let url = preset.keyURL {
                            Link(preset.name, destination: url)
                        }
                    }
                } label: {
                    Label(AppFlavor.text("获取 Key", "Get Key"), systemImage: "key")
                }
                .menuStyle(.button)
                .font(.caption)
            }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 126), spacing: 8)], alignment: .leading, spacing: 8) {
                ForEach(LLMServicePresets.all) { preset in
                    let modelLabel = preset.model.isEmpty ? AppFlavor.text("自定义模型", "Custom model") : preset.model
                    let endpointLabel = preset.baseURL.isEmpty ? AppFlavor.text("手动填写 Base URL", "Custom Base URL") : preset.baseURL
                    Button {
                        onApply(preset)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(preset.name)
                                .font(.system(size: 12, weight: .semibold))
                                .lineLimit(1)
                            Text(modelLabel)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                            Text(preset.note)
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity, minHeight: 54, alignment: .leading)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 7)
                        .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Color.primary.opacity(0.04)))
                        .overlay {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .strokeBorder(Color.primary.opacity(0.07), lineWidth: 0.5)
                        }
                    }
                    .buttonStyle(.plain)
                    .help("\(endpointLabel) · \(modelLabel)")
                }
            }
            helperText(AppFlavor.text("预设只填充 Base URL 和模型名，不会覆盖 API Key。",
                                      "Presets fill Base URL and model only; your API key is not overwritten."))
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Color.primary.opacity(0.025)))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.06), lineWidth: 0.5)
        }
    }

    private func factRow(_ title: String, value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
        }
    }

    private func helperText(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func connectionTestRow(key: String,
                                   title: String,
                                   disabled: Bool,
                                   action: @escaping () -> Void) -> some View {
        let isTesting = testingServices.contains(key)
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Button {
                    action()
                } label: {
                    if isTesting {
                        HStack(spacing: 6) {
                            ProgressView()
                                .controlSize(.small)
                            Text(AppFlavor.text("检测中", "Testing"))
                        }
                    } else {
                        Label(title, systemImage: "checkmark.seal")
                    }
                }
                .disabled(disabled || isTesting)
                if disabled {
                    Text(AppFlavor.text("填完整后可检测", "Complete fields to test"))
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                Spacer()
            }
            if let result = serviceTestResults[key] {
                Label(result.message, systemImage: result.succeeded ? "checkmark.circle.fill" : "xmark.octagon.fill")
                    .font(.caption)
                    .foregroundStyle(result.succeeded ? Color.green : Color.red)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Color.primary.opacity(0.028)))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.06), lineWidth: 0.5)
        }
    }

    private func isLLMConfigReady(baseURL: String, apiKey: String, model: String) -> Bool {
        !baseURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func testLLMConnection(key: String, provider: LLMProviderConfig) {
        testingServices.insert(key)
        serviceTestResults[key] = nil
        Task {
            let result: ServiceTestResult
            do {
                let response = try await LLMClient.testConnection(provider: provider)
                let clean = response.trimmingCharacters(in: .whitespacesAndNewlines)
                let message: String
                if clean.uppercased().contains("OK") {
                    message = AppFlavor.text("连接成功，模型已响应。", "Connection succeeded. The model responded.")
                } else {
                    message = AppFlavor.text("连接成功，返回：\(String(clean.prefix(60)))",
                                             "Connection succeeded. Response: \(String(clean.prefix(60)))")
                }
                result = ServiceTestResult(succeeded: true, message: message)
            } catch {
                result = ServiceTestResult(succeeded: false, message: describeServiceTestError(error))
            }
            await MainActor.run {
                serviceTestResults[key] = result
                testingServices.remove(key)
            }
        }
    }

    private func testSpeechConnection(key: String, provider: CloudTTSProvider) {
        testingServices.insert(key)
        serviceTestResults[key] = nil
        Task {
            let result: ServiceTestResult
            do {
                let sample = AppFlavor.text("Dob 接口检测。", "Dob API test.")
                let data = try await provider.synthesize(sample)
                guard !data.isEmpty else { throw CloudTTSError.noAudio(provider.displayName) }
                let size = ByteCountFormatter.string(fromByteCount: Int64(data.count), countStyle: .file)
                result = ServiceTestResult(
                    succeeded: true,
                    message: AppFlavor.text("接口可用，已收到音频数据（\(size)）。",
                                            "API is available. Audio data received (\(size)).")
                )
            } catch {
                result = ServiceTestResult(succeeded: false, message: describeServiceTestError(error))
            }
            await MainActor.run {
                serviceTestResults[key] = result
                testingServices.remove(key)
            }
        }
    }

    private func describeServiceTestError(_ error: Error) -> String {
        let message: String
        if let llm = error as? LLMError {
            message = llm.description
        } else if let cloud = error as? CloudTTSError {
            message = cloud.description
        } else if let volcano = error as? VolcanoTTSError {
            switch volcano {
            case .notConfigured:
                message = AppFlavor.text("火山引擎配置不完整", "Volcengine configuration is incomplete")
            case .http(let code, let body):
                let clean = body.trimmingCharacters(in: .whitespacesAndNewlines)
                message = "HTTP \(code): \(clean.isEmpty ? AppFlavor.text("无错误详情", "No error detail") : clean)"
            case .api(let code, let body):
                message = "API \(code): \(body)"
            case .noAudio:
                message = AppFlavor.text("服务没有返回音频数据", "The service returned no audio data")
            }
        } else {
            message = error.localizedDescription
        }
        let clean = message.trimmingCharacters(in: .whitespacesAndNewlines)
        return String((clean.isEmpty ? String(describing: error) : clean).prefix(260))
    }

    private var selectedLLMProviderID: String? {
        if case .llmProvider(let id) = selection { return id }
        return nil
    }

    private func providerStatus(_ provider: LLMServiceProvider) -> String {
        if !provider.enabled { return AppFlavor.text("关闭", "Off") }
        if provider.compareEnabled { return AppFlavor.text("比较", "Compare") }
        return provider.isConfigured ? AppFlavor.text("已配置", "Configured") : AppFlavor.text("未配置", "Missing")
    }

    private func saveLLMProviders() {
        Settings.llmServiceProviders = llmProviders
    }

    private func addLLMProvider() {
        let provider = LLMServiceProvider(label: AppFlavor.text("新服务", "New Service"),
                                          baseURL: Settings.recommendedLLMBaseURL,
                                          model: Settings.recommendedLLMModel)
        llmProviders.append(provider)
        saveLLMProviders()
        selection = .llmProvider(provider.id)
    }

    private func deleteSelectedLLMProvider() {
        guard let id = selectedLLMProviderID else { return }
        llmProviders.removeAll { $0.id == id }
        Settings.clearActionProviderReferences(to: id)
        saveLLMProviders()
        selection = .defaultModel
    }

    private func updateLLMProvider(_ id: String, mutate: (inout LLMServiceProvider) -> Void) {
        guard let index = llmProviders.firstIndex(where: { $0.id == id }) else { return }
        mutate(&llmProviders[index])
        if !llmProviders[index].enabled {
            llmProviders[index].compareEnabled = false
        }
        saveLLMProviders()
    }

    private func providerStringBinding(id: String, keyPath: WritableKeyPath<LLMServiceProvider, String>) -> Binding<String> {
        Binding(
            get: { llmProviders.first(where: { $0.id == id })?[keyPath: keyPath] ?? "" },
            set: { value in updateLLMProvider(id) { $0[keyPath: keyPath] = value } }
        )
    }

    private func providerBoolBinding(id: String, keyPath: WritableKeyPath<LLMServiceProvider, Bool>) -> Binding<Bool> {
        Binding(
            get: { llmProviders.first(where: { $0.id == id })?[keyPath: keyPath] ?? false },
            set: { value in updateLLMProvider(id) { $0[keyPath: keyPath] = value } }
        )
    }

    private func compareBinding(for id: String) -> Binding<Bool> {
        providerBoolBinding(id: id, keyPath: \.compareEnabled)
    }

    private func setProviderAsDefault(_ provider: LLMServiceProvider) {
        llmBaseURL = provider.baseURL
        llmAPIKey = provider.apiKey
        llmModel = provider.model
        llmProviders.removeAll { $0.id == provider.id }
        Settings.clearActionProviderReferences(to: provider.id)
        saveLLMProviders()
        selection = .defaultModel
    }

    private func speechBadge(engine: String, configured: Bool) -> String {
        if ttsEngine == engine { return AppFlavor.text("正在使用", "Active") }
        return configured ? AppFlavor.text("已配置", "Configured") : AppFlavor.text("未配置", "Missing")
    }

    private func defaultSelection(for category: Category) -> Selection {
        switch category {
        case .text: return .defaultModel
        case .recognition: return .systemOCR
        case .speech:
            switch ttsEngine {
            case "volcano": return .volcanoSpeech
            case "microsoft": return .microsoftSpeech
            case "google": return .googleSpeech
            case "tencent": return .tencentSpeech
            default: return .localSpeech
            }
        }
    }
}
