import Foundation
import UIKit
import AVFoundation

/// Beheert de wachtrij van opnames die uitgeschreven moeten worden (via
/// AssemblyAI) en vertaalt de voortgang naar de UI.
@MainActor
final class TranscriptionEngine: ObservableObject {
    @Published private(set) var hasAPIKey = KeychainStore.read() != nil
    @Published private(set) var currentRecordingID: UUID?
    @Published private(set) var phase = ""
    @Published private(set) var progress: Double?

    private let keepAlive = BackgroundKeepAlive()
    private var queue: [UUID] = []
    private var isWorking = false
    private var suspendCount = 0
    private let cancelFlag = CancelFlag()
    private var wentToBackgroundDuringJob = false
    private weak var store: RecordingStore?

    init() {
        NotificationCenter.default.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in
                if self?.isWorking == true { self?.wentToBackgroundDuringJob = true }
            }
        }
        NotificationCenter.default.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.processPending() }
        }
    }

    /// Klaar om uit te schrijven (er is een API-sleutel).
    var isReady: Bool { hasAPIKey }

    func attach(store: RecordingStore) {
        self.store = store
        processPending()
    }

    // MARK: - API-sleutel

    /// Controleert de sleutel bij AssemblyAI en bewaart hem in de sleutelhanger.
    func setAPIKey(_ key: String) async throws {
        let key = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { throw AssemblyAIClient.APIError(message: "Vul een API-sleutel in.") }
        try await AssemblyAIClient(apiKey: key).validateKey()
        KeychainStore.save(key)
        hasAPIKey = true
        processPending()
    }

    func removeAPIKey() {
        KeychainStore.delete()
        hasAPIKey = false
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
    /// gemaakt zijn zonder internet of voordat de API-sleutel was ingevuld).
    func processPending() {
        guard isReady, let store else { return }
        for rec in store.recordings.reversed() where rec.status == .recorded {
            enqueue(rec)
        }
    }

    /// Pauzeert het uitschrijven tijdens een nieuwe opname (de opname heeft voorrang).
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
                if wentToBackgroundDuringJob || Self.isConnectionProblem(error) {
                    // Geen internet of de app werd gepauzeerd: opnieuw proberen
                    // zodra de app weer open is.
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
        guard let key = KeychainStore.read() else {
            throw AssemblyAIClient.APIError(message: "Vul eerst je AssemblyAI API-sleutel in bij Instellingen.")
        }
        let client = AssemblyAIClient(apiKey: key)
        let expected = recording.expectedSpeakers
        let flag = cancelFlag
        return try await client.transcribe(
            fileURL: audioURL,
            expectedSpeakers: expected,
            phase: { phase in
                Task { @MainActor [weak self] in
                    switch phase {
                    case .uploading: self?.phase = "Uploaden naar AssemblyAI"
                    case .transcribing: self?.phase = "Uitschrijven bij AssemblyAI"
                    }
                    self?.progress = nil
                }
            },
            shouldContinue: { !flag.value }
        )
    }

    private static func isConnectionProblem(_ error: Error) -> Bool {
        guard let urlError = error as? URLError else { return false }
        return [.notConnectedToInternet, .networkConnectionLost, .timedOut, .cannotFindHost, .cannotConnectToHost, .dataNotAllowed]
            .contains(urlError.code)
    }
}

/// Thread-veilige vlag om een lopende verwerking af te breken.
final class CancelFlag: @unchecked Sendable {
    private let lock = NSLock()
    private var flag = false
    var value: Bool { lock.lock(); defer { lock.unlock() }; return flag }
    func set(_ newValue: Bool) { lock.lock(); flag = newValue; lock.unlock() }
}

/// Speelt stilte af zolang er wordt uitgeschreven, zodat iOS de app niet
/// pauzeert als het scherm uitgaat terwijl er nog wordt geüpload of gewacht
/// (de app heeft de achtergrondmodus "audio").
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
