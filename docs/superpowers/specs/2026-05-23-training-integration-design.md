# Training Integration Design

**Goal:** Unify all training tab features into one coherent pre→during→post workout experience driven by a single observable state layer.

**Date:** 2026-05-23

---

## Problem

Training features exist as isolated tools connected by quick-action buttons. Nothing knows what anything else is doing:

- TrainView holds a pile of `@State` booleans for sheet presentation — navigation state is untestable and scattered
- Readiness check-in is stored in SwiftData but nothing reads it
- WarmupLibrary generates warmup blocks but ActiveSessionView never shows them
- Finishing a session dismisses straight back to TrainView — no summary, no context
- TrainView renders the same layout whether you have a split or not, whether it's a rest day or a gym day
- Split Finder creates a split but the rest of the tab doesn't react to it

The fix is a single shared context object that drives what every training view shows.

---

## Architecture

### `TrainingContext` (new file)

A dedicated `ObservableObject` injected into the training tab alongside `AppViewModel`. It owns the training day state machine and all navigation state for the tab.

`TrainingContext` does **not** hold a `ModelContext` directly and does **not** hold a reference to `TrainViewModel` (which would risk retain cycles between long-lived observables). Instead:

- `AppViewModel` gains a new published property `todayReadiness: ReadinessCheckInRecord?` — loaded alongside the active split in `loadForUser`. `TrainingContext` reads this via a view-layer binding, not a direct reference.
- Deload/RPE signal is passed in from the view: `TrainView` calls `context.update(shouldDeload: trainVM.showDeloadSuggestion, readinessScore: vm.todayReadiness?.overallScore)` on `onAppear` and `onChange`.

**Creation:** `TrainingContext` is created as a `@StateObject` in `ElosApp.swift`, the same way `AppViewModel`, `TrainViewModel`, and `SocialViewModel` are, and injected via `.environmentObject(trainingContext)` at the root.

```swift
// ElosApp.swift (addition)
@StateObject private var trainingContext = TrainingContext()
// in body: .environmentObject(trainingContext)
```

```swift
final class TrainingContext: ObservableObject {

    // MARK: - Phase
    @Published var phase: TrainingPhase = .idle

    // MARK: - Navigation (replaces TrainView @State booleans)
    @Published var showSplitFinder    = false
    @Published var showAnalytics      = false
    @Published var showLibrary        = false
    @Published var showTemplates      = false
    @Published var showHistory        = false
    @Published var showStretches      = false
    @Published var showSplitLibrary   = false
    @Published var showLeaderboard    = false
    @Published var showExercisePicker = false

    // MARK: - Readiness
    @Published var showReadinessSheet = false

    // MARK: - Warmup
    @Published var warmupExercises: [WarmupExercise] = []
    @Published var warmupPhaseComplete = false

    // MARK: - Post-session
    @Published var sessionSummary: SessionSummary? = nil
    @Published var showPostSummary = false
    @Published var pendingAnalytics = false

    // MARK: - Derived (updated from view via update())
    private(set) var shouldSuggestDeload: Bool = false
    private(set) var readinessScore: Int? = nil
    var volumeNudge: String? {
        guard let score = readinessScore else { return nil }
        return score <= 2 ? "Very low energy today — consider reducing volume." :
               score == 3 ? "Moderate fatigue — consider –20% volume today." : nil
    }

    // MARK: - Called from TrainView on appear/change
    func update(shouldDeload: Bool, readinessScore: Int?) {
        self.shouldSuggestDeload = shouldDeload || (readinessScore.map { $0 <= 2 } ?? false)
        self.readinessScore = readinessScore
    }

    // MARK: - Called from ReadinessCheckInView on save
    func readinessDidComplete(_ record: ReadinessCheckInRecord) {
        showReadinessSheet = false
        // Caller (TrainView) must reload vm.todayReadiness after this
    }

    // MARK: - Called from TrainViewModel.finishSession()
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

enum TrainingPhase {
    case idle
    case warmup
    case active
    case postSummary
}
```

---

## Schema Change: `includeWarmups` on `UserSplitRecord`

`SplitFinderInput.includeWarmups` is a questionnaire field that currently only exists in memory during the survey. It is never persisted, so `TrainingContext` cannot read it at session-start time.

**Fix:** Add `includeWarmups: Bool = false` to `UserSplitRecord` in `ElosSchema.swift`.

`SplitSubscribeSheet.saveAndDismiss()` already creates the `UserSplitRecord` — it will set `splitRecord.includeWarmups = recommendation.includeWarmups` (the `SplitRecommendation` struct already carries this from `SplitRecommender.build()`).

For existing splits (created before this change): `includeWarmups` defaults to `false` — no migration needed.

`WarmupStyle` preference does not need to be persisted — `WarmupLibrary.block(goal:style:)` will use `.dynamic` as the default when `includeWarmups` is true and no style preference is stored.

---

## `AppViewModel` Addition: `todayReadiness`

```swift
// MARK: - Readiness (new)
@Published var todayReadiness: ReadinessCheckInRecord? = nil
```

Loaded in `loadForUser()` after habits:

```swift
let readinessDesc = FetchDescriptor<ReadinessCheckInRecord>(
    predicate: #Predicate { $0.ownerID == uid }
)
let allReadiness = (try? context.fetch(readinessDesc)) ?? []
todayReadiness = allReadiness.first { Calendar.current.isDateInToday($0.date) }
```

`ReadinessCheckInView` calls `vm.loadTodayReadiness()` (a thin wrapper that re-runs the above fetch) after saving, then calls `context.readinessDidComplete(record)`.

---

## Training Day Flow

### Pre-Workout

When the user taps "Start Today's Workout":

1. Check `vm.todayReadiness` — if nil, set `context.showReadinessSheet = true`. Session start is deferred until readiness completes or is explicitly skipped.
2. On readiness save: `context.readinessDidComplete(record)` fires, view calls `vm.loadTodayReadiness()`, then session start resumes.
3. On readiness skip (one tap — "Skip for now"): session start resumes immediately.
4. Check `vm.activeSplit?.includeWarmups`:
   - `true` → `context.warmupExercises = WarmupLibrary.block(goal: splitGoal, style: .dynamic)`, `context.phase = .warmup`
   - `false` → `context.phase = .active`
5. `vm.showingSession = true` opens `ActiveSessionView`.

`splitGoal` is derived by mapping `UserSplitRecord.name` or a new stored `goalRaw: String` field — see note below.

> **Implementation note:** Rather than storing the full `TrainingGoal` enum on `UserSplitRecord`, the warmup block selection can use `SplitStyle` which is already derivable. `WarmupLibrary.block(goal:style:)` only needs to distinguish athletic vs lifting — map `SplitStyle.athletic` → `TrainingGoal.athletic`, everything else → `TrainingGoal.hypertrophy`.

### During-Workout — Warmup Phase

`ActiveSessionView` observes `TrainingContext.phase` via `@EnvironmentObject`:

- **Phase `.warmup`**: Shows warmup exercise list from `context.warmupExercises`. A segmented progress indicator at the top: "Warmup" (filled) → "Workout" (unfilled). "Skip Warmup" and "Done with Warmup" both call `context.warmupPhaseComplete = true` and `context.phase = .active`.
- **Phase `.active`**: Existing session UI unchanged.

If `context.readinessScore != nil && context.readinessScore! <= 3`: a non-blocking banner at the top of the session reads the `context.volumeNudge` string.

### Post-Workout

When the user taps "Finish" in `ActiveSessionView`:

1. `TrainViewModel.finishSession(sessionRPE:ownerID:)` runs its existing logic (saves session, computes volume, detects PRs). It does **not** reference `TrainingContext` — this keeps `TrainViewModel` unaware of the view layer and avoids a retain cycle between two long-lived `@StateObject` singletons.
2. `ActiveSessionView`'s "Finish" button calls `context.sessionDidEnd(summary: trainVM.buildSessionSummary())` directly from the view, then defers `vm.showingSession = false` by one run loop.
3. `vm.showingSession = false` dismisses `ActiveSessionView`.
4. `TrainView` observes `context.showPostSummary == true` and presents `PostSessionSummaryView` as a `.sheet`.

`TrainViewModel` gains a pure function `buildSessionSummary() -> SessionSummary` that constructs the struct from `sessionSets`, `prsHitThisSession`, and `currentSessionRecord` — no side effects, no context reference.

The dismiss-then-present sequence: `showingSession = false` and `showPostSummary = true` must not happen in the same frame. The safe pattern:

```swift
// In ActiveSessionView "Finish" button:
trainVM.finishSession(sessionRPE: rpe, ownerID: vm.currentUserID)
let summary = trainVM.buildSessionSummary()
context.sessionDidEnd(summary: summary)
// Defer dismiss by one run loop so TrainView sees showPostSummary = true first:
Task { @MainActor in vm.showingSession = false }
```

This ensures `PostSessionSummaryView` sheet fires from `TrainView` after `ActiveSessionView` has fully dismissed.

---

## `SessionSummary` Struct

```swift
struct SessionSummary {
    let totalVolumeKg: Double            // stored in kg, displayed as lbs in UI with ×2.205
    let setsByMuscle: [String: Int]      // "chest" → 12
    let prsHit: [String]                 // exercise names where a PR was hit this session
    let comparisonPercent: Double?       // +0.08 = 8% more than last matching session
    let comparisonLabel: String?         // "vs last Chest Day (May 16)"
    let nextWorkoutDay: UserSplitDayRecord?
    let nextWorkoutDate: Date?
}
```

**"Same-day session" matching key:** Use `WorkoutSessionRecord.templateID` when non-empty. When empty (Split Finder splits that use `exercisesJSON` directly), match by the split day's `dayName`. This gives a best-effort comparison without requiring server data.

**PRs this session:** `TrainViewModel` currently tracks only `newPRExerciseName: String?`, replacing on each new PR. Add `var prsHitThisSession: [String] = []` to `TrainViewModel`. Each time a new PR is detected, append to this array. Reset to `[]` at session start.

**Volume unit:** All volume stored as kg (`totalVolume: Double` on `WorkoutSessionRecord`). `SessionSummary` stores kg, `PostSessionSummaryView` converts with `× 2.205` for display.

**Next workout date:** Computed by advancing one day at a time from tomorrow using the same logic as `AppViewModel.gymDay(for:)` until a non-rest day is found (cap at 14 days).

---

## `PostSessionSummaryView` — Replacement

A file named `PostSessionSummaryView.swift` already exists in `Features/ActiveWorkout/`. The new implementation **replaces** it. The existing view uses a `WorkoutSessionRecord`-based interface and includes RPE rating, XP display, and gamification rank-up.

The replacement approach: **extend, not discard**. The new `PostSessionSummaryView` takes a `SessionSummary` + `WorkoutSessionRecord` (still available from `TrainViewModel.currentSessionRecord`). It retains the RPE rating and XP/rank-up sections from the existing view and adds:

- Volume breakdown (total kg → displayed as lbs)
- Muscle set chips
- PR row (exercise names, no confetti — use a gold trophy `Image(systemName: "trophy.fill").foregroundStyle(.yellow)` per PR, no third-party package required)
- Comparison line
- Next workout card
- "View Analytics" button

**"View Analytics" deep-link:** Because `PostSessionSummaryView` is a sheet presented by `TrainView`, setting `context.showAnalytics = true` will not fire immediately while the summary sheet is still presented. The correct pattern is to use `onChange` to watch `showPostSummary` transitioning to `false`, then set the next flag — no hard-coded sleep needed:

```swift
// In PostSessionSummaryView:
Button("View Analytics") {
    context.pendingAnalytics = true   // set on context, not local @State
    context.dismissPostSummary()      // sets showPostSummary = false
}

// In TrainView (parent), observing the flag via context:
.onChange(of: context.showPostSummary) { _, isShowing in
    if !isShowing && context.pendingAnalytics {
        context.pendingAnalytics = false
        context.showAnalytics = true
    }
}
```

`pendingAnalytics: Bool` is added as a published property on `TrainingContext`.

---

## TrainView Context States

TrainView computes its state from `vm.activeSplit`, `vm.todayReadiness`, and `vm.weekLoadMap`:

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

### State: `.noSplit`
- Large "Find Your Split" card (wand icon) as the first element, above the week strip
- Quick actions: "Programs" replaced by "Find Split"

### State: `.restDay`
- Recovery card: next gym day countdown ("Next: Push Day in 2 days")
- Stretches row surfaces above the start button
- Muscle volume panel stays prominent
- Start button label: "Start Free Workout" (not tied to split)

### State: `.gymDayNoReadiness`
- Soft inline card below program header: "Quick check-in before you train?"
- Three icons: sleep moon, soreness flame, energy bolt — read-only indicators, tapping opens full readiness sheet
- Not blocking

### State: `.gymDayReady`
- Program header expands to show today's exercises inline (first 4, "See all" to expand)
- Start button dominant: "Start Today's Workout"
- Deload/nudge banners shown if `context.shouldSuggestDeload` or `context.volumeNudge != nil`

**Navigation migration:** All sheet bindings in `TrainView` change from `@State private var showX = false` to `$context.showX`. The `TrainingContext` instance is available via `@EnvironmentObject var context: TrainingContext`.

---

## Programs View: Active Split Progress Card

At the top of `ProgramsView`, above the split list:

```swift
// If vm.activeSplit != nil:
// Week X · Day Y of Z   [thin tint progress bar]
```

Week calculated from `split.activatedAt` to `Date()` (in weeks, minimum 1). Day is `vm.currentSplitDayIndex + 1` of `vm.activeSplitDays.count`. Tapping opens `WorkoutSplitDetailView` (existing). No other changes to `ProgramsView`.

---

## File Map

| File | Action | Notes |
|------|--------|-------|
| `Features/Train/TrainingContext.swift` | **Create** | Phase state, navigation, readiness, warmup, session-summary coordination |
| `Features/ActiveWorkout/PostSessionSummaryView.swift` | **Replace** | Extends existing with SessionSummary struct; retains RPE/XP sections |
| `SwiftData/ElosSchema.swift` | **Modify** | Add `includeWarmups: Bool = false` to `UserSplitRecord` |
| `AppViewModel.swift` | **Modify** | Add `todayReadiness`, `loadTodayReadiness()` |
| `ElosApp.swift` | **Modify** | Create and inject `TrainingContext` |
| `Views/TrainView.swift` | **Modify** | 4 context states; migrate `@State` booleans to `context.*` |
| `Views/ActiveSessionView.swift` | **Modify** | Warmup phase rendering; readiness nudge banner; session-end calls context |
| `Features/Train/TrainViewModel.swift` | **Modify** | `prsHitThisSession: [String]`; add pure `buildSessionSummary() -> SessionSummary` |
| `Features/Train/Readiness/ReadinessCheckInView.swift` | **Modify** | Add `onComplete: (ReadinessCheckInRecord) -> Void` callback |
| `Features/Train/Programs/SplitSubscribeSheet.swift` | **Modify** | Set `splitRecord.includeWarmups` from recommendation |
| `Features/Train/Programs/ProgramsView.swift` | **Modify** | Active split progress card at top |

---

## Data Flow

```
SwiftData
  (ReadinessCheckInRecord, UserSplitRecord.includeWarmups,
   WorkoutSessionRecord, ExerciseSetRecord)
        ↓ read by
AppViewModel
  (activeSplit, activeSplitDays, todayReadiness, exercises)
TrainViewModel
  (session lifecycle, RPE trend, prsHitThisSession, finishSession → SessionSummary)
        ↓ values passed to
TrainingContext  (via view .update() calls and direct callbacks)
  (phase, navigation flags, warmupExercises, sessionSummary, deload signal)
        ↓ drives
TrainView (4 context states, navigation sheets)
ActiveSessionView (warmup phase, nudge banner, session-end handoff)
PostSessionSummaryView (summary display, deep-link to analytics)
```

---

## Out of Scope

- Server-side readiness analytics
- AI-generated workout suggestions
- Social features in the training flow
- Changes to Analytics, History, Library, or Exercise Picker internals
- Third-party confetti packages — PRs shown with `trophy.fill` icon only

---

## Implementation Phases

**Phase 1 — Foundation (pure refactor, no visible change):**
- Create `TrainingContext`, inject in `ElosApp`
- Migrate `TrainView` `@State` navigation booleans to `context.*`
- Add `todayReadiness` to `AppViewModel`
- Add `includeWarmups` to `UserSplitRecord`

**Phase 2 — Context States (visible payoff):**
- Implement four `TrainState` variants in `TrainView`
- Programs active split progress card

**Phase 3 — Flow Arc:**
- Readiness gate before session start
- Warmup phase in `ActiveSessionView`
- `prsHitThisSession` accumulator in `TrainViewModel`
- `SessionSummary` built in `finishSession`
- `PostSessionSummaryView` replacement

**Phase 4 — Integration Polish:**
- `context.update(shouldDeload:readinessScore:)` wiring in `TrainView`
- "View Analytics" deep-link with dismiss-then-present pattern
- `SplitSubscribeSheet` sets `includeWarmups`
