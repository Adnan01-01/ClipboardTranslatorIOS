import Foundation
import MLKitTranslate

class TranslationService: ObservableObject {
    @Published var isZhToEnDownloaded = false
    @Published var isEnToZhDownloaded = false
    @Published var statusMessage = "Offline Models Not Downloaded"
    
    private var zhToEnTranslator: Translator?
    private var enToZhTranslator: Translator?
    
    init() {
        setupTranslators()
        checkModelStatus()
    }
    
    private func setupTranslators() {
        let zhToEnOptions = TranslatorOptions(sourceLanguage: .chinese, targetLanguage: .english)
        self.zhToEnTranslator = Translator.translator(options: zhToEnOptions)
        
        let enToZhOptions = TranslatorOptions(sourceLanguage: .english, targetLanguage: .chinese)
        self.enToZhTranslator = Translator.translator(options: enToZhOptions)
    }
    
    func checkModelStatus() {
        let modelManager = ModelManager.modelManager()
        
        let zhModel = TranslateRemoteModel.translateRemoteModel(language: .chinese)
        let enModel = TranslateRemoteModel.translateRemoteModel(language: .english)
        
        self.isZhToEnDownloaded = modelManager.isModelDownloaded(zhModel) && modelManager.isModelDownloaded(enModel)
        self.isEnToZhDownloaded = modelManager.isModelDownloaded(enModel) && modelManager.isModelDownloaded(zhModel)
        
        if isZhToEnDownloaded && isEnToZhDownloaded {
            statusMessage = "Bilingual translation models ready offline"
        } else {
            statusMessage = "Language packs required for offline use"
        }
    }
    
    func downloadModels(completion: @escaping (Bool) -> Void) {
        statusMessage = "Downloading offline translation models..."
        let modelManager = ModelManager.modelManager()
        
        let zhModel = TranslateRemoteModel.translateRemoteModel(language: .chinese)
        let enModel = TranslateRemoteModel.translateRemoteModel(language: .english)
        
        let conditions = ModelDownloadConditions(
            allowsCellularAccess: true,
            allowsBackgroundDownloading: true
        )
        
        modelManager.download(zhModel, conditions: conditions) { [weak self] error in
            if let error = error {
                self?.statusMessage = "Chinese model download failed: \(error.localizedDescription)"
                completion(false)
                return
            }
            
            modelManager.download(enModel, conditions: conditions) { [weak self] error in
                if let error = error {
                    self?.statusMessage = "English model download failed: \(error.localizedDescription)"
                    completion(false)
                    return
                }
                
                self?.checkModelStatus()
                completion(true)
            }
        }
    }
    
    // Quick offline detection: contains Chinese character?
    private func isChineseText(_ text: String) -> Bool {
        for scalar in text.unicodeScalars {
            // CJK Unified Ideographs block
            if scalar.value >= 0x4E00 && scalar.value <= 0x9FFF {
                return true
            }
        }
        return false
    }
    
    func translate(_ text: String, completion: @escaping (String) -> Void) {
        let cleanedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanedText.isEmpty else {
            completion("")
            return
        }
        
        if isChineseText(cleanedText) {
            guard isZhToEnDownloaded, let translator = zhToEnTranslator else {
                completion("Download offline model first")
                return
            }
            translator.translate(cleanedText) { result, error in
                if let error = error {
                    completion("Error: \(error.localizedDescription)")
                } else if let result = result {
                    completion(result)
                }
            }
        } else {
            guard isEnToZhDownloaded, let translator = enToZhTranslator else {
                completion("Download offline model first")
                return
            }
            translator.translate(cleanedText) { result, error in
                if let error = error {
                    completion("Error: \(error.localizedDescription)")
                } else if let result = result {
                    completion(result)
                }
            }
        }
    }
}
