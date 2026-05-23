# Split Finder — Design Spec
**Date:** 2026-05-23
**Status:** Approved

## Overview

A survey-driven split recommendation engine accessible from a wand icon button in `TrainView`'s top-right toolbar. Users answer 8 questions and receive 3 personalized workout split options generated client-side by a rule-based engine. They can subscribe to a split, resolve conflicts with their current active split, and assign training days — all in one flow.

---

## Entry Point

Add a `wand.and.stars` toolbar button to `TrainView` (top-right, alongside existing history and analytics icons). Tapping it presents `SplitFinderView` as a `.sheet`. Controlled by a new `@State private var showSplitFinder = false` in `TrainView`.

---

## Survey Flow

`SplitFinderView` is a multi-step form with a linear progress bar across the top. `SplitFinderViewModel` (`@StateObject`) owns all state and drives step transitions via `currentStep: Int`.

### Steps

| Step | Question | Control |
|------|----------|---------|
| 1 | Primary goal | 4 tappable cards: Hypertrophy / Strength / Athletic / General |
| 2 | Days per week | Segmented picker: 2 / 3 / 4 / 5 / 6 |
| 3 | Session length | Stepped slider: 30 / 45 / 60 / 75 / 90 min |
| 4 | Equipment lean | 3 sliders (Machine, Dumbbell, Barbell), each 0–100; auto-normalized so they always sum to 100% |
| 5 | Gym type | 2 tappable cards: Commercial (full rack room) / Small or Home |
| 6 | Sport training | Toggle. If on: 12-sport grid picker + focus scale slider (0 = plays as hobby, 100 = peak athlete performance) |
| 7 | Injuries | Toggle. If on: body-part chip multi-select (Shoulder / Knee / Lower Back / Wrist / Elbow / Hip / Ankle) + per-part severity segmented picker (Mild / Moderate / Avoid entirely) |
| 8 | Warmups | Toggle. If on: style cards (Dynamic / Static Stretching / Both) |

Navigation: "Next" / "Back" buttons at the bottom of each step. Step 6–8 can be skipped if the toggle is off (counts as answered). After step 8, the view transitions to the results screen.

### Sports List (Step 6)
Basketball, Football, Soccer, Baseball, Tennis, Swimming, MMA/Boxing, Wrestling, Track & Field, Volleyball, Hockey, Golf, Lacrosse — displayed as a scrollable grid of icon+label chips.

---

## Data Model (`SplitFinderModels.swift`)

```swift
enum TrainingGoal    { case hypertrophy, strength, athletic, general }
enum GymSize         { case commercial, small }
enum WarmupStyle     { case dynamic, staticStretch, both }
enum InjuredPart     { case shoulder, knee, lowerBack, wrist, elbow, hip, ankle }
enum InjurySeverity  { case mild, moderate, avoid }
enum SplitStyle      { case fullBody, upperLower, pushPullLegs, arnold, broSplit, athletic }

struct EquipmentProfile {
    var machineRatio: Double    // 0.0–1.0
    var dumbbellRatio: Double
    var barbellRatio: Double
    // always normalized so the three sum to 1.0
}

struct InjuryEntry {
    var part: InjuredPart
    var severity: InjurySeverity
}

struct SplitFinderInput {
    var goal: TrainingGoal
    var daysPerWeek: Int            // 2–6
    var sessionMinutes: Int         // 30 / 45 / 60 / 75 / 90
    var equipment: EquipmentProfile
    var gymSize: GymSize
    var sport: Sport?               // nil if no sport selected
    var sportFocusRatio: Double     // 0.0–1.0
    var injuries: [InjuryEntry]
    var includeWarmups: Bool
    var warmupStyle: WarmupStyle?
}

struct SplitRecommendation: Identifiable {
    var id: UUID
    var name: String
    var style: SplitStyle
    var days: [RecommendedDay]
    var estimatedMinutes: Int
    var matchScore: Double          // 0.0–1.0, used for internal ranking only
    var matchTags: [String]         // e.g. "Great for hypertrophy", "Shoulder-safe"
}

struct RecommendedDay: Identifiable {
    var id: UUID
    var label: String               // "Push", "Upper", "Full Body A", etc.
    var isRest: Bool
    var exercises: [RecommendedExercise]
    var warmupBlock: [WarmupExercise]
}

struct RecommendedExercise: Identifiable {
    var id: UUID
    var name: String
    var sets: Int
    var reps: String                // e.g. "8–10"
    var equipment: String           // "Barbell" / "Dumbbell" / "Machine" / "Bodyweight"
    var primaryMuscle: String
}

struct WarmupExercise: Identifiable {
    var id: UUID
    var name: String
    var duration: String            // e.g. "30s" or "10 reps"
}
```

---

## Recommendation Engine (`SplitRecommender.swift`)

Pure Swift struct — no side effects, no network calls. Input: `SplitFinderInput`. Output: `[SplitRecommendation]` (always exactly 3, distinct styles when possible).

### Candidate Templates

Static templates defined per `(SplitStyle, daysPerWeek)`:

| Style | Compatible day counts |
|-------|-----------------------|
| Full Body | 2, 3 |
| Upper / Lower | 3, 4 |
| Push / Pull / Legs | 3, 4, 5, 6 |
| Arnold (Push A/B + Pull A/B + Legs) | 3, 6 |
| Bro Split (1 muscle group/day) | 5 |
| Athletic (compound-first, power emphasis) | 3, 4, 5 |

Each template defines day labels + a base exercise list per day (name, default sets/reps, equipment tag).

### Scoring Pipeline

Run for every eligible candidate (day count matches):

1. **Eligibility filter** — if `gymSize == .small` and template requires `barbellRatio > 0.5`, skip candidate.
2. **Goal score** — PPL/Arnold → best for hypertrophy; Athletic → best for athletic; Upper/Lower → best for strength; Full Body → best for general. Scored 0–1.
3. **Sport modifier** — if `sportFocusRatio > 0.3`, boost Athletic-style by up to 0.3. Increases weight on explosive compound movements in exercise selection.
4. **Equipment score** — for each exercise in the candidate's base list, check if it matches the user's `EquipmentProfile` (within ±20% tolerance). Score = fraction of exercises satisfied.
5. **Injury penalty** — for each injury with `.avoid` severity, count how many base exercises target that body part. Subtract 0.05 per unavoidable exercise.
6. **Final score** = goal score × 0.4 + equipment score × 0.35 + sport modifier × 0.15 − injury penalty × 0.1

Top 3 unique-style candidates returned (if fewer than 3 styles exist for the given day count, allow one duplicate style).

### Match Tags

Generated from scores:
- Score ≥ 0.85 → "Excellent match"
- Goal score ≥ 0.9 → "Great for [goal]"
- Equipment score ≥ 0.9 → "Equipment-friendly"
- Any injury with `.avoid` + 0 unavoidable exercises → "Shoulder-safe" (etc., per body part)
- `gymSize == .small` and candidate passes eligibility → "Works in any gym"

---

## Injury Substitution Engine (`InjurySubstitutionEngine.swift`)

Applied to all 3 candidates after scoring, before presenting results.

### Substitution Map

Static dictionary: `[String: [InjuryCondition: String?]]`

`InjuryCondition` is a struct of `(part: InjuredPart, severity: InjurySeverity)`. Value is the substitute exercise name, or `nil` meaning remove entirely.

**Sample entries (~40 total, covering all 7 body parts):**

| Original Exercise | Condition | Substitute |
|-------------------|-----------|------------|
| Barbell Overhead Press | Shoulder + mild | Dumbbell Lateral Raise |
| Barbell Overhead Press | Shoulder + moderate | Cable Face Pull |
| Barbell Overhead Press | Shoulder + avoid | *(removed)* |
| Barbell Back Squat | Knee + mild | Leg Press |
| Barbell Back Squat | Knee + moderate | Goblet Squat |
| Barbell Back Squat | Knee + avoid | *(removed)* |
| Barbell Deadlift | Lower Back + mild | Romanian Deadlift |
| Barbell Deadlift | Lower Back + moderate | Cable Pull-Through |
| Barbell Deadlift | Lower Back + avoid | *(removed)* |
| Barbell Curl | Wrist + mild | Hammer Curl |
| Barbell Curl | Wrist + moderate | Cable Curl |
| Skull Crushers | Elbow + mild | Cable Tricep Pushdown |
| Skull Crushers | Elbow + moderate | Tricep Dips (assisted) |
| Hip Thrust | Hip + mild | Glute Bridge |
| Hip Thrust | Hip + avoid | *(removed)* |
| Box Jump | Ankle + mild | Step-Up |
| Box Jump | Ankle + avoid | *(removed)* |

When an exercise is removed with no substitute and the day would have fewer than the minimum exercise count, the engine backfills from a safe-exercise pool filtered to the same muscle group and equipment profile.

---

## Warmup Library (`WarmupLibrary.swift`)

Static lookup keyed by `(goal: TrainingGoal, style: WarmupStyle)`.

### Session Budget Split

| Session Length | Warmup Budget | Working Time |
|----------------|---------------|--------------|
| 30 min | 5 min | 25 min |
| 45 min | 8 min | 37 min |
| 60 min | 10 min | 50 min |
| 75 min | 10 min | 65 min |
| 90 min | 12 min | 78 min |

Working time → set count per exercise (assume ~3 min/set including rest):
- 25 min → 3 exercises × 3 sets
- 37 min → 4 exercises × 3 sets
- 50 min → 5 exercises × 3–4 sets
- 65 min → 6 exercises × 3–4 sets
- 78 min → 6–7 exercises × 4–5 sets

### Warmup Blocks (examples)

**Dynamic (hypertrophy/strength day):** Band pull-aparts × 15, Leg swings × 10/side, Hip circles × 10/side, Cat-cow × 10, Shoulder circles × 10/side — 5–8 min total.

**Dynamic (athletic day):** High knees 30s, Lateral shuffles 30s, Arm circles, Inchworm × 5, Jump rope 60s — 8–10 min total.

**Static:** Chest opener 30s, Hip flexor stretch 30s/side, Hamstring stretch 30s/side, Thoracic rotation 30s/side — 5 min total.

**Both:** Dynamic block first (as above, shortened), static block post-session.

---

## Results Screen (`SplitFinderResultsView.swift`)

Shows after survey completes. Displays 3 `SplitRecommendationCard` views in a `ScrollView`.

### Recommendation Card

- Split name (large, bold) + style badge pill
- Row: days/week · estimated session time · warmup indicator (flame icon if included)
- Match tags as small pill chips
- Collapsible day-by-day preview: each day label + first 3 exercise names
- "Use This Split" filled button at bottom

---

## Subscribe Flow (`SplitSubscribeSheet.swift`)

Presented as a sheet when the user taps "Use This Split".

### Step 1 — Conflict Resolution (skip if no active split)
Bottom half-sheet: "You're currently on **[Split Name]**"
- "Switch Now" — replaces immediately
- "Start Next Monday" — schedules; current split stays active until then

### Step 2 — Day Assignment
7-day grid (Mon–Sun). Pre-populated with recommended days based on `daysPerWeek`:
- 2 days → Mon, Thu
- 3 days → Mon, Wed, Fri
- 4 days → Mon, Tue, Thu, Fri
- 5 days → Mon, Tue, Wed, Fri, Sat
- 6 days → Mon–Sat

User taps any day to toggle. Rest days shown with a moon icon. Minimum 2 training days enforced.

### Step 3 — Confirm
"Start [Split Name]" button. On tap:
- Saves split locally (SwiftData) with assigned days
- Calls `vm.loadActiveSplit()` to reflect immediately in `TrainView`
- Background API sync (same pattern as templates — local UUID first, update on success)
- Sheet dismisses, `SplitFinderView` dismisses

---

## New Files

| File | Purpose |
|------|---------|
| `SplitFinderModels.swift` | All input/result structs and enums |
| `SplitFinderView.swift` | 8-step survey stepper + results transition |
| `SplitFinderViewModel.swift` | Survey state, step logic, triggers recommendation |
| `SplitRecommender.swift` | Pure scoring + candidate selection engine |
| `InjurySubstitutionEngine.swift` | Static substitution map + backfill logic |
| `WarmupLibrary.swift` | Warmup block definitions keyed by goal + style |
| `SplitFinderResultsView.swift` | 3-card results display |
| `SplitSubscribeSheet.swift` | Conflict resolution + day assignment + confirm |

## Modified Files

| File | Change |
|------|--------|
| `TrainView.swift` | Add `showSplitFinder` state + toolbar button + `.sheet(isPresented: $showSplitFinder)` |
