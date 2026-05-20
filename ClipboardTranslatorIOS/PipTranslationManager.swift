import Foundation
import UIKit
import AVKit
import AVFoundation

class PipViewController: UIViewController {
    let textLabel = UILabel()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.black.withAlphaComponent(0.85)
        
        // Premium typography and UI design
        textLabel.textColor = .white
        textLabel.font = UIFont.systemFont(ofSize: 14, weight: .semibold)
        textLabel.numberOfLines = 0
        textLabel.textAlignment = .center
        textLabel.text = "Copy text to begin..."
        
        view.addSubview(textLabel)
        textLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            textLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 14),
            textLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -14),
            textLabel.topAnchor.constraint(equalTo: view.topAnchor, constant: 8),
            textLabel.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -8)
        ])
    }
}

class PipTranslationManager: NSObject, ObservableObject, AVPictureInPictureControllerDelegate {
    @Published var isPipActive = false
    @Published var currentText = ""
    @Published var translatedText = ""
    @Published var lastCopiedString = ""
    
    private var pipController: AVPictureInPictureController?
    private let pipViewController = PipViewController()
    private var audioPlayer: AVAudioPlayer?
    private var clipboardTimer: Timer?
    private let translationService: TranslationService
    
    init(translationService: TranslationService) {
        self.translationService = translationService
        super.init()
        setupAudioSession()
    }
    
    private func setupAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .moviePlayback, options: [.mixWithOthers])
            try session.setActive(true)
            
            // Create and play silent WAV loop
            if let silentURL = createSilentWavFile() {
                audioPlayer = try AVAudioPlayer(contentsOf: silentURL)
                audioPlayer?.numberOfLoops = -1 // Loop infinitely
                audioPlayer?.volume = 0.01 // Very low volume to prevent noise
            }
        } catch {
            print("Audio session configuration failed: \(error.localizedDescription)")
        }
    }
    
    private func createSilentWavFile() -> URL? {
        let fileManager = FileManager.default
        guard let cacheDir = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first else { return nil }
        let fileURL = cacheDir.appendingPathComponent("silence.wav")
        
        if fileManager.fileExists(atPath: fileURL.path) {
            return fileURL
        }
        
        let sampleRate: Int32 = 8000
        let numChannels: Int16 = 1
        let bitsPerSample: Int16 = 16
        let byteRate = sampleRate * Int32(numChannels) * Int32(bitsPerSample) / 8
        let blockAlign = numChannels * bitsPerSample / 8
        
        var header = Data()
        header.append("RIFF".data(using: .utf8)!)
        var fileSize: Int32 = 36 + 8000 * 2
        header.append(Data(bytes: &fileSize, count: 4))
        header.append("WAVE".data(using: .utf8)!)
        header.append("fmt ".data(using: .utf8)!)
        var subchunk1Size: Int32 = 16
        header.append(Data(bytes: &subchunk1Size, count: 4))
        var audioFormat: Int16 = 1
        header.append(Data(bytes: &audioFormat, count: 2))
        var channels = numChannels
        header.append(Data(bytes: &channels, count: 2))
        var rate = sampleRate
        header.append(Data(bytes: &rate, count: 4))
        var bRate = byteRate
        header.append(Data(bytes: &bRate, count: 4))
        var align = blockAlign
        header.append(Data(bytes: &align, count: 2))
        var bps = bitsPerSample
        header.append(Data(bytes: &bps, count: 2))
        header.append("data".data(using: .utf8)!)
        var subchunk2Size: Int32 = 8000 * 2
        header.append(Data(bytes: &subchunk2Size, count: 4))
        
        let silentBuffer = Data(repeating: 0, count: 8000 * 2)
        var wavData = Data()
        wavData.append(header)
        wavData.append(silentBuffer)
        
        do {
            try wavData.write(to: fileURL)
            return fileURL
        } catch {
            return nil
        }
    }
    
    func startPip(from parentViewController: UIViewController) {
        guard AVPictureInPictureController.isPictureInPictureSupported() else {
            print("PiP is not supported on this device")
            return
        }
        
        // Configure PiP view controller size
        pipViewController.preferredContentSize = CGSize(width: 320, height: 110)
        let contentSource = AVPictureInPictureController.ContentSource(
            activeVideoCallViewController: pipViewController,
            preferredParentViewController: parentViewController
        )
        
        pipController = AVPictureInPictureController(contentSource: contentSource)
        pipController?.delegate = self
        pipController?.canStartPictureInPictureAutomaticallyFromBackground = true
        
        // Start background silent loop
        audioPlayer?.play()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.pipController?.startPictureInPicture()
        }
    }
    
    func stopPip() {
        pipController?.stopPictureInPicture()
        audioPlayer?.stop()
        stopClipboardPolling()
    }
    
    func startClipboardPolling() {
        clipboardTimer?.invalidate()
        clipboardTimer = Timer.scheduledTimer(withTimeInterval: 0.8, repeats: true) { [weak self] _ in
            self?.checkClipboard()
        }
    }
    
    func stopClipboardPolling() {
        clipboardTimer?.invalidate()
        clipboardTimer = nil
    }
    
    private func checkClipboard() {
        guard let copiedString = UIPasteboard.general.string, !copiedString.isEmpty else { return }
        
        if copiedString != lastCopiedString {
            lastCopiedString = copiedString
            currentText = copiedString
            
            translationService.translate(copiedString) { [weak self] result in
                DispatchQueue.main.async {
                    self?.translatedText = result
                    self?.updatePipDisplay(original: copiedString, translated: result)
                }
            }
        }
    }
    
    private func updatePipDisplay(original: String, translated: String) {
        let maxLen = 50
        let originalSnippet = original.count > maxLen ? String(original.prefix(maxLen)) + "..." : original
        
        let displayText = """
        "\(originalSnippet)"
        ⬇️
        \(translated)
        """
        
        pipViewController.textLabel.text = displayText
    }
    
    // MARK: - AVPictureInPictureControllerDelegate
    
    func pictureInPictureControllerDidStartPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        DispatchQueue.main.async {
            self.isPipActive = true
            self.startClipboardPolling()
        }
    }
    
    func pictureInPictureControllerDidStopPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        DispatchQueue.main.async {
            self.isPipActive = false
            self.stopClipboardPolling()
        }
    }
    
    func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, failedToStartPictureInPictureWithError error: Error) {
        print("PiP failed to start: \(error.localizedDescription)")
        DispatchQueue.main.async {
            self.isPipActive = false
        }
    }
}
