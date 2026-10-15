import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var engine: TranscriptionEngine
    @Environment(\.dismiss) private var dismiss
    @State private var confirmDelete = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Spraakmodellen") {
                    ModelBanner()
                    LabeledContent("Spraak", value: "Whisper large-v3 turbo")
                    LabeledContent("Sprekers", value: "Pyannote (SpeakerKit)")
                    if engine.modelsDownloaded {
                        Button("Modellen verwijderen", role: .destructive) { confirmDelete = true }
                    }
                }

                Section("Privacy") {
                    Text("Opnames en tekst blijven op deze iPhone. Alleen het eenmalig downloaden van de modellen gebruikt internet.")
                    Text("Je opnames staan ook in de Bestanden-app onder Op mijn iPhone › Notulen › Opnames.")
                }
                .font(.footnote)
                .foregroundStyle(.secondary)

                Section("Over") {
                    LabeledContent("Versie", value: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "–")
                }
            }
            .navigationTitle("Instellingen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Klaar") { dismiss() }
                }
            }
            .confirmationDialog("Modellen verwijderen? Je moet ze daarna opnieuw downloaden om te kunnen uitschrijven.", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Verwijderen", role: .destructive) { Task { await engine.deleteModels() } }
            }
        }
    }
}
