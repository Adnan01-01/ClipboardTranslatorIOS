import SwiftUI
import AVFoundation

@main
struct ClipboardTranslatorIOSApp: App {
    @StateObject private var translationService = TranslationService()
    @StateObject private var pipManager = PipTranslationManager()
    
    init() {
        setupAudioSession()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(translationService)
                .environmentObject(pipManager)
                .onAppear {
                    pipManager.setService(translationService)
                }
        }
    }
    
    private func setupAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .videoChat, options: [.mixWithOthers, .defaultToSpeaker])
            try session.setActive(true)
        } catch {
            print("Startup audio session configuration failed: \(error.localizedDescription)")
        }
    }
}
