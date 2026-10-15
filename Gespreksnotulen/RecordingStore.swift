import Foundation
import AVFoundation

/// Bewaart opnames in Documenten/Opnames/<id>/ (zichtbaar in de Bestanden-app).
@MainActor
final class RecordingStore: ObservableObject {
    @Published private(set) var recordings: [Recording] = []

    let baseURL: URL = {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let url = docs.appendingPathComponent("Opnames", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }()

    init() {
        load()
    }

    func folder(for recording: Recording) -> URL {
        baseURL.appendingPathComponent(recording.id.uuidString, isDirectory: true)
    }

    func audioURL(for recording: Recording) -> URL {
        folder(for: recording).appendingPathComponent(recording.audioFileName)
    }

    func recording(withID id: UUID) -> Recording? {
        recordings.first { $0.id == id }
    }

    func load() {
        let fm = FileManager.default
        let folders = (try? fm.contentsOfDirectory(at: baseURL, includingPropertiesForKeys: nil)) ?? []
        var result: [Recording] = []
        var repaired: [Recording] = []
        for folder in folders {
            let metaURL = folder.appendingPathComponent("opname.json")
            guard let data = try? Data(contentsOf: metaURL),
                  var rec = try? JSONDecoder().decode(Recording.self, from: data) else { continue }
            // Verwerking die werd onderbroken (app gesloten) opnieuw laten starten.
            if rec.status == .processing { rec.status = .recorded }
            // Opname die nooit netjes is gestopt (app gecrasht of afgesloten tijdens
            // het opnemen): duur alsnog bepalen uit het audiobestand.
            if rec.duration == 0 {
                let audio = folder.appendingPathComponent(rec.audioFileName)
                let size = (try? FileManager.default.attributesOfItem(atPath: audio.path)[.size] as? Int) ?? 0
                if let duration = AudioFiles.duration(of: audio), duration > 0 {
                    rec.duration = duration
                    rec.title += " (hersteld)"
                    repaired.append(rec)
                } else if size > 8_192 {
                    // Niet leesbaar, maar wel data: niet weggooien, de gebruiker kan
                    // het bestand nog via de Bestanden-app redden.
                    rec.duration = Double(size) / 32_000   // 16 kHz × 16 bit
                    rec.title += " (beschadigd)"
                    rec.status = .failed
                    rec.errorMessage = "De opname is niet netjes afgesloten en kan niet worden gelezen."
                    repaired.append(rec)
                } else {
                    try? FileManager.default.removeItem(at: folder)
                    continue
                }
            }
            result.append(rec)
        }
        recordings = result.sorted { $0.createdAt > $1.createdAt }
        repaired.forEach(save)
    }

    /// Maakt een nieuwe opname en slaat die direct op, zodat de opname ook na een
    /// crash tijdens het opnemen terug te vinden is.
    func startNewRecording() -> Recording {
        let rec = makeNewRecording(fileExtension: "caf")
        save(rec)
        return rec
    }

    /// Comprimeert een opname (CAF, ~115 MB/uur) naar AAC (~15-30 MB/uur).
    /// Bij een fout blijft het originele bestand gewoon in gebruik.
    func compressAudio(of recording: Recording) async -> Recording {
        guard recording.audioFileName.hasSuffix(".caf") else { return recording }
        let source = audioURL(for: recording)
        let destination = source.deletingPathExtension().appendingPathExtension("m4a")
        do {
            try await Task.detached(priority: .utility) {
                try AudioFiles.compressToM4A(source, destination: destination)
            }.value
        } catch {
            return recording
        }
        var updated = self.recording(withID: recording.id) ?? recording
        updated.audioFileName = destination.lastPathComponent
        save(updated)
        try? FileManager.default.removeItem(at: source)
        return updated
    }

    /// Maakt een nieuwe map met een leeg audiobestand-pad voor een opname.
    func makeNewRecording(fileExtension: String = "m4a") -> Recording {
        let rec = Recording(
            title: "Gesprek \(Date().formatted(.dateTime.day().month(.abbreviated).hour().minute()))",
            createdAt: Date(),
            duration: 0,
            audioFileName: "audio.\(fileExtension)"
        )
        try? FileManager.default.createDirectory(at: folder(for: rec), withIntermediateDirectories: true)
        return rec
    }

    func save(_ recording: Recording) {
        if let index = recordings.firstIndex(where: { $0.id == recording.id }) {
            recordings[index] = recording
        } else {
            recordings.insert(recording, at: 0)
            recordings.sort { $0.createdAt > $1.createdAt }
        }
        let folder = folder(for: recording)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted]
        if let data = try? encoder.encode(recording) {
            try? data.write(to: folder.appendingPathComponent("opname.json"), options: .atomic)
        }
        if recording.status == .done {
            try? recording.exportText.write(to: folder.appendingPathComponent("tekst.txt"), atomically: true, encoding: .utf8)
        }
    }

    func update(_ id: UUID, _ change: (inout Recording) -> Void) {
        guard var rec = recording(withID: id) else { return }
        change(&rec)
        save(rec)
    }

    func delete(_ recording: Recording) {
        try? FileManager.default.removeItem(at: folder(for: recording))
        recordings.removeAll { $0.id == recording.id }
    }

    /// Importeert een bestaand audiobestand (bijv. uit Dictafoon of WhatsApp).
    func importAudio(from url: URL) async throws -> Recording {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }

        let ext = url.pathExtension.isEmpty ? "m4a" : url.pathExtension.lowercased()
        var rec = makeNewRecording(fileExtension: ext)
        rec.title = url.deletingPathExtension().lastPathComponent
        let destination = audioURL(for: rec)
        try FileManager.default.copyItem(at: url, to: destination)

        // Datum van de oorspronkelijke opname gebruiken als die bekend is.
        let values = try? url.resourceValues(forKeys: [.creationDateKey, .contentModificationDateKey])
        if let original = [values?.creationDate, values?.contentModificationDate].compactMap({ $0 }).min(),
           original < rec.createdAt {
            rec.createdAt = original
        }
        // iOS zet gedeelde bestanden soms eerst in Documenten/Inbox; die kopie opruimen.
        if url.path.contains("/Documents/Inbox/") {
            try? FileManager.default.removeItem(at: url)
        }

        if let duration = AudioFiles.duration(of: destination), duration > 0 {
            rec.duration = duration
        } else {
            let asset = AVURLAsset(url: destination)
            if let duration = try? await asset.load(.duration), duration.seconds.isFinite {
                rec.duration = duration.seconds
            }
        }
        guard rec.duration > 0 else {
            delete(rec)
            throw NSError(domain: "Notulen", code: 4, userInfo: [NSLocalizedDescriptionKey: "Dit audioformaat wordt niet ondersteund (WhatsApp-.opus bijvoorbeeld niet). Probeer m4a, mp3 of wav."])
        }
        save(rec)
        return rec
    }
}
