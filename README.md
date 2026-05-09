# ELOS — Daily Performance OS

Your personal app for habits, training, nutrition, schedule, and recovery. Built with React + Vite, wrapped in Capacitor 6 for native iOS.

---

## How this repo works

You write code on your Windows PC using Claude Code. When you want to test on your iPhone, you pull the repo on your Mac, build it, and open it in Xcode. That's it — no weird sync tools needed.

```
Windows (code here) ──git push──▶ GitHub ──git pull──▶ Mac (build + run on iPhone)
```

---

## One-time Mac setup

You only need to do this section once.

### 1. Install the tools

**Xcode** — download it from the Mac App Store. It's big (~10 GB), so start this first.

**Homebrew** — open Terminal and run:
```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

**Node.js** (via Homebrew):
```bash
brew install node
```

**CocoaPods** (iOS dependency manager):
```bash
sudo gem install cocoapods
```

If that fails with a Ruby error, try:
```bash
brew install cocoapods
```

### 2. Clone the repo

```bash
git clone https://github.com/FrankieBiz/ELOS-iOS.git
cd ELOS-iOS
```

### 3. Install npm dependencies and run the first build

```bash
npm install
npm run build
npx cap sync
```

### 4. Install iOS CocoaPods dependencies

```bash
cd ios/App
pod install
cd ../..
```

This downloads the native Capacitor plugins. Only needed after the first clone and whenever you add a new Capacitor plugin.

### 5. Open in Xcode

```bash
npx cap open ios
```

This opens `ios/App/App.xcworkspace` — always use the `.xcworkspace` file, **not** `.xcodeproj`. If Xcode is already open you can also open it manually via `File → Open`.

---

## Running on your iPhone

### First time only — trust your Mac

1. Plug your iPhone into your Mac with a cable.
2. Xcode will ask you to trust the device — tap **Trust** on your iPhone.

### Sign the app

1. In Xcode, click the top-level **App** project in the left sidebar.
2. Go to **Signing & Capabilities**.
3. Under **Team**, sign in with your Apple ID (free account works for device testing).
4. The Bundle Identifier is already set to `com.elos.app` — you can leave it or change it to something like `com.yourname.elos`.
5. Make sure **Automatically manage signing** is checked.

### Run it

1. In the top bar, click the device selector (next to the play button) and choose your iPhone.
2. Hit the **▶ Play** button (or `Cmd + R`).
3. Xcode builds and installs the app on your phone. First build takes ~1-2 minutes.

**If you get an "Untrusted Developer" error on your iPhone:**
Go to `Settings → General → VPN & Device Management → Developer App → Trust`.

---

## Your coding workflow

Every time you make changes on your Windows PC and want to see them on your iPhone:

**On Windows (after making changes):**
```bash
git add .
git commit -m "your message"
git push
```

**On Mac:**
```bash
git pull
npm run build
npx cap sync
```

Then hit **▶** in Xcode — it redeploys to your phone in seconds.

> You don't need to re-run `pod install` unless you add new Capacitor plugins.

---

## Uploading to TestFlight

Once you're happy with a build and want to share it or test it properly:

1. In Xcode, make sure your device target is set to **Any iOS Device (arm64)** (not your specific phone).
2. Go to **Product → Archive**.
3. Wait for the archive to finish — it opens the Organizer window automatically.
4. Click **Distribute App → TestFlight & App Store → Next**.
5. Follow the prompts. Xcode uploads it to App Store Connect.
6. Go to [appstoreconnect.apple.com](https://appstoreconnect.apple.com) → TestFlight → add yourself as a tester.
7. You'll get an email invite — accept it, install the TestFlight app on your iPhone, and install ELOS from there.

> **Note:** To upload to TestFlight you need a paid Apple Developer account ($99/year). For just running on your own phone via USB, a free Apple ID works fine.

---

## Local web preview (no iPhone needed)

If you just want to see the app in a browser while working:

```bash
npm run dev
```

Open `http://localhost:5173`. The app will look exactly like it does on iPhone, minus the native status bar behavior.

---

## Project structure

```
ELOS-iOS/
├── screens/          # Tab screens (Today, Train, Eat, Plan, Me)
├── app.jsx           # Root component + state management
├── shell.jsx         # StatusBar, TabBar, NavBar, shared UI components
├── sheets.jsx        # Bottom sheet modals (log meal, add habit, etc.)
├── settings_screens.jsx  # Settings sub-screens
├── storage.js        # localStorage persistence + cloud sync
├── styles.css        # All styles (design system + iOS-specific overrides)
├── main.jsx          # Vite entry point + Capacitor native init
├── vite.config.js    # Build config
├── capacitor.config.json  # iOS app config (bundle ID, plugins)
└── ios/App/          # Xcode project — open App.xcworkspace
```

---

## Backend API

The cloud sync feature uses a lightweight Vercel API. See [README_BACKEND.md](README_BACKEND.md) for endpoint docs. The app works fully offline without it — all data is stored locally on device.
