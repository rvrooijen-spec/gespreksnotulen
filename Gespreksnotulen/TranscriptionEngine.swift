import Foundation
import UIKit
import WhisperKit
import SpeakerKit

/// Zet opnames om naar tekst (WhisperKit) en bepaalt wie wat zei (SpeakerKit).
/// Alles draait op de iPhone zelf; alleen het eenmalig downloaden van de modellen
/// gebruikt internet.
@MainActor
final class TranscriptionEngine: ObservableObject {
    enum ModelState: Equatable {
        case notDownloaded
        case downloading(String, Double?)   // omschrijving, voortgang 0...1
        case loading
        case ready
        case failed(String)
    }

    /// Nauwkeurigste meertalige model dat Argmax aanraadt voor iPhone (~630 MB).
    static let whisperModel = "large-v3-v20240930_626MB"

    @Published private(set) var modelState: ModelState = .notDownloaded
    @Published private(set) var currentRecordingID: UUID?
    @Published private(set) var phase = ""
    @Published private(set) var progress: Double?

    private var whisperKit: WhisperKit?
    private var speakerKit: SpeakerKit?
    private var queue: [UUID] = []
    private var isWorking = false
    private weak var store: RecordingStore?

    private let modelsURL: URL = {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let url = support.appendingPathComponent("Modellen", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        var mutable = url
        try? mutable.setResourceValues(values)
        return url
    }()

    private let whisperFolderKey = "whisperModelFolder"

    /// Pad van het gedownloade Whisper-model, relatief t.o.v. de modellenmap
    /// (het absolute pad van de app-container kan veranderen na herinstallatie).
    private var whisperFolder: URL? {
        guard let relative = UserDefaults.standard.string(forKey: whisperFolderKey) else { return nil }
        let url = modelsURL.appendingPathComponent(relative, isDirectory: true)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    var modelsDownloaded: Bool { whisperFolder != nil }

    func attach(store: RecordingStore) {
        self.store = store
        if modelsDownloaded, modelState == .notDownloaded {
            modelState = .ready
        }
    }

    // MARK: - Modellen

    func downloadModels() async {
        if case .downloading = modelState { return }
        do {
            try await ensureModels()
        } catch {
            modelState = .failed(error.localizedDescription)
        }
    }

    private func ensureModels() async throws {
        if whisperKit != nil, speakerKit != nil {
            modelState = .ready
            return
        }

        var folder = whisperFolder
        if folder == nil {
            modelState = .downloading("Spraakmodel downloaden", 0)
            let downloaded = try await WhisperKit.download(
                variant: Self.whisperModel,
                downloadBase: modelsURL
            ) { progress in
                let fraction = progress.fractionCompleted
                Task { @MainActor [weak self] in
                    self?.modelState = .downloading("Spraakmodel downloaden", fraction)
                }
            }
            // Alleen het deel na ".../Modellen/" bewaren (iOS wisselt soms /var en /private/var).
            let components = downloaded.standardizedFileURL.pathComponents
            if let index = components.lastIndex(of: modelsURL.lastPathComponent) {
                let relative = components[(index + 1)...].joined(separator: "/")
                UserDefaults.standard.set(relative, forKey: whisperFolderKey)
            }
            folder = downloaded
        }

        if speakerKit == nil {
            modelState = .downloading("Sprekermodel downloaden", nil)
            let config = PyannoteConfig(downloadBase: modelsURL.path, verbose: false)
            let kit = try await SpeakerKit(config)
            try await kit.ensureModelsLoaded()
            speakerKit = kit
        }

        if whisperKit == nil, let folder {
            modelState = .loading
            let config = WhisperKitConfig(
                downloadBase: modelsURL,
                modelFolder: folder.path,
                verbose: false,
                prewarm: true,
                load: true,
                download: false
            )
            whisperKit = try await WhisperKit(config)
        }
        modelState = .ready
    }

    func deleteModels() async {
        whisperKit = nil
        await speakerKit?.unloadModels()
        speakerKit = nil
        UserDefaults.standard.removeObject(forKey: whisperFolderKey)
        try? FileManager.default.removeItem(at: modelsURL)
        try? FileManager.default.createDirectory(at: modelsURL, withIntermediateDirectories: true)
        modelState = .notDownloaded
    }

    // MARK: - Verwerken

    func isQueued(_ id: UUID) -> Bool {
        currentRecordingID == id || queue.contains(id)
    }

    func enqueue(_ recording: Recording) {
        guard !isQueued(recording.id) else { return }
        queue.append(recording.id)
        store?.update(recording.id) {
            $0.status = .processing
            $0.errorMessage = nil
        }
        Task { await processQueue() }
    }

    private func processQueue() async {
        guard !isWorking else { return }
        isWorking = true
        UIApplication.shared.isIdleTimerDisabled = true
        let backgroundTask = UIApplication.shared.beginBackgroundTask(withName: "Uitschrijven")
        defer {
            isWorking = false
            currentRecordingID = nil
            phase = ""
            progress = nil
            UIApplication.shared.isIdleTimerDisabled = false
            UIApplication.shared.endBackgroundTask(backgroundTask)
        }

        while !queue.isEmpty {
            let id = queue.removeFirst()
            guard let store, let recording = store.recording(withID: id) else { continue }
            currentRecordingID = id
            do {
                let utterances = try await transcribe(recording, audioURL: store.audioURL(for: recording))
                store.update(id) {
                    $0.utterances = utterances
                    $0.status = .done
                    $0.errorMessage = nil
                }
            } catch {
                store.update(id) {
                    $0.status = .failed
                    $0.errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func transcribe(_ recording: Recording, audioURL: URL) async throws -> [Utterance] {
        phase = "Modellen voorbereiden"
        progress = nil
        try await ensureModels()
        guard let whisperKit, let speakerKit else {
            throw NSError(domain: "Notulen", code: 2, userInfo: [NSLocalizedDescriptionKey: "Modellen zijn niet geladen."])
        }

        phase = "Audio inladen"
        let path = audioURL.path
        let audio = try await Task.detached(priority: .userInitiated) {
            try AudioProcessor.loadAudioAsFloatArray(fromPath: path)
        }.value
        guard !audio.isEmpty else {
            throw NSError(domain: "Notulen", code: 3, userInfo: [NSLocalizedDescriptionKey: "De opname is leeg."])
        }

        // 1. Tekst
        phase = "Tekst uitschrijven"
        progress = 0
        let decodeOptions = DecodingOptions(
            task: .transcribe,
            language: "nl",
            temperatureFallbackCount: 3,
            usePrefillPrompt: true,
            detectLanguage: false,
            skipSpecialTokens: true,
            wordTimestamps: true,
            chunkingStrategy: .vad
        )
        let progressTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                self?.progress = whisperKit.progress.fractionCompleted
                try? await Task.sleep(for: .milliseconds(500))
            }
        }
        defer { progressTask.cancel() }
        let transcription = try await whisperKit.transcribe(audioArray: audio, decodeOptions: decodeOptions)
        progressTask.cancel()

        // 2. Sprekers
        phase = "Sprekers herkennen"
        progress = 0
        let diarizeOptions = PyannoteDiarizationOptions(numberOfSpeakers: recording.expectedSpeakers)
        let diarization = try await speakerKit.diarize(audioArray: audio, options: diarizeOptions) { p in
            let fraction = p.fractionCompleted
            Task { @MainActor [weak self] in self?.progress = fraction }
        }

        // 3. Samenvoegen
        phase = "Samenvoegen"
        progress = nil
        let segments = diarization.addSpeakerInfo(to: transcription).flatMap { $0 }
        return Self.makeUtterances(from: segments)
    }

    /// Voegt opeenvolgende stukjes van dezelfde spreker samen en nummert de
    /// sprekers op volgorde van eerste keer spreken (Spreker 1, 2, ...).
    private static func makeUtterances(from segments: [SpeakerSegment]) -> [Utterance] {
        var numbering: [Int: Int] = [:]
        var result: [Utterance] = []

        for segment in segments {
            let text = segment.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { continue }

            var speaker: Int?
            if let rawID = segment.speaker.speakerId ?? segment.speaker.speakerIds.first {
                if numbering[rawID] == nil { numbering[rawID] = numbering.count + 1 }
                speaker = numbering[rawID]
            }
            let start = Double(segment.speakerWords.first?.wordTiming.start ?? segment.startTime)
            let end = Double(segment.speakerWords.last?.wordTiming.end ?? segment.endTime)

            if var last = result.last, last.speaker == speaker, start - last.end < 3 {
                last.text += " " + text
                last.end = end
                result[result.count - 1] = last
            } else {
                result.append(Utterance(speaker: speaker, start: start, end: end, text: text))
            }
        }
        return result
    }
}
