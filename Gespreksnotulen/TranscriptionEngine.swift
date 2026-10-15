import Foundation
import UIKit
import AVFoundation

/// Beheert de wachtrij van opnames die uitgeschreven moeten worden en vertaalt
/// de voortgang van `TranscriptionPipeline` naar de UI.
@MainActor
final class TranscriptionEngine: ObservableObject {
    enum ModelState: Equatable {
        case notDownloaded
        case downloading(String, Double?)   // omschrijving, voortgang 0...1
        case loading
        case ready
        case failed(String)
    }

    @Published private(set) var modelState: ModelState = .notDownloaded
    @Published private(set) var currentRecordingID: UUID?
    @Published private(set) var phase = ""
    @Published private(set) var progress: Double?

    private let pipeline: TranscriptionPipeline
    private let keepAlive = BackgroundKeepAlive()
    private var queue: [UUID] = []
    private var isWorking = false
    private var suspendCount = 0
    private let cancelFlag = CancelFlag()
    private var wentToBackgroundDuringJob = false
    private weak var store: RecordingStore?

    init() {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        var modelsURL = support.appendingPathComponent("Modellen", isDirectory: true)
        try? FileManager.default.createDirectory(at: modelsURL, withIntermediateDirectories: true)
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try? modelsURL.setResourceValues(values)
        pipeline = TranscriptionPipeline(modelsURL: modelsURL)

        NotificationCenter.default.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in
                if self?.isWorking == true { self?.wentToBackgroundDuringJob = true }
            }
        }
        NotificationCenter.default.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.processPending() }
        }
    }

    var modelsDownloaded: Bool { pipeline.whisperFolder != nil }

    func attach(store: RecordingStore) {
        self.store = store
        if modelsDownloaded, modelState == .notDownloaded {
            modelState = .ready
        }
        processPending()
    }

    // MARK: - Modellen

    func downloadModels() async {
        switch modelState {
        case .downloading, .loading: return
        default: break
        }
        do {
            try await prepareModels()
            processPending()
        } catch {
            modelState = .failed(error.localizedDescription)
        }
    }

    private func prepareModels() async throws {
        if pipeline.isLoaded {
            modelState = .ready
            return
        }
        try await pipeline.prepare { status in
            Task { @MainActor [weak self] in
                switch status {
                case .downloadingSpeech(let fraction):
                    self?.modelState = .downloading("Spraakmodel downloaden", fraction)
                case .downloadingSpeakers:
                    self?.modelState = .downloading("Sprekermodel downloaden", nil)
                case .loading:
                    self?.modelState = .loading
                }
            }
        }
        modelState = .ready
    }

    func deleteModels() async {
        await pipeline.deleteModels()
        modelState = .notDownloaded
    }

    // MARK: - Wachtrij

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

    /// Zet alle nog niet uitgeschreven opnames in de wachtrij (bijv. opnames die
    /// gemaakt zijn voordat de modellen gedownload waren).
    func processPending() {
        guard modelsDownloaded, let store else { return }
        for rec in store.recordings.reversed() where rec.status == .recorded {
            enqueue(rec)
        }
    }

    /// Pauzeert het uitschrijven, bijv. tijdens een nieuwe opname: zo concurreren
    /// opnemen en rekenen niet om geheugen en kan een crash geen opname kosten.
    func suspend() {
        suspendCount += 1
        if let current = currentRecordingID {
            cancelFlag.set(true)
            // Na het afbreken opnieuw vooraan in de wachtrij.
            if !queue.contains(current) { queue.insert(current, at: 0) }
        }
    }

    func resume() {
        suspendCount = max(0, suspendCount - 1)
        if suspendCount == 0 {
            Task { await processQueue() }
        }
    }

    private func processQueue() async {
        guard !isWorking, suspendCount == 0, !queue.isEmpty else { return }
        isWorking = true
        cancelFlag.set(false)
        wentToBackgroundDuringJob = false
        UIApplication.shared.isIdleTimerDisabled = true
        keepAlive.start()
        let backgroundTask = UIApplication.shared.beginBackgroundTask(withName: "Uitschrijven")
        defer {
            isWorking = false
            currentRecordingID = nil
            phase = ""
            progress = nil
            keepAlive.stop()
            UIApplication.shared.isIdleTimerDisabled = false
            UIApplication.shared.endBackgroundTask(backgroundTask)
        }

        while !queue.isEmpty, suspendCount == 0 {
            let id = queue.removeFirst()
            guard let store, let recording = store.recording(withID: id) else { continue }
            currentRecordingID = id
            cancelFlag.set(false)
            do {
                phase = "Modellen voorbereiden"
                progress = nil
                try await prepareModels()
                let utterances = try await run(recording, audioURL: store.audioURL(for: recording))
                store.update(id) {
                    $0.utterances = utterances
                    $0.status = .done
                    $0.errorMessage = nil
                }
            } catch is CancellationError {
                // Gepauzeerd voor een opname: staat al opnieuw in de wachtrij.
                store.update(id) { $0.status = .processing }
            } catch {
                if case .failed = modelState {} else if !pipeline.isLoaded {
                    modelState = .failed(error.localizedDescription)
                }
                if wentToBackgroundDuringJob {
                    // iOS kan rekenwerk weigeren als de app op de achtergrond staat;
                    // dan opnieuw proberen zodra de app weer open is.
                    store.update(id) {
                        $0.status = .recorded
                        $0.errorMessage = nil
                    }
                } else {
                    store.update(id) {
                        $0.status = .failed
                        $0.errorMessage = error.localizedDescription
                    }
                }
            }
        }
    }

    private func run(_ recording: Recording, audioURL: URL) async throws -> [Utterance] {
        let path = audioURL.path
        let expected = recording.expectedSpeakers
        let flag = cancelFlag
        let pipeline = pipeline
        let throttle = ProgressThrottle()
        return try await Task.detached(priority: .userInitiated) {
            try await pipeline.transcribe(
                audioPath: path,
                expectedSpeakers: expected,
                phase: { phase in
                    guard throttle.shouldReport(phase) else { return }
                    Task { @MainActor [weak self] in self?.show(phase) }
                },
                shouldContinue: { !flag.value }
            )
        }.value
    }

    private func show(_ phase: TranscriptionPipeline.Phase) {
        switch phase {
        case .loadingAudio:
            self.phase = "Audio inladen"
            progress = nil
        case .transcribing(let fraction):
            self.phase = "Tekst uitschrijven"
            progress = fraction
        case .diarizing(let fraction):
            self.phase = "Sprekers herkennen"
            progress = fraction
        case .merging:
            self.phase = "Samenvoegen"
            progress = nil
        }
    }
}

/// Thread-veilige vlag om een lopende verwerking af te breken.
final class CancelFlag: @unchecked Sendable {
    private let lock = NSLock()
    private var flag = false
    var value: Bool { lock.lock(); defer { lock.unlock() }; return flag }
    func set(_ newValue: Bool) { lock.lock(); flag = newValue; lock.unlock() }
}

/// Voorkomt dat elke token een UI-update veroorzaakt.
final class ProgressThrottle: @unchecked Sendable {
    private let lock = NSLock()
    private var last = Date.distantPast

    func shouldReport(_ phase: TranscriptionPipeline.Phase) -> Bool {
        switch phase {
        case .transcribing, .diarizing:
            lock.lock(); defer { lock.unlock() }
            let now = Date()
            guard now.timeIntervalSince(last) > 0.3 else { return false }
            last = now
            return true
        default:
            return true
        }
    }
}

/// Speelt stilte af zolang er wordt uitgeschreven, zodat iOS de app niet
/// pauzeert als het scherm uitgaat (de app heeft de achtergrondmodus "audio").
/// Mengt met andere audio, dus muziek of podcasts van de gebruiker blijven spelen.
@MainActor
final class BackgroundKeepAlive {
    private var player: AVAudioPlayer?

    func start() {
        guard player == nil else { return }
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
            let player = try AVAudioPlayer(data: Self.silentWAV())
            player.numberOfLoops = -1
            player.volume = 0
            player.play()
            self.player = player
        } catch {
            player = nil
        }
    }

    func stop() {
        player?.stop()
        player = nil
    }

    /// Eén seconde stilte als WAV (8 kHz, 16-bit mono).
    private static func silentWAV() -> Data {
        let sampleRate: UInt32 = 8_000
        let dataSize = sampleRate * 2
        var data = Data()
        func append<T: FixedWidthInteger>(_ value: T) {
            withUnsafeBytes(of: value.littleEndian) { data.append(contentsOf: $0) }
        }
        data.append(contentsOf: Array("RIFF".utf8)); append(UInt32(36 + dataSize))
        data.append(contentsOf: Array("WAVE".utf8))
        data.append(contentsOf: Array("fmt ".utf8)); append(UInt32(16)); append(UInt16(1)); append(UInt16(1))
        append(sampleRate); append(sampleRate * 2); append(UInt16(2)); append(UInt16(16))
        data.append(contentsOf: Array("data".utf8)); append(dataSize)
        data.append(Data(count: Int(dataSize)))
        return data
    }
}
