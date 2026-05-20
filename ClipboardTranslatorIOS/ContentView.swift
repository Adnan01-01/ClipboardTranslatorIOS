import SwiftUI

// MARK: - Helpers
struct PipSourceView: UIViewRepresentable {
    let sourceView: UIView
    func makeUIView(context: Context) -> UIView {
        sourceView.backgroundColor = .clear
        return sourceView
    }
    func updateUIView(_ uiView: UIView, context: Context) {}
}

struct ViewControllerFinder: UIViewControllerRepresentable {
    var onFind: (UIViewController) -> Void
    func makeUIViewController(context: Context) -> UIViewController {
        let vc = UIViewController()
        vc.view.backgroundColor = .clear
        DispatchQueue.main.async {
            if let parent = vc.parent {
                onFind(parent)
            } else {
                onFind(vc)
            }
        }
        return vc
    }
    func updateUIViewController(_ vc: UIViewController, context: Context) {}
}

struct ContentView: View {
    @EnvironmentObject private var translationService: TranslationService
    @EnvironmentObject private var pipManager: PipTranslationManager
    @State private var isDownloading = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var hostVC: UIViewController?

    var body: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.08, green: 0.09, blue: 0.13),
                    Color(red: 0.04, green: 0.04, blue: 0.06)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            // Helper to find the host UIViewController
            ViewControllerFinder { vc in
                self.hostVC = vc
            }
            .frame(width: 0, height: 0)

            ScrollView {
                VStack(spacing: 24) {

                    // App Header
                    VStack(spacing: 8) {
                        Text("TransOverlay")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [
                                        Color(red: 0.4, green: 0.6, blue: 1.0),
                                        Color(red: 0.8, green: 0.4, blue: 1.0)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )

                        Text("iOS Floating Clipboard Translator")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(Color.white.opacity(0.6))
                    }
                    .padding(.top, 28)

                    // Card 1: Language Models
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Image(systemName: "icloud.and.arrow.down.fill")
                                .foregroundColor(.cyan)
                                .font(.title3)
                            Text("Bilingual Translation Packs")
                                .font(.headline)
                                .foregroundColor(.white)
                        }

                        Text(translationService.statusMessage)
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.8))

                        HStack(spacing: 12) {
                            StatusPill(title: "Chinese", active: translationService.isZhToEnDownloaded)
                            StatusPill(title: "English", active: translationService.isEnToZhDownloaded)
                        }

                        if !translationService.isModelsReady {
                            Button(action: {
                                isDownloading = true
                                translationService.downloadModels { success in
                                    DispatchQueue.main.async {
                                        isDownloading = false
                                        if !success {
                                            alertMessage = "Model download failed. Please check internet connection."
                                            showAlert = true
                                        }
                                    }
                                }
                            }) {
                                HStack {
                                    if isDownloading {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                            .padding(.trailing, 8)
                                    }
                                    Text(isDownloading ? "Downloading..." : "Download Offline Models")
                                        .fontWeight(.semibold)
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(
                                    LinearGradient(
                                        colors: [.blue, .purple],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .cornerRadius(12)
                            }
                            .disabled(isDownloading)
                        }
                    }
                    .padding()
                    .background(Color.white.opacity(0.04))
                    .cornerRadius(16)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )

                    // Card 2: PiP Control
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Image(systemName: "pip.fill")
                                .foregroundColor(.purple)
                                .font(.title3)
                            Text("Floating Translation Overlay")
                                .font(.headline)
                                .foregroundColor(.white)
                        }

                        Text(pipManager.isPipActive
                             ? "Overlay Active: Copy text anywhere to translate"
                             : "Tap below to launch the floating window")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.7))

                        Button(action: {
                            if pipManager.isPipActive {
                                pipManager.stopPip()
                            } else {
                                if let vc = hostVC {
                                    pipManager.startPip(from: vc)
                                } else {
                                    alertMessage = "Unable to find parent view controller."
                                    showAlert = true
                                }
                            }
                        }) {
                            Text(pipManager.isPipActive ? "Stop Overlay" : "Start Floating Overlay")
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(
                                    pipManager.isPipActive
                                    ? Color.red.opacity(0.8)
                                    : Color.green.opacity(0.8)
                                )
                                .cornerRadius(12)
                        }
                        .disabled(!translationService.isModelsReady)
                    }
                    .padding()
                    .background(Color.white.opacity(0.04))
                    .cornerRadius(16)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )

                    // Card 3: Live preview when active
                    if pipManager.isPipActive {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Active Session Clipboard")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.white.opacity(0.5))

                            VStack(alignment: .leading, spacing: 8) {
                                Text("Original:")
                                    .font(.caption)
                                    .foregroundColor(.cyan)
                                Text(pipManager.currentText.isEmpty ? "(Nothing copied yet)" : pipManager.currentText)
                                    .font(.system(size: 14))
                                    .foregroundColor(.white)

                                Divider().background(Color.white.opacity(0.1))

                                Text("Translated:")
                                    .font(.caption)
                                    .foregroundColor(.purple)
                                Text(pipManager.translatedText.isEmpty ? "(Waiting...)" : pipManager.translatedText)
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.white)
                            }
                            .padding()
                            .background(Color.black.opacity(0.2))
                            .cornerRadius(12)
                        }
                        .padding()
                        .background(Color.white.opacity(0.04))
                        .cornerRadius(16)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.white.opacity(0.08), lineWidth: 1)
                        )
                        .transition(.slide)
                    }

                    // Card 4: Setup Guide
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Setup Guide")
                            .font(.headline)
                            .foregroundColor(.white)

                        VStack(alignment: .leading, spacing: 12) {
                            GuideStep(num: "1", text: "Download both language packs above.")
                            GuideStep(num: "2", text: "Go to iPhone Settings > TransOverlay > Paste from Other Apps > Allow.")
                            GuideStep(num: "3", text: "Start the overlay and drag the window to the screen edge to dock it.")
                            GuideStep(num: "4", text: "Copy any Chinese or English text, then pull the side arrow to see the translation.")
                        }
                    }
                    .padding()
                    .background(Color.white.opacity(0.02))
                    .cornerRadius(16)

                }
                .padding(.horizontal, 16)
                .padding(.bottom, 32)
            }
        }
        .alert(isPresented: $showAlert) {
            Alert(
                title: Text("Alert"),
                message: Text(alertMessage),
                dismissButton: .default(Text("OK"))
            )
        }
    }
}

struct StatusPill: View {
    let title: String
    let active: Bool

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(active ? Color.green : Color.red)
                .frame(width: 8, height: 8)
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.white.opacity(0.8))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.white.opacity(0.06))
        .cornerRadius(20)
    }
}

struct GuideStep: View {
    let num: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(num)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.black)
                .frame(width: 20, height: 20)
                .background(Color.cyan)
                .clipShape(Circle())
                .padding(.top, 2)

            Text(text)
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.7))
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
