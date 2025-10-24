import Foundation

struct OpenAIError: Error, LocalizedError, Decodable {
    let message: String
    var errorDescription: String? { message }

    init(message: String) { self.message = message }
}

final class OpenAIClient {
    private let apiKey: String
    private let baseURL = URL(string: "https://api.openai.com/v1")!

    // 既定モデル（必要に応じて.envで上書き可能）
    private let chatModel: String
    private let ttsModel: String
    private let sttModel: String
    private let ttsVoice: String

    init?() {
        guard let key = Env.shared.string("OPENAI_API_KEY"), !key.isEmpty else { return nil }
        self.apiKey = key

        self.chatModel = Env.shared.string("OPENAI_CHAT_MODEL") ?? "gpt-4o-mini"
        // 2024年時点の安定モデル。新モデル(gpt-4o-mini-tts等)を使う場合は.envで指定。
        self.ttsModel = Env.shared.string("OPENAI_TTS_MODEL") ?? "tts-1"
        self.ttsVoice = Env.shared.string("OPENAI_TTS_VOICE") ?? "alloy"
        // 2024年時点の安定モデル。新モデル(gpt-4o-mini-transcribe等)は.envで指定。
        self.sttModel = Env.shared.string("OPENAI_STT_MODEL") ?? "whisper-1"
    }

    // Chat Completions (gpt-4o-mini)
    struct ChatRequestMessage: Codable {
        let role: String
        let content: String
    }

    struct ChatResponse: Codable {
        struct Choice: Codable {
            struct Message: Codable { let role: String; let content: String }
            let message: Message
        }
        let choices: [Choice]
    }

    func chat(messages: [ChatRequestMessage]) async throws -> String {
        var req = URLRequest(url: baseURL.appendingPathComponent("chat/completions"))
        req.httpMethod = "POST"
        req.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        req.addValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "model": chatModel,
            "messages": messages.map { ["role": $0.role, "content": $0.content] }
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse else { throw OpenAIError(message: "Invalid response") }
        if http.statusCode >= 300 {
            let text = String(data: data, encoding: .utf8) ?? ""
            throw OpenAIError(message: "Chat API error: \(http.statusCode) \n\(text)")
        }
        let decoded = try JSONDecoder().decode(ChatResponse.self, from: data)
        return decoded.choices.first?.message.content ?? ""
    }

    // Speech-to-Text (Audio Transcriptions)
    struct TranscriptionResponse: Codable { let text: String }

    func transcribe(fileURL: URL, language: String? = nil) async throws -> String {
        var req = URLRequest(url: baseURL.appendingPathComponent("audio/transcriptions"))
        req.httpMethod = "POST"
        req.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        // multipart/form-data
        let boundary = "Boundary-\(UUID().uuidString)"
        req.addValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        func appendForm(_ name: String, _ value: String) {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(value)\r\n".data(using: .utf8)!)
        }

        // model
        appendForm("model", sttModel)
        if let lang = language { appendForm("language", lang) }

        // file
        let fileData = try Data(contentsOf: fileURL)
        let filename = fileURL.lastPathComponent
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: audio/m4a\r\n\r\n".data(using: .utf8)!)
        body.append(fileData)
        body.append("\r\n".data(using: .utf8)!)

        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        req.httpBody = body

        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse else { throw OpenAIError(message: "Invalid response") }
        if http.statusCode >= 300 {
            let text = String(data: data, encoding: .utf8) ?? ""
            throw OpenAIError(message: "Transcription API error: \(http.statusCode) \n\(text)")
        }
        let decoded = try JSONDecoder().decode(TranscriptionResponse.self, from: data)
        return decoded.text
    }

    // Text-to-Speech
    func synthesize(text: String, format: String = "audio/mpeg") async throws -> Data {
        var req = URLRequest(url: baseURL.appendingPathComponent("audio/speech"))
        req.httpMethod = "POST"
        req.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        req.addValue("application/json", forHTTPHeaderField: "Content-Type")
        req.addValue(format, forHTTPHeaderField: "Accept")

        let body: [String: Any] = [
            "model": ttsModel,
            "voice": ttsVoice,
            "input": text
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse else { throw OpenAIError(message: "Invalid response") }
        if http.statusCode >= 300 {
            let text = String(data: data, encoding: .utf8) ?? ""
            throw OpenAIError(message: "TTS API error: \(http.statusCode) \n\(text)")
        }
        return data
    }
}
