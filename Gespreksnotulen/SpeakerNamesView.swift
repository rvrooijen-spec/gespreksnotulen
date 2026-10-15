import SwiftUI

/// Koppel namen aan de stemmen. De eerste uitspraak van elke stem staat erbij
/// zodat je kunt horen/lezen wie het is. Aangeven wie "ik" is, is verplicht.
struct SpeakerNamesView: View {
    let recordingID: UUID
    /// Verplicht invullen (na het uitschrijven): niet te annuleren zonder "Dit ben ik".
    var required = false

    @EnvironmentObject private var store: RecordingStore
    @Environment(\.dismiss) private var dismiss
    @StateObject private var player = AudioPlayer()
    @State private var names: [Int: String] = [:]
    @State private var mySpeaker: Int?

    var body: some View {
        NavigationStack {
            Form {
                if let rec = store.recording(withID: recordingID) {
                    Section {
                        Label {
                            Text("Geef aan welke stem **jij** bent. Namen van anderen invullen mag, hoeft niet.")
                        } icon: {
                            Image(systemName: mySpeaker == nil ? "person.crop.circle.badge.questionmark" : "person.crop.circle.badge.checkmark")
                                .foregroundStyle(mySpeaker == nil ? .orange : .green)
                        }
                        .font(.subheadline)
                    }
                    ForEach(rec.speakers, id: \.self) { speaker in
                        Section {
                            TextField(rec.defaultName(for: speaker, me: .some(mySpeaker)), text: binding(for: speaker))
                                .textInputAutocapitalization(.words)
                                .accessibilityIdentifier("naam-\(speaker)")
                            Toggle("Dit ben ik", isOn: Binding(
                                get: { mySpeaker == speaker },
                                set: { isMe in
                                    if isMe {
                                        // Eigen naam van vorige keer alvast invullen.
                                        if let previous = mySpeaker, names[previous] == UserSettings.myName {
                                            names[previous] = nil
                                        }
                                        mySpeaker = speaker
                                        if (names[speaker] ?? "").isEmpty, !UserSettings.myName.isEmpty {
                                            names[speaker] = UserSettings.myName
                                        }
                                    } else if mySpeaker == speaker {
                                        mySpeaker = nil
                                    }
                                }
                            ))
                            .accessibilityIdentifier("ik-\(speaker)")
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
                            Text("Stem \(speaker)").foregroundStyle(SpeakerColors.color(for: speaker))
                        }
                    }
                }
            }
            .navigationTitle(required ? "Wie ben jij?" : "Sprekers")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if !required {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Annuleer") { dismiss() }
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Bewaar") {
                        let cleaned = names.mapValues { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.value.isEmpty }
                        if let me = mySpeaker, let myName = cleaned[me] {
                            UserSettings.myName = myName
                        }
                        store.update(recordingID) {
                            $0.speakerNames = cleaned
                            $0.mySpeaker = mySpeaker
                        }
                        dismiss()
                    }
                    .disabled(mySpeaker == nil)
                }
            }
            .onAppear {
                names = store.recording(withID: recordingID)?.speakerNames ?? [:]
                mySpeaker = store.recording(withID: recordingID)?.mySpeaker
            }
            .onDisappear { player.stop() }
        }
        .interactiveDismissDisabled(required && mySpeaker == nil)
    }

    private func binding(for speaker: Int) -> Binding<String> {
        Binding(
            get: { names[speaker] ?? "" },
            set: { names[speaker] = $0 }
        )
    }
}
