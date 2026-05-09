# ELOS Native iOS — Xcode Setup Guide

## Requirements
- macOS 14+ (Sonoma)
- Xcode 15.2+
- iOS 17+ deployment target

---

## 1. Create the Xcode Project

1. Open Xcode → **File → New → Project**
2. Choose **iOS → App**
3. Set:
   - **Product Name**: `ELOS`
   - **Team**: Your Apple Developer account
   - **Bundle Identifier**: `com.yourname.elos`
   - **Interface**: SwiftUI
   - **Language**: Swift
   - **Storage**: SwiftData ← REQUIRED
4. Click **Next** → choose a save location

---

## 2. Add the Swift Files

Delete the default `ContentView.swift` Xcode generates, then **drag the entire `ELOS/` folder** from this repo into your Xcode project navigator.

When the import dialog appears:
- ✅ **Copy items if needed**
- ✅ **Create groups**

The folder structure being imported:

```
ELOS/
├── ELOSApp.swift
├── AppState.swift
├── ContentView.swift
├── Theme.swift
│
├── Models/
│   └── ELOSModels.swift
│
├── Services/
│   ├── ExerciseData.swift
│   ├── ProgramLibrary.swift
│   └── APIService.swift
│
└── Views/
    ├── Onboarding/
    │   └── OnboardingFlow.swift
    ├── Today/
    │   └── TodayView.swift
    ├── Train/
    │   ├── TrainView.swift
    │   ├── ActiveSessionView.swift
    │   └── WorkoutCompleteView.swift
    ├── Progress/
    │   └── ProgressView.swift
    ├── Me/
    │   └── MeView.swift
    ├── Eat/
    │   └── EatView.swift        ← stub, kept for project ref
    ├── Plan/
    │   └── PlanView.swift       ← stub, kept for project ref
    └── Components/
        ├── SharedComponents.swift
        ├── Steppers.swift
        ├── RestTimer.swift
        ├── PlateCalculator.swift
        └── Confetti.swift
```

---

## 3. Add the Charts Framework

1. Select your project in the navigator → **Package Dependencies**
2. **Apple Charts is built into iOS 16+** — no package needed, it's part of the SDK
3. Make sure your deployment target is **iOS 17.0**

---

## 4. Configure Signing & Capabilities

1. Select the `ELOS` target → **Signing & Capabilities**
2. Set your **Team** (Apple Developer account)
3. Optionally add **HealthKit** capability if you want Apple Health integration

---

## 5. Info.plist Keys (HealthKit only)

If you added the HealthKit capability, add to `Info.plist`:

```xml
<key>NSHealthShareUsageDescription</key>
<string>ELOS reads body metrics from Apple Health.</string>

<key>NSHealthUpdateUsageDescription</key>
<string>ELOS can log workouts and body weight to Apple Health.</string>
```

---

## 6. Run the App

Select your iPhone or simulator → **Run (⌘R)**

First launch shows onboarding:
1. Welcome screen
2. Name input
3. Body stats (weight, height, experience level, units)
4. Program selection (PPL, Upper/Lower, Full Body, 5/3/1, Bro Split)

After onboarding you land on the **Today** tab.

---

## 7. What's in the App

| Tab | Features |
|-----|----------|
| **Today** | Program hero card, today's workout CTA, streak badge, week calendar, quick stats, recent PRs |
| **Train** | Programs browser, exercise library (70+ exercises), workout history; start any workout |
| **Progress** | Volume bar chart, muscle breakdown, streak card, PR list, bodyweight trend (Apple Charts) |
| **You** | Profile, units/theme/haptics settings, rest timer default, plate setup, HealthKit toggle |

**Active Workout (fullscreen):**
- Elapsed timer, progress bar, finish button
- Per-set weight + reps with smart pre-fill from previous performance
- WeightStepper with long-press acceleration
- Rest timer with animated ring, auto-haptic countdown
- Plate calculator with IPF color visualization
- Automatic PR detection (Epley 1RM) with confetti
- Difficulty rating after each set → adjusts next recommendation

---

## 8. Architecture

| Layer | Technology |
|-------|-----------|
| UI | SwiftUI (100% native) |
| Global state | `@Observable AppState` |
| Persistence | SwiftData (6 models) |
| Progressive overload | UserDefaults `[String: Double]` keyed by exercise |
| Charts | Apple Charts framework |
| Haptics | `UIImpactFeedbackGenerator` |

All data is local — no backend, no internet required. Perfect for the gym.

---

## 9. App Store Submission

1. **Archive**: Product → Archive
2. **Validate**: Xcode Organizer → Validate App
3. **Distribute**: App Store Connect → upload
4. Set screenshots, description, pricing in App Store Connect
5. Submit for Apple Review
