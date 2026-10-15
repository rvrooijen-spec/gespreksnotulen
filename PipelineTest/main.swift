import Foundation
import WhisperKit

// Test van de rekenkern op een Mac (GitHub Actions). Draait exact dezelfde
// code als de app: TranscriptionPipeline, AudioFiles en Models.
//
// Gebruik: PipelineTest <testgesprek.wav> <dialoog.json>
// Omgevingsvariabele MODELS_DIR: map voor de modellen (wordt gecachet in CI).

struct Line: Decodable {
    let voice: String
    let keyword: String
    let text: String
}

final class ProgressThrottleCLI: @unchecked Sendable {
    private let lock = NSLock()
    private var last = -1
    func shouldPrint(_ fraction: Double) -> Bool {
        lock.lock(); defer { lock.unlock() }
        let step = Int(fraction * 10)
        guard step != last else { return false }
        last = step
        return true
    }
}

var failures: [String] = []

func check(_ condition: Bool, _ message: String) {
    print(condition ? "✅ \(message)" : "❌ \(message)")
    if !condition { failures.append(message) }
}

func finish() -> Never {
    print("")
    if failures.isEmpty {
        print("ALLE TESTS GESLAAGD")
        exit(0)
    }
    print("\(failures.count) TEST(S) MISLUKT:")
    failures.forEach { print("  - \($0)") }
    exit(1)
}

let args = CommandLine.arguments

// MARK: Modus "--transcribe <uitvoermap> <audio...>": echte opnames uitschrijven
// (gebruikt door .github/workflows/transcribeer.yml).
if args.count >= 4, args[1] == "--transcribe" {
    let outputDir = URL(fileURLWithPath: args[2], isDirectory: true)
    try FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)
    let modelsDir = ProcessInfo.processInfo.environment["MODELS_DIR"] ?? NSTemporaryDirectory() + "notulen-modellen"
    let defaults = UserDefaults(suiteName: "nl.rvrooijen.pipelinetest")!
    let pipeline = TranscriptionPipeline(modelsURL: URL(fileURLWithPath: modelsDir, isDirectory: true), defaults: defaults)
    try await pipeline.prepare { _ in }
    var failed = false
    for path in args[3...] {
        let url = URL(fileURLWithPath: path)
        print("== \(url.lastPathComponent) ==")
        let start = Date()
        do {
            let chunking: ChunkingStrategy = ProcessInfo.processInfo.environment["NOTULEN_CHUNKING"] == "none" ? .none : .vad
            let utterances = try await pipeline.transcribe(audioPath: path, expectedSpeakers: nil, chunking: chunking, phase: { _ in }, shouldContinue: { true })
            var rec = Recording(
                title: url.deletingPathExtension().lastPathComponent,
                createdAt: Date(),
                duration: AudioFiles.duration(of: url) ?? 0,
                audioFileName: url.lastPathComponent
            )
            rec.utterances = utterances
            let text = rec.exportText
            print(text)
            print("(verwerkt in \(Int(Date().timeIntervalSince(start))) s, \(Set(utterances.compactMap(\.speaker)).count) sprekers)")
            try text.write(to: outputDir.appendingPathComponent(rec.title + ".txt"), atomically: true, encoding: .utf8)
        } catch {
            print("Mislukt: \(error)")
            failed = true
        }
    }
    exit(failed ? 1 : 0)
}

guard args.count >= 3 else {
    print("Gebruik: PipelineTest <testgesprek.wav> <dialoog.json>")
    exit(2)
}
let audioURL = URL(fileURLWithPath: args[1])
let dialogue = try JSONDecoder().decode([Line].self, from: Data(contentsOf: URL(fileURLWithPath: args[2])))
let modelsDir = ProcessInfo.processInfo.environment["MODELS_DIR"] ?? NSTemporaryDirectory() + "notulen-modellen"

// MARK: 1. Samenvoegen en hallucinatiefilter (zonder modellen)

print("== Samenvoegen ==")
do {
    typealias Part = TranscriptionPipeline.Part
    let merged = TranscriptionPipeline.makeUtterances(from: [
        Part(rawSpeaker: 7, start: 0, end: 1, text: " Hallo"),
        Part(rawSpeaker: 7, start: 1.2, end: 2, text: "daar."),
        Part(rawSpeaker: 3, start: 2.5, end: 4, text: "Goedemiddag."),
        Part(rawSpeaker: nil, start: 4, end: 5, text: "Ondertiteld door de Amara.org gemeenschap"),
        Part(rawSpeaker: 7, start: 5, end: 6, text: "Tot ziens."),
        Part(rawSpeaker: 7, start: 20, end: 21, text: "Nog iets."),
        Part(rawSpeaker: 3, start: 21, end: 22, text: "   "),
    ])
    check(merged.count == 4, "4 uitspraken na samenvoegen (gevonden \(merged.count))")
    check(merged.first?.text == "Hallo daar.", "opeenvolgende stukjes van één spreker samengevoegd")
    check(merged.map(\.speaker) == [1, 2, 1, 1], "sprekers genummerd op volgorde van eerste keer spreken")
    check(!merged.contains { $0.text.contains("Amara") }, "Amara-hallucinatie weggefilterd")
    check(merged.last?.start == 20, "lange stilte (>3 s) begint een nieuwe uitspraak")

    var rec = Recording(title: "Test", createdAt: Date(), duration: 22, audioFileName: "audio.m4a")
    rec.utterances = merged
    rec.speakerNames = [1: "Jan", 2: "  "]
    check(rec.name(for: 1) == "Jan" && rec.name(for: 2) == "Persoon 2" && rec.name(for: nil) == "Onbekend", "sprekernamen (lege naam valt terug op 'Persoon 2')")
    var other = rec
    other.speakerNames = [:]
    other.mySpeaker = 2
    check(other.name(for: 2) == "Ik" && other.name(for: 1) == "Persoon 2", "zonder namen: ik = 'Ik', de ander = 'Persoon 2'")
    check(other.speakerTags.first?.isMe == true, "eigen naam staat vooraan in de tags")
    check(rec.exportText.contains("[00:00] Jan: Hallo daar."), "export bevat tijd, naam en tekst")
    rec.mySpeaker = 1
    let decoded = try JSONDecoder().decode(Recording.self, from: JSONEncoder().encode(rec))
    check(decoded == rec, "opname overleeft opslaan en inladen (JSON)")
}

// MARK: 2. Comprimeren

print("\n== Comprimeren ==")
do {
    let m4a = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("test-\(UUID().uuidString).m4a")
    let original = AudioFiles.duration(of: audioURL) ?? 0
    check(original > 10, "testgesprek is ingelezen (\(String(format: "%.1f", original)) s)")
    do {
        try AudioFiles.compressToM4A(audioURL, destination: m4a)
        let compressed = AudioFiles.duration(of: m4a) ?? 0
        let before = (try? FileManager.default.attributesOfItem(atPath: audioURL.path)[.size] as? Int) ?? 0
        let after = (try? FileManager.default.attributesOfItem(atPath: m4a.path)[.size] as? Int) ?? 0
        check(abs(compressed - original) < 1, "m4a heeft dezelfde duur (\(String(format: "%.1f", compressed)) s)")
        check(after > 0 && after < before / 2, "m4a is kleiner (\(before / 1024) kB → \(after / 1024) kB)")
    } catch {
        check(false, "comprimeren: \(error.localizedDescription)")
    }
}

// MARK: 3. Volledige verwerking met de echte modellen

print("\n== Modellen ==")
let defaults = UserDefaults(suiteName: "nl.rvrooijen.pipelinetest")!
let pipeline = TranscriptionPipeline(modelsURL: URL(fileURLWithPath: modelsDir, isDirectory: true), defaults: defaults)
let prepareStart = Date()
let lastReported = ProgressThrottleCLI()
do {
    try await pipeline.prepare { status in
        switch status {
        case .downloadingSpeech(let f):
            if lastReported.shouldPrint(f) { print("  spraakmodel downloaden: \(Int(f * 100))%") }
        case .downloadingSpeakers:
            print("  sprekermodel downloaden/laden…")
        case .loading:
            print("  spraakmodel laden…")
        }
    }
    print("  klaar in \(Int(Date().timeIntervalSince(prepareStart))) s")
    check(pipeline.isLoaded, "beide modellen geladen")
    check(pipeline.whisperFolder != nil, "modelmap wordt teruggevonden (geen nieuwe download bij volgende start)")
} catch {
    check(false, "modellen voorbereiden: \(error)")
    finish()
}

func run(expectedSpeakers: Int?) async -> [Utterance]? {
    let start = Date()
    do {
        let result = try await pipeline.transcribe(
            audioPath: audioURL.path,
            expectedSpeakers: expectedSpeakers,
            phase: { _ in },
            shouldContinue: { true }
        )
        print("  verwerkt in \(Int(Date().timeIntervalSince(start))) s")
        for u in result {
            print("  [\(Format.timestamp(u.start))] Spreker \(u.speaker.map(String.init) ?? "?"): \(u.text)")
        }
        return result
    } catch {
        check(false, "uitschrijven (sprekers: \(expectedSpeakers.map(String.init) ?? "auto")): \(error)")
        return nil
    }
}

/// Bepaalt per dialoogregel welke spreker de app eraan koppelde (via het
/// sleutelwoord) en controleert of dat consistent is met de echte stemmen.
func evaluate(_ utterances: [Utterance], label: String) {
    let fullText = utterances.map(\.text).joined(separator: " ").lowercased()
    let found = dialogue.filter { fullText.contains($0.keyword) }
    check(Double(found.count) / Double(dialogue.count) >= 0.8,
          "\(label): sleutelwoorden herkend (\(found.count)/\(dialogue.count)): \(found.map(\.keyword).joined(separator: ", "))")

    let speakersFound = Set(utterances.compactMap(\.speaker))
    check(speakersFound.count == 2, "\(label): 2 sprekers gevonden (gevonden \(speakersFound.count))")

    var assigned: [(voice: String, speaker: Int)] = []
    for line in dialogue {
        if let u = utterances.first(where: { $0.text.lowercased().contains(line.keyword) }), let s = u.speaker {
            assigned.append((line.voice, s))
        }
    }
    var correctPairs = 0
    var totalPairs = 0
    for i in 0..<assigned.count {
        for j in (i + 1)..<assigned.count {
            totalPairs += 1
            let sameVoice = assigned[i].voice == assigned[j].voice
            let sameSpeaker = assigned[i].speaker == assigned[j].speaker
            if sameVoice == sameSpeaker { correctPairs += 1 }
        }
    }
    let accuracy = totalPairs == 0 ? 0 : Double(correctPairs) / Double(totalPairs)
    check(accuracy >= 0.8, "\(label): juiste spreker bij de uitspraken (\(Int(accuracy * 100))%)")
}

print("\n== Uitschrijven, sprekers automatisch ==")
if let auto = await run(expectedSpeakers: nil) {
    check(!auto.isEmpty, "er is tekst uitgeschreven")
    evaluate(auto, label: "auto")
}

print("\n== Uitschrijven, 2 sprekers opgegeven ==")
if let fixed = await run(expectedSpeakers: 2) {
    evaluate(fixed, label: "2 sprekers")
}

print("\n== Afbreken ==")
do {
    _ = try await pipeline.transcribe(audioPath: audioURL.path, expectedSpeakers: nil, phase: { _ in }, shouldContinue: { false })
    check(false, "afbreken geeft een CancellationError")
} catch is CancellationError {
    check(true, "afbreken geeft een CancellationError")
} catch {
    check(false, "afbreken gaf een andere fout: \(error)")
}

finish()
