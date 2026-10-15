import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @EnvironmentObject private var store: RecordingStore
    @EnvironmentObject private var engine: TranscriptionEngine

    @State private var showRecorder = false
    @State private var showSettings = false
    @State private var showImporter = false
    @State private var path: [UUID] = []
    @State private var alertMessage: String?
    @State private var searchText = ""
    @State private var showImportHelp = false
    @State private var renameID: UUID?
    @State private var renameDraft = ""

    private var filtered: [Recording] {
        let query = searchText.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return store.recordings }
        return store.recordings.filter { rec in
            rec.title.localizedCaseInsensitiveContains(query)
                || rec.speakerNames.values.contains { $0.localizedCaseInsensitiveContains(query) }
                || rec.utterances.contains { $0.text.localizedCaseInsensitiveContains(query) }
        }
    }

    var body: some View {
        NavigationStack(path: $path) {
            List {
                if !engine.modelsDownloaded || isDownloading {
                    Section {
                        ModelBanner()
                    }
                }

                if store.recordings.isEmpty {
                    Section {
                        ContentUnavailableView(
                            "Nog geen gesprekken",
                            systemImage: "waveform",
                            description: Text("Tik op de rode knop om een gesprek op te nemen.")
                        )
                    }
                } else {
                    Section {
                        ForEach(filtered) { rec in
                            NavigationLink(value: rec.id) {
                                RecordingRow(recording: rec)
                            }
                            .accessibilityIdentifier("opname-\(rec.title)")
                            .swipeActions(edge: .leading) {
                                Button("Naam", systemImage: "pencil") {
                                    renameID = rec.id
                                    renameDraft = rec.title
                                }
                                .tint(.gray)
                            }
                        }
                        .onDelete { offsets in
                            let items = filtered
                            for index in offsets { store.delete(items[index]) }
                        }
                    }
                }
            }
            .navigationTitle("Notulen")
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Zoek in gesprekken")
            .navigationDestination(for: UUID.self) { id in
                RecordingDetailView(recordingID: id)
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { showSettings = true } label: { Image(systemName: "gearshape") }
                        .accessibilityLabel("Instellingen")
                }
            }
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 10) {
                    Button {
                        showImportHelp = true
                    } label: {
                        Label("Gesprek importeren", systemImage: "square.and.arrow.down")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 4)
                    }
                    .buttonStyle(.bordered)
                    .tint(.gray)
                    .foregroundStyle(.primary)

                    Button {
                        showRecorder = true
                    } label: {
                        Label("Opnemen", systemImage: "mic.fill")
                            .font(.title3.bold())
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
            }
        }
        .fullScreenCover(isPresented: $showRecorder) {
            RecordingView { recording in
                path = [recording.id]
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
        .sheet(isPresented: $showImportHelp) {
            ImportView {
                showImportHelp = false
                // Even wachten tot het blad dicht is, anders opent de bestandskiezer niet.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { showImporter = true }
            }
            .presentationDetents([.medium, .large])
        }
        .fileImporter(isPresented: $showImporter, allowedContentTypes: [.audio]) { result in
            switch result {
            case .success(let url):
                importFile(url)
            case .failure(let error):
                alertMessage = error.localizedDescription
            }
        }
        // Gedeeld vanuit een andere app, bijv. Dictafoon: Deel → Notulen.
        .onOpenURL { url in
            importFile(url)
        }
        .alert("Naam wijzigen", isPresented: Binding(get: { renameID != nil }, set: { if !$0 { renameID = nil } })) {
            TextField("Naam", text: $renameDraft)
            Button("Bewaar") {
                let title = renameDraft.trimmingCharacters(in: .whitespaces)
                if let id = renameID, !title.isEmpty { store.update(id) { $0.title = title } }
                renameID = nil
            }
            Button("Annuleer", role: .cancel) { renameID = nil }
        }
        .alert("Let op", isPresented: Binding(get: { alertMessage != nil }, set: { if !$0 { alertMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(alertMessage ?? "")
        }
    }

    private func importFile(_ url: URL) {
        Task {
            do {
                let rec = try await store.importAudio(from: url)
                if engine.modelsDownloaded { engine.enqueue(rec) }
                path = [rec.id]
            } catch {
                alertMessage = "Importeren mislukt: \(error.localizedDescription)"
            }
        }
    }

    private var isDownloading: Bool {
        switch engine.modelState {
        case .downloading, .loading, .failed: return true
        default: return false
        }
    }
}

struct RecordingRow: View {
    let recording: Recording
    @EnvironmentObject private var engine: TranscriptionEngine

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .firstTextBaseline) {
                Text(recording.title)
                    .font(.headline)
                    .lineLimit(2)
                Spacer(minLength: 8)
                statusLabel
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Text("\(recording.createdAt.formatted(.dateTime.weekday(.wide).day().month(.wide).year().hour().minute())) · \(Format.duration(recording.duration))")
                .font(.caption)
                .foregroundStyle(.secondary)
            if recording.status == .done, !recording.speakers.isEmpty {
                FlowLayout(spacing: 6) {
                    ForEach(recording.speakerTags, id: \.speaker) { tag in
                        SpeakerTag(name: tag.name, isMe: tag.isMe)
                    }
                }
                .padding(.top, 2)
            }
        }
        .padding(.vertical, 3)
    }

    @ViewBuilder private var statusLabel: some View {
        switch recording.status {
        case .done:
            EmptyView()
        case .processing:
            if engine.currentRecordingID == recording.id {
                ProgressView().controlSize(.mini)
            } else {
                Text("In wachtrij")
            }
        case .recorded:
            Text("Niet uitgeschreven")
        case .failed:
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
        }
    }
}

struct ModelBanner: View {
    @EnvironmentObject private var engine: TranscriptionEngine

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            switch engine.modelState {
            case .notDownloaded:
                Text("Spraakmodellen nodig").font(.headline)
                Text("Om gesprekken op je iPhone zelf uit te schrijven zijn eenmalig ca. 700 MB aan modellen nodig. Gebruik bij voorkeur wifi.")
                    .font(.subheadline).foregroundStyle(.secondary)
                Button("Nu downloaden") { Task { await engine.downloadModels() } }
                    .buttonStyle(.bordered)
            case .downloading(let what, let fraction):
                Text(what + "…").font(.headline)
                if let fraction {
                    ProgressView(value: fraction)
                    Text("\(Int(fraction * 100))% – houd de app open").font(.caption).foregroundStyle(.secondary)
                } else {
                    ProgressView()
                }
            case .loading:
                Text("Modellen laden…").font(.headline)
                Text("De eerste keer kan dit een paar minuten duren.").font(.caption).foregroundStyle(.secondary)
                ProgressView()
            case .failed(let message):
                Text("Downloaden mislukt").font(.headline)
                Text(message).font(.caption).foregroundStyle(.secondary)
                Button("Opnieuw proberen") { Task { await engine.downloadModels() } }
                    .buttonStyle(.bordered)
            case .ready:
                Label("Modellen klaar", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
            }
        }
        .padding(.vertical, 4)
    }
}

/// Naam van een spreker als klein grijs label ("tag").
struct SpeakerTag: View {
    let name: String
    var isMe = false

    var body: some View {
        HStack(spacing: 3) {
            if isMe {
                Image(systemName: "person.fill")
                    .font(.system(size: 9, weight: .semibold))
            }
            Text(name)
                .font(.caption2.weight(.semibold))
                .lineLimit(1)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 4)
        .foregroundStyle(.primary)
        .background(Capsule().fill(Color(.systemGray5)))
        .overlay(Capsule().strokeBorder(Color(.systemGray3), lineWidth: 0.5))
        .accessibilityLabel(isMe ? "\(name) (ik)" : name)
    }
}

/// Zet kinderen naast elkaar en gaat door op een nieuwe regel als het niet past.
struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0, widest: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x > 0, x + size.width > maxWidth {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
            widest = max(widest, x - spacing)
        }
        return CGSize(width: widest, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x > bounds.minX, x + size.width > bounds.maxX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            view.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
