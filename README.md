# TransOverlay (iOS Clipboard Translation App)

A lightweight, native iOS utility that runs inside a Picture-in-Picture (PiP) window, polling the clipboard and translating Chinese <-> English texts offline using Google's ML Kit.

---

## How It Works (The Architecture)

1. **Floating Window:** Bypasses iOS's strict overlay sandboxing by rendering a custom UI inside an `AVPictureInPictureVideoCallViewController` video stream.
2. **Background Wakefulness:** Runs a silent audio loop (`AVAudioSession.sharedInstance()`) to keep the background clipboard polling thread active even when you are inside Snapchat or other apps.
3. **Privacy Bypass:** Relies on the iOS **"Always Allow Paste"** app setting to read the clipboard without triggering constant permission pop-ups.
4. **Offline Translate:** Uses Google ML Kit's local neural translation models (approx. 30MB per language), enabling sub-second local translations without cell data usage.

---

## Free Build Pipeline via Codemagic

Since you do not have a physical Mac, you can compile this app for the iOS Simulator for free using Codemagic's free tier (500 free build minutes per month on Mac M-series runners).

### Step 1: Upload the Code
1. Push this folder (`ClipboardTranslatorIOS`) to your personal **GitHub, GitLab, or Bitbucket** account.

### Step 2: Set Up Codemagic
1. Sign up for a free account at [Codemagic.io](https://codemagic.io/).
2. Connect your GitHub/GitLab account and select the **`ClipboardTranslatorIOS`** repository.
3. Choose **macOS / iOS Application** as your build type.
4. In the workflow settings:
   * **Build Platform:** iOS Simulator.
   * **Codemagic.yaml:** Check the option to read the build pipeline from the committed `codemagic.yaml` file (it is already included in your project!).
5. Click **Start New Build**.

### Step 3: Download the Artifact
* Once the build finishes (takes ~2 minutes), download the zipped build file: **`ClipboardTranslatorIOS.zip`**.

---

## Free Browser Testing via Appetize.io

You can run and test this iOS app on your Windows/Android browser using Appetize.io's free tier (100 minutes of device streaming per month).

1. Go to [Appetize.io](https://appetize.io/) and create a free account.
2. Click **Upload** and upload the **`ClipboardTranslatorIOS.zip`** file you downloaded from Codemagic.
3. Launch the simulator.
4. **Onboarding configuration:**
   * Open the app inside the simulator.
   * Click **Download Offline Models** to initialize the translation packages.
   * Minimize the app. Go to the native iOS **Settings > TransOverlay > Paste from Other Apps** and set it to **Allow**.
5. **Testing the overlay:**
   * Open the TransOverlay app again, and click **Start Floating Overlay**.
   * Drag the PiP window to the edge of the screen to dock it (it will turn into a small side arrow).
   * Open the native **Notes** app in the simulator, type any Chinese text (e.g., `你好`), highlight it, and tap **Copy**.
   * Pull the floating arrow tab out. The English translation (`Hello`) will be waiting for you instantly!
