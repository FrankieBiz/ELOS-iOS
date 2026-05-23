# Split Finder — Design Spec
**Date:** 2026-05-23
**Status:** Approved (rev 3 — second spec-review fixes applied)

## Overview

A survey-driven split recommendation engine accessible from a wand icon button in `TrainView`'s top-right toolbar. Users answer 8 questions and receive 3 personalized workout split options generated client-side by a rule-based engine. They can subscribe to a split, resolve conflicts with their current active split, and assign training days — all in one flow.

---

## Entry Point

Add a `wand.and.stars` toolbar button to `TrainView` (top-right, alongside existing history and analytics icons). Tapping it presents `SplitFinderView` as a `.sheet`. Controlled by a new `@State private var showSplitFinder = false` in `TrainView`.

---

## Survey Flow

`SplitFinderView` is a multi-step form with a linear progress bar across the top. `SplitFinderViewModel` (`@StateObject`) owns all state and drives step transitions via `currentStep: Int`. **All answers are preserved when navigating back** — the view model is never reset mid-survey.

### Steps

| Step | Question | Control |
|------|----------|---------|
| 1 | Primary goal | 4 tappable cards: Hypertrophy / Strength / Athletic / General |
| 2 | Days per week | Segmented picker: 2 / 3 / 4 / 5 / 6 |
| 3 | Session length | Stepped slider: 30 / 45 / 60 / 75 / 90 min |
| 4 | Equipment lean | 3 sliders (Machine, Dumbbell, Barbell) — see normalization rules below |
| 5 | Gym type | 2 tappable cards: Commercial (full rack room) / Small or Home |
| 6 | Sport training | Toggle. If on: 12-sport grid picker + 5-step focus picker (see below) |
| 7 | Injuries | Toggle. If on: body-part chip multi-select + per-part severity segmented picker (Mild / Moderate / Avoid) |
| 8 | Warmups | Toggle. If on: style cards (Dynamic / Static Stretching / Both) |

Navigation: "Next" / "Back" buttons at the bottom of each step. Steps 6–8 advance immediately when their toggle is left off (the sub-form is not shown). After step 8, the view transitions to `SplitFinderResultsView`.

### Sports List (Step 6)
Basketball, Football, Soccer, Baseball, Tennis, Swimming, MMA/Boxing, Wrestling, Track & Field, Volleyball, Hockey, Golf, Lacrosse — displayed as a scrollable grid of icon+label chips. Only one sport can be selected.

**Sport focus:** 5-step discrete picker below the sport grid:
`Hobby → Enthusiast → Competitive → Semi-Pro → Elite`
Maps internally to `sportFocusRatio`: 0.0 / 0.25 / 0.5 / 0.75 / 1.0

### Equipment Slider Normalization (Step 4)
Each of the three sliders (Machine, Dumbbell, Barbell) runs 0–100. Normalization fires on drag release:

1. Sum all three values.
2. If sum == 0, set all to 33 (equal split).
3. Else divide each by sum and multiply by 100 to normalize proportionally.
4. The moved slider's value is normalized last and receives any rounding remainder.

**Example:** User drags Machine to 60, Dumbbell is 20, Barbell is 20 → sum = 100, all stay. User then drags Barbell to 0 → sum = 80 → Machine = 75, Dumbbell = 25, Barbell = 0.

---

## Data Model (`SplitFinderModels.swift`)

```swift
enum TrainingGoal: String, CaseIterable {
    case hypertrophy, strength, athletic, general
}

enum GymSize { case commercial, small }

enum WarmupStyle { case dynamic, staticStretch, both }

enum InjuredPart: String, CaseIterable {
    case shoulder, knee, lowerBack, wrist, elbow, hip, ankle
}

enum InjurySeverity { case mild, moderate, avoid }

enum SplitStyle: String {
    case fullBody, upperLower, pushPullLegs, arnold, broSplit, athletic
}

enum Sport: String, CaseIterable {
    case basketball, football, soccer, baseball, tennis, swimming
    case mmaBoxing, wrestling, trackAndField, volleyball, hockey, golf, lacrosse
}

struct EquipmentProfile {
    var machineRatio: Double    // 0.0–1.0, always normalized with others to sum 1.0
    var dumbbellRatio: Double
    var barbellRatio: Double
}

struct InjuryEntry {
    var part: InjuredPart
    var severity: InjurySeverity
}

struct SplitFinderInput {
    var goal: TrainingGoal          = .hypertrophy
    var daysPerWeek: Int            = 4
    var sessionMinutes: Int         = 60
    var equipment: EquipmentProfile = EquipmentProfile(machineRatio: 0.33, dumbbellRatio: 0.34, barbellRatio: 0.33)
    var gymSize: GymSize            = .commercial
    var sport: Sport?               = nil
    var sportFocusRatio: Double     = 0.0      // 0.0–1.0 via 5-step picker
    var injuries: [InjuryEntry]     = []
    var includeWarmups: Bool        = false
    var warmupStyle: WarmupStyle?   = nil
}

struct SplitRecommendation: Identifiable {
    var id: UUID = UUID()
    var name: String                // e.g. "4-Day Push Pull Legs"
    var style: SplitStyle
    var days: [RecommendedDay]      // count == daysPerWeek + rest days to fill 7
    var estimatedMinutes: Int       // working minutes + warmup minutes
    var matchScore: Double          // 0.0–1.0, internal only (not shown to user)
    var matchTags: [String]         // e.g. ["Great for hypertrophy", "Shoulder-safe"]
}

struct RecommendedDay: Identifiable {
    var id: UUID = UUID()
    var label: String               // "Push", "Upper A", "Full Body", "Rest"
    var isRest: Bool
    var exercises: [RecommendedExercise]
    var warmupBlock: [WarmupExercise]  // empty if !includeWarmups or isRest
}

struct RecommendedExercise: Identifiable {
    var id: UUID = UUID()
    var name: String
    var sets: Int
    var reps: String                // e.g. "8–10" or "5"
    var equipment: String           // "Barbell" | "Dumbbell" | "Machine" | "Bodyweight"
    var primaryMuscle: String       // e.g. "chest", "quads" — used by substitution engine
}

struct WarmupExercise: Identifiable {
    var id: UUID = UUID()
    var name: String
    var duration: String            // e.g. "30s" or "10 reps"
}
```

---

## Recommendation Engine (`SplitRecommender.swift`)

Pure Swift struct — no side effects, no network calls, no SwiftData access. Input: `SplitFinderInput`. Output: `[SplitRecommendation]` (exactly 3; see fallback rules).

### Candidate Templates

Static templates defined per `(SplitStyle, [Int])` (compatible day counts). Each template contains day labels + a base exercise list per day (name, default sets, reps string, equipment tag, primaryMuscle).

| Style | Compatible day counts | Best goal match |
|-------|-----------------------|-----------------|
| Full Body | 2, 3 | general |
| Upper / Lower | 3, 4 | strength |
| Push / Pull / Legs | 3, 4, 5, 6 | hypertrophy |
| Arnold (PPL A/B variant) | 3, 6 | hypertrophy |
| Bro Split (1 muscle/day) | 5 | hypertrophy |
| Athletic (compound-first) | 3, 4, 5 | athletic |

### Scoring Pipeline

Run for every candidate whose day count matches `daysPerWeek`:

**1. Eligibility filter (hard gates — candidate is excluded if any fails):**
- Day count must match exactly.
- If `gymSize == .small` AND `equipment.barbellRatio > 0.5`, exclude barbell-dominant templates.
- If `gymSize == .small`, exclude Bro Split (requires 5+ different cable/machine stations).

**2. Goal score** (lookup table, 0.0–1.0):

| Style \ Goal | Hypertrophy | Strength | Athletic | General |
|--------------|-------------|----------|----------|---------|
| Full Body | 0.5 | 0.6 | 0.6 | 1.0 |
| Upper/Lower | 0.7 | 1.0 | 0.7 | 0.7 |
| PPL | 1.0 | 0.6 | 0.5 | 0.6 |
| Arnold | 0.95 | 0.5 | 0.4 | 0.5 |
| Bro Split | 0.85 | 0.5 | 0.3 | 0.5 |
| Athletic | 0.4 | 0.7 | 1.0 | 0.6 |

**3. Sport modifier** (added to goal score before weighting):
- If `sport == nil` or `sportFocusRatio == 0`: +0.0
- If `sportFocusRatio > 0` and style == `.athletic`: +`(sportFocusRatio × 0.3)`
- If `sportFocusRatio > 0.5` and style != `.athletic`: −0.1 (penalizes non-functional splits for competitive athletes)

**4. Equipment score** (0.0–1.0):
For each exercise in the candidate template, check its `equipment` tag against `EquipmentProfile`. An exercise "matches" if its equipment ratio in the profile is ≥ 0.2. Score = `matchingExercises / totalExercises`.

**5. Injury penalty** (subtracted):
For each injury entry with severity `.avoid`: count exercises in the template whose `primaryMuscle` is directly loaded by that body part (mapping defined below). Penalty = `avoidConflicts × 0.05`, capped at 0.25.

Body part → primary muscles loaded:
- shoulder: `["front_delts", "side_delts", "rear_delts"]`
- knee: `["quads", "hamstrings"]`
- lowerBack: `["lower_back", "glutes"]`
- wrist: `["forearms"]`
- elbow: `["biceps", "triceps"]`
- hip: `["hip_flexors", "glutes"]`
- ankle: `["calves"]`

**6. Final score:**
```
score = (goalScore + sportModifier) × 0.40
      + equipmentScore × 0.35
      + (1.0 − injuryPenalty) × 0.25
```

**7. Rank and return top 3:**
- Prefer distinct styles. If fewer than 3 styles pass eligibility, allow a second instance of the highest-scoring style with a different day arrangement.
- If only 1 or 2 candidates pass eligibility (e.g., very restrictive inputs), return 1 or 2 results. The results screen handles an array of 1–3 items.

### Match Tags (generated from scores)

| Condition | Tag |
|-----------|-----|
| finalScore ≥ 0.85 | "Excellent match" |
| goalScore ≥ 0.9 | "Great for [goal.rawValue]" |
| equipmentScore ≥ 0.9 | "Equipment-friendly" |
| any injury `.avoid` + zero avoid-conflicts | "[Part]-safe" (e.g., "Shoulder-safe") |
| gymSize == .small and passes eligibility | "Works in any gym" |
| sportFocusRatio ≥ 0.5 and style == .athletic | "Sport performance focus" |

---

## Injury Substitution Engine (`InjurySubstitutionEngine.swift`)

Applied to all 3 candidates after scoring, before the results screen is shown. Mutates the `[RecommendedExercise]` array on each `RecommendedDay`.

### Substitution Map

`static let map: [String: [InjuryKey: String?]]`

`InjuryKey` is a struct `(part: InjuredPart, severity: InjurySeverity)`. Value is the substitute name, or `nil` = remove.

**Full substitution table (~40 entries):**

| Original | Condition | Substitute |
|----------|-----------|------------|
| Barbell Overhead Press | shoulder + mild | Dumbbell Lateral Raise |
| Barbell Overhead Press | shoulder + moderate | Cable Face Pull |
| Barbell Overhead Press | shoulder + avoid | *(remove)* |
| Dumbbell Shoulder Press | shoulder + mild | Dumbbell Lateral Raise |
| Dumbbell Shoulder Press | shoulder + moderate | Band Pull-Apart |
| Dumbbell Shoulder Press | shoulder + avoid | *(remove)* |
| Barbell Back Squat | knee + mild | Leg Press |
| Barbell Back Squat | knee + moderate | Goblet Squat |
| Barbell Back Squat | knee + avoid | *(remove)* |
| Leg Press | knee + moderate | Seated Leg Extension |
| Leg Press | knee + avoid | *(remove)* |
| Barbell Deadlift | lowerBack + mild | Romanian Deadlift |
| Barbell Deadlift | lowerBack + moderate | Cable Pull-Through |
| Barbell Deadlift | lowerBack + avoid | *(remove)* |
| Romanian Deadlift | lowerBack + mild | Cable Pull-Through |
| Romanian Deadlift | lowerBack + avoid | *(remove)* |
| Barbell Curl | wrist + mild | Hammer Curl |
| Barbell Curl | wrist + moderate | Cable Curl |
| Barbell Curl | wrist + avoid | *(remove)* |
| Dumbbell Curl | wrist + moderate | Cable Curl |
| Barbell Row | lowerBack + mild | Cable Row |
| Barbell Row | lowerBack + avoid | *(remove)* |
| Skull Crushers | elbow + mild | Cable Tricep Pushdown |
| Skull Crushers | elbow + moderate | Tricep Dips (Assisted) |
| Skull Crushers | elbow + avoid | *(remove)* |
| Tricep Dips | elbow + moderate | Cable Tricep Pushdown |
| Tricep Dips | elbow + avoid | *(remove)* |
| Hip Thrust | hip + mild | Glute Bridge |
| Hip Thrust | hip + moderate | Glute Bridge |
| Hip Thrust | hip + avoid | *(remove)* |
| Barbell Hip Thrust | hip + mild | Dumbbell Glute Bridge |
| Barbell Hip Thrust | hip + avoid | *(remove)* |
| Box Jump | ankle + mild | Step-Up |
| Box Jump | ankle + avoid | *(remove)* |
| Jump Rope | ankle + mild | Rowing Machine |
| Jump Rope | ankle + avoid | *(remove)* |
| Calf Raise | ankle + mild | Seated Calf Raise |
| Calf Raise | ankle + avoid | *(remove)* |
| Lateral Lunge | knee + mild | Sumo Squat |
| Lateral Lunge | knee + avoid | *(remove)* |

### Safe-Exercise Backfill Pool

Defined as a static array in `InjurySubstitutionEngine.swift`. Used when an exercise is removed and the day would fall below the minimum exercise count for that session length (see Warmup Library section).

```swift
static let safePool: [RecommendedExercise] = [
    // Chest (safe for all injuries)
    RecommendedExercise(name: "Machine Chest Press", sets: 3, reps: "10–12", equipment: "Machine", primaryMuscle: "chest"),
    RecommendedExercise(name: "Cable Fly", sets: 3, reps: "12–15", equipment: "Machine", primaryMuscle: "chest"),
    // Back
    RecommendedExercise(name: "Lat Pulldown", sets: 3, reps: "10–12", equipment: "Machine", primaryMuscle: "lats"),
    RecommendedExercise(name: "Seated Cable Row", sets: 3, reps: "10–12", equipment: "Machine", primaryMuscle: "lats"),
    // Quads (knee-safe)
    RecommendedExercise(name: "Leg Extension", sets: 3, reps: "12–15", equipment: "Machine", primaryMuscle: "quads"),
    RecommendedExercise(name: "Wall Sit", sets: 3, reps: "30s", equipment: "Bodyweight", primaryMuscle: "quads"),
    // Hamstrings
    RecommendedExercise(name: "Leg Curl", sets: 3, reps: "12–15", equipment: "Machine", primaryMuscle: "hamstrings"),
    // Glutes (lower-back-safe)
    RecommendedExercise(name: "Cable Kickback", sets: 3, reps: "15", equipment: "Machine", primaryMuscle: "glutes"),
    // Shoulders (shoulder-safe)
    RecommendedExercise(name: "Band Pull-Apart", sets: 3, reps: "20", equipment: "Bodyweight", primaryMuscle: "rear_delts"),
    RecommendedExercise(name: "Face Pull", sets: 3, reps: "15", equipment: "Machine", primaryMuscle: "rear_delts"),
    // Arms
    RecommendedExercise(name: "Cable Curl", sets: 3, reps: "12", equipment: "Machine", primaryMuscle: "biceps"),
    RecommendedExercise(name: "Tricep Pushdown", sets: 3, reps: "12–15", equipment: "Machine", primaryMuscle: "triceps"),
    // Core
    RecommendedExercise(name: "Plank", sets: 3, reps: "30s", equipment: "Bodyweight", primaryMuscle: "core"),
    RecommendedExercise(name: "Dead Bug", sets: 3, reps: "10/side", equipment: "Bodyweight", primaryMuscle: "core"),
]
```

Backfill selects from the pool by matching `primaryMuscle` to the removed exercise's `primaryMuscle`. If no muscle match, selects the first pool exercise that satisfies the day's equipment profile. If pool is exhausted, the slot is left empty (acceptable — session is shorter than intended, no crash).

---

## Warmup Library (`WarmupLibrary.swift`)

Static lookup keyed by `(goal: TrainingGoal, style: WarmupStyle)`.

### Session Budget Split

| Session (min) | Warmup budget | Min exercises/day |
|---------------|---------------|-------------------|
| 30 | 5 | 3 |
| 45 | 8 | 4 |
| 60 | 10 | 5 |
| 75 | 10 | 6 |
| 90 | 12 | 6–7 |

Working time = `sessionMinutes − warmupMinutes`. Assume 3 min per set (including rest). Set count per exercise comes from the template (3–5 sets). Total sets that fit = `floor(workingTime / 3)`. Exercises per day = `totalSets / templateSetCount`, capped by the min-exercise floor above.

### Warmup Block Definitions

**Dynamic (hypertrophy/strength):**
- Band Pull-Apart × 15 (30s)
- Leg Swings × 10/side (45s)
- Hip Circles × 10/side (30s)
- Cat-Cow × 10 (30s)
- Shoulder Circles × 10/side (30s)
Total ≈ 5 min

**Dynamic (athletic):**
- High Knees × 30s
- Lateral Shuffles × 30s
- Arm Circles × 20
- Inchworm × 5 (60s)
- Jump Rope × 60s
Total ≈ 8 min

**Static (any goal):**
- Chest Opener 30s/side
- Hip Flexor Stretch 30s/side
- Hamstring Stretch 30s/side
- Thoracic Rotation 30s/side
Total ≈ 5 min

**Both:** Dynamic block first (full duration), static block recommended post-session (noted in day description, not baked into pre-session budget).

---

## Results Screen (`SplitFinderResultsView.swift`)

Shown after survey completes. `SplitFinderViewModel.recommendations: [SplitRecommendation]` is populated by calling `SplitRecommender.recommend(input:)` followed by `InjurySubstitutionEngine.apply(to:input:)`.

### Recommendation Card

Each card shows:
- Split name (large, bold) + style badge pill
- Row: `X days/week` · `~Y min/session` · flame icon if warmups included
- Match tag chips (up to 3)
- Collapsible section "See Schedule": lists each non-rest day label + first 3 exercise names separated by commas (e.g. "Push — Bench Press, OHP, Tricep Pushdown"). Rest days shown as "Rest". Warmup exercises not shown in preview.
- "Use This Split" filled button

If only 1 or 2 recommendations are returned (very restrictive input), render only those cards — no placeholder for the missing slot.

---

## Subscribe Flow

### Schema Changes (`ElosSchema.swift`)

`UserSplitRecord` gains three new stored properties:

- `scheduledStartAt: Date?` — nil = active immediately; non-nil = pending activation.
- `pinnedWeekdaysJSON: String?` — nil = ordinal rotation (existing behavior); non-nil = JSON-encoded `[Int]` of Calendar weekday numbers (1=Sunday … 7=Saturday). Follows the codebase pattern of `skippedDatesJSON`/`exercisesJSON`. Expose via computed accessor:
  ```swift
  var pinnedWeekdays: [Int]? {
      get { pinnedWeekdaysJSON.flatMap { try? JSONDecoder().decode([Int].self, from: Data($0.utf8)) } }
      set { pinnedWeekdaysJSON = newValue.flatMap { try? String(data: JSONEncoder().encode($0), encoding: .utf8) } }
  }
  ```
- `syncPending: Bool` — add only if not already present.

`libraryKey = ""` for synthesized splits (no library origin).

### Deferred Activation in `loadActiveSplit()`

**TrainView while pending:** No special UI — the existing "No Active Split / Pick a split in Programs" message continues to show until the start date arrives.

**Order of operations** (both in a single synchronous call):
1. **Promote pending first:** fetch all records where `isActive == false && scheduledStartAt != nil`. For each where `scheduledStartAt! <= Date()`: set `isActive = true`, clear `scheduledStartAt`, save context.
2. **Then fetch active:** existing predicate `isActive == true` runs after promotion so a just-promoted record is picked up on the same call.

### Day Assignment — Weekday-Pinned Model

The existing ordinal rotation model uses `activatedAt` to count days since activation. The Split Finder introduces a parallel weekday-pinned mode using `pinnedWeekdaysJSON`.

`pinnedWeekdays` is an **ordered array** where element at index `i` is the Calendar weekday number assigned to the `i`-th non-rest split day (by `orderIndex`). Populated at subscribe time from the day-assignment grid selections.

When `pinnedWeekdays` is non-nil, `gymDay(for date:)` works as follows:
- Compute `weekday = Calendar.current.component(.weekday, from: date)`.
- If `weekday` appears at index `i` in `pinnedWeekdays`, return `activeSplitDays[i]` (the `i`-th non-rest day by `orderIndex`).
- If not found, return a synthetic rest day (`isRest = true`).
- The ordinal cursor / `activatedAt` advancement logic is **not used** for pinned splits.

Only splits created via Split Finder use `pinnedWeekdays`. Existing manually-created splits (`pinnedWeekdaysJSON == nil`) remain ordinal.

### SplitSubscribeSheet

Presented as a `.sheet` from `SplitFinderResultsView`. On dismiss (any path), also dismisses `SplitFinderResultsView` and the parent `SplitFinderView` via a `dismissAll: () -> Void` closure passed down from `TrainView`.

**Step 1 — Conflict resolution (skipped if no active split):**
Half-sheet with active split name and two buttons:
- "Switch Now" → `conflictResolution = .now`
- "Start Next Monday" → `conflictResolution = .nextMonday`

**Step 2 — Day assignment:**
7-day grid (Mon–Sun). Pre-populated based on `daysPerWeek`:

| Days | Pre-selected |
|------|-------------|
| 2 | Mon, Thu |
| 3 | Mon, Wed, Fri |
| 4 | Mon, Tue, Thu, Fri |
| 5 | Mon, Tue, Wed, Fri, Sat |
| 6 | Mon–Sat |

User taps any day to toggle. Rest days show a moon icon. Minimum 2 training days enforced (confirm button disabled otherwise).

**Step 3 — Confirm:**
"Start [Split Name]" button. On tap:

1. Build `UserSplitRecord`:
   - `name`: recommendation name
   - `libraryKey`: `""` (synthesized split — no library origin)
   - `isActive`: `true` if `.now`, `false` if `.nextMonday`
   - `scheduledStartAt`: `nil` if `.now`; next Monday's `startOfDay` if `.nextMonday`
   - `pinnedWeekdays`: selected weekday integers from day-assignment grid (stored via `pinnedWeekdaysJSON` computed setter)
   - `activatedAt`: `Date()` if `.now`, nil if `.nextMonday`
2. If `.now` and there is an existing active split: set its `isActive = false`.
3. Build `UserSplitDayRecord` entries from `recommendation.days` (non-rest days only) with `orderIndex`.
4. Save all to SwiftData `modelContext`.
5. Background API sync via `ApiClient.shared.post("/splits", body: ...)` — on failure, set `syncPending = true`. Retry happens inside `syncSplitsFromServer()` (called by `loadForUser()` on app launch). The implementation plan must ensure `syncSplitsFromServer()` handles `libraryKey == ""` synthesized splits correctly.
6. Call `vm.loadActiveSplit()`.
7. Call `dismissAll()`.

---

## New Files

| File | Location |
|------|---------|
| `SplitFinderModels.swift` | `Features/Train/Programs/` |
| `SplitFinderView.swift` | `Features/Train/Programs/` |
| `SplitFinderViewModel.swift` | `Features/Train/Programs/` |
| `SplitRecommender.swift` | `Features/Train/Programs/` |
| `InjurySubstitutionEngine.swift` | `Features/Train/Programs/` |
| `WarmupLibrary.swift` | `Features/Train/Programs/` |
| `SplitFinderResultsView.swift` | `Features/Train/Programs/` |
| `SplitSubscribeSheet.swift` | `Features/Train/Programs/` |

---

## Modified Files

| File | Change |
|------|--------|
| `TrainView.swift` | Add `showSplitFinder: Bool` state + `wand.and.stars` toolbar button + `.sheet(isPresented: $showSplitFinder) { SplitFinderView(dismissAll: { showSplitFinder = false }) }` |
| `ElosSchema.swift` | Add `scheduledStartAt: Date?`, `pinnedWeekdaysJSON: String?`, and `syncPending: Bool` to `UserSplitRecord` |
| `AppViewModel.swift` | Update `loadActiveSplit()` to (1) promote pending splits before fetching active, (2) use `pinnedWeekdays` in `gymDay(for:)` when non-nil; update `syncSplitsFromServer()` to handle `libraryKey == ""` synthesized splits |
