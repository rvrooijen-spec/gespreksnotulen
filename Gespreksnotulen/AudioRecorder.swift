import Foundation
import AVFoundation

/// Neemt audio op als AAC (16 kHz mono, genoeg voor spraak). Blijft doorlopen met
/// het scherm uit dankzij de achtergrondmodus "audio".
@MainActor
final class AudioRecorder: NSObject, ObservableObject {
    @Published private(set) var isRecording = false
    @Published private(set) var isPaused = false
    @Published private(set) var elapsed: TimeInterval = 0
    @Published private(set) var level: Float = 0   // 0...1

    private var recorder: AVAudioRecorder?
    private var timer: Timer?
    private var interruptionObserver: NSObjectProtocol?

    static func requestPermission() async -> Bool {
        await AVAudioApplication.requestRecordPermission()
    }

    func start(to url: URL) throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
        try session.setActive(true)

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 16_000,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
        ]
        let recorder = try AVAudioRecorder(url: url, settings: settings)
        recorder.isMeteringEnabled = true
        guard recorder.record() else {
            throw NSError(domain: "Notulen", code: 1, userInfo: [NSLocalizedDescriptionKey: "Opnemen kon niet starten."])
        }
        self.recorder = recorder
        isRecording = true
        isPaused = false
        elapsed = 0
        startTimer()
        observeInterruptions()
    }

    func togglePause() {
        guard let recorder else { return }
        if isPaused {
            recorder.record()
        } else {
            recorder.pause()
        }
        isPaused.toggle()
    }

    /// Stopt de opname en geeft de duur terug.
    @discardableResult
    func stop() -> TimeInterval {
        let duration = recorder?.currentTime ?? elapsed
        recorder?.stop()
        recorder = nil
        timer?.invalidate()
        timer = nil
        if let interruptionObserver {
            NotificationCenter.default.removeObserver(interruptionObserver)
        }
        interruptionObserver = nil
        isRecording = false
        isPaused = false
        level = 0
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        return max(duration, elapsed)
    }

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
    }

    private func tick() {
        guard let recorder, recorder.isRecording else {
            level = 0
            return
        }
        elapsed = recorder.currentTime
        recorder.updateMeters()
        let db = recorder.averagePower(forChannel: 0)   // -160...0
        level = max(0, min(1, (db + 50) / 50))
    }

    /// Bij een telefoontje pauzeert iOS de opname; daarna gaan we automatisch verder.
    private func observeInterruptions() {
        interruptionObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance(),
            queue: .main
        ) { [weak self] note in
            guard let raw = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
                  let type = AVAudioSession.InterruptionType(rawValue: raw) else { return }
            Task { @MainActor in
                guard let self, let recorder = self.recorder else { return }
                switch type {
                case .began:
                    self.isPaused = true
                case .ended:
                    try? AVAudioSession.sharedInstance().setActive(true)
                    recorder.record()
                    self.isPaused = false
                @unknown default:
                    break
                }
            }
        }
    }
}
