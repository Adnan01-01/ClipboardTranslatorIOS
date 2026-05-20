import Foundation
import MLKitTranslate
import Combine

class TranslationService: ObservableObject {
    @Published var isModelsReady = false
    @Published var isZhToEnDownloaded = false
    @Published var isEnToZhDownloaded = false
    @Published var statusMessage = "Language packs required for offline use"

    private let zhToEnTranslator: Translator
    private let enToZhTranslator: Translator

    init() {
        let zhToEnOptions = TranslatorOptions(
            sourceLanguage: .chinese,
            targetLanguage: .english
        )
        zhToEnTranslator = Translator.translator(options: zhToEnOptions)

        let enToZhOptions = TranslatorOptions(
            sourceLanguage: .english,
            targetLanguage: .chinese
        )
        enToZhTranslator = Translator.translator(options: enToZhOptions)
        
        checkModelStatus()
    }

    func checkModelStatus() {
        let modelManager = ModelManager.modelManager()
        let zhModel = TranslateRemoteModel.translateRemoteModel(language: .chinese)
        let enModel = TranslateRemoteModel.translateRemoteModel(language: .english)
        let zhReady = modelManager.isModelDownloaded(zhModel)
        let enReady = modelManager.isModelDownloaded(enModel)
        
        DispatchQueue.main.async {
            self.isZhToEnDownloaded = zhReady && enReady
            self.isEnToZhDownloaded = enReady && zhReady
            self.isModelsReady = zhReady && enReady
            if self.isModelsReady {
                self.statusMessage = "Bilingual offline models ready"
            } else {
                self.statusMessage = "Language packs required for offline use"
            }
        }
    }

    func downloadModels(completion: @escaping (Bool) -> Void) {
        DispatchQueue.main.async { self.statusMessage = "Downloading Chinese model..." }
        let conditions = ModelDownloadConditions(
            allowsCellularAccess: true,
            allowsBackgroundDownloading: true
        )
        zhToEnTranslator.downloadModelIfNeeded(with: conditions) { [weak self] error in
            if let error = error {
                DispatchQueue.main.async {
                    self?.statusMessage = "Chinese model failed: \(error.localizedDescription)"
                }
                completion(false)
                return
            }
            DispatchQueue.main.async { self?.statusMessage = "Downloading English model..." }
            self?.enToZhTranslator.downloadModelIfNeeded(with: conditions) { [weak self] error in
                if let error = error {
                    DispatchQueue.main.async {
                        self?.statusMessage = "English model failed: \(error.localizedDescription)"
                    }
                    completion(false)
                    return
                }
                self?.checkModelStatus()
                completion(true)
            }
        }
    }

    private func isChineseText(_ text: String) -> Bool {
        for scalar in text.unicodeScalars {
            if scalar.value >= 0x4E00 && scalar.value <= 0x9FFF {
                return true
            }
        }
        return false
    }

    func translate(_ text: String, completion: @escaping (String) -> Void) {
        let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { completion(""); return }

        let translator = isChineseText(cleaned) ? zhToEnTranslator : enToZhTranslator
        
        let conditions = ModelDownloadConditions(
            allowsCellularAccess: false,
            allowsBackgroundDownloading: false
        )
        translator.downloadModelIfNeeded(with: conditions) { error in
            guard error == nil else {
                completion("Model unavailable - please download first")
                return
            }
            translator.translate(cleaned) { result, error in
                if let error = error {
                    completion("Translation error: \(error.localizedDescription)")
                } else {
                    completion(result ?? "")
                }
            }
        }
    }
}
