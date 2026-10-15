import Foundation

/// Eén uitspraak: een aaneengesloten stuk tekst van één spreker.
struct Utterance: Codable, Hashable, Identifiable {
    var id = UUID()
    /// Sprekernummer, beginnend bij 1. `nil` als de spreker niet te bepalen was.
    var speaker: Int?
    var start: Double
    var end: Double
    var text: String
}

enum RecordingStatus: String, Codable {
    case recorded     // opgenomen, nog niet uitgeschreven
    case processing   // wordt uitgeschreven
    case done         // klaar
    case failed       // mislukt, zie errorMessage
}

struct Recording: Codable, Identifiable, Hashable {
    var id = UUID()
    var title: String
    var createdAt: Date
    var duration: TimeInterval
    var audioFileName: String
    var status: RecordingStatus = .recorded
    var errorMessage: String?
    var utterances: [Utterance] = []
    /// Namen per sprekernummer, bijv. [1: "Jan", 2: "Petra"].
    var speakerNames: [Int: String] = [:]
    /// Aantal sprekers dat de gebruiker heeft opgegeven, `nil` = automatisch.
    var expectedSpeakers: Int?
    /// Welke spreker de gebruiker zelf is ("Dit ben ik"), `nil` = niet aangegeven.
    var mySpeaker: Int?

    var speakers: [Int] {
        Array(Set(utterances.compactMap(\.speaker))).sorted()
    }

    func name(for speaker: Int?) -> String {
        guard let speaker else { return "Onbekend" }
        if let name = speakerNames[speaker], !name.trimmingCharacters(in: .whitespaces).isEmpty {
            return name
        }
        return "Spreker \(speaker)"
    }

    /// Het volledige gesprek als platte tekst, om te delen of op te slaan.
    var exportText: String {
        var lines = [title, "\(createdAt.formatted(date: .long, time: .shortened)) · \(Format.duration(duration))", ""]
        for u in utterances {
            lines.append("[\(Format.timestamp(u.start))] \(name(for: u.speaker)): \(u.text)")
            lines.append("")
        }
        return lines.joined(separator: "\n")
    }
}

enum Format {
    static func timestamp(_ seconds: Double) -> String {
        let s = Int(seconds.rounded(.down))
        if s >= 3600 {
            return String(format: "%d:%02d:%02d", s / 3600, (s % 3600) / 60, s % 60)
        }
        return String(format: "%02d:%02d", s / 60, s % 60)
    }

    static func duration(_ seconds: Double) -> String {
        let minutes = Int((seconds / 60).rounded())
        if seconds < 60 { return "\(Int(seconds)) sec" }
        if minutes < 60 { return "\(minutes) min" }
        return "\(minutes / 60) u \(minutes % 60) min"
    }
}
