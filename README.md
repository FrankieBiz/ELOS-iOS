# ELOS — Native iOS Gym App

A hyper-aesthetic, offline-first gym tracking app built entirely in **SwiftUI + SwiftData**. No web views, no Capacitor, no JavaScript. 100% native Apple.

---

## What's in the App

| Tab | What it does |
|-----|-------------|
| **Today** | Your program's workout for today, streak badge, week calendar, recent PRs |
| **Train** | Browse 5 built-in programs, 70+ exercise library, full workout history |
| **Progress** | Apple Charts — volume over time, muscle breakdown, bodyweight trend, PR list |
| **You** | Profile, units, haptics, rest timer, plate setup, HealthKit |

**Active Workout (fullscreen):**
- Live elapsed timer + progress bar
- Smart weight pre-fill based on your last session
- WeightStepper with long-press to accelerate
- Rest timer with animated ring + haptics at 3s countdown
- IPF color-coded plate calculator
- Automatic PR detection (Epley 1RM formula) + confetti burst
- Difficulty rating after each set → adjusts next recommendation

**Onboarding:** 4-page animated flow (welcome → name → body stats → program pick)

---

## Built-In Programs

- **PPL** — Push/Pull/Legs, 6 days
- **Upper/Lower** — 4 days
- **Full Body 3×** — Beginner-friendly
- **5/3/1** — Advanced strength
- **Bro Split** — Classic 5-day

---

## Tech Stack

| Layer | Technology |
|-------|-----------|
| UI | SwiftUI (iOS 17+) |
| State | `@Observable AppState` |
| Persistence | SwiftData (6 models) |
| Charts | Apple Charts framework |
| Haptics | `UIImpactFeedbackGenerator` |
| Progressive overload | UserDefaults `[exerciseName: recommendedKg]` |

**No backend. No internet required. All data lives locally on device.**

---

## File Structure

```
ELOS/
├── ELOSApp.swift              # @main entry, SwiftData container
├── AppState.swift             # Global @Observable state, streak logic
├── ContentView.swift          # 4-tab TabView + fullScreenCover workout
├── Theme.swift                # Colors, fonts, spacing, haptics, animations
│
├── Models/
│   └── ELOSModels.swift       # WorkoutSession, WorkoutSet, PersonalRecord,
│                              # CustomExercise, WorkoutTemplate, BodyMetric
│
├── Services/
│   ├── ExerciseData.swift     # 70+ exercises with muscle groups + SF Symbols
│   ├── ProgramLibrary.swift   # 5 programs with day-by-day structure
│   └── APIService.swift       # Stub (app is fully offline)
│
└── Views/
    ├── Onboarding/
    │   └── OnboardingFlow.swift
    ├── Today/
    │   └── TodayView.swift
    ├── Train/
    │   ├── TrainView.swift           # Programs / Library / History tabs
    │   ├── ActiveSessionView.swift   # Full workout flow
    │   └── WorkoutCompleteView.swift # Summary + confetti
    ├── Progress/
    │   └── ProgressView.swift        # Apple Charts dashboard
    ├── Me/
    │   └── MeView.swift              # Settings + profile (struct: YouView)
    ├── Eat/
    │   └── EatView.swift             # Stub
    ├── Plan/
    │   └── PlanView.swift            # Stub
    └── Components/
        ├── SharedComponents.swift    # GlassCard, SolidCard, StatTile, etc.
        ├── Steppers.swift            # WeightStepper, RepStepper, RPESelector
        ├── RestTimer.swift           # Animated ring timer + banner
        ├── PlateCalculator.swift     # IPF color plate visualization
        └── Confetti.swift            # Particle burst for PRs
```

---

## Setup (Xcode Only — No Terminal Needed)

### 1. Clone the repo

Open **Terminal** on your Mac and run:

```bash
cd ~/Desktop
git clone https://github.com/FrankieBiz/ELOS-iOS.git
```

### 2. Create a new Xcode project

1. Open **Xcode**
2. **File → New → Project**
3. Select **iOS → App** → click **Next**
4. Fill in:
   - **Product Name**: `ELOS`
   - **Interface**: SwiftUI
   - **Language**: Swift
   - **Storage**: SwiftData ← **required**
5. Click **Next** → Save somewhere on your Mac → **Create**

### 3. Delete the default ContentView

In Xcode's left sidebar:
- Right-click `ContentView.swift` → **Delete** → **Remove Reference**

### 4. Add the Swift files

1. Open **Finder** → navigate to `~/Desktop/ELOS-iOS/`
2. In Xcode's left sidebar, right-click the top-level **ELOS** folder
3. Click **Add Files to "ELOS"...**
4. Select the **`ELOS/`** folder from the cloned repo
5. Make sure these are checked:
   - ✅ **Copy items if needed**
   - ✅ **Create groups**
6. Click **Add**

### 5. Set deployment target

1. Click the **ELOS** project (top of left sidebar, blue icon)
2. Select the **ELOS** target
3. **General** tab → scroll to **Minimum Deployments**
4. Set **iOS** to **17.0**

### 6. Build and run

1. Press **⌘B** to build — wait for "Build Succeeded"
2. Select a simulator from the top bar (e.g. iPhone 15 Pro)
3. Press **⌘R** to run

---

## Running on a Real iPhone

1. Plug your iPhone in via USB
2. In Xcode: **ELOS target → Signing & Capabilities → Team** → sign in with your Apple ID
3. Select your iPhone from the device picker at the top
4. Press **⌘R**
5. If you get "Untrusted Developer" on your phone: **Settings → General → VPN & Device Management → Developer App → Trust**

---

## TestFlight / App Store

1. Device selector → **Any iOS Device (arm64)**
2. **Product → Archive**
3. Organizer → **Distribute App → TestFlight & App Store**
4. Upload → go to [appstoreconnect.apple.com](https://appstoreconnect.apple.com)

> Requires a paid Apple Developer account ($99/year) to upload. Free Apple ID works for USB device testing.

---

## Common Issues

| Problem | Fix |
|---------|-----|
| Play button greyed out | Press ⌘B (build) first, then ⌘R |
| "Cannot find type X in scope" | Make sure all files in `ELOS/` were added with **Create groups** |
| Build errors after adding files | Product → Clean Build Folder (⇧⌘K) → then ⌘B |
| Simulator doesn't appear | Xcode → Settings → Platforms → download an iOS simulator |
| App crashes on launch | Check deployment target is iOS 17.0 |
