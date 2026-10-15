import SwiftUI
import AVFoundation

struct RecordingDetailView: View {
    let recordingID: UUID

    @EnvironmentObject private var store: RecordingStore
    @EnvironmentObject private var engine: TranscriptionEngine
    @Environment(\.dismiss) private var dismiss
    @StateObject private var player = AudioPlayer()

    @State private var showSpeakers = false
    @State private var confirmDelete = false
    @State private var editingTitle = false
    @State private var titleDraft = ""

    var body: some View {
        Group {
            if let rec = store.recording(withID: recordingID) {
                content(rec)
            } else {
                ContentUnavailableView("Opname niet gevonden", systemImage: "questionmark.folder")
            }
        }
        .onDisappear { player.stop() }
    }

    @ViewBuilder
    private func content(_ rec: Recording) -> some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 4) {
                    Text(rec.createdAt.formatted(date: .complete, time: .shortened))
                    Text(Format.duration(rec.duration))
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)

                PlayerControls(player: player, url: store.audioURL(for: rec))
            }

            switch rec.status {
            case .processing:
                Section { ProcessingStatus(recordingID: rec.id) }
            case .recorded:
                Section {
                    if engine.modelsDownloaded {
                        Button("Uitschrijven") { engine.enqueue(rec) }
                    } else {
                        ModelBanner()
                    }
                }
            case .failed:
                Section {
                    Label(rec.errorMessage ?? "Onbekende fout", systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Button("Opnieuw proberen") { engine.enqueue(rec) }
                }
            case .done:
                if rec.utterances.isEmpty {
                    Section { Text("Er is geen spraak gevonden in deze opname.").foregroundStyle(.secondary) }
                } else {
                    Section {
                        ForEach(rec.utterances) { u in
                            UtteranceRow(recording: rec, utterance: u, isPlaying: player.isPlaying && player.currentTime >= u.start && player.currentTime < u.end)
                                .contentShape(Rectangle())
                                .onTapGesture { player.play(url: store.audioURL(for: rec), from: u.start) }
                        }
                    } footer: {
                        Text("Tik op een uitspraak om die terug te luisteren.")
                    }
                }
            }
        }
        .navigationTitle(rec.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                if rec.status == .done {
                    AIShareMenu(recording: rec, onChooseSpeakers: { showSpeakers = true })
                    Button { showSpeakers = true } label: { Image(systemName: "person.2") }
                        .accessibilityLabel("Sprekers benoemen")
                    ShareLink(item: rec.exportText, subject: Text(rec.title)) {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
                Menu {
                    Button("Naam wijzigen", systemImage: "pencil") {
                        titleDraft = rec.title
                        editingTitle = true
                    }
                    if rec.status == .done {
                        Button("Kopieer tekst", systemImage: "doc.on.doc") {
                            UIPasteboard.general.string = rec.exportText
                        }
                    }
                    ShareLink(item: store.audioURL(for: rec)) {
                        Label("Deel audio", systemImage: "waveform")
                    }
                    Menu("Opnieuw uitschrijven", systemImage: "arrow.clockwise") {
                        Button("Aantal sprekers automatisch") { reprocess(rec, speakers: nil) }
                        ForEach(2...6, id: \.self) { n in
                            Button("\(n) sprekers") { reprocess(rec, speakers: n) }
                        }
                    }
                    .disabled(!engine.modelsDownloaded || engine.isQueued(rec.id))
                    Divider()
                    Button("Verwijderen", systemImage: "trash", role: .destructive) { confirmDelete = true }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .accessibilityLabel("Meer")
                }
            }
        }
        .sheet(isPresented: $showSpeakers) {
            SpeakerNamesView(recordingID: rec.id)
        }
        .alert("Naam wijzigen", isPresented: $editingTitle) {
            TextField("Naam", text: $titleDraft)
            Button("Bewaar") {
                let title = titleDraft.trimmingCharacters(in: .whitespaces)
                if !title.isEmpty { store.update(rec.id) { $0.title = title } }
            }
            Button("Annuleer", role: .cancel) {}
        }
        .confirmationDialog("Deze opname verwijderen?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Verwijderen", role: .destructive) {
                player.stop()
                store.delete(rec)
                dismiss()
            }
        }
    }

    private func reprocess(_ rec: Recording, speakers: Int?) {
        store.update(rec.id) { $0.expectedSpeakers = speakers }
        if let updated = store.recording(withID: rec.id) {
            engine.enqueue(updated)
        }
    }
}

struct UtteranceRow: View {
    let recording: Recording
    let utterance: Utterance
    let isPlaying: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(recording.name(for: utterance.speaker))
                    .font(.subheadline.bold())
                    .foregroundStyle(SpeakerColors.color(for: utterance.speaker))
                Spacer()
                Text(Format.timestamp(utterance.start))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            Text(utterance.text)
                .textSelection(.enabled)
        }
        .padding(.vertical, 2)
        .listRowBackground(isPlaying ? SpeakerColors.color(for: utterance.speaker).opacity(0.12) : nil)
    }
}

struct ProcessingStatus: View {
    let recordingID: UUID
    @EnvironmentObject private var engine: TranscriptionEngine

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if engine.currentRecordingID == recordingID {
                Text(engine.phase.isEmpty ? "Bezig…" : engine.phase + "…").font(.headline)
                if let progress = engine.progress {
                    ProgressView(value: progress)
                } else {
                    ProgressView()
                }
                Text("Dit kan even duren bij een lang gesprek. Je mag het scherm vergrendelen; wissel liever niet naar zware apps.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Label("In de wachtrij", systemImage: "clock")
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Afspelen

@MainActor
final class AudioPlayer: NSObject, ObservableObject, AVAudioPlayerDelegate {
    @Published private(set) var isPlaying = false
    @Published private(set) var currentTime: Double = 0
    @Published private(set) var duration: Double = 0

    private var player: AVAudioPlayer?
    private var loadedURL: URL?
    private var timer: Timer?

    func load(url: URL) {
        guard loadedURL != url else { return }
        player = try? AVAudioPlayer(contentsOf: url)
        player?.delegate = self
        loadedURL = url
        duration = player?.duration ?? 0
        currentTime = 0
    }

    func play(url: URL, from time: Double? = nil) {
        load(url: url)
        guard let player else { return }
        try? AVAudioSession.sharedInstance().setCategory(.playback)
        try? AVAudioSession.sharedInstance().setActive(true)
        if let time { player.currentTime = time }
        player.play()
        isPlaying = true
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, let player = self.player else { return }
                self.currentTime = player.currentTime
            }
        }
    }

    func pause() {
        player?.pause()
        isPlaying = false
        timer?.invalidate()
    }

    func seek(to time: Double) {
        player?.currentTime = time
        currentTime = time
    }

    func stop() {
        player?.stop()
        isPlaying = false
        timer?.invalidate()
    }

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            self.isPlaying = false
            self.timer?.invalidate()
            self.currentTime = 0
        }
    }
}

struct PlayerControls: View {
    @ObservedObject var player: AudioPlayer
    let url: URL

    var body: some View {
        HStack(spacing: 12) {
            Button {
                player.isPlaying ? player.pause() : player.play(url: url)
            } label: {
                Image(systemName: player.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 36))
            }
            .buttonStyle(.plain)

            Slider(
                value: Binding(get: { player.currentTime }, set: { player.seek(to: $0) }),
                in: 0...max(player.duration, 1)
            )
            Text(Format.timestamp(player.currentTime))
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .onAppear { player.load(url: url) }
    }
}
