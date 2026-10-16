import Foundation
import AVFoundation

/// Hulpfuncties voor audiobestanden (opnemen en comprimeren).
enum AudioFiles {
    /// Opname-instellingen: 16 kHz mono 16-bit PCM in een CAF-bestand. CAF blijft
    /// leesbaar als de app tijdens het opnemen crasht; na afloop comprimeren we naar AAC.
    static let recordingSettings: [String: Any] = [
        AVFormatIDKey: Int(kAudioFormatLinearPCM),
        AVSampleRateKey: 16_000,
        AVNumberOfChannelsKey: 1,
        AVLinearPCMBitDepthKey: 16,
        AVLinearPCMIsFloatKey: false,
        AVLinearPCMIsBigEndianKey: false,
    ]

    static func duration(of url: URL) -> TimeInterval? {
        guard let file = try? AVAudioFile(forReading: url) else { return nil }
        let rate = file.fileFormat.sampleRate
        guard rate > 0 else { return nil }
        return Double(file.length) / rate
    }

    /// Zet een audiobestand om naar AAC (.m4a). Controleert dat de duur klopt
    /// voordat het resultaat wordt teruggegeven; het origineel blijft staan.
    static func compressToM4A(_ source: URL, destination: URL) throws {
        try? FileManager.default.removeItem(at: destination)
        try writeM4A(source, destination: destination)

        guard let original = duration(of: source),
              let compressed = duration(of: destination),
              abs(original - compressed) < max(1.0, original * 0.01) else {
            try? FileManager.default.removeItem(at: destination)
            throw NSError(domain: "Notulen", code: 10, userInfo: [NSLocalizedDescriptionKey: "Comprimeren gaf een onvolledig bestand."])
        }
    }

    /// Apart zodat de AVAudioFile's aan het eind van deze functie worden
    /// vrijgegeven (en het uitvoerbestand dus netjes wordt afgesloten).
    private static func writeM4A(_ source: URL, destination: URL) throws {
        let input = try AVAudioFile(forReading: source)
        let format = input.processingFormat
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: input.fileFormat.sampleRate,
            AVNumberOfChannelsKey: Int(format.channelCount),
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
        ]
        let output = try AVAudioFile(
            forWriting: destination,
            settings: settings,
            commonFormat: format.commonFormat,
            interleaved: format.isInterleaved
        )
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 32_768) else {
            throw NSError(domain: "Notulen", code: 11, userInfo: [NSLocalizedDescriptionKey: "Geen geheugen voor audiobuffer."])
        }
        while input.framePosition < input.length {
            try input.read(into: buffer)
            if buffer.frameLength == 0 { break }
            try output.write(from: buffer)
        }
    }
}
