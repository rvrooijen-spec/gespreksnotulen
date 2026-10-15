import SwiftUI

@main
struct GespreksnotulenApp: App {
    @StateObject private var store = RecordingStore()
    @StateObject private var recorder = AudioRecorder()
    @StateObject private var engine = TranscriptionEngine()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .environmentObject(recorder)
                .environmentObject(engine)
                .onAppear { engine.attach(store: store) }
        }
    }
}

enum SpeakerColors {
    static let palette: [Color] = [.blue, .orange, .green, .purple, .pink, .teal, .brown, .indigo]

    static func color(for speaker: Int?) -> Color {
        guard let speaker else { return .secondary }
        return palette[(speaker - 1) % palette.count]
    }
}
