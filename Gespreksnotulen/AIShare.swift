import SwiftUI
import UIKit

/// Deelt een uitgeschreven gesprek met ChatGPT of Claude, met een opdracht erbij.
enum AIAssistant: String, CaseIterable, Identifiable {
    case chatGPT = "ChatGPT"
    case claude = "Claude"

    var id: String { rawValue }

    /// Universal links: openen de app als die geïnstalleerd is, anders de website.
    func url(prefill: String?) -> URL {
        var components: URLComponents
        switch self {
        case .chatGPT: components = URLComponents(string: "https://chatgpt.com/")!
        case .claude: components = URLComponents(string: "https://claude.ai/new")!
        }
        if let prefill {
            components.queryItems = [URLQueryItem(name: "q", value: prefill)]
        }
        return components.url!
    }
}

enum AITask: String, CaseIterable, Identifiable {
    case summary = "Samenvatting en actiepunten"
    case minutes = "Notulen maken"
    case myBusinessPart = "Mijn inbreng: zakelijk verslag functioneren"
    case textOnly = "Alleen de tekst"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .summary: return "list.bullet.clipboard"
        case .minutes: return "doc.text"
        case .myBusinessPart: return "person.badge.shield.checkmark"
        case .textOnly: return "text.quote"
        }
    }

    /// Voor deze taak moet bekend zijn welke spreker de gebruiker is.
    var needsMySpeaker: Bool { self == .myBusinessPart }

    /// De opdracht voor de AI. De app voegt alleen deze opdracht toe; het gesprek
    /// zelf wordt altijd volledig en ongewijzigd meegestuurd.
    func instruction(for recording: Recording) -> String? {
        let intro = "Hieronder staat een volledig uitgeschreven Nederlands gesprek (automatisch gemaakt, er kunnen fouten in zitten)."
        switch self {
        case .summary:
            return """
            \(intro) Geef een korte samenvatting in het Nederlands, gevolgd door een lijst met actiepunten \
            (wie doet wat, en voor wanneer als dat genoemd is) en eventuele afspraken, bedragen en data.
            """
        case .minutes:
            return """
            \(intro) Maak er nette notulen van in het Nederlands met de kopjes: Aanwezigen, Besproken punten, \
            Besluiten en Actiepunten (met wie en wanneer).
            """
        case .myBusinessPart:
            let me = recording.name(for: recording.mySpeaker)
            return """
            \(intro) Het is een werkgesprek tussen mij en een medewerker. Ik ben "\(me)" in de tekst.
            Maak een kort, zakelijk verslag in het Nederlands over het functioneren van de medewerker, \
            uitsluitend gebaseerd op wat ik ("\(me)") heb gezegd, met de kopjes: Functioneren en resultaten, \
            Gedrag en samenwerking, Afspraken en verbeterpunten, Vervolg.
            Strikte regels:
            - Gebruik alleen mijn eigen uitspraken; de uitspraken van anderen dienen alleen als context.
            - Alleen inhoudelijke, zakelijke punten over werk en functioneren.
            - Laat alles weg wat privé is: gezondheid, ziekte, familie, relaties, financiën, \
            religie en andere persoonlijke omstandigheden, ook als ik het zelf noemde.
            - Laat small talk, grapjes en randzaken weg.
            - Geen citaten of namen van derden; feitelijk en neutraal geformuleerd.
            - Voeg niets toe dat niet in het gesprek staat.
            """
        case .textOnly:
            return nil
        }
    }

    /// Opdracht (indien van toepassing) + het volledige, ongewijzigde gesprek.
    func message(for recording: Recording) -> String {
        guard let instruction = instruction(for: recording) else { return recording.exportText }
        return instruction + "\n\n---\n\n" + recording.exportText
    }
}

/// Knop met menu: kies ChatGPT of Claude en wat er met het gesprek moet gebeuren.
struct AIShareMenu: View {
    let recording: Recording

    @Environment(\.openURL) private var openURL
    @State private var pending: (assistant: AIAssistant, message: String)?
    @State private var needsMySpeaker = false
    @State private var fileToShare: SharedFile?
    var onChooseSpeakers: () -> Void = {}

    /// Langere teksten passen niet betrouwbaar in een link; die gaan via het klembord.
    private let maxPrefillLength = 3_500

    var body: some View {
        Menu {
            ForEach(AIAssistant.allCases) { assistant in
                Menu("Deel met \(assistant.rawValue)") {
                    ForEach(AITask.allCases) { task in
                        Button(task.rawValue, systemImage: task.systemImage) {
                            if task.needsMySpeaker, recording.mySpeaker == nil {
                                needsMySpeaker = true
                            } else {
                                share(task.message(for: recording), with: assistant)
                            }
                        }
                    }
                }
            }
            // Als .txt via het deelmenu: werkt ook voor lange gesprekken, en met
            // elke app (ChatGPT, Claude, Mail, Bestanden, ...).
            Menu("Deel als tekstbestand") {
                ForEach(AITask.allCases) { task in
                    Button(task.rawValue, systemImage: task.systemImage) {
                        if task.needsMySpeaker, recording.mySpeaker == nil {
                            needsMySpeaker = true
                        } else {
                            fileToShare = SharedFile.make(for: recording, task: task)
                        }
                    }
                }
            }
        } label: {
            Image(systemName: "sparkles")
                .accessibilityLabel("Deel met AI")
        }
        .alert(
            "Tekst gekopieerd",
            isPresented: Binding(get: { pending != nil }, set: { if !$0 { pending = nil } }),
            presenting: pending
        ) { item in
            Button("Open \(item.assistant.rawValue)") {
                openURL(item.assistant.url(prefill: nil))
            }
            Button("Annuleer", role: .cancel) {}
        } message: { item in
            Text("Het gesprek is te lang om automatisch in te vullen. Het staat op het klembord: houd in \(item.assistant.rawValue) je vinger in het tekstveld en kies Plak.")
        }
        .sheet(item: $fileToShare) { file in
            ActivityView(items: [file.url])
                .presentationDetents([.medium, .large])
                .ignoresSafeArea()
        }
        .alert("Welke spreker ben jij?", isPresented: $needsMySpeaker) {
            Button("Sprekers openen") { onChooseSpeakers() }
            Button("Annuleer", role: .cancel) {}
        } message: {
            Text("Zet bij jouw spreker 'Dit ben ik' aan. Het hele gesprek wordt gedeeld; de AI krijgt de opdracht alleen jouw uitspraken te gebruiken.")
        }
    }

    private func share(_ message: String, with assistant: AIAssistant) {
        UIPasteboard.general.string = message
        if message.count <= maxPrefillLength {
            openURL(assistant.url(prefill: message))
        } else {
            pending = (assistant, message)
        }
    }
}

/// Tijdelijk .txt-bestand met opdracht en gesprek, om te delen.
struct SharedFile: Identifiable {
    let url: URL
    var id: URL { url }

    static func make(for recording: Recording, task: AITask) -> SharedFile? {
        let safeTitle = recording.title
            .components(separatedBy: CharacterSet(charactersIn: "/\\:?%*|\"<>"))
            .joined(separator: "-")
        let suffix: String
        switch task {
        case .summary: suffix = "samenvatting"
        case .minutes: suffix = "notulen"
        case .myBusinessPart: suffix = "mijn inbreng zakelijk"
        case .textOnly: suffix = "tekst"
        }
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("Delen", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let url = folder.appendingPathComponent("\(safeTitle) - \(suffix).txt")
        do {
            try task.message(for: recording).write(to: url, atomically: true, encoding: .utf8)
            return SharedFile(url: url)
        } catch {
            return nil
        }
    }
}

/// Het standaard iOS-deelmenu.
struct ActivityView: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
