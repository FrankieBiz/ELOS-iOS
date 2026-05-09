# ELOS — Native iOS Gym App

Pure SwiftUI + SwiftData. No web views, no npm, no CocoaPods. Just open and run.

---

## Setup (5 steps)

### Step 1 — Clone the repo

Open **Terminal** on your Mac and run:

```bash
cd ~/Desktop
git clone https://github.com/FrankieBiz/ELOS-iOS.git
```

Wait for it to finish. You'll see a folder called `ELOS-iOS` appear on your Desktop.

---

### Step 2 — Open in Xcode

In Terminal, run:

```bash
open ~/Desktop/ELOS-iOS/ELOS.xcodeproj
```

Xcode opens with everything already wired up. All 22 Swift files are already in the project — you don't need to drag or add anything.

---

### Step 3 — Sign in with your Apple ID

1. In Xcode, click **ELOS** in the left sidebar (the blue icon at the very top)
2. In the middle panel, click the **ELOS** target (under "Targets")
3. Click the **Signing & Capabilities** tab
4. Under **Team**, click the dropdown and select your Apple ID
   - If you don't see your Apple ID: click **Add an Account...**, sign in, then select it
5. Xcode will automatically handle code signing

---

### Step 4 — Pick a simulator

At the top of Xcode, next to the Play button, there's a device selector.  
Click it and choose **iPhone 15 Pro** (or any iPhone simulator listed).

---

### Step 5 — Run it

Press **⌘R** (or click the ▶ Play button).

Xcode builds the app (first build takes ~30–60 seconds) and launches the simulator.  
You'll see the ELOS onboarding screen.

---

## Running on a real iPhone

1. Plug your iPhone into your Mac with a USB cable
2. Xcode will ask you to **trust** the Mac on your phone — tap Trust
3. In the device selector (top of Xcode), choose your iPhone instead of a simulator
4. Press **⌘R**

If you get **"Untrusted Developer"** on your iPhone:  
Go to **Settings → General → VPN & Device Management → [your Apple ID] → Trust**

> Note: Running on a real device requires a free Apple ID. Uploading to the App Store requires a paid developer account ($99/year).

---

## What's in the app

| Tab | What it does |
|-----|-------------|
| **Today** | Your program's workout for today, streak tracker, week calendar, recent PRs |
| **Train** | 5 built-in programs, 70+ exercise library, full workout history |
| **Progress** | Volume charts, muscle breakdown, bodyweight trend (Apple Charts) |
| **You** | Profile, units, haptics, rest timer, plate setup, HealthKit |

**Active workout:**
- Smart weight suggestions based on your last session
- Rest timer with animated ring + haptic countdown
- Plate calculator with IPF color coding
- Auto PR detection with confetti

---

## If anything goes wrong

| Problem | Fix |
|---------|-----|
| "No account for team" | Go to Signing & Capabilities → add your Apple ID |
| Red errors in Xcode | Press **⇧⌘K** (Clean), then **⌘B** (Build) |
| Simulator not listed | Xcode → Settings → Platforms → download iOS 17 simulator |
| Build says "iOS 17 required" | Click ELOS target → General → set Minimum Deployments to iOS 17.0 |
| App crashes instantly | Make sure you selected iOS 17+ simulator, not an older one |
