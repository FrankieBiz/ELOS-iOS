# Training Integration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Wire all training tab features into a coherent pre→during→post workout arc via a new `TrainingContext` observable, replacing scattered `@State` booleans and adding context-aware TrainView states.

**Architecture:** A new `TrainingContext` class is injected at app root and observed by all training views. It owns navigation flags, phase state (idle/warmup/active/postSummary), and the session summary. AppViewModel gains `todayReadiness`. TrainViewModel gains a PR accumulator and a pure `buildSessionSummary()` function. PostSessionSummaryView is replaced with a richer version driven by `SessionSummary`.

**Tech Stack:** SwiftUI, SwiftData, Combine, MVVM, `@EnvironmentObject` injection.

---

## File Map

| Path (relative to `Elos/Elos/`) | Action |
|---|---|
| `Features/Train/TrainingContext.swift` | **Create** |
| `SwiftData/ElosSchema.swift` | **Modify** — add `includeWarmups` to `UserSplitRecord` |
| `Features/Train/Programs/SplitFinderModels.swift` | **Modify** — add `includeWarmups` to `SplitRecommendation` |
| `Features/Train/Programs/SplitRecommender.swift` | **Modify** — set `includeWarmups` in `build()` |
| `AppViewModel.swift` | **Modify** — add `todayReadiness`, `loadTodayReadiness()` |
| `ElosApp.swift` | **Modify** — inject `TrainingContext` |
| `Features/Train/TrainViewModel.swift` | **Modify** — `prsHitThisSession`, `buildSessionSummary()` |
| `Views/TrainView.swift` | **Modify** — nav migration, 4 states, readiness gate, post-session sheet |
| `Features/Train/Programs/ProgramsView.swift` | **Modify** — active split progress card |
| `Features/Train/Readiness/ReadinessCheckInView.swift` | **Modify** — `onComplete` callback |
| `Features/Train/Programs/SplitSubscribeSheet.swift` | **Modify** — set `includeWarmups` |
| `Views/ActiveSessionView.swift` | **Modify** — warmup phase, readiness nudge, session-end handoff |
| `Features/ActiveWorkout/PostSessionSummaryView.swift` | **Replace** |

**Build command** (run after each task to verify):
```bash
cd /Users/frankbisignano/dev/elos && xcodebuild build \
  -project apps/elos-mobile/Elos/Elos.xcodeproj \
  -scheme Elos \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  2>&1 | grep -v "static subscript\|Combine\|missing import" \
       | grep -E "error:|BUILD SUCCEEDED|BUILD FAILED" | head -20
```

**Git repo for commits:** `apps/elos-mobile/Elos/` (the iOS project has its own `.git`)

---

## Task 1: Create `TrainingContext` and `SessionSummary`

**Files:**
- Create: `apps/elos-mobile/Elos/Elos/Features/Train/TrainingContext.swift`

- [ ] **Step 1: Create the file with full content**

```swift
import SwiftUI
import Combine

// MARK: - Session Summary

struct SessionSummary {
    var startedAt: Date
    var totalVolumeKg: Double
    var setsByMuscle: [String: Int]
    var prsHit: [String]
    var comparisonPercent: Double?
    var comparisonLabel: String?
    var nextWorkoutDay: UserSplitDayRecord?
    var nextWorkoutDate: Date?
}

// MARK: - Training Phase

enum TrainingPhase {
    case idle
    case warmup
    case active
    case postSummary
}

// MARK: - TrainingContext

final class TrainingContext: ObservableObject {
    import Combine

    // MARK: Phase
    @Published var phase: TrainingPhase = .idle

    // MARK: Navigation (owned here instead of TrainView @State)
    @Published var showSplitFinder    = false
    @Published var showAnalytics      = false
    @Published var showLibrary        = false
    @Published var showTemplates      = false
    @Published var showHistory        = false
    @Published var showStretches      = false
    @Published var showSplitLibrary   = false
    @Published var showLeaderboard    = false
    @Published var showExercisePicker = false

    // MARK: Readiness
    @Published var showReadinessSheet = false

    // MARK: Warmup
    @Published var warmupExercises: [WarmupExercise] = []
    @Published var warmupPhaseComplete = false

    // MARK: Post-session
    @Published var sessionSummary: SessionSummary? = nil
    @Published var showPostSummary = false
    @Published var pendingAnalytics = false

    // MARK: Derived (set by TrainView via update())
    private(set) var shouldSuggestDeload: Bool = false
    private(set) var readinessScore: Int? = nil

    var volumeNudge: String? {
        guard let score = readinessScore else { return nil }
        if score <= 2 { return "Very low energy today — consider reducing volume." }
        if score == 3 { return "Moderate fatigue — consider –20% volume today." }
        return nil
    }

    // MARK: - API

    /// Called from TrainView on .onAppear and .onChange to pass derived state in.
    func update(shouldDeload: Bool, readinessScore: Int?) {
        self.shouldSuggestDeload = shouldDeload || (readinessScore.map { $0 <= 2 } ?? false)
        self.readinessScore = readinessScore
    }

    /// Called from ReadinessCheckInView after save. Caller must reload vm.todayReadiness.
    func readinessDidComplete(_ record: ReadinessCheckInRecord) {
        showReadinessSheet = false
    }

    /// Called from ActiveSessionView "Finish" flow, before vm.showingSession = false.
    func sessionDidEnd(summary: SessionSummary) {
        sessionSummary = summary
        showPostSummary = true
        phase = .postSummary
    }

    func dismissPostSummary() {
        showPostSummary = false
        sessionSummary = nil
        phase = .idle
    }
}
```

> **Note:** The `import Combine` inside the class body above is a typo in the plan — do NOT include it there. The file-level `import Combine` at the top is correct. The class body starts with `// MARK: Phase`.

- [ ] **Step 2: Build to verify no errors**

Run the build command above.
Expected: `BUILD SUCCEEDED`

- [ ] **Step 3: Commit**

```bash
git -C /Users/frankbisignano/dev/elos/apps/elos-mobile/Elos add Elos/Features/Train/TrainingContext.swift
git -C /Users/frankbisignano/dev/elos/apps/elos-mobile/Elos commit -m "feat: add TrainingContext and SessionSummary"
```

---

## Task 2: Schema — Add `includeWarmups` to `UserSplitRecord`

**Files:**
- Modify: `apps/elos-mobile/Elos/Elos/SwiftData/ElosSchema.swift`

The `UserSplitRecord` class starts around line 439. Add the field after `pinnedWeekdaysJSON`.

- [ ] **Step 1: Add property after `pinnedWeekdaysJSON` declaration**

In the class body, after:
```swift
var pinnedWeekdaysJSON: String? = nil // JSON [Int] of Calendar weekday numbers; nil = ordinal rotation
```
Add:
```swift
var includeWarmups: Bool = false      // true = warmup exercises shown before session
```

- [ ] **Step 2: Add parameter to `init`**

The `init` signature currently ends with:
```swift
pinnedWeekdaysJSON: String? = nil) {
```
Change to:
```swift
pinnedWeekdaysJSON: String? = nil,
includeWarmups: Bool = false) {
```

- [ ] **Step 3: Add assignment in `init` body**

After:
```swift
self.pinnedWeekdaysJSON  = pinnedWeekdaysJSON
```
Add:
```swift
self.includeWarmups      = includeWarmups
```

- [ ] **Step 4: Build to verify**

Expected: `BUILD SUCCEEDED`

- [ ] **Step 5: Commit**

```bash
git -C /Users/frankbisignano/dev/elos/apps/elos-mobile/Elos add Elos/SwiftData/ElosSchema.swift
git -C /Users/frankbisignano/dev/elos/apps/elos-mobile/Elos commit -m "feat: add includeWarmups to UserSplitRecord schema"
```

---

## Task 3: Add `includeWarmups` to `SplitRecommendation` and wire through

**Files:**
- Modify: `apps/elos-mobile/Elos/Elos/Features/Train/Programs/SplitFinderModels.swift`
- Modify: `apps/elos-mobile/Elos/Elos/Features/Train/Programs/SplitRecommender.swift`

`SplitRecommendation` is defined around line 195 of `SplitFinderModels.swift`.

- [ ] **Step 1: Add field to `SplitRecommendation`**

The struct currently ends with:
```swift
    var matchTags: [String]
}
```
Change to:
```swift
    var matchTags: [String]
    var includeWarmups: Bool
}
```

- [ ] **Step 2: Fix the `SplitRecommendation` initializer call in `SplitRecommender.swift`**

In `SplitRecommender.swift` around line 143, the `return SplitRecommendation(...)` call. Add the new field:

```swift
return SplitRecommendation(
    name: "\(input.daysPerWeek)-Day \(template.style.displayName)",
    style: template.style,
    days: builtDays,
    estimatedMinutes: input.sessionMinutes,
    matchScore: finalScore,
    matchTags: tags,
    includeWarmups: input.includeWarmups
)
```

- [ ] **Step 3: Build to verify**

Expected: `BUILD SUCCEEDED`

- [ ] **Step 4: Commit**

```bash
git -C /Users/frankbisignano/dev/elos/apps/elos-mobile/Elos add \
  Elos/Features/Train/Programs/SplitFinderModels.swift \
  Elos/Features/Train/Programs/SplitRecommender.swift
git -C /Users/frankbisignano/dev/elos/apps/elos-mobile/Elos commit -m "feat: add includeWarmups to SplitRecommendation"
```

---

## Task 4: `AppViewModel` — `todayReadiness` + `loadTodayReadiness()`

**Files:**
- Modify: `apps/elos-mobile/Elos/Elos/AppViewModel.swift`

`ReadinessCheckInRecord.logDate` is a `String` formatted as `"yyyy-MM-dd"`. The `overallScore` is a `Double` (average of 4 sliders on a 1–5 scale).

- [ ] **Step 1: Add `todayReadiness` published property**

In the `// MARK: - Training` section, after:
```swift
@Published var personalRecords: [PersonalRecord] = []
```
Add:
```swift
@Published var todayReadiness: ReadinessCheckInRecord? = nil
```

- [ ] **Step 2: Add `loadTodayReadiness()` method**

Add this method to the `// MARK: - Active Split` section (after `skipToday()`):

```swift
func loadTodayReadiness() {
    guard !currentUserID.isEmpty else { return }
    let uid = currentUserID
    let fmt = DateFormatter(); fmt.dateFormat = "yyyy-MM-dd"
    let todayStr = fmt.string(from: Date())
    let desc = FetchDescriptor<ReadinessCheckInRecord>(
        predicate: #Predicate { $0.ownerID == uid }
    )
    let all = (try? context.fetch(desc)) ?? []
    todayReadiness = all.first { $0.logDate == todayStr }
}
```

- [ ] **Step 3: Call `loadTodayReadiness()` inside `loadForUser()`**

At the end of `loadForUser()`, just before `loadActiveSplit()`, add:
```swift
loadTodayReadiness()
```

So it reads:
```swift
loadTodayReadiness()
loadActiveSplit()
Task { await syncCanvasIfConfigured() }
Task { await syncSplitsFromServer() }
```

- [ ] **Step 4: Build to verify**

Expected: `BUILD SUCCEEDED`

- [ ] **Step 5: Commit**

```bash
git -C /Users/frankbisignano/dev/elos/apps/elos-mobile/Elos add Elos/AppViewModel.swift
git -C /Users/frankbisignano/dev/elos/apps/elos-mobile/Elos commit -m "feat: add todayReadiness to AppViewModel"
```

---

## Task 5: Inject `TrainingContext` in `ElosApp`

**Files:**
- Modify: `apps/elos-mobile/Elos/Elos/ElosApp.swift`

- [ ] **Step 1: Add `@StateObject private var trainingContext = TrainingContext()`**

After:
```swift
@StateObject private var socialViewModel: SocialViewModel
```
Add:
```swift
@StateObject private var trainingContext = TrainingContext()
```

- [ ] **Step 2: Inject via `.environmentObject`**

In `var body: some Scene`, after:
```swift
.environmentObject(socialViewModel)
```
Add:
```swift
.environmentObject(trainingContext)
```

- [ ] **Step 3: Build to verify**

Expected: `BUILD SUCCEEDED`

- [ ] **Step 4: Commit**

```bash
git -C /Users/frankbisignano/dev/elos/apps/elos-mobile/Elos add Elos/ElosApp.swift
git -C /Users/frankbisignano/dev/elos/apps/elos-mobile/Elos commit -m "feat: inject TrainingContext at app root"
```

---

## Task 6: `TrainViewModel` — `prsHitThisSession` + `buildSessionSummary()`

**Files:**
- Modify: `apps/elos-mobile/Elos/Elos/Features/Train/TrainViewModel.swift`

- [ ] **Step 1: Add `prsHitThisSession` property**

After:
```swift
@Published var newPRExerciseName: String?
```
Add:
```swift
@Published var prsHitThisSession: [String] = []
```

- [ ] **Step 2: Reset `prsHitThisSession` in `startSession()`**

In `startSession()`, after `sessionSets = []`, add:
```swift
prsHitThisSession = []
```

- [ ] **Step 3: Accumulate in `checkAndUpdatePR()`**

In `checkAndUpdatePR()`, after:
```swift
withAnimation(.spring(duration: 0.3)) {
    newPRExerciseName = exerciseName
}
```
Add:
```swift
if !prsHitThisSession.contains(exerciseName) {
    prsHitThisSession.append(exerciseName)
}
```

- [ ] **Step 4: Add `buildSessionSummary()` method**

Add this method after `finishSession()`:

```swift
/// Pure function — call BEFORE finishSession() since currentSession is nil after.
func buildSessionSummary(
    splitDayTemplateID: String = "",
    splitDayName: String = "",
    nextWorkoutDay: UserSplitDayRecord? = nil,
    nextWorkoutDate: Date? = nil
) -> SessionSummary {
    let session = currentSession
    let totalVol = session?.totalVolume ?? 0
    let startedAt = session?.startedAt ?? Date()

    // Sets by muscle group
    let doneSets = sessionSets.filter(\.isDone)
    var setsByMuscle: [String: Int] = [:]
    for set in doneSets {
        let group = muscleGroup(for: set.exerciseName)
        setsByMuscle[group, default: 0] += 1
    }

    // Comparison to last matching session
    var comparisonPercent: Double? = nil
    var comparisonLabel: String? = nil
    let matchKey = splitDayTemplateID.isEmpty ? splitDayName : splitDayTemplateID
    if !matchKey.isEmpty, let curSession = session {
        let uid = curSession.ownerID
        var desc = FetchDescriptor<WorkoutSessionRecord>(
            predicate: #Predicate { $0.ownerID == uid && $0.finishedAt != nil }
        )
        desc.sortBy = [SortDescriptor(\.startedAt, order: .reverse)]
        let allSessions = (try? context.fetch(desc)) ?? []
        let matching: WorkoutSessionRecord?
        if splitDayTemplateID.isEmpty {
            // Match by day name — look for sessions whose templateID is empty (also Split Finder)
            // Use volume comparison heuristic: closest prior session
            matching = allSessions.first { $0.id != curSession.id && $0.templateID.isEmpty }
        } else {
            matching = allSessions.first { $0.id != curSession.id && $0.templateID == splitDayTemplateID }
        }
        if let prior = matching, prior.totalVolume > 0 {
            let pct = (totalVol - prior.totalVolume) / prior.totalVolume
            comparisonPercent = pct
            let fmt = DateFormatter(); fmt.dateFormat = "MMM d"
            let dayLabel = splitDayName.isEmpty ? "last session" : splitDayName
            comparisonLabel = "vs last \(dayLabel) (\(fmt.string(from: prior.startedAt)))"
        }
    }

    return SessionSummary(
        startedAt: startedAt,
        totalVolumeKg: totalVol,
        setsByMuscle: setsByMuscle,
        prsHit: prsHitThisSession,
        comparisonPercent: comparisonPercent,
        comparisonLabel: comparisonLabel,
        nextWorkoutDay: nextWorkoutDay,
        nextWorkoutDate: nextWorkoutDate
    )
}
```

- [ ] **Step 5: Build to verify**

Expected: `BUILD SUCCEEDED`

- [ ] **Step 6: Commit**

```bash
git -C /Users/frankbisignano/dev/elos/apps/elos-mobile/Elos add Elos/Features/Train/TrainViewModel.swift
git -C /Users/frankbisignano/dev/elos/apps/elos-mobile/Elos commit -m "feat: add prsHitThisSession accumulator and buildSessionSummary to TrainViewModel"
```

---

## Task 7: `TrainView` Phase 1 — Migrate Navigation `@State` to `TrainingContext`

**Files:**
- Modify: `apps/elos-mobile/Elos/Elos/Views/TrainView.swift`

This is a pure refactor — no visible behaviour change. All `@State private var showX` booleans that control sheets become bindings to `context.showX`.

- [ ] **Step 1: Add `@EnvironmentObject var context: TrainingContext`**

After:
```swift
@Environment(\.modelContext) private var modelContext
```
Add:
```swift
@EnvironmentObject var context: TrainingContext
```

- [ ] **Step 2: Remove `@State` navigation booleans that now live in context**

Remove these lines:
```swift
@State private var showAnalytics       = false
@State private var showLibrary         = false
@State private var showTemplates       = false
@State private var showHistory         = false
@State private var showStretches       = false
@State private var showSplitLibrary    = false
@State private var showLeaderboard     = false
@State private var showCrew            = false
@State private var showExercisePicker  = false
@State private var showSplitFinder     = false
```

Keep `@State private var expandedExercise`, `selectedMuscleName`, `prsExpanded`, `recentExercises`, `userProgress` — these are local display state.

- [ ] **Step 3: Update all sheet presentations to use `context.*` bindings**

Change each `.sheet(isPresented:)` that used local `@State`:

```swift
.sheet(isPresented: $context.showSplitFinder) {
    SplitFinderView(dismissAll: { context.showSplitFinder = false })
        .environmentObject(vm)
}
.sheet(isPresented: $context.showAnalytics)        { AnalyticsView() }
.sheet(isPresented: $context.showLibrary)          { ExerciseLibraryView(modelContext: vm.modelContext) }
.sheet(isPresented: $context.showTemplates)        { TemplatesView(modelContext: vm.modelContext) }
.sheet(isPresented: $context.showStretches)        { StretchRoutinesView() }
.sheet(isPresented: $context.showSplitLibrary)     { ProgramsView() }
.sheet(isPresented: $context.showHistory)          { WorkoutHistoryView() }
.sheet(isPresented: $context.showLeaderboard) {
    CrewView()
        .environmentObject(socialVM)
        .environmentObject(vm)
}
```

- [ ] **Step 4: Update all `showX = true` callsites in toolbar + quick actions**

Toolbar buttons: change `showHistory = true` → `context.showHistory = true`, `showAnalytics = true` → `context.showAnalytics = true`, `showSplitFinder = true` → `context.showSplitFinder = true`.

Quick actions: change `showTemplates = true` → `context.showTemplates = true`, `showLibrary = true` → `context.showLibrary = true`, `showStretches = true` → `context.showStretches = true`, `showSplitLibrary = true` → `context.showSplitLibrary = true`.

Leaderboard card: change `showLeaderboard = true` → `context.showLeaderboard = true`.

Exercise section "Add" button: change `showExercisePicker = true` → `context.showExercisePicker = true`.

Recent exercises row: change `showExercisePicker = false` → `context.showExercisePicker = false`.

- [ ] **Step 5: Build to verify — should compile clean and look identical**

Expected: `BUILD SUCCEEDED`

- [ ] **Step 6: Commit**

```bash
git -C /Users/frankbisignano/dev/elos/apps/elos-mobile/Elos add Elos/Views/TrainView.swift
git -C /Users/frankbisignano/dev/elos/apps/elos-mobile/Elos commit -m "refactor: migrate TrainView navigation @State to TrainingContext"
```

---

## Task 8: `TrainView` Phase 2 — Four Context States

**Files:**
- Modify: `apps/elos-mobile/Elos/Elos/Views/TrainView.swift`

- [ ] **Step 1: Add `TrainState` enum and `trainState` computed property**

Add inside `TrainView` (before `var body`):

```swift
private enum TrainState {
    case noSplit
    case restDay
    case gymDayNoReadiness
    case gymDayReady
}

private var trainState: TrainState {
    guard vm.activeSplit != nil else { return .noSplit }
    let isGymToday = vm.weekLoadMap(daysAhead: 1).first?.loadType == "gym"
    guard isGymToday else { return .restDay }
    guard vm.todayReadiness != nil else { return .gymDayNoReadiness }
    return .gymDayReady
}
```

- [ ] **Step 2: Add `context.update()` call in `onAppear` and `onChange`**

In `.onAppear { ... }`, add at the end:
```swift
context.update(
    shouldDeload: trainVM.showDeloadSuggestion,
    readinessScore: vm.todayReadiness.map { Int($0.overallScore.rounded()) }
)
```

Add after the existing `.onChange(of: vm.showingSession)`:
```swift
.onChange(of: vm.todayReadiness?.id) { _, _ in
    context.update(
        shouldDeload: trainVM.showDeloadSuggestion,
        readinessScore: vm.todayReadiness.map { Int($0.overallScore.rounded()) }
    )
}
```

- [ ] **Step 3: Replace static `programHeader` with state-switched content**

In `var body`, the `VStack(spacing: 20)` currently starts with:
```swift
if trainVM.showDeloadSuggestion { deloadBanner }
programHeader
weekStrip
```

Replace with:
```swift
if context.shouldSuggestDeload { deloadBanner }
switch trainState {
case .noSplit:            noSplitCard
case .restDay:            restDayCard
case .gymDayNoReadiness:  programHeader; readinessPromptCard
case .gymDayReady:        programHeader
}
weekStrip
```

- [ ] **Step 4: Remove `trainVM.showDeloadSuggestion` from the deload banner trigger**

The banner is now shown via `context.shouldSuggestDeload` (set in `context.update()`). Remove the old `if trainVM.showDeloadSuggestion { deloadBanner }` line (it's replaced in step 3 above).

- [ ] **Step 5: Add `noSplitCard` view**

```swift
private var noSplitCard: some View {
    Button { context.showSplitFinder = true } label: {
        HStack(spacing: 14) {
            Image(systemName: "wand.and.stars")
                .font(.title2)
                .foregroundStyle(Color.tint)
                .frame(width: 40)
            VStack(alignment: .leading, spacing: 4) {
                Text("Find Your Split")
                    .font(.system(size: 18, weight: .bold))
                Text("Answer 8 questions and we'll build the right program for you.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .background(Color.tintSoft)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.tint.opacity(0.3), lineWidth: 1))
    }
    .buttonStyle(.plain)
}
```

- [ ] **Step 6: Add `restDayCard` view**

```swift
private var restDayCard: some View {
    VStack(alignment: .leading, spacing: 10) {
        HStack {
            Image(systemName: "moon.fill").foregroundStyle(Color.tint)
            Text("Rest Day").font(.system(size: 18, weight: .bold))
            Spacer()
        }
        if let next = vm.weekLoadMap(daysAhead: 7).first(where: { $0.loadType == "gym" }) {
            let cal = Calendar.current
            let daysAway = (cal.dateComponents([.day], from: cal.startOfDay(for: Date()),
                                               to: cal.startOfDay(for: next.date)).day ?? 0)
            let dayName = vm.gymDay(for: next.date)?.dayName ?? "Workout"
            Text("Next: \(dayName) in \(daysAway) day\(daysAway == 1 ? "" : "s")")
                .font(.subheadline).foregroundStyle(.secondary)
        }
    }
    .padding(16)
    .elosCard()
}
```

- [ ] **Step 7: Add `readinessPromptCard` view**

```swift
private var readinessPromptCard: some View {
    Button { context.showReadinessSheet = true } label: {
        HStack(spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "moon.zzz.fill").foregroundStyle(.indigo)
                Image(systemName: "flame.fill").foregroundStyle(.orange)
                Image(systemName: "bolt.fill").foregroundStyle(.yellow)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("Quick check-in before you train?")
                    .font(.subheadline).fontWeight(.semibold)
                Text("Takes 10 seconds — helps us guide your session.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right").font(.caption).foregroundStyle(.secondary)
        }
        .padding(14)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    .buttonStyle(.plain)
}
```

- [ ] **Step 8: Wire `showReadinessSheet` to present ReadinessCheckInView**

Add to the sheet list:
```swift
.sheet(isPresented: $context.showReadinessSheet) {
    ReadinessCheckInView(
        onDismiss: { context.showReadinessSheet = false },
        onComplete: { record in
            context.readinessDidComplete(record)
            vm.loadTodayReadiness()
        }
    )
    .environmentObject(vm)
}
```

- [ ] **Step 9: Update `quickActions` to show "Find Split" when no split**

In `quickActions`, change the Programs button line to:
```swift
if vm.activeSplit != nil {
    QuickActionButton(icon: "figure.strengthtraining.traditional",
                      label: vm.activeSplit?.name ?? "Programs") { context.showSplitLibrary = true }
} else {
    QuickActionButton(icon: "wand.and.stars",
                      label: "Find Split") { context.showSplitFinder = true }
}
```

- [ ] **Step 10: Add volume nudge line below start button**

In `startButton`, after the "Start Today's Workout" button and before the skip button, add:
```swift
if let nudge = context.volumeNudge {
    Text(nudge)
        .font(.caption)
        .foregroundStyle(Color.warn)
        .frame(maxWidth: .infinity, alignment: .center)
}
```

- [ ] **Step 11: Build to verify**

Expected: `BUILD SUCCEEDED`

- [ ] **Step 12: Commit**

```bash
git -C /Users/frankbisignano/dev/elos/apps/elos-mobile/Elos add Elos/Views/TrainView.swift
git -C /Users/frankbisignano/dev/elos/apps/elos-mobile/Elos commit -m "feat: add 4 context states to TrainView"
```

---

## Task 9: `ProgramsView` — Active Split Progress Card

**Files:**
- Modify: `apps/elos-mobile/Elos/Elos/Features/Train/Programs/ProgramsView.swift`

- [ ] **Step 1: Add the active split progress card component**

Add this private view inside `ProgramsView`:

```swift
private var activeSplitProgressCard: some View {
    guard let split = vm.activeSplit else { return AnyView(EmptyView()) }
    let cal = Calendar.current
    let weeksIn = max(1, (cal.dateComponents([.weekOfYear],
        from: split.activatedAt ?? Date(), to: Date()).weekOfYear ?? 0) + 1)
    let dayIdx = vm.currentSplitDayIndex + 1
    let dayCount = vm.activeSplitDays.count
    let progress = dayCount > 0 ? Double(dayIdx) / Double(dayCount) : 0

    return AnyView(
        Button {
            // Opens WorkoutSplitDetailView via selectedSplit
            selectedSplit = split
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(split.name)
                            .font(.subheadline).fontWeight(.bold)
                        Text("Week \(weeksIn) · Day \(dayIdx) of \(dayCount)")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption).foregroundStyle(.secondary)
                }
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.secondary.opacity(0.15))
                            .frame(height: 4)
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.tint)
                            .frame(width: geo.size.width * CGFloat(progress), height: 4)
                    }
                }
                .frame(height: 4)
            }
            .padding(14)
            .background(Color.tintSoft)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.tint.opacity(0.25), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 16)
        .padding(.top, 12)
    )
}
```

- [ ] **Step 2: Insert above `mySplitsSection` in `body`**

In `var body`, the `VStack` content currently starts:
```swift
if !userSplits.isEmpty {
    mySplitsSection
```
Change to:
```swift
activeSplitProgressCard
if !userSplits.isEmpty {
    mySplitsSection
```

- [ ] **Step 3: Build to verify**

Expected: `BUILD SUCCEEDED`

- [ ] **Step 4: Commit**

```bash
git -C /Users/frankbisignano/dev/elos/apps/elos-mobile/Elos add Elos/Features/Train/Programs/ProgramsView.swift
git -C /Users/frankbisignano/dev/elos/apps/elos-mobile/Elos commit -m "feat: add active split progress card to ProgramsView"
```

---

## Task 10: `ReadinessCheckInView` — `onComplete` Callback

**Files:**
- Modify: `apps/elos-mobile/Elos/Elos/Features/Train/Readiness/ReadinessCheckInView.swift`

- [ ] **Step 1: Add `onComplete` property**

The view currently has:
```swift
let onDismiss: () -> Void
```
Add below it:
```swift
var onComplete: ((ReadinessCheckInRecord) -> Void)? = nil
```

- [ ] **Step 2: Call `onComplete` after saving**

Find where the view saves the record. It calls `vm`'s model context and creates a `ReadinessCheckInRecord`. After the `context.insert(record)` and `try? modelContext.save()` call, add:
```swift
onComplete?(record)
```
Then call `onDismiss()` as before.

> To find the exact save location, look for where `ReadinessCheckInRecord(` is initialized in the view body. The callback fires with the newly created record right before `onDismiss()`.

- [ ] **Step 3: Build to verify**

Expected: `BUILD SUCCEEDED`

- [ ] **Step 4: Commit**

```bash
git -C /Users/frankbisignano/dev/elos/apps/elos-mobile/Elos add \
  Elos/Features/Train/Readiness/ReadinessCheckInView.swift
git -C /Users/frankbisignano/dev/elos/apps/elos-mobile/Elos commit -m "feat: add onComplete callback to ReadinessCheckInView"
```

---

## Task 11: `SplitSubscribeSheet` — Persist `includeWarmups`

**Files:**
- Modify: `apps/elos-mobile/Elos/Elos/Features/Train/Programs/SplitSubscribeSheet.swift`

- [ ] **Step 1: Set `includeWarmups` on the record**

In `saveAndDismiss()`, after:
```swift
splitRecord.pinnedWeekdays = sortedPinned
```
Add:
```swift
splitRecord.includeWarmups = recommendation.includeWarmups
```

- [ ] **Step 2: Build to verify**

Expected: `BUILD SUCCEEDED`

- [ ] **Step 3: Commit**

```bash
git -C /Users/frankbisignano/dev/elos/apps/elos-mobile/Elos add \
  Elos/Features/Train/Programs/SplitSubscribeSheet.swift
git -C /Users/frankbisignano/dev/elos/apps/elos-mobile/Elos commit -m "feat: persist includeWarmups when subscribing to split"
```

---

## Task 12: `ActiveSessionView` — Warmup Phase + Readiness Nudge + Session-End Handoff

**Files:**
- Modify: `apps/elos-mobile/Elos/Elos/Views/ActiveSessionView.swift`

- [ ] **Step 1: Add `@EnvironmentObject var context: TrainingContext`**

After:
```swift
@EnvironmentObject var authStore: AuthStore
```
Add:
```swift
@EnvironmentObject var context: TrainingContext
```

- [ ] **Step 2: Add warmup phase section to the scroll view**

In the `ScrollView` content `VStack`, after `statsRow` and before `if restActive { restTimerBanner }`, add:

```swift
if context.phase == .warmup {
    warmupPhaseSection
}
if let nudge = context.volumeNudge {
    HStack(spacing: 8) {
        Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(Color.warn)
        Text(nudge).font(.caption).foregroundStyle(Color.warn)
    }
    .padding(10)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(Color.warn.opacity(0.1))
    .clipShape(RoundedRectangle(cornerRadius: 8))
}
```

- [ ] **Step 3: Add `warmupPhaseSection` view**

```swift
private var warmupPhaseSection: some View {
    VStack(alignment: .leading, spacing: 10) {
        HStack {
            // Phase indicator: Warmup (filled) → Workout (unfilled)
            Label("Warmup", systemImage: "flame.fill")
                .font(.caption).fontWeight(.semibold).foregroundStyle(Color.tint)
            Image(systemName: "chevron.right").font(.caption2).foregroundStyle(.secondary)
            Text("Workout").font(.caption).foregroundStyle(.secondary)
            Spacer()
            Button("Skip") {
                context.warmupPhaseComplete = true
                context.phase = .active
            }
            .font(.caption).foregroundStyle(.secondary)
        }

        ForEach(context.warmupExercises, id: \.name) { ex in
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(ex.name).font(.subheadline).fontWeight(.semibold)
                    Text("\(ex.sets) sets · \(ex.reps) · ~\(ex.durationSeconds / 60) min")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(10)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }

        Button {
            context.warmupPhaseComplete = true
            context.phase = .active
        } label: {
            Text("Done with Warmup")
                .font(.subheadline).fontWeight(.semibold)
                .foregroundStyle(Color.tint)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Color.tintSoft)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }
    .padding(14)
    .elosCard()
}
```

- [ ] **Step 4: Replace the PostSessionSummaryView sheet with the new session-end flow**

The current sheet in `ActiveSessionView`:
```swift
.sheet(isPresented: $showRPEPrompt) {
    if let session = trainVM.currentSession {
        PostSessionSummaryView(session: session) {
            showRPEPrompt = false
            vm.showingSession = false
        }
        ...
    }
}
```

Replace with (using the existing `SessionRPESheet` private struct that's already in the file):
```swift
.sheet(isPresented: $showRPEPrompt) {
    SessionRPESheet(rpe: $pendingSessionRPE) {
        // Build summary BEFORE finishSession clears currentSession
        let splitDay = vm.currentSplitDay
        let summary = trainVM.buildSessionSummary(
            splitDayTemplateID: splitDay?.templateID ?? "",
            splitDayName: splitDay?.dayName ?? ""
        )
        trainVM.finishSession(sessionRPE: pendingSessionRPE, ownerID: vm.currentUserID)
        context.sessionDidEnd(summary: summary)
        showRPEPrompt = false
        // Defer dismiss so TrainView sees showPostSummary = true before sheet stack changes
        Task { @MainActor in vm.showingSession = false }
    }
}
```

- [ ] **Step 5: Update the nav bar back-button "empty session" path**

The navBar back button currently calls `finishSession` directly when no sets are done:
```swift
trainVM.finishSession(sessionRPE: 0, ownerID: vm.currentUserID)
vm.showingSession = false
```
This path doesn't need a summary (user bailed immediately). Keep it as-is.

- [ ] **Step 6: Build to verify**

Expected: `BUILD SUCCEEDED`

- [ ] **Step 7: Commit**

```bash
git -C /Users/frankbisignano/dev/elos/apps/elos-mobile/Elos add Elos/Views/ActiveSessionView.swift
git -C /Users/frankbisignano/dev/elos/apps/elos-mobile/Elos commit -m "feat: add warmup phase and readiness nudge to ActiveSessionView; wire session-end to TrainingContext"
```

---

## Task 13: Replace `PostSessionSummaryView`

**Files:**
- Replace: `apps/elos-mobile/Elos/Elos/Features/ActiveWorkout/PostSessionSummaryView.swift`

The existing file has RPE collection, XP display, gamification rank-up, muscle breakdown, and share. The new file retains all of that and adds: volume lbs display, multi-PR trophy row, comparison line, next workout card, and "View Analytics" button driven by `TrainingContext`.

- [ ] **Step 1: Overwrite the file with the new implementation**

```swift
import SwiftUI
import SwiftData

struct PostSessionSummaryView: View {
    @EnvironmentObject var vm: AppViewModel
    @EnvironmentObject var trainVM: TrainViewModel
    @EnvironmentObject var context: TrainingContext
    @Environment(\.modelContext) private var modelContext

    let summary: SessionSummary

    @State private var beforeProgress: GamificationEngine.UserProgress?
    @State private var afterProgress:  GamificationEngine.UserProgress?

    private var durationMinutes: Int {
        Int(Date().timeIntervalSince(summary.startedAt)) / 60
    }

    private var volumeLbs: String {
        let lbs = summary.totalVolumeKg * 2.205
        if lbs >= 1000 { return String(format: "%.1fk lbs", lbs / 1000) }
        return String(format: "%.0f lbs", lbs)
    }

    private var thisSessionXP: Int {
        let doneSets = trainVM.sessionSets.filter(\.isDone).count
        return GamificationEngine.sessionXP(completedSets: doneSets, hitPR: !summary.prsHit.isEmpty)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Rank-up banner
                    if let after = afterProgress, let before = beforeProgress,
                       after.rank != before.rank {
                        rankUpBanner(after.rank)
                    }

                    headerCard
                    xpCard
                    if !summary.prsHit.isEmpty { prCard }
                    muscleCard
                    if summary.comparisonLabel != nil { comparisonCard }
                    if summary.nextWorkoutDay != nil { nextWorkoutCard }
                    analyticsButton
                    doneButton
                }
                .padding(16)
                .padding(.bottom, 40)
            }
            .scrollIndicators(.hidden)
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Session Complete")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.large])
        .interactiveDismissDisabled(true)
        .onAppear { computeProgress() }
    }

    // MARK: Header

    private var headerCard: some View {
        HStack(spacing: 0) {
            statColumn(title: "\(durationMinutes) min", sub: "Duration")
            Divider().frame(height: 40)
            statColumn(title: volumeLbs, sub: "Volume")
            Divider().frame(height: 40)
            statColumn(title: "\(trainVM.sessionSets.filter(\.isDone).count)", sub: "Sets")
        }
        .padding(16)
        .elosCard()
    }

    private func statColumn(title: String, sub: String) -> some View {
        VStack(spacing: 3) {
            Text(title).font(.system(size: 18, weight: .bold, design: .monospaced))
            Text(sub).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: XP

    private var xpCard: some View {
        HStack(spacing: 10) {
            Image(systemName: "bolt.fill").foregroundStyle(Color.tint)
            Text("+\(thisSessionXP) XP earned")
                .font(.subheadline).fontWeight(.semibold)
            Spacer()
            if let after = afterProgress {
                Text(after.rank.rawValue)
                    .font(.caption).fontWeight(.semibold)
                    .foregroundStyle(after.rank.color)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(after.rank.color.opacity(0.12))
                    .clipShape(Capsule())
            }
        }
        .padding(14)
        .elosCard()
    }

    // MARK: PRs

    private var prCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("PERSONAL RECORDS")
                .font(.caption).fontWeight(.semibold).foregroundStyle(.secondary)
            ForEach(summary.prsHit, id: \.self) { exercise in
                HStack(spacing: 8) {
                    Image(systemName: "trophy.fill").foregroundStyle(.yellow)
                    Text(exercise).font(.subheadline).fontWeight(.semibold)
                    Spacer()
                }
            }
        }
        .padding(14)
        .elosCard()
    }

    // MARK: Muscle breakdown

    private var muscleCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("MUSCLES HIT")
                .font(.caption).fontWeight(.semibold).foregroundStyle(.secondary)
            let sorted = summary.setsByMuscle.sorted { $0.value > $1.value }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(sorted, id: \.key) { muscle, sets in
                        VStack(spacing: 2) {
                            Text("\(sets)")
                                .font(.system(size: 13, weight: .bold, design: .monospaced))
                            Text(muscle.capitalized)
                                .font(.system(size: 9))
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
            }
        }
        .padding(14)
        .elosCard()
    }

    // MARK: Comparison

    private var comparisonCard: some View {
        HStack(spacing: 8) {
            let pct = summary.comparisonPercent ?? 0
            Image(systemName: pct >= 0 ? "arrow.up.right" : "arrow.down.right")
                .foregroundStyle(pct >= 0 ? Color.good : Color.bad)
            VStack(alignment: .leading, spacing: 2) {
                Text(String(format: "%+.0f%%", pct * 100))
                    .font(.subheadline).fontWeight(.bold)
                    .foregroundStyle(pct >= 0 ? Color.good : Color.bad)
                if let label = summary.comparisonLabel {
                    Text(label).font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
        .padding(14)
        .elosCard()
    }

    // MARK: Next Workout

    private var nextWorkoutCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("UP NEXT")
                .font(.caption).fontWeight(.semibold).foregroundStyle(.secondary)
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(summary.nextWorkoutDay?.dayName ?? "Workout")
                        .font(.subheadline).fontWeight(.semibold)
                    if let date = summary.nextWorkoutDate {
                        let fmt = DateFormatter(); fmt.dateFormat = "EEEE, MMM d"
                        Text(fmt.string(from: date))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Image(systemName: "dumbbell.fill").foregroundStyle(Color.tint)
            }
        }
        .padding(14)
        .elosCard()
    }

    // MARK: Buttons

    private var analyticsButton: some View {
        Button {
            context.pendingAnalytics = true
            context.dismissPostSummary()
        } label: {
            Label("View Analytics", systemImage: "chart.line.uptrend.xyaxis")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.tint)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.tintSoft)
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }

    private var doneButton: some View {
        Button {
            context.dismissPostSummary()
        } label: {
            Text("Done")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.tint)
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }

    // MARK: Rank-up Banner

    private func rankUpBanner(_ rank: GamificationEngine.Rank) -> some View {
        HStack(spacing: 12) {
            Image(systemName: rank.icon).font(.title2).foregroundStyle(rank.color)
            VStack(alignment: .leading, spacing: 2) {
                Text("Ranked Up!").font(.subheadline).fontWeight(.bold)
                Text("You're now \(rank.rawValue)").font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(16)
        .background(rank.color.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(rank.color.opacity(0.35), lineWidth: 1))
    }

    // MARK: Progress computation

    private func computeProgress() {
        let ownerID = vm.currentUserID
        guard !ownerID.isEmpty else { return }
        let allSessions = (try? modelContext.fetch(FetchDescriptor<WorkoutSessionRecord>())) ?? []
        let allSets     = (try? modelContext.fetch(FetchDescriptor<ExerciseSetRecord>())) ?? []
        let mySessions  = allSessions.filter { $0.ownerID == ownerID && $0.finishedAt != nil }
        let mySets      = allSets.filter { $0.ownerID == ownerID }
        let afterXP = GamificationEngine.totalXP(sessions: mySessions, sets: mySets,
                                                  prCount: vm.personalRecords.count)
        afterProgress = GamificationEngine.progress(totalXP: afterXP)
        let beforeXP = max(0, afterXP - thisSessionXP)
        beforeProgress = GamificationEngine.progress(totalXP: beforeXP)
    }
}
```

- [ ] **Step 2: Build to verify**

Expected: `BUILD SUCCEEDED`

- [ ] **Step 3: Commit**

```bash
git -C /Users/frankbisignano/dev/elos/apps/elos-mobile/Elos add \
  Elos/Features/ActiveWorkout/PostSessionSummaryView.swift
git -C /Users/frankbisignano/dev/elos/apps/elos-mobile/Elos commit -m "feat: replace PostSessionSummaryView with SessionSummary-driven version"
```

---

## Task 14: `TrainView` — Post-Session Sheet, Analytics Deep-Link, Readiness Gate

**Files:**
- Modify: `apps/elos-mobile/Elos/Elos/Views/TrainView.swift`

- [ ] **Step 1: Add post-session sheet**

Add to the sheet list:
```swift
.sheet(isPresented: $context.showPostSummary) {
    if let summary = context.sessionSummary {
        PostSessionSummaryView(summary: summary)
            .environmentObject(vm)
            .environmentObject(trainVM)
            .environmentObject(context)
    }
}
```

- [ ] **Step 2: Add `onChange` for analytics deep-link**

After the existing `.onChange(of: vm.showingSession)` block, add:
```swift
.onChange(of: context.showPostSummary) { _, isShowing in
    if !isShowing && context.pendingAnalytics {
        context.pendingAnalytics = false
        context.showAnalytics = true
    }
}
```

- [ ] **Step 3: Add readiness gate to the "Start Today's Workout" button**

The start button currently calls:
```swift
vm.prepareExercisesForToday()
vm.showingSession = true
```

Replace with:
```swift
vm.prepareExercisesForToday()
if vm.todayReadiness == nil {
    context.showReadinessSheet = true
} else {
    startSessionWithWarmup()
}
```

Add a private helper:
```swift
private func startSessionWithWarmup() {
    if vm.activeSplit?.includeWarmups == true {
        let goal: TrainingGoal = vm.activeSplit?.name.lowercased().contains("athletic") == true
            ? .athletic : .hypertrophy
        context.warmupExercises = WarmupLibrary.block(goal: goal, style: .dynamic)
        context.warmupPhaseComplete = false
        context.phase = .warmup
    } else {
        context.phase = .active
    }
    vm.showingSession = true
}
```

- [ ] **Step 4: Resume session start after readiness completes**

Update the readiness sheet callback in the `.sheet(isPresented: $context.showReadinessSheet)` that was added in Task 8:

```swift
.sheet(isPresented: $context.showReadinessSheet) {
    ReadinessCheckInView(
        onDismiss: { context.showReadinessSheet = false },
        onComplete: { record in
            context.readinessDidComplete(record)
            vm.loadTodayReadiness()
            // Resume session start that was gated
            if !vm.showingSession {
                startSessionWithWarmup()
            }
        }
    )
    .environmentObject(vm)
}
```

Also add a "Skip for now" path: when the readiness sheet is dismissed without completing (user swipes down), the session should also start. Since `.sheet(isPresented:)` fires `onDismiss` when the sheet disappears either way, add an `onDismissReadiness` to handle the skip:

Actually the `ReadinessCheckInView` already has `let onDismiss: () -> Void`. If the user taps "Skip for now" inside the view, it calls `onDismiss()`. In that case `context.showReadinessSheet = false` fires, the sheet dismisses, but the session hasn't started. Add a `@State private var waitingForReadiness = false` flag:

```swift
@State private var waitingForReadiness = false
```

In the start button:
```swift
if vm.todayReadiness == nil {
    waitingForReadiness = true
    context.showReadinessSheet = true
} else {
    startSessionWithWarmup()
}
```

In the `onComplete` callback: `waitingForReadiness = false; startSessionWithWarmup()`

Add `.onChange(of: context.showReadinessSheet)`:
```swift
.onChange(of: context.showReadinessSheet) { _, isShowing in
    if !isShowing && waitingForReadiness {
        waitingForReadiness = false
        startSessionWithWarmup()
    }
}
```

- [ ] **Step 5: Build to verify**

Expected: `BUILD SUCCEEDED`

- [ ] **Step 6: Commit**

```bash
git -C /Users/frankbisignano/dev/elos/apps/elos-mobile/Elos add Elos/Views/TrainView.swift
git -C /Users/frankbisignano/dev/elos/apps/elos-mobile/Elos commit -m "feat: add post-session sheet, analytics deep-link, and readiness gate to TrainView"
```

---

## Task 15: Final Build Verification

- [ ] **Step 1: Full clean build**

```bash
cd /Users/frankbisignano/dev/elos && xcodebuild build \
  -project apps/elos-mobile/Elos/Elos.xcodeproj \
  -scheme Elos \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  2>&1 | grep -v "static subscript\|Combine\|missing import" \
       | grep -E "error:|BUILD SUCCEEDED|BUILD FAILED"
```

Expected: `BUILD SUCCEEDED`

- [ ] **Step 2: Smoke-test checklist (manual)**

- [ ] Open app → Training tab → no active split → "Find Your Split" card visible
- [ ] Tap "Find Your Split" → Split Finder opens
- [ ] Subscribe to a split with warmups → split activates, Training tab shows gym-day state
- [ ] Tap "Start Today's Workout" with no readiness logged → readiness sheet appears
- [ ] Skip readiness → session starts (warmup phase if split has warmups, else straight to workout)
- [ ] Complete a set with a PR → trophy accumulates
- [ ] Tap "Finish Workout" → RPE sheet → confirm → `PostSessionSummaryView` slides up with volume, PRs, next workout
- [ ] Tap "View Analytics" → summary dismisses → analytics sheet opens
- [ ] Tap "Done" → back to TrainView
- [ ] Tap "Programs" → active split progress card visible at top with correct week/day

- [ ] **Step 3: Final commit tag**

```bash
git -C /Users/frankbisignano/dev/elos/apps/elos-mobile/Elos log --oneline -10
```
