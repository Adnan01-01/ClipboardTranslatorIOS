import SwiftUI
import AVFoundation

@main
struct ClipboardTranslatorIOSApp: App {
    @StateObject private var translationService: TranslationService
    @StateObject private var pipManager: PipTranslationManager

    init() {
        let service = TranslationService()
        let pip = PipTranslationManager(translationService: service)
        _translationService = StateObject(wrappedValue: service)
        _pipManager = StateObject(wrappedValue: pip)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(translationService)
                .environmentObject(pipManager)
        }
    }
}
