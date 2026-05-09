# ELOS Native iOS — Xcode Setup Guide

## Requirements
- macOS 14+ (Sonoma)
- Xcode 15+
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
   - **Storage**: SwiftData ← IMPORTANT
4. Click **Next** → save to `ELOS-Native/`

---

## 2. Add Swift Files

Delete the default `ContentView.swift` that Xcode generates, then **drag all files** from `ELOS-Native/ELOS/` into your Xcode project:

```
ELOSApp.swift
ContentView.swift
AppState.swift

Models/
  ELOSModels.swift

Views/
  Today/TodayView.swift
  Train/TrainView.swift
  Train/ActiveSessionView.swift
  Eat/EatView.swift
  Plan/PlanView.swift
  Me/MeView.swift
  Components/SharedComponents.swift

Services/
  APIService.swift
  ExerciseData.swift
```

When the import dialog appears: ✅ **Copy items if needed** + ✅ **Create groups**

---

## 3. Configure Signing & Capabilities

1. Select the `ELOS` target → **Signing & Capabilities**
2. Set your **Team** (Apple Developer account)
3. Add capabilities:
   - **Push Notifications** (for future)
   - **HealthKit** (optional, for Apple Health integration)
   - **Camera** (for barcode scanning — requires NSCameraUsageDescription in Info.plist)

---

## 4. Info.plist Keys

Add these to `Info.plist`:
```xml
<key>NSCameraUsageDescription</key>
<string>ELOS uses the camera to scan food barcodes for quick nutrition logging.</string>

<key>NSHealthShareUsageDescription</key>
<string>ELOS can read your health data to provide insights.</string>

<key>NSHealthUpdateUsageDescription</key>
<string>ELOS can write workouts and nutrition data to Apple Health.</string>
```

---

## 5. Run the App

Select your iPhone (or simulator) → **Run (⌘R)**

The app will launch with:
- ✅ Full offline storage (SwiftData)
- ✅ 5 tabs: Today / Train / Eat / Plan / Me
- ✅ Live workout logging with timer
- ✅ Nutrition tracking with macro rings
- ✅ Habit tracking with streaks
- ✅ Assignment and exam tracker
- ✅ Dark/light mode (system adaptive)

---

## 6. Connect a Backend (Optional)

In the app: **Me → (future Settings screen) → Backend URL + Auth Token**

The app works 100% offline — the backend is optional for cloud sync.

If you want to connect your existing ELOS backend:
1. Set `apiBaseURL` to `https://elos.vercel.app`
2. Set `authToken` to the user's JWT from your NextAuth system
3. The `APIService.swift` layer will sync data automatically

---

## 7. AI Meal Parsing

To enable Claude-powered AI meal parsing:
1. Add your Anthropic API key to the app (via Settings → Developer)
2. The `SyncManager.parseMealWithAI()` function in `APIService.swift` handles the call
3. Rate-limit this to 30 calls/hour per your existing cost controls

---

## 8. Barcode Scanner (AVFoundation)

The barcode scanner sheet (`BarcodeScannerSheet`) is currently a stub.
To implement the real camera scanner:
1. Create a `UIViewRepresentable` wrapping `AVCaptureSession`
2. Add an `AVMetadataObjectTypeEAN13Code` output
3. On scan, call OpenFoodFacts API: `https://world.openfoodfacts.org/api/v2/product/{barcode}.json`

---

## 9. App Store Submission

1. **Archive**: Product → Archive
2. **Validate**: Xcode Organizer → Validate App
3. **Upload**: Distribute App → App Store Connect
4. **App Store Connect**: Set screenshots, description, pricing
5. **Review**: Submit for Apple Review

---

## Architecture Notes

| Layer | Technology | Purpose |
|---|---|---|
| UI | SwiftUI | 100% native Apple views |
| State | `@Observable` AppState | Global ephemeral state |
| Persistence | SwiftData | Offline-first local storage |
| Networking | URLSession + actor | Backend sync (optional) |
| AI | Anthropic Claude API | Meal parsing |

All data lives locally in SwiftData first. Network sync is additive — the app is fully functional without any internet connection. Perfect for the gym.
