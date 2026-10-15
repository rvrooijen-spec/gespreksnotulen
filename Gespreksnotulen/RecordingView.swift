import SwiftUI

/// Scherm tijdens het opnemen.
struct RecordingView: View {
    var onFinished: (Recording) -> Void

    @EnvironmentObject private var store: RecordingStore
    @EnvironmentObject private var recorder: AudioRecorder
    @EnvironmentObject private var engine: TranscriptionEngine
    @Environment(\.dismiss) private var dismiss

    @State private var recording: Recording?
    @State private var errorMessage: String?
    @State private var confirmCancel = false
    @State private var suspendedEngine = false

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            Text(Format.timestamp(recorder.elapsed))
                .font(.system(size: 64, weight: .light, design: .rounded))
                .monospacedDigit()

            LevelMeter(level: recorder.level)
                .frame(height: 48)
                .padding(.horizontal, 40)

            Text(statusText)
                .foregroundStyle(.secondary)

            if let errorMessage {
                Text(errorMessage).foregroundStyle(.red).multilineTextAlignment(.center).padding(.horizontal)
            }

            Spacer()

            HStack(spacing: 48) {
                Button {
                    confirmCancel = true
                } label: {
                    Image(systemName: "xmark")
                        .font(.title2)
                        .frame(width: 64, height: 64)
                        .background(Circle().fill(Color(.secondarySystemBackground)))
                }
                .accessibilityLabel("Annuleren")

                Button(action: finish) {
                    Image(systemName: "stop.fill")
                        .font(.largeTitle)
                        .foregroundStyle(.white)
                        .frame(width: 88, height: 88)
                        .background(Circle().fill(.red))
                }
                .accessibilityLabel("Stoppen en bewaren")
                .disabled(!recorder.isRecording)

                Button {
                    recorder.togglePause()
                } label: {
                    Image(systemName: recorder.isPaused ? "record.circle" : "pause.fill")
                        .font(.title2)
                        .frame(width: 64, height: 64)
                        .background(Circle().fill(Color(.secondarySystemBackground)))
                }
                .accessibilityLabel(recorder.isPaused ? "Doorgaan" : "Pauzeren")
                .disabled(!recorder.isRecording)
            }
            .padding(.bottom, 48)
        }
        .tint(.primary)
        .task { await begin() }
        .confirmationDialog("Opname weggooien?", isPresented: $confirmCancel, titleVisibility: .visible) {
            Button("Weggooien", role: .destructive) { cancel() }
            Button("Doorgaan met opnemen", role: .cancel) {}
        }
        .interactiveDismissDisabled()
        .onDisappear {
            // Vangnet: als het scherm op een andere manier sluit.
            if recorder.isRecording, var rec = recording {
                rec.duration = recorder.stop()
                store.save(rec)
            }
            releaseEngine()
        }
    }

    private var statusText: String {
        if !recorder.isRecording { return "Voorbereiden…" }
        if recorder.isPaused { return "Gepauzeerd" }
        return "Opname loopt – mag met scherm uit"
    }

    private func begin() async {
        guard recording == nil, !suspendedEngine else { return }
        engine.suspend()
        suspendedEngine = true
        guard await AudioRecorder.requestPermission() else {
            errorMessage = "Geen toegang tot de microfoon. Zet dit aan via Instellingen > Notulen."
            return
        }
        let rec = store.startNewRecording()
        do {
            try recorder.start(to: store.audioURL(for: rec))
            recording = rec
        } catch {
            store.delete(rec)
            errorMessage = error.localizedDescription
        }
    }

    private func finish() {
        guard var rec = recording else { return }
        rec.duration = recorder.stop()
        store.save(rec)
        dismiss()
        onFinished(rec)
        let store = store
        let engine = engine
        Task {
            // Eerst comprimeren, daarna pas uitschrijven weer toestaan.
            let compressed = await store.compressAudio(of: rec)
            engine.resume()
            if engine.modelsDownloaded { engine.enqueue(compressed) }
        }
        suspendedEngine = false
    }

    private func cancel() {
        if recorder.isRecording { recorder.stop() }
        if let rec = recording { store.delete(rec) }
        releaseEngine()
        dismiss()
    }

    private func releaseEngine() {
        if suspendedEngine {
            engine.resume()
            suspendedEngine = false
        }
    }
}

struct LevelMeter: View {
    let level: Float

    var body: some View {
        GeometryReader { geo in
            let bars = 30
            HStack(alignment: .center, spacing: 3) {
                ForEach(0..<bars, id: \.self) { i in
                    let threshold = Float(i) / Float(bars)
                    Capsule()
                        .fill(level > threshold ? Color.red : Color(.tertiarySystemFill))
                        .frame(height: geo.size.height * (0.3 + 0.7 * CGFloat(sin(Double(i) / Double(bars) * .pi))))
                }
            }
            .animation(.linear(duration: 0.1), value: level)
        }
    }
}
