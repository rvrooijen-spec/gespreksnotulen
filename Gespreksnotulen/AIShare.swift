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
    case textOnly = "Alleen de tekst"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .summary: return "list.bullet.clipboard"
        case .minutes: return "doc.text"
        case .textOnly: return "text.quote"
        }
    }

    var instruction: String? {
        switch self {
        case .summary:
            return """
            Hieronder staat een uitgeschreven Nederlands gesprek (automatisch gemaakt, er kunnen fouten in zitten). \
            Geef een korte samenvatting in het Nederlands, gevolgd door een lijst met actiepunten \
            (wie doet wat, en voor wanneer als dat genoemd is) en eventuele afspraken, bedragen en data.
            """
        case .minutes:
            return """
            Hieronder staat een uitgeschreven Nederlands gesprek (automatisch gemaakt, er kunnen fouten in zitten). \
            Maak er nette notulen van in het Nederlands met de kopjes: Aanwezigen, Besproken punten, \
            Besluiten en Actiepunten (met wie en wanneer).
            """
        case .textOnly:
            return nil
        }
    }

    func message(for recording: Recording) -> String {
        guard let instruction else { return recording.exportText }
        return instruction + "\n\n---\n\n" + recording.exportText
    }
}

/// Knop met menu: kies ChatGPT of Claude en wat er met het gesprek moet gebeuren.
struct AIShareMenu: View {
    let recording: Recording

    @Environment(\.openURL) private var openURL
    @State private var pending: (assistant: AIAssistant, message: String)?

    /// Langere teksten passen niet betrouwbaar in een link; die gaan via het klembord.
    private let maxPrefillLength = 3_500

    var body: some View {
        Menu {
            ForEach(AIAssistant.allCases) { assistant in
                Menu("Deel met \(assistant.rawValue)") {
                    ForEach(AITask.allCases) { task in
                        Button(task.rawValue, systemImage: task.systemImage) {
                            share(task.message(for: recording), with: assistant)
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
