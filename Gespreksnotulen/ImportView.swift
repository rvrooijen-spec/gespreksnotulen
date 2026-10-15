import SwiftUI

/// Uitleg hoe je een gesprek importeert. Dictafoon-opnames zijn niet via de
/// bestandskiezer te bereiken; die deel je vanuit Dictafoon naar Notulen.
struct ImportView: View {
    var onChooseFile: () -> Void

    @Environment(\.openURL) private var openURL
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Step(number: 1, text: "Open **Dictafoon** en tik op de opname.")
                    Step(number: 2, text: "Tik op **•••** en kies **Deel**.")
                    Step(number: 3, text: "Kies **Notulen**. Staat het er niet tussen? Kijk onder **Meer**.")
                    Button {
                        if let url = URL(string: "voicememos://") {
                            openURL(url)
                        }
                    } label: {
                        Label("Open Dictafoon", systemImage: "waveform")
                    }
                } header: {
                    Text("Uit Dictafoon")
                } footer: {
                    Text("Opnames van je Apple Watch staan ook in Dictafoon op je iPhone (zet iCloud › Dictafoon aan).")
                }

                Section {
                    Button(action: onChooseFile) {
                        Label("Kies een audiobestand", systemImage: "folder")
                    }
                } header: {
                    Text("Uit Bestanden")
                } footer: {
                    Text("Bijvoorbeeld uit iCloud Drive. Werkt met m4a, mp3 en wav.")
                }
            }
            .navigationTitle("Gesprek importeren")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Klaar") { dismiss() }
                }
            }
        }
    }
}

private struct Step: View {
    let number: Int
    let text: LocalizedStringKey

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text("\(number)")
                .font(.subheadline.bold())
                .foregroundStyle(.white)
                .frame(width: 24, height: 24)
                .background(Circle().fill(.red))
            Text(text)
        }
    }
}
