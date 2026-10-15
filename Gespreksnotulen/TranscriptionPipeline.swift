import Foundation
import CoreML
import WhisperKit
import SpeakerKit

/// De rekenkern: modellen downloaden/laden, tekst uitschrijven, sprekers bepalen
/// en alles samenvoegen tot uitspraken. Bevat geen UI-code, zodat dezelfde code
/// ook op een Mac in GitHub Actions getest kan worden (zie PipelineTest/).
final class TranscriptionPipeline: @unchecked Sendable {
    enum PrepareStatus: Sendable {
        case downloadingSpeech(Double)
        case downloadingSpeakers
        case loading
    }

    /// Nauwkeurigste meertalige model dat Argmax aanraadt voor iPhone (~630 MB).
    static let whisperModel = "large-v3-v20240930_626MB"

    let modelsURL: URL
    private let defaults: UserDefaults
    private let whisperFolderKey = "whisperModelFolder"

    private var whisperKit: WhisperKit?
    private var speakerKit: SpeakerKit?

    init(modelsURL: URL, defaults: UserDefaults = .standard) {
        self.modelsURL = modelsURL
        self.defaults = defaults
        try? FileManager.default.createDirectory(at: modelsURL, withIntermediateDirectories: true)
    }

    var isLoaded: Bool { whisperKit != nil && speakerKit != nil }

    /// Map van het gedownloade Whisper-model. Opgeslagen relatief t.o.v. de
    /// modellenmap, want het absolute pad van de app-container kan veranderen.
    var whisperFolder: URL? {
        guard let relative = defaults.string(forKey: whisperFolderKey) else { return nil }
        let url = modelsURL.appendingPathComponent(relative, isDirectory: true)
        let contents = (try? FileManager.default.contentsOfDirectory(atPath: url.path)) ?? []
        return contents.contains(where: { $0.hasSuffix(".mlmodelc") }) ? url : nil
    }

    /// Downloadt (indien nodig) en laadt beide modellen.
    func prepare(status: @escaping @Sendable (PrepareStatus) -> Void) async throws {
        if isLoaded { return }

        var folder = whisperFolder
        if folder == nil {
            status(.downloadingSpeech(0))
            let downloaded = try await WhisperKit.download(
                variant: Self.whisperModel,
                downloadBase: modelsURL
            ) { progress in
                status(.downloadingSpeech(progress.fractionCompleted))
            }
            // Alleen het deel na ".../Modellen/" bewaren (iOS wisselt soms /var en /private/var).
            let components = downloaded.standardizedFileURL.pathComponents
            if let index = components.lastIndex(of: modelsURL.lastPathComponent) {
                defaults.set(components[(index + 1)...].joined(separator: "/"), forKey: whisperFolderKey)
            }
            folder = downloaded
        }

        if speakerKit == nil {
            status(.downloadingSpeakers)
            let config = PyannoteConfig(downloadBase: modelsURL.path, verbose: false)
            let kit = try await SpeakerKit(config)
            try await kit.ensureModelsLoaded()
            speakerKit = kit
        }

        if whisperKit == nil, let folder {
            status(.loading)
            let config = WhisperKitConfig(
                downloadBase: modelsURL,
                modelFolder: folder.path,
                // Geen GPU: iOS verbiedt GPU-werk zodra de app op de achtergrond staat
                // (scherm uit). Neural Engine en CPU mogen wel.
                computeOptions: ModelComputeOptions(
                    melCompute: .cpuOnly,
                    audioEncoderCompute: .cpuAndNeuralEngine,
                    textDecoderCompute: .cpuAndNeuralEngine
                ),
                verbose: false,
                prewarm: true,
                load: true,
                download: false
            )
            whisperKit = try await WhisperKit(config)
        }
    }

    func unload() async {
        whisperKit = nil
        await speakerKit?.unloadModels()
        speakerKit = nil
    }

    func deleteModels() async {
        await unload()
        defaults.removeObject(forKey: whisperFolderKey)
        try? FileManager.default.removeItem(at: modelsURL)
        try? FileManager.default.createDirectory(at: modelsURL, withIntermediateDirectories: true)
    }

    // MARK: - Uitschrijven

    enum Phase: Sendable {
        case loadingAudio
        case transcribing(Double)
        case diarizing(Double)
        case merging
    }

    struct PipelineError: LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }

    /// Schrijft een audiobestand uit met sprekers.
    /// - Parameter shouldContinue: wordt regelmatig aangeroepen; geef `false` terug om te stoppen.
    func transcribe(
        audioPath: String,
        expectedSpeakers: Int?,
        chunking: ChunkingStrategy = .vad,
        phase: @escaping @Sendable (Phase) -> Void,
        shouldContinue: @escaping @Sendable () -> Bool
    ) async throws -> [Utterance] {
        guard let whisperKit, let speakerKit else {
            throw PipelineError(message: "Modellen zijn niet geladen.")
        }

        phase(.loadingAudio)
        let audio = try AudioProcessor.loadAudioAsFloatArray(fromPath: audioPath)
        guard audio.count > 16_000 / 2 else {
            throw PipelineError(message: "De opname is leeg of korter dan een halve seconde.")
        }
        try checkContinue(shouldContinue)

        // 1. Tekst
        phase(.transcribing(0))
        let decodeOptions = DecodingOptions(
            task: .transcribe,
            language: "nl",
            temperatureFallbackCount: 3,
            usePrefillPrompt: true,
            detectLanguage: false,
            skipSpecialTokens: true,
            wordTimestamps: true,
            chunkingStrategy: chunking
        )
        let progress = whisperKit.progress
        let callback: TranscriptionCallback = { _ in
            phase(.transcribing(progress.fractionCompleted))
            return shouldContinue() ? nil : false
        }
        let transcription = try await Self.withoutGPU {
            try await whisperKit.transcribe(audioArray: audio, decodeOptions: decodeOptions, callback: callback)
        }
        try checkContinue(shouldContinue)

        // 2. Sprekers
        phase(.diarizing(0))
        let diarizeOptions = PyannoteDiarizationOptions(numberOfSpeakers: expectedSpeakers)
        let diarization = try await speakerKit.diarize(audioArray: audio, options: diarizeOptions) { p in
            phase(.diarizing(p.fractionCompleted))
        }
        try checkContinue(shouldContinue)

        // 3. Samenvoegen
        phase(.merging)
        let segments = diarization.addSpeakerInfo(to: transcription).flatMap { $0 }
        let parts = segments.map { segment in
            Part(
                rawSpeaker: segment.speaker.speakerId ?? segment.speaker.speakerIds.first,
                start: Double(segment.speakerWords.first?.wordTiming.start ?? segment.startTime),
                end: Double(segment.speakerWords.last?.wordTiming.end ?? segment.endTime),
                text: segment.text
            )
        }
        return Self.makeUtterances(from: parts)
    }

    private func checkContinue(_ shouldContinue: () -> Bool) throws {
        if !shouldContinue() { throw CancellationError() }
    }

    /// Laat MLTensor-berekeningen (iOS 18+) op de CPU draaien in plaats van de GPU.
    private static func withoutGPU<T>(_ body: () async throws -> T) async throws -> T {
        if #available(iOS 18.0, macOS 15.0, *) {
            return try await withMLTensorComputePolicy(MLComputePolicy(.cpuOnly)) {
                try await body()
            }
        }
        return try await body()
    }

    // MARK: - Samenvoegen

    /// Een stukje tekst met de (ruwe) spreker-id van SpeakerKit.
    struct Part: Sendable {
        var rawSpeaker: Int?
        var start: Double
        var end: Double
        var text: String
    }

    /// Voegt opeenvolgende stukjes van dezelfde spreker samen, filtert bekende
    /// Whisper-hallucinaties en nummert sprekers op volgorde van eerste keer
    /// spreken (Spreker 1, 2, ...).
    static func makeUtterances(from parts: [Part]) -> [Utterance] {
        var numbering: [Int: Int] = [:]
        var result: [Utterance] = []

        for part in parts {
            let text = part.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty, !isHallucination(text) else { continue }

            var speaker: Int?
            if let raw = part.rawSpeaker {
                if numbering[raw] == nil { numbering[raw] = numbering.count + 1 }
                speaker = numbering[raw]
            }

            if var last = result.last, last.speaker == speaker, part.start - last.end < 3 {
                last.text += " " + text
                last.end = max(last.end, part.end)
                result[result.count - 1] = last
            } else {
                result.append(Utterance(speaker: speaker, start: part.start, end: part.end, text: text))
            }
        }
        return result
    }

    /// Zinnen die Whisper bij stilte of ruis vaak "verzint" in het Nederlands
    /// (overgehouden aan ondertitels in de trainingsdata).
    static let hallucinationMarkers = [
        "amara.org",
        "ondertiteld door",
        "ondertiteling door",
        "ondertitels ingediend door",
        "bedankt voor het kijken",
        "bedankt voor het luisteren",
        "tv gelderland",
        "abonneer op het kanaal",
        "vergeet niet te abonneren",
    ]

    static func isHallucination(_ text: String) -> Bool {
        let lower = text.lowercased()
        return hallucinationMarkers.contains { lower.contains($0) }
    }
}
