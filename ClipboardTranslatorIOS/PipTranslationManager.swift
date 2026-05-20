import Foundation
import UIKit
import AVKit
import AVFoundation

// MARK: - PiP Content View Controller
// Must subclass AVPictureInPictureVideoCallViewController for the ContentSource API
class PipContentViewController: AVPictureInPictureVideoCallViewController {
    let containerView = UIView()
    let originalLabel = UILabel()
    let arrowLabel = UILabel()
    let translatedLabel = UILabel()

    override func viewDidLoad() {
        super.viewDidLoad()
        preferredContentSize = CGSize(width: 320, height: 120)
        setupUI()
    }

    private func setupUI() {
        // Dark glass background
        view.backgroundColor = UIColor(red: 0.08, green: 0.08, blue: 0.12, alpha: 0.95)

        // Source text label (top)
        originalLabel.textColor = UIColor(red: 0.6, green: 0.8, blue: 1.0, alpha: 1.0)
        originalLabel.font = UIFont.systemFont(ofSize: 11, weight: .regular)
        originalLabel.numberOfLines = 2
        originalLabel.textAlignment = .center
        originalLabel.text = "Copy text to begin..."

        // Arrow
        arrowLabel.text = "⬇"
        arrowLabel.textAlignment = .center
        arrowLabel.font = UIFont.systemFont(ofSize: 10)
        arrowLabel.textColor = .white.withAlphaComponent(0.5)

        // Translated text label (bottom)
        translatedLabel.textColor = .white
        translatedLabel.font = UIFont.systemFont(ofSize: 13, weight: .semibold)
        translatedLabel.numberOfLines = 2
        translatedLabel.textAlignment = .center
        translatedLabel.text = ""

        let stack = UIStackView(arrangedSubviews: [originalLabel, arrowLabel, translatedLabel])
        stack.axis = .vertical
        stack.spacing = 4
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),
            stack.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }

    func update(original: String, translated: String) {
        let maxLen = 45
        let snippet = original.count > maxLen ? String(original.prefix(maxLen)) + "…" : original
        originalLabel.text = ""\(snippet)""
        translatedLabel.text = translated
        arrowLabel.isHidden = translated.isEmpty
    }
}

// MARK: - PiP Translation Manager
class PipTranslationManager: NSObject, ObservableObject, AVPictureInPictureControllerDelegate {
    @Published var isPipActive = false
    @Published var currentText = ""
    @Published var translatedText = ""

    private var pipController: AVPictureInPictureController?
    private let pipContentVC = PipContentViewController()
    // Invisible anchor view — required by ContentSource API
    private let sourceView = UIView(frame: CGRect(x: 0, y: 0, width: 1, height: 1))
    private var audioPlayer: AVAudioPlayer?
    private var clipboardTimer: Timer?
    private var lastCopiedString = ""
    private let translationService: TranslationService

    init(translationService: TranslationService) {
        self.translationService = translationService
        super.init()
        setupAudioSession()
    }

    // MARK: - Audio Session (keeps app alive in background)
    private func setupAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .moviePlayback, options: [.mixWithOthers])
            try session.setActive(true)
            if let url = createSilentWavFile() {
                audioPlayer = try AVAudioPlayer(contentsOf: url)
                audioPlayer?.numberOfLoops = -1
                audioPlayer?.volume = 0.001
            }
        } catch {
            print("Audio session error: \(error.localizedDescription)")
        }
    }

    private func createSilentWavFile() -> URL? {
        guard let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else { return nil }
        let url = cacheDir.appendingPathComponent("silence.wav")
        guard !FileManager.default.fileExists(atPath: url.path) else { return url }

        // Minimal valid WAV: 44-byte header + 1 second of silence at 8kHz mono 16-bit
        let dataSize = 16000 // 8000 samples * 2 bytes
        var wav = Data()

        func appendString(_ s: String) { wav.append(contentsOf: s.utf8) }
        func appendInt32(_ v: Int32) {
            var val = v.littleEndian
            wav.append(contentsOf: withUnsafeBytes(of: &val) { Array($0) })
        }
        func appendInt16(_ v: Int16) {
            var val = v.littleEndian
            wav.append(contentsOf: withUnsafeBytes(of: &val) { Array($0) })
        }

        appendString("RIFF")
        appendInt32(Int32(36 + dataSize))
        appendString("WAVE")
        appendString("fmt ")
        appendInt32(16)          // subchunk1 size
        appendInt16(1)           // PCM format
        appendInt16(1)           // mono
        appendInt32(8000)        // sample rate
        appendInt32(16000)       // byte rate
        appendInt16(2)           // block align
        appendInt16(16)          // bits per sample
        appendString("data")
        appendInt32(Int32(dataSize))
        wav.append(Data(repeating: 0, count: dataSize))

        do { try wav.write(to: url); return url } catch { return nil }
    }

    // MARK: - PiP Control
    func startPip(from parentViewController: UIViewController) {
        guard AVPictureInPictureController.isPictureInPictureSupported() else {
            print("PiP not supported on this device/simulator")
            return
        }

        // Attach the invisible source view to the parent's view hierarchy (required)
        parentViewController.view.addSubview(sourceView)

        let contentSource = AVPictureInPictureController.ContentSource(
            activeVideoCallSourceView: sourceView,
            contentViewController: pipContentVC
        )

        pipController = AVPictureInPictureController(contentSource: contentSource)
        pipController?.delegate = self
        pipController?.canStartPictureInPictureAutomaticallyFromBackground = true

        audioPlayer?.play()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.pipController?.startPictureInPicture()
        }
    }

    func stopPip() {
        pipController?.stopPictureInPicture()
        audioPlayer?.stop()
        stopClipboardPolling()
        sourceView.removeFromSuperview()
    }

    // MARK: - Clipboard Polling
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
        guard let copied = UIPasteboard.general.string,
              !copied.isEmpty,
              copied != lastCopiedString else { return }

        lastCopiedString = copied
        DispatchQueue.main.async { self.currentText = copied }

        translationService.translate(copied) { [weak self] result in
            DispatchQueue.main.async {
                self?.translatedText = result
                self?.pipContentVC.update(original: copied, translated: result)
            }
        }
    }

    // MARK: - AVPictureInPictureControllerDelegate
    func pictureInPictureControllerDidStartPictureInPicture(_ controller: AVPictureInPictureController) {
        DispatchQueue.main.async {
            self.isPipActive = true
            self.startClipboardPolling()
        }
    }

    func pictureInPictureControllerDidStopPictureInPicture(_ controller: AVPictureInPictureController) {
        DispatchQueue.main.async {
            self.isPipActive = false
            self.stopClipboardPolling()
        }
    }

    func pictureInPictureController(_ controller: AVPictureInPictureController,
                                    failedToStartPictureInPictureWithError error: Error) {
        print("PiP failed: \(error.localizedDescription)")
        DispatchQueue.main.async { self.isPipActive = false }
    }
}
