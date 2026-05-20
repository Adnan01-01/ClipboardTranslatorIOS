import SwiftUI

extension UIApplication {
    var rootViewController: UIViewController? {
        return self.connectedScenes
            .filter { $0.activationState == .foregroundActive }
            .first(where: { $0 is UIWindowScene })
            .flatMap { $0 as? UIWindowScene }?
            .windows
            .first(where: { $0.isKeyWindow })?
            .rootViewController
    }
}

struct ContentView: View {
    @StateObject private var translationService = TranslationService()
    @StateObject private var pipManager: PipTranslationManager
    @State private var isDownloading = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    
    init() {
        let service = TranslationService()
        _translationService = StateObject(wrappedValue: service)
        _pipManager = StateObject(wrappedValue: PipTranslationManager(translationService: service))
    }
    
    var body: some View {
        ZStack {
            // Premium background gradient
            LinearGradient(
                gradient: Gradient(colors: [Color(red: 0.08, green: 0.09, blue: 0.13), Color(red: 0.04, green: 0.04, blue: 0.06)]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 24) {
                    
                    // App Header
                    VStack(spacing: 8) {
                        Text("TransOverlay")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color(red: 0.4, green: 0.6, blue: 1.0), Color(red: 0.8, green: 0.4, blue: 1.0)],
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
                        
                        // Status pills
                        HStack(spacing: 12) {
                            StatusPill(title: "Chinese 🇨🇳", active: translationService.isZhToEnDownloaded)
                            StatusPill(title: "English 🇺🇸", active: translationService.isEnToZhDownloaded)
                        }
                        
                        if !translationService.isZhToEnDownloaded || !translationService.isEnToZhDownloaded {
                            Button(action: {
                                isDownloading = true
                                translationService.downloadModels { success in
                                    isDownloading = false
                                    if !success {
                                        alertMessage = "Model download failed. Please check internet connection."
                                        showAlert = true
                                    }
                                }
                            }) {
                                HStack {
                                    if isDownloading {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                            .padding(.trailing, 8)
                                    }
                                    Text(isDownloading ? "Downloading Packs..." : "Download Offline Models")
                                        .fontWeight(.semibold)
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(
                                    LinearGradient(colors: [.blue, .purple], startPoint: .leading, endPoint: .trailing)
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
                    
                    // Card 2: Floating PiP Control
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Image(systemName: "app.in.air.fill")
                                .foregroundColor(.purple)
                                .font(.title3)
                            Text("Floating Translation Overlay")
                                .font(.headline)
                                .foregroundColor(.white)
                        }
                        
                        Text(pipManager.isPipActive ? "Overlay Active: Copy text anywhere to translate" : "Tap below to launch the floating window")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.7))
                        
                        Button(action: {
                            if pipManager.isPipActive {
                                pipManager.stopPip()
                            } else {
                                if let rootVC = UIApplication.shared.rootViewController {
                                    pipManager.startPip(from: rootVC)
                                } else {
                                    alertMessage = "Unable to launch PiP window."
                                    showAlert = true
                                }
                            }
                        }) {
                            Text(pipManager.isPipActive ? "Stop Overlay" : "Start Floating Overlay")
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(pipManager.isPipActive ? Color.red.opacity(0.8) : Color.green.opacity(0.8))
                                .cornerRadius(12)
                        }
                        .disabled(!translationService.isZhToEnDownloaded || !translationService.isEnToZhDownloaded)
                    }
                    .padding()
                    .background(Color.white.opacity(0.04))
                    .cornerRadius(16)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )
                    
                    // Card 3: Live Preview
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
                                Text(pipManager.translatedText.isEmpty ? "(Waiting for translation...)" : pipManager.translatedText)
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
                    
                    // Card 4: How to Configure (Guide)
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Configuring iOS (Critical Steps)")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        VStack(alignment: .leading, spacing: 12) {
                            GuideStep(num: "1", text: "Download both language packs above.")
                            GuideStep(num: "2", text: "Go to iPhone Settings > TransOverlay > Paste from Other Apps > change to 'Allow'.")
                            GuideStep(num: "3", text: "Start the overlay. Drag the floating window to the side of the screen to dock it as an arrow tab.")
                            GuideStep(num: "4", text: "Copy any Chinese/English chat text in Snapchat, then pull the arrow tab out to see your translation instantly!")
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
            Alert(title: Text("Alert"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
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

#Preview {
    ContentView()
}
