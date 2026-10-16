import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var engine: TranscriptionEngine
    @Environment(\.dismiss) private var dismiss
    @State private var keyDraft = ""
    @State private var checking = false
    @State private var message: String?
    @State private var confirmRemove = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    if engine.hasAPIKey {
                        Label("API-sleutel opgeslagen", systemImage: "checkmark.seal.fill")
                            .foregroundStyle(.green)
                        Button("Sleutel verwijderen", role: .destructive) { confirmRemove = true }
                    } else {
                        SecureField("Plak je API-sleutel", text: $keyDraft)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .accessibilityIdentifier("api-sleutel")
                        Button {
                            Task { await save() }
                        } label: {
                            HStack {
                                Text("Controleren en bewaren")
                                if checking { Spacer(); ProgressView() }
                            }
                        }
                        .disabled(keyDraft.trimmingCharacters(in: .whitespaces).isEmpty || checking)
                    }
                    if let message {
                        Text(message).font(.footnote).foregroundStyle(.red)
                    }
                } header: {
                    Text("AssemblyAI")
                } footer: {
                    Text("Je sleutel vind je op assemblyai.com › Dashboard. Hij wordt veilig in de sleutelhanger van deze iPhone bewaard.")
                }

                Section("Privacy") {
                    Text("Opnames staan op deze iPhone. Voor het uitschrijven wordt de audio naar AssemblyAI gestuurd, via hun EU-server (Dublin).")
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
            .confirmationDialog("API-sleutel verwijderen? Daarna kun je pas weer uitschrijven als je een sleutel invult.", isPresented: $confirmRemove, titleVisibility: .visible) {
                Button("Verwijderen", role: .destructive) { engine.removeAPIKey() }
            }
        }
    }

    private func save() async {
        checking = true
        message = nil
        defer { checking = false }
        do {
            try await engine.setAPIKey(keyDraft)
            keyDraft = ""
        } catch {
            message = error.localizedDescription
        }
    }
}
