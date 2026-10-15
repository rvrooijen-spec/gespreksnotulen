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
        for folder in folders {
            let metaURL = folder.appendingPathComponent("opname.json")
            guard let data = try? Data(contentsOf: metaURL),
                  var rec = try? JSONDecoder().decode(Recording.self, from: data) else { continue }
            // Verwerking die werd onderbroken (app gesloten) opnieuw laten starten.
            if rec.status == .processing { rec.status = .recorded }
            result.append(rec)
        }
        recordings = result.sorted { $0.createdAt > $1.createdAt }
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

        let asset = AVURLAsset(url: destination)
        if let duration = try? await asset.load(.duration) {
            rec.duration = duration.seconds.isFinite ? duration.seconds : 0
        }
        save(rec)
        return rec
    }
}
