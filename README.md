# ELOS — Native iOS Gym App

Pure SwiftUI + SwiftData. No npm, no CocoaPods, no web views.

---

## Setup

### 1. Clone the repo

Open **Terminal** and run:

```bash
cd ~/Desktop
git clone https://github.com/FrankieBiz/ELOS-iOS.git
```

### 2. Open in Xcode

```bash
open ~/Desktop/ELOS-iOS/ELOS.xcodeproj
```

### 3. Sign in with your Apple ID

1. In the left sidebar, click **ELOS** (the blue icon at the top)
2. Select the **ELOS** target
3. Click **Signing & Capabilities**
4. Under **Team**, select your Apple ID from the dropdown
   - If it's not listed: click **Add an Account...**, sign in, then select it

### 4. Select a simulator or your iPhone

- **Simulator**: In the top bar next to the ▶ button, click the device picker → choose **iPhone 15 Pro**
- **Real iPhone**: Plug it in via USB → tap **Trust** on your phone → select it from the picker

### 5. Build and run

Press **⌘R**

First build takes ~30–60 seconds. The app launches into the ELOS onboarding screen.

---

## If you already have it cloned and just want the latest changes

```bash
cd ~/Desktop/ELOS-iOS
git pull
```

Then in Xcode: **⇧⌘K** (Clean Build Folder) → **⌘R** (Run)

---

## Troubleshooting

| Problem | Fix |
|---------|-----|
| "Requires a development team" | Signing & Capabilities → pick your Apple ID under Team |
| Play button greyed out | Press **⌘B** to build first, then **⌘R** |
| Red build errors | **⇧⌘K** to clean, then **⌘B** to rebuild |
| "Untrusted Developer" on iPhone | Settings → General → VPN & Device Management → your Apple ID → Trust |
| Simulator missing | Xcode → Settings → Platforms → download iOS 17 |

---

## Running on a real iPhone

1. Plug your iPhone into your Mac via USB
2. Select your iPhone from the device picker at the top of Xcode
3. Press **⌘R**
4. If prompted on your phone: tap **Trust This Computer**
5. If you see "Untrusted Developer": Settings → General → VPN & Device Management → tap your Apple ID → Trust

> A free Apple ID works for personal device testing. You only need a paid account ($99/yr) to submit to the App Store.

---

## Uploading to TestFlight

1. In the device picker, select **Any iOS Device (arm64)**
2. **Product → Archive**
3. Xcode Organizer opens → click **Distribute App**
4. Choose **TestFlight & App Store → Next → Upload**
5. Go to [appstoreconnect.apple.com](https://appstoreconnect.apple.com) → TestFlight → add yourself as a tester
