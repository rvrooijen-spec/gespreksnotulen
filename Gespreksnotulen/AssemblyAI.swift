import Foundation
import Security

/// Uitschrijven via AssemblyAI (EU-endpoint: audio blijft in de EU).
struct AssemblyAIClient: Sendable {
    static let baseURL = URL(string: "https://api.eu.assemblyai.com")!

    let apiKey: String

    struct APIError: LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }

    enum Phase: Sendable {
        case uploading
        case transcribing
    }

    /// Nieuwste modellen eerst; AssemblyAI valt binnen één verzoek terug op het
    /// volgende model als het eerste geen Nederlands kan. Wordt een combinatie
    /// helemaal geweigerd, dan proberen we de volgende.
    private static let modelAttempts: [[String]?] = [
        ["universal-3-5-pro", "universal-2"],
        ["universal-3-pro", "universal-2"],
        ["universal-2"],
        nil,
    ]

    // MARK: - Uitschrijven

    func transcribe(
        fileURL: URL,
        expectedSpeakers: Int?,
        phase: @Sendable (Phase) -> Void,
        shouldContinue: @Sendable () -> Bool
    ) async throws -> [Utterance] {
        phase(.uploading)
        let uploadURL = try await upload(fileURL)
        guard shouldContinue() else { throw CancellationError() }

        phase(.transcribing)
        var lastError: Error = APIError(message: "Uitschrijven is niet gestart.")
        for models in Self.modelAttempts {
            let id: String
            do {
                id = try await createTranscript(audioURL: uploadURL, models: models, expectedSpeakers: expectedSpeakers)
            } catch let error as APIError where !error.message.contains("API-sleutel") {
                lastError = error   // dit model/deze instelling niet geaccepteerd: volgende proberen
                continue
            }
            while true {
                try await Task.sleep(for: .seconds(3))
                guard shouldContinue() else { throw CancellationError() }
                let result = try await transcript(id: id)
                switch result.status {
                case "completed":
                    return Self.makeUtterances(from: result)
                case "error":
                    lastError = APIError(message: result.error ?? "AssemblyAI gaf een fout.")
                default:
                    continue
                }
                break
            }
        }
        throw lastError
    }

    /// Controleert of de sleutel werkt (zonder kosten).
    func validateKey() async throws {
        var request = URLRequest(url: Self.baseURL.appendingPathComponent("v2/transcript"))
        request.url?.append(queryItems: [URLQueryItem(name: "limit", value: "1")])
        _ = try await send(request)
    }

    // MARK: - API

    private func upload(_ fileURL: URL) async throws -> String {
        var request = URLRequest(url: Self.baseURL.appendingPathComponent("v2/upload"))
        request.httpMethod = "POST"
        request.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 600
        let (data, response) = try await URLSession.shared.upload(for: request, fromFile: fileURL)
        try Self.check(response, data)
        struct Upload: Decodable { let upload_url: String }
        return try JSONDecoder().decode(Upload.self, from: data).upload_url
    }

    private func createTranscript(audioURL: String, models: [String]?, expectedSpeakers: Int?) async throws -> String {
        var body: [String: Any] = [
            "audio_url": audioURL,
            "language_code": "nl",
            "speaker_labels": true,
        ]
        if let models { body["speech_models"] = models }
        if let expectedSpeakers { body["speakers_expected"] = expectedSpeakers }
        var request = URLRequest(url: Self.baseURL.appendingPathComponent("v2/transcript"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let data = try await send(request)
        struct Created: Decodable { let id: String }
        return try JSONDecoder().decode(Created.self, from: data).id
    }

    private func transcript(id: String) async throws -> TranscriptResponse {
        let request = URLRequest(url: Self.baseURL.appendingPathComponent("v2/transcript/\(id)"))
        return try JSONDecoder().decode(TranscriptResponse.self, from: try await send(request))
    }

    private func send(_ request: URLRequest) async throws -> Data {
        var request = request
        request.setValue(apiKey, forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 60
        let (data, response) = try await URLSession.shared.data(for: request)
        try Self.check(response, data)
        return data
    }

    private static func check(_ response: URLResponse, _ data: Data) throws {
        guard let http = response as? HTTPURLResponse else { return }
        switch http.statusCode {
        case 200..<300:
            return
        case 401, 403:
            throw APIError(message: "De AssemblyAI API-sleutel is ongeldig. Controleer hem in Instellingen.")
        default:
            struct Failure: Decodable { let error: String? }
            let detail = (try? JSONDecoder().decode(Failure.self, from: data))?.error
                ?? String(data: data, encoding: .utf8) ?? ""
            throw APIError(message: "AssemblyAI (\(http.statusCode)): \(detail)")
        }
    }

    // MARK: - Resultaat

    struct TranscriptResponse: Decodable {
        struct Item: Decodable {
            let speaker: String?
            let start: Double
            let end: Double
            let text: String
        }
        let status: String
        let error: String?
        let text: String?
        let utterances: [Item]?
    }

    /// Sprekers A, B, ... worden 1, 2, ... op volgorde van eerste keer spreken.
    static func makeUtterances(from result: TranscriptResponse) -> [Utterance] {
        var numbering: [String: Int] = [:]
        var utterances: [Utterance] = []
        for item in result.utterances ?? [] {
            let text = item.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { continue }
            var speaker: Int?
            if let label = item.speaker {
                if numbering[label] == nil { numbering[label] = numbering.count + 1 }
                speaker = numbering[label]
            }
            utterances.append(Utterance(speaker: speaker, start: item.start / 1000, end: item.end / 1000, text: text))
        }
        if utterances.isEmpty, let text = result.text?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty {
            utterances.append(Utterance(speaker: nil, start: 0, end: 0, text: text))
        }
        return utterances
    }
}

/// Veilige opslag van de API-sleutel in de iOS-sleutelhanger.
enum KeychainStore {
    private static let service = "nl.rvrooijen.notulen"
    private static let account = "assemblyai-api-key"

    static func read() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func save(_ value: String) {
        delete()
        let attributes: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: Data(value.utf8),
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        ]
        SecItemAdd(attributes as CFDictionary, nil)
    }

    static func delete() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)
    }
}
