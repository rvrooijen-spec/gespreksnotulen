import SwiftUI

/// Koppel namen aan Spreker 1, 2, ... De eerste uitspraak van elke spreker
/// staat erbij zodat je kunt horen/lezen wie het is.
struct SpeakerNamesView: View {
    let recordingID: UUID

    @EnvironmentObject private var store: RecordingStore
    @Environment(\.dismiss) private var dismiss
    @StateObject private var player = AudioPlayer()
    @State private var names: [Int: String] = [:]

    var body: some View {
        NavigationStack {
            Form {
                if let rec = store.recording(withID: recordingID) {
                    ForEach(rec.speakers, id: \.self) { speaker in
                        Section {
                            TextField("Spreker \(speaker)", text: binding(for: speaker))
                                .textInputAutocapitalization(.words)
                                .accessibilityIdentifier("naam-\(speaker)")
                            if let first = rec.utterances.first(where: { $0.speaker == speaker }) {
                                Button {
                                    player.play(url: store.audioURL(for: rec), from: first.start)
                                } label: {
                                    Label {
                                        Text("“\(first.text)”").lineLimit(2).foregroundStyle(.secondary)
                                    } icon: {
                                        Image(systemName: "play.circle")
                                    }
                                }
                            }
                        } header: {
                            Text("Spreker \(speaker)").foregroundStyle(SpeakerColors.color(for: speaker))
                        }
                    }
                }
            }
            .navigationTitle("Sprekers")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuleer") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Bewaar") {
                        store.update(recordingID) { $0.speakerNames = names }
                        dismiss()
                    }
                }
            }
            .onAppear {
                names = store.recording(withID: recordingID)?.speakerNames ?? [:]
            }
            .onDisappear { player.stop() }
        }
    }

    private func binding(for speaker: Int) -> Binding<String> {
        Binding(
            get: { names[speaker] ?? "" },
            set: { names[speaker] = $0 }
        )
    }
}
