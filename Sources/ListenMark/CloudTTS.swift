import CryptoKit
import Foundation

enum CloudTTSError: Error, CustomStringConvertible {
    case notConfigured(String)
    case invalidEndpoint(String)
    case http(String, Int, String)
    case api(String, String)
    case noAudio(String)

    var description: String {
        switch self {
        case .notConfigured(let provider):
            return "\(provider) not configured"
        case .invalidEndpoint(let value):
            return "Invalid endpoint: \(value)"
        case .http(let provider, let status, let body):
            return "\(provider) HTTP \(status): \(body)"
        case .api(let provider, let message):
            return "\(provider) API error: \(message)"
        case .noAudio(let provider):
            return "\(provider) returned no audio"
        }
    }
}

enum CloudTTSProvider: String {
    case volcano
    case microsoft
    case google
    case tencent

    var displayName: String {
        switch self {
        case .volcano: return AppFlavor.text("火山引擎", "Volcengine")
        case .microsoft: return AppFlavor.text("Microsoft 语音合成", "Microsoft Speech")
        case .google: return AppFlavor.text("Google 语音合成", "Google Text-to-Speech")
        case .tencent: return AppFlavor.text("腾讯云语音合成", "Tencent Cloud TTS")
        }
    }

    func isConfigured() -> Bool {
        switch self {
        case .volcano: return Settings.volcConfigured
        case .microsoft: return Settings.microsoftTTSConfigured
        case .google: return Settings.googleTTSConfigured
        case .tencent: return Settings.tencentTTSConfigured
        }
    }

    func maxCharacters(for text: String) -> Int? {
        let hasCJK = text.containsCJK
        switch self {
        case .volcano:
            return hasCJK ? 500 : 1_200
        case .microsoft:
            return hasCJK ? 800 : 1_800
        case .google:
            return hasCJK ? 800 : 1_800
        case .tencent:
            return hasCJK ? 140 : 450
        }
    }

    func synthesize(_ text: String) async throws -> Data {
        switch self {
        case .volcano:
            return try await VolcanoTTS.synthesize(text)
        case .microsoft:
            return try await MicrosoftTTS.synthesize(text)
        case .google:
            return try await GoogleTTS.synthesize(text)
        case .tencent:
            return try await TencentTTS.synthesize(text)
        }
    }
}

enum CloudTTS {
    static func currentProvider() -> CloudTTSProvider? {
        guard let provider = CloudTTSProvider(rawValue: Settings.ttsEngine), provider.isConfigured() else {
            return nil
        }
        return provider
    }

    static func synthesize(_ text: String, provider: CloudTTSProvider) async throws -> [Data] {
        let chunks = textChunks(text, provider: provider)
        var audio: [Data] = []
        for chunk in chunks {
            audio.append(try await provider.synthesize(chunk))
        }
        return audio
    }

    static func textChunks(_ text: String, provider: CloudTTSProvider) -> [String] {
        TTSChunker.chunks(text, maxCharacters: provider.maxCharacters(for: text))
    }
}

private enum MicrosoftTTS {
    static func synthesize(_ text: String) async throws -> Data {
        let key = Settings.microsoftTTSKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let region = Settings.microsoftTTSRegion.trimmingCharacters(in: .whitespacesAndNewlines)
        let voice = Settings.microsoftTTSVoice.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty, !region.isEmpty, !voice.isEmpty else {
            throw CloudTTSError.notConfigured("Microsoft")
        }
        guard let endpoint = microsoftEndpoint(from: region) else {
            throw CloudTTSError.invalidEndpoint(region)
        }

        var req = URLRequest(url: endpoint)
        req.httpMethod = "POST"
        req.setValue(key, forHTTPHeaderField: "Ocp-Apim-Subscription-Key")
        req.setValue("application/ssml+xml", forHTTPHeaderField: "Content-Type")
        req.setValue("audio-24khz-48kbitrate-mono-mp3", forHTTPHeaderField: "X-Microsoft-OutputFormat")
        req.setValue("Dob", forHTTPHeaderField: "User-Agent")
        req.httpBody = ssml(text: text, voice: voice).data(using: .utf8)

        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse else { throw CloudTTSError.noAudio("Microsoft") }
        guard (200..<300).contains(http.statusCode) else {
            throw CloudTTSError.http("Microsoft", http.statusCode, String(data: data, encoding: .utf8) ?? "")
        }
        guard !data.isEmpty else { throw CloudTTSError.noAudio("Microsoft") }
        return data
    }

    private static func microsoftEndpoint(from regionOrEndpoint: String) -> URL? {
        if regionOrEndpoint.lowercased().hasPrefix("http") {
            let trimmed = regionOrEndpoint.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            if trimmed.hasSuffix("/cognitiveservices/v1") {
                return URL(string: trimmed)
            }
            return URL(string: "\(trimmed)/cognitiveservices/v1")
        }
        return URL(string: "https://\(regionOrEndpoint).tts.speech.microsoft.com/cognitiveservices/v1")
    }

    private static func ssml(text: String, voice: String) -> String {
        let language = TTSVoiceLanguage.infer(from: voice, fallback: text.containsCJK ? "zh-CN" : "en-US")
        return """
        <speak version="1.0" xml:lang="\(language)" xmlns="http://www.w3.org/2001/10/synthesis">
          <voice xml:lang="\(language)" name="\(voice.xmlEscaped)">\(text.xmlEscaped)</voice>
        </speak>
        """
    }
}

private enum GoogleTTS {
    static func synthesize(_ text: String) async throws -> Data {
        let key = Settings.googleTTSKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let voice = Settings.googleTTSVoice.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty, !voice.isEmpty else {
            throw CloudTTSError.notConfigured("Google")
        }
        var components = URLComponents(string: "https://texttospeech.googleapis.com/v1/text:synthesize")!
        if !key.lowercased().hasPrefix("bearer ") {
            components.queryItems = [URLQueryItem(name: "key", value: key)]
        }
        guard let url = components.url else { throw CloudTTSError.invalidEndpoint("Google Text-to-Speech") }

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
        if key.lowercased().hasPrefix("bearer ") {
            req.setValue(key, forHTTPHeaderField: "Authorization")
        }
        let language = TTSVoiceLanguage.infer(from: voice, fallback: text.containsCJK ? "cmn-CN" : "en-US")
        let body: [String: Any] = [
            "input": ["text": text],
            "voice": [
                "languageCode": language,
                "name": voice
            ],
            "audioConfig": [
                "audioEncoding": "MP3",
                "speakingRate": Settings.googleTTSSpeed
            ]
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse else { throw CloudTTSError.noAudio("Google") }
        guard (200..<300).contains(http.statusCode) else {
            throw CloudTTSError.http("Google", http.statusCode, String(data: data, encoding: .utf8) ?? "")
        }
        guard let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let b64 = obj["audioContent"] as? String,
              let audio = Data(base64Encoded: b64) else {
            throw CloudTTSError.noAudio("Google")
        }
        return audio
    }
}

private enum TencentTTS {
    private static let algorithm = "TC3-HMAC-SHA256"
    private static let service = "tts"
    private static let version = "2019-08-23"
    private static let action = "TextToVoice"
    private static let contentType = "application/json; charset=utf-8"

    static func synthesize(_ text: String) async throws -> Data {
        let secretId = Settings.tencentTTSSecretId.trimmingCharacters(in: .whitespacesAndNewlines)
        let secretKey = Settings.tencentTTSSecretKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let host = Settings.tencentTTSHost.trimmingCharacters(in: .whitespacesAndNewlines)
        let region = Settings.tencentTTSRegion.trimmingCharacters(in: .whitespacesAndNewlines)
        let voice = Int(Settings.tencentTTSVoice.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 1001
        guard !secretId.isEmpty, !secretKey.isEmpty, !host.isEmpty, !region.isEmpty else {
            throw CloudTTSError.notConfigured("Tencent")
        }

        let body: [String: Any] = [
            "Text": text,
            "SessionId": UUID().uuidString,
            "Volume": 0,
            "Speed": Settings.tencentTTSSpeed,
            "ProjectId": 0,
            "ModelType": 1,
            "VoiceType": voice,
            "PrimaryLanguage": text.containsCJK ? 1 : 2,
            "SampleRate": 16000,
            "Codec": "mp3",
            "EnableSubtitle": false
        ]
        let payload = try JSONSerialization.data(withJSONObject: body)
        let timestamp = Int(Date().timeIntervalSince1970)
        let authorization = authorization(secretId: secretId,
                                          secretKey: secretKey,
                                          host: host,
                                          timestamp: timestamp,
                                          payload: payload)

        var req = URLRequest(url: URL(string: "https://\(host)")!)
        req.httpMethod = "POST"
        req.setValue(authorization, forHTTPHeaderField: "Authorization")
        req.setValue(contentType, forHTTPHeaderField: "Content-Type")
        req.setValue(host, forHTTPHeaderField: "Host")
        req.setValue(action, forHTTPHeaderField: "X-TC-Action")
        req.setValue(region, forHTTPHeaderField: "X-TC-Region")
        req.setValue(String(timestamp), forHTTPHeaderField: "X-TC-Timestamp")
        req.setValue(version, forHTTPHeaderField: "X-TC-Version")
        req.httpBody = payload

        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse else { throw CloudTTSError.noAudio("Tencent") }
        guard (200..<300).contains(http.statusCode) else {
            throw CloudTTSError.http("Tencent", http.statusCode, String(data: data, encoding: .utf8) ?? "")
        }
        let decoded = try JSONDecoder().decode(TencentTextToVoiceResponse.self, from: data)
        if let error = decoded.response.error {
            throw CloudTTSError.api("Tencent", "\(error.code): \(error.message)")
        }
        guard let b64 = decoded.response.audio,
              let audio = Data(base64Encoded: b64) else {
            throw CloudTTSError.noAudio("Tencent")
        }
        return audio
    }

    private static func authorization(secretId: String,
                                      secretKey: String,
                                      host: String,
                                      timestamp: Int,
                                      payload: Data) -> String {
        let signedHeaders = "content-type;host"
        let canonicalHeaders = "content-type:\(contentType)\n" + "host:\(host)\n"
        let canonicalRequest = [
            "POST",
            "/",
            "",
            canonicalHeaders,
            signedHeaders,
            payload.sha256Hex
        ].joined(separator: "\n")
        let date = UTCDateFormatter.yyyyMMdd(fromUnixTimestamp: timestamp)
        let credentialScope = "\(date)/\(service)/tc3_request"
        let stringToSign = [
            algorithm,
            String(timestamp),
            credentialScope,
            canonicalRequest.utf8Data.sha256Hex
        ].joined(separator: "\n")
        let secretDate = Data.hmacSHA256(key: ("TC3" + secretKey).utf8Data, message: date)
        let secretService = Data.hmacSHA256(key: secretDate, message: service)
        let secretSigning = Data.hmacSHA256(key: secretService, message: "tc3_request")
        let signature = Data.hmacSHA256(key: secretSigning, message: stringToSign).hexString
        return "\(algorithm) Credential=\(secretId)/\(credentialScope), SignedHeaders=\(signedHeaders), Signature=\(signature)"
    }
}

private struct TencentTextToVoiceResponse: Decodable {
    let response: Body

    enum CodingKeys: String, CodingKey {
        case response = "Response"
    }

    struct Body: Decodable {
        let audio: String?
        let error: TencentError?

        enum CodingKeys: String, CodingKey {
            case audio = "Audio"
            case error = "Error"
        }
    }

    struct TencentError: Decodable {
        let code: String
        let message: String

        enum CodingKeys: String, CodingKey {
            case code = "Code"
            case message = "Message"
        }
    }
}

private enum TTSChunker {
    static func chunks(_ text: String, maxCharacters: Int?) -> [String] {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let maxCharacters, trimmed.count > maxCharacters else { return [trimmed].filter { !$0.isEmpty } }
        var chunks: [String] = []
        var current = ""
        let preferredBreaks = CharacterSet(charactersIn: "。！？!?；;")
        let hardBreaks = CharacterSet.newlines
        let softMinimum = min(maxCharacters, max(80, maxCharacters / 3))

        func flush() {
            let value = current.trimmingCharacters(in: .whitespacesAndNewlines)
            if !value.isEmpty { chunks.append(value) }
            current = ""
        }

        for char in trimmed {
            current.append(char)
            if current.count >= maxCharacters {
                flush()
            } else if char.unicodeScalars.contains(where: { hardBreaks.contains($0) }) {
                flush()
            } else if current.count >= softMinimum,
                      char.unicodeScalars.contains(where: { preferredBreaks.contains($0) }) {
                flush()
            }
        }
        flush()
        return chunks
    }
}

private enum TTSVoiceLanguage {
    static func infer(from voice: String, fallback: String) -> String {
        let parts = voice.split(separator: "-")
        guard parts.count >= 2 else { return fallback }
        return parts.prefix(2).joined(separator: "-")
    }
}

private enum UTCDateFormatter {
    static func yyyyMMdd(fromUnixTimestamp timestamp: Int) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date(timeIntervalSince1970: TimeInterval(timestamp)))
    }
}

private extension String {
    var utf8Data: Data { Data(utf8) }

    var xmlEscaped: String {
        replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }
}

private extension Data {
    var sha256Hex: String {
        Data(SHA256.hash(data: self)).hexString
    }

    var hexString: String {
        map { String(format: "%02x", $0) }.joined()
    }

    static func hmacSHA256(key: Data, message: String) -> Data {
        let signature = HMAC<SHA256>.authenticationCode(for: message.utf8Data,
                                                        using: SymmetricKey(data: key))
        return Data(signature)
    }
}
