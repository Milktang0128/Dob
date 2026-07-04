import Foundation

struct VolcanoVoice: Identifiable {
    let id: String      // voice_type
    let name: String
}

struct TTSVoicePreset: Identifiable {
    let id: String
    let name: String
    let note: String

    init(id: String, name: String, note: String = "") {
        self.id = id
        self.name = name
        self.note = note
    }

    var displayName: String {
        note.isEmpty ? name : "\(name) · \(note)"
    }
}

/// 豆包语音合成模型 2.0（_uranus_bigtts）常用音色，节选自官方音色列表（2026.05）。
/// 账号需在火山控制台开通对应音色；也可在设置里手填任意 voice_type。
enum VolcanoVoices {
    static let all: [VolcanoVoice] = [
        .init(id: "zh_female_cancan_uranus_bigtts", name: AppFlavor.text("灿灿 · 知性女声", "Cancang · Chinese female")),
        .init(id: "zh_female_shuangkuaisisi_uranus_bigtts", name: AppFlavor.text("爽快思思", "Sisi · Chinese female")),
        .init(id: "zh_female_qingxinnvsheng_uranus_bigtts", name: AppFlavor.text("清新女声", "Fresh Chinese female")),
        .init(id: "zh_female_wenrouxiaoya_uranus_bigtts", name: AppFlavor.text("温柔小雅", "Xiaoya · gentle Chinese female")),
        .init(id: "zh_female_tianmeitaozi_uranus_bigtts", name: AppFlavor.text("甜美桃子", "Taozi · sweet Chinese female")),
        .init(id: "zh_female_linjianvhai_uranus_bigtts", name: AppFlavor.text("邻家女孩", "Neighbor girl · Chinese female")),
        .init(id: "zh_female_gaolengyujie_uranus_bigtts", name: AppFlavor.text("高冷御姐", "Cool mature Chinese female")),
        .init(id: "zh_female_vv_uranus_bigtts", name: AppFlavor.text("Vivi · 多语种(中日西)", "Vivi · multilingual")),
        .init(id: "zh_male_wennuanahu_uranus_bigtts", name: AppFlavor.text("温暖阿虎 / Alvin", "Alvin · warm Chinese male")),
        .init(id: "zh_male_shaonianzixin_uranus_bigtts", name: AppFlavor.text("少年梓辛 / Brayan", "Brayan · young Chinese male")),
        .init(id: "zh_male_yuanboxiaoshu_uranus_bigtts", name: AppFlavor.text("渊博小叔", "Knowledgeable Chinese male")),
        .init(id: "zh_male_yangguangqingnian_uranus_bigtts", name: AppFlavor.text("阳光青年", "Bright Chinese male")),
        .init(id: "zh_male_ruyaqingnian_uranus_bigtts", name: AppFlavor.text("儒雅青年", "Refined Chinese male")),
        .init(id: "zh_male_cixingjieshuonan_uranus_bigtts", name: AppFlavor.text("磁性解说 / Morgan", "Morgan · narrator")),
        .init(id: "zh_male_shenyeboke_uranus_bigtts", name: AppFlavor.text("深夜播客", "Late-night podcast male")),
        .init(id: "zh_male_xuanyijieshuo_uranus_bigtts", name: AppFlavor.text("悬疑解说", "Suspense narrator")),
        .init(id: "zh_female_yingyujiaoxue_uranus_bigtts", name: AppFlavor.text("Tina 老师 · 中英", "Tina · Chinese and English")),
        .init(id: "en_male_tim_uranus_bigtts", name: AppFlavor.text("Tim · 美式英语", "Tim · American English")),
        .init(id: "en_female_dacey_uranus_bigtts", name: AppFlavor.text("Dacey · 美式英语", "Dacey · American English"))
    ]
}

/// Common Azure AI Speech voices verified against Microsoft Learn language and
/// voice support docs. The text field still accepts any official voice name.
enum MicrosoftVoices {
    static let all: [TTSVoicePreset] = [
        .init(id: "zh-CN-XiaoxiaoNeural", name: AppFlavor.text("晓晓 · 普通话女声", "Xiaoxiao · Mandarin female"), note: AppFlavor.text("通用/助手", "general")),
        .init(id: "zh-CN-XiaoyiNeural", name: AppFlavor.text("晓伊 · 普通话女声", "Xiaoyi · Mandarin female"), note: AppFlavor.text("亲和", "friendly")),
        .init(id: "zh-CN-XiaochenNeural", name: AppFlavor.text("晓辰 · 普通话女声", "Xiaochen · Mandarin female"), note: AppFlavor.text("直播/商业", "commercial")),
        .init(id: "zh-CN-YunxiNeural", name: AppFlavor.text("云希 · 普通话男声", "Yunxi · Mandarin male"), note: AppFlavor.text("聊天/旁白", "chat")),
        .init(id: "zh-CN-YunjianNeural", name: AppFlavor.text("云健 · 普通话男声", "Yunjian · Mandarin male"), note: AppFlavor.text("纪录片/体育", "documentary")),
        .init(id: "zh-CN-YunyangNeural", name: AppFlavor.text("云扬 · 普通话男声", "Yunyang · Mandarin male"), note: AppFlavor.text("新闻/客服", "news")),
        .init(id: "zh-HK-HiuMaanNeural", name: AppFlavor.text("晓曼 · 粤语女声", "HiuMaan · Cantonese female"), note: "zh-HK"),
        .init(id: "zh-HK-WanLungNeural", name: AppFlavor.text("云龙 · 粤语男声", "WanLung · Cantonese male"), note: "zh-HK"),
        .init(id: "zh-TW-HsiaoChenNeural", name: AppFlavor.text("晓臻 · 台湾女声", "HsiaoChen · Taiwan female"), note: "zh-TW"),
        .init(id: "zh-TW-YunJheNeural", name: AppFlavor.text("云哲 · 台湾男声", "YunJhe · Taiwan male"), note: "zh-TW"),
        .init(id: "en-US-JennyNeural", name: "Jenny · English female", note: "en-US"),
        .init(id: "en-US-GuyNeural", name: "Guy · English male", note: "en-US")
    ]
}

/// Common Google Cloud Text-to-Speech voices verified against the supported
/// voices page. API availability can still depend on project permissions.
enum GoogleVoices {
    static let all: [TTSVoicePreset] = [
        .init(id: "cmn-CN-Chirp3-HD-Achernar", name: AppFlavor.text("Achernar · 普通话女声", "Achernar · Mandarin female"), note: "Chirp3 HD"),
        .init(id: "cmn-CN-Chirp3-HD-Aoede", name: AppFlavor.text("Aoede · 普通话女声", "Aoede · Mandarin female"), note: "Chirp3 HD"),
        .init(id: "cmn-CN-Chirp3-HD-Achird", name: AppFlavor.text("Achird · 普通话男声", "Achird · Mandarin male"), note: "Chirp3 HD"),
        .init(id: "cmn-CN-Chirp3-HD-Algenib", name: AppFlavor.text("Algenib · 普通话男声", "Algenib · Mandarin male"), note: "Chirp3 HD"),
        .init(id: "cmn-CN-Standard-A", name: AppFlavor.text("Standard A · 普通话女声", "Standard A · Mandarin female"), note: AppFlavor.text("兼容", "standard")),
        .init(id: "cmn-CN-Standard-B", name: AppFlavor.text("Standard B · 普通话男声", "Standard B · Mandarin male"), note: AppFlavor.text("兼容", "standard")),
        .init(id: "cmn-CN-Wavenet-A", name: AppFlavor.text("Wavenet A · 普通话女声", "Wavenet A · Mandarin female"), note: "Wavenet"),
        .init(id: "cmn-CN-Wavenet-B", name: AppFlavor.text("Wavenet B · 普通话男声", "Wavenet B · Mandarin male"), note: "Wavenet"),
        .init(id: "en-US-Neural2-F", name: "Neural2 F · English female", note: "en-US"),
        .init(id: "en-US-Neural2-J", name: "Neural2 J · English male", note: "en-US")
    ]
}

/// Common Tencent Cloud TTS VoiceType presets verified against the official
/// voice list for realtime/basic/long-form synthesis.
enum TencentVoices {
    static let all: [TTSVoicePreset] = [
        .init(id: "502001", name: AppFlavor.text("智小柔 · 聊天女声", "Zhixiaorou · female"), note: AppFlavor.text("中英文", "zh/en")),
        .init(id: "502003", name: AppFlavor.text("智小敏 · 聊天女声", "Zhixiaomin · female"), note: AppFlavor.text("中英文", "zh/en")),
        .init(id: "502005", name: AppFlavor.text("智小解 · 解说男声", "Zhixiaojie · narrator"), note: AppFlavor.text("中英文", "zh/en")),
        .init(id: "502006", name: AppFlavor.text("智小悟 · 聊天男声", "Zhixiaowu · male"), note: AppFlavor.text("中英文", "zh/en")),
        .init(id: "502007", name: AppFlavor.text("智小虎 · 聊天童声", "Zhixiaohu · child"), note: AppFlavor.text("中英文", "zh/en")),
        .init(id: "602004", name: AppFlavor.text("暖心阿灿 · 聊天男声", "Acan · male"), note: AppFlavor.text("中英文", "zh/en")),
        .init(id: "602005", name: AppFlavor.text("专业梓欣 · 聊天女声", "Zixin · female"), note: AppFlavor.text("中英文", "zh/en")),
        .init(id: "501000", name: AppFlavor.text("智斌 · 阅读男声", "Zhibin · reading male"), note: AppFlavor.text("长文本", "long-form")),
        .init(id: "501001", name: AppFlavor.text("智兰 · 资讯女声", "Zhilan · news female"), note: AppFlavor.text("长文本", "long-form")),
        .init(id: "501002", name: AppFlavor.text("智菊 · 阅读女声", "Zhiju · reading female"), note: AppFlavor.text("长文本", "long-form")),
        .init(id: "501008", name: "WeJames · English male", note: AppFlavor.text("长文本英文", "long-form en")),
        .init(id: "501009", name: "WeWinny · English female", note: AppFlavor.text("长文本英文", "long-form en"))
    ]
}

/// MiniMax T2A 模型。`speech-02-hd` 兼容性最好，作为默认；账号有权限时可选更新的版本。
enum MiniMaxModels {
    static let all: [String] = [
        "speech-02-hd", "speech-02-turbo",
        "speech-2.6-hd", "speech-2.6-turbo",
        "speech-2.8-hd", "speech-2.8-turbo"
    ]
}

/// MiniMax 系统音色。中文列表排除官方标注 beta 的音色；账号需有对应权限，
/// 也可在设置里手填任意 voice_id。
enum MiniMaxVoices {
    private static func zh(_ id: String, _ name: String, _ englishName: String) -> TTSVoicePreset {
        TTSVoicePreset(id: id, name: AppFlavor.text(name, englishName), note: AppFlavor.text("中文", "zh"))
    }

    private static func yue(_ id: String, _ name: String, _ englishName: String) -> TTSVoicePreset {
        TTSVoicePreset(id: id, name: AppFlavor.text(name, englishName), note: AppFlavor.text("粤语", "yue"))
    }

    static let all: [TTSVoicePreset] = [
        zh("male-qn-qingse", "青涩青年音色", "Qingse Youth"),
        zh("male-qn-jingying", "精英青年音色", "Elite Youth"),
        zh("male-qn-badao", "霸道青年音色", "Domineering Youth"),
        zh("male-qn-daxuesheng", "青年大学生音色", "College Student"),
        zh("female-shaonv", "少女音色", "Young Girl"),
        zh("female-yujie", "御姐音色", "Mature Lady"),
        zh("female-chengshu", "成熟女性音色", "Mature Woman"),
        zh("female-tianmei", "甜美女性音色", "Sweet Woman"),
        zh("clever_boy", "聪明男童", "Clever Boy"),
        zh("cute_boy", "可爱男童", "Cute Boy"),
        zh("lovely_girl", "萌萌女童", "Lovely Girl"),
        zh("cartoon_pig", "卡通猪小琪", "Cartoon Pig"),
        zh("bingjiao_didi", "病娇弟弟", "Yandere Younger Brother"),
        zh("junlang_nanyou", "俊朗男友", "Handsome Boyfriend"),
        zh("chunzhen_xuedi", "纯真学弟", "Innocent Junior"),
        zh("lengdan_xiongzhang", "冷淡学长", "Reserved Senior"),
        zh("badao_shaoye", "霸道少爷", "Domineering Young Master"),
        zh("tianxin_xiaoling", "甜心小玲", "Sweet Xiaoling"),
        zh("qiaopi_mengmei", "俏皮萌妹", "Playful Girl"),
        zh("wumei_yujie", "妩媚御姐", "Charming Lady"),
        zh("diadia_xuemei", "嗲嗲学妹", "Coquettish Junior"),
        zh("danya_xuejie", "淡雅学姐", "Elegant Senior"),
        zh("Chinese (Mandarin)_Reliable_Executive", "沉稳高管", "Reliable Executive"),
        zh("Chinese (Mandarin)_News_Anchor", "新闻女声", "News Anchor"),
        zh("Chinese (Mandarin)_Mature_Woman", "傲娇御姐", "Mature Woman"),
        zh("Chinese (Mandarin)_Unrestrained_Young_Man", "不羁青年", "Unrestrained Young Man"),
        zh("Arrogant_Miss", "嚣张小姐", "Arrogant Miss"),
        zh("Robot_Armor", "机械战甲", "Robot Armor"),
        zh("Chinese (Mandarin)_Kind-hearted_Antie", "热心大婶", "Kind-hearted Auntie"),
        zh("Chinese (Mandarin)_HK_Flight_Attendant", "港普空姐", "HK Flight Attendant"),
        zh("Chinese (Mandarin)_Humorous_Elder", "搞笑大爷", "Humorous Elder"),
        zh("Chinese (Mandarin)_Gentleman", "温润男声", "Gentleman"),
        zh("Chinese (Mandarin)_Warm_Bestie", "温暖闺蜜", "Warm Bestie"),
        zh("Chinese (Mandarin)_Male_Announcer", "播报男声", "Male Announcer"),
        zh("Chinese (Mandarin)_Sweet_Lady", "甜美女声", "Sweet Lady"),
        zh("Chinese (Mandarin)_Southern_Young_Man", "南方小哥", "Southern Young Man"),
        zh("Chinese (Mandarin)_Wise_Women", "阅历姐姐", "Wise Woman"),
        zh("Chinese (Mandarin)_Gentle_Youth", "温润青年", "Gentle Youth"),
        zh("Chinese (Mandarin)_Warm_Girl", "温暖少女", "Warm Girl"),
        zh("Chinese (Mandarin)_Kind-hearted_Elder", "花甲奶奶", "Kind-hearted Elder"),
        zh("Chinese (Mandarin)_Cute_Spirit", "憨憨萌兽", "Cute Spirit"),
        zh("Chinese (Mandarin)_Radio_Host", "电台男主播", "Radio Host"),
        zh("Chinese (Mandarin)_Lyrical_Voice", "抒情男声", "Lyrical Voice"),
        zh("Chinese (Mandarin)_Straightforward_Boy", "率真弟弟", "Straightforward Boy"),
        zh("Chinese (Mandarin)_Sincere_Adult", "真诚青年", "Sincere Adult"),
        zh("Chinese (Mandarin)_Gentle_Senior", "温柔学姐", "Gentle Senior"),
        zh("Chinese (Mandarin)_Stubborn_Friend", "嘴硬竹马", "Stubborn Friend"),
        zh("Chinese (Mandarin)_Crisp_Girl", "清脆少女", "Crisp Girl"),
        zh("Chinese (Mandarin)_Pure-hearted_Boy", "清澈邻家弟弟", "Pure-hearted Boy"),
        zh("Chinese (Mandarin)_Soft_Girl", "柔和少女", "Soft Girl"),
        yue("Cantonese_ProfessionalHost（F)", "专业女主持", "Professional Host F"),
        yue("Cantonese_GentleLady", "温柔女声", "Gentle Lady"),
        yue("Cantonese_ProfessionalHost（M)", "专业男主持", "Professional Host M"),
        yue("Cantonese_PlayfulMan", "活泼男声", "Playful Man"),
        yue("Cantonese_CuteGirl", "可爱女孩", "Cute Girl"),
        yue("Cantonese_KindWoman", "善良女声", "Kind Woman"),
        .init(id: "English_Graceful_Lady",
              name: AppFlavor.text("English Graceful Lady · 英文女声", "English Graceful Lady"),
              note: "en")
    ]
}

enum VolcanoTTSError: Error {
    case notConfigured
    case http(Int, String)
    case api(Int, String)
    case noAudio
}

/// 火山引擎（豆包语音）TTS — HTTP non-streaming `/api/v1/tts`.
/// Auth header is the literal `Bearer;{token}` form; success is code 3000 with
/// base64 audio in `data`.
enum VolcanoTTS {

    static func synthesize(_ text: String) async throws -> Data {
        guard Settings.volcConfigured else { throw VolcanoTTSError.notConfigured }

        var req = URLRequest(url: URL(string: "https://openspeech.bytedance.com/api/v1/tts")!)
        req.httpMethod = "POST"
        req.setValue("Bearer;\(Settings.volcToken)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "app": [
                "appid": Settings.volcAppId,
                "token": Settings.volcToken,
                "cluster": Settings.volcCluster
            ],
            "user": ["uid": "guoerbuwang"],
            "audio": [
                "voice_type": Settings.volcVoice,
                "encoding": "mp3",
                "speed_ratio": Settings.volcSpeed
            ],
            "request": [
                "reqid": UUID().uuidString,
                "text": text,
                "text_type": "plain",
                "operation": "query"
            ]
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse else { throw VolcanoTTSError.noAudio }
        guard http.statusCode == 200 else {
            throw VolcanoTTSError.http(http.statusCode, String(data: data, encoding: .utf8) ?? "")
        }
        guard let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw VolcanoTTSError.noAudio
        }
        let code = (obj["code"] as? Int) ?? -1
        guard code == 3000,
              let b64 = obj["data"] as? String,
              let audio = Data(base64Encoded: b64) else {
            throw VolcanoTTSError.api(code, (obj["message"] as? String) ?? AppFlavor.text("未知错误", "Unknown error"))
        }
        return audio
    }
}
