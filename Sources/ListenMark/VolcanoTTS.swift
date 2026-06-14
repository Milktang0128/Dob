import Foundation

struct VolcanoVoice: Identifiable {
    let id: String      // voice_type
    let name: String
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
