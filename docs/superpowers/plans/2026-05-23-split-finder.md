# Split Finder Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a wand-icon toolbar button to TrainView that launches an 8-step survey, generates 3 personalized workout split recommendations via a client-side rule engine, and lets users subscribe with weekday-pinned scheduling.

**Architecture:** Pure client-side Swift engine — `SplitRecommender` scores static candidate templates, `InjurySubstitutionEngine` swaps out conflict exercises, `WarmupLibrary` assigns warmup blocks per session. The subscribe flow persists to SwiftData first and syncs to the backend in background (same local-first pattern as templates). A new `pinnedWeekdaysJSON` field on `UserSplitRecord` enables weekday-pinned scheduling alongside the existing ordinal rotation.

**Tech Stack:** SwiftUI, SwiftData, Swift strict mode, `AppViewModel` / `TrainViewModel` ObservableObject pattern, `ApiClient.shared` for background sync.

---

## File Map

**New files — all in `apps/elos-mobile/Elos/Elos/Features/Train/Programs/`:**
- `SplitFinderModels.swift` — all enums and structs (pure data, no UI)
- `WarmupLibrary.swift` — static warmup blocks, session budget math
- `SplitRecommender.swift` — candidate templates + full scoring pipeline
- `InjurySubstitutionEngine.swift` — substitution map + safe-exercise backfill pool
- `SplitFinderViewModel.swift` — `@ObservableObject` driving survey state + recommendation
- `SplitFinderView.swift` — 8-step survey UI + progress bar
- `SplitFinderResultsView.swift` — 3-card results display
- `SplitSubscribeSheet.swift` — conflict resolution + day-assignment grid + confirm

**Modified files:**
- `apps/elos-mobile/Elos/Elos/SwiftData/ElosSchema.swift` — add `scheduledStartAt: Date?` and `pinnedWeekdaysJSON: String?` to `UserSplitRecord`
- `apps/elos-mobile/Elos/Elos/AppViewModel.swift` — update `loadActiveSplit()` (pending promotion) and `gymDay(for:)` (weekday-pinned branch)
- `apps/elos-mobile/Elos/Elos/Views/TrainView.swift` — add `showSplitFinder` state + toolbar button + sheet

**Build check command** (run from repo root after each task):
```bash
xcodebuild build -project apps/elos-mobile/Elos/Elos.xcodeproj -scheme Elos \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  2>&1 | grep -E "^(error:|BUILD SUCCEEDED|BUILD FAILED)" | head -20
```

---

## Task 1: Schema — Add `scheduledStartAt` and `pinnedWeekdaysJSON` to `UserSplitRecord`

**Files:**
- Modify: `apps/elos-mobile/Elos/Elos/SwiftData/ElosSchema.swift` (around line 440)

`syncPending: Bool` already exists — do NOT add it again.

- [ ] **Step 1: Add the two new stored properties and init params**

In `ElosSchema.swift`, find the `UserSplitRecord` class (line ~440). Add after `var syncPending: Bool = false`:

```swift
var scheduledStartAt: Date? = nil    // non-nil = pending; activates when Date() >= this
var pinnedWeekdaysJSON: String? = nil // JSON [Int] of Calendar weekday numbers; nil = ordinal rotation
```

Add to the `init` signature (after `syncPending: Bool = false`):
```swift
scheduledStartAt: Date? = nil,
pinnedWeekdaysJSON: String? = nil
```

Add to the init body (after `self.syncPending = syncPending`):
```swift
self.scheduledStartAt    = scheduledStartAt
self.pinnedWeekdaysJSON  = pinnedWeekdaysJSON
```

- [ ] **Step 2: Add the `pinnedWeekdays` computed accessor**

After the `addSkip` function inside `UserSplitRecord`, add:

```swift
var pinnedWeekdays: [Int]? {
    get {
        guard let json = pinnedWeekdaysJSON else { return nil }
        return try? JSONDecoder().decode([Int].self, from: Data(json.utf8))
    }
    set {
        pinnedWeekdaysJSON = newValue.flatMap {
            try? String(data: JSONEncoder().encode($0), encoding: .utf8)
        }
    }
}
```

- [ ] **Step 3: Build**
```bash
xcodebuild build -project apps/elos-mobile/Elos/Elos.xcodeproj -scheme Elos \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  2>&1 | grep -E "error:|BUILD SUCCEEDED|BUILD FAILED"
```
Expected: `BUILD SUCCEEDED`

- [ ] **Step 4: Commit**
```bash
git add apps/elos-mobile/Elos/Elos/SwiftData/ElosSchema.swift
git commit -m "feat(schema): add scheduledStartAt and pinnedWeekdaysJSON to UserSplitRecord"
```

---

## Task 2: Data Models (`SplitFinderModels.swift`)

**Files:**
- Create: `apps/elos-mobile/Elos/Elos/Features/Train/Programs/SplitFinderModels.swift`

- [ ] **Step 1: Create the file**

```swift
import Foundation

// MARK: - Enums

enum TrainingGoal: String, CaseIterable {
    case hypertrophy, strength, athletic, general

    var displayName: String {
        switch self {
        case .hypertrophy: return "Hypertrophy"
        case .strength:    return "Strength"
        case .athletic:    return "Athletic"
        case .general:     return "General Fitness"
        }
    }

    var icon: String {
        switch self {
        case .hypertrophy: return "dumbbell.fill"
        case .strength:    return "figure.strengthtraining.traditional"
        case .athletic:    return "figure.run"
        case .general:     return "heart.fill"
        }
    }
}

enum GymSize: String, CaseIterable {
    case commercial, small

    var displayName: String { self == .commercial ? "Commercial Gym" : "Small / Home Gym" }
    var icon: String         { self == .commercial ? "building.2.fill" : "house.fill" }
}

enum WarmupStyle: String, CaseIterable {
    case dynamic, staticStretch, both

    var displayName: String {
        switch self {
        case .dynamic:       return "Dynamic"
        case .staticStretch: return "Static Stretching"
        case .both:          return "Both"
        }
    }
}

enum InjuredPart: String, CaseIterable {
    case shoulder, knee, lowerBack, wrist, elbow, hip, ankle

    var displayName: String {
        switch self {
        case .shoulder:  return "Shoulder"
        case .knee:      return "Knee"
        case .lowerBack: return "Lower Back"
        case .wrist:     return "Wrist"
        case .elbow:     return "Elbow"
        case .hip:       return "Hip"
        case .ankle:     return "Ankle"
        }
    }
}

enum InjurySeverity: String, CaseIterable {
    case mild, moderate, avoid

    var displayName: String {
        switch self {
        case .mild:     return "Mild"
        case .moderate: return "Moderate"
        case .avoid:    return "Avoid"
        }
    }
}

enum SplitStyle: String, CaseIterable {
    case fullBody, upperLower, pushPullLegs, arnold, broSplit, athletic

    var displayName: String {
        switch self {
        case .fullBody:      return "Full Body"
        case .upperLower:    return "Upper / Lower"
        case .pushPullLegs:  return "Push / Pull / Legs"
        case .arnold:        return "Arnold Split"
        case .broSplit:      return "Bro Split"
        case .athletic:      return "Athletic"
        }
    }
}

enum Sport: String, CaseIterable {
    case basketball, football, soccer, baseball, tennis, swimming
    case mmaBoxing, wrestling, trackAndField, volleyball, hockey, golf, lacrosse

    var displayName: String {
        switch self {
        case .basketball:   return "Basketball"
        case .football:     return "Football"
        case .soccer:       return "Soccer"
        case .baseball:     return "Baseball"
        case .tennis:       return "Tennis"
        case .swimming:     return "Swimming"
        case .mmaBoxing:    return "MMA / Boxing"
        case .wrestling:    return "Wrestling"
        case .trackAndField:return "Track & Field"
        case .volleyball:   return "Volleyball"
        case .hockey:       return "Hockey"
        case .golf:         return "Golf"
        case .lacrosse:     return "Lacrosse"
        }
    }

    var icon: String {
        switch self {
        case .basketball:   return "basketball.fill"
        case .football:     return "football.fill"
        case .soccer:       return "soccerball"
        case .baseball:     return "baseball.fill"
        case .tennis:       return "tennis.racket"
        case .swimming:     return "figure.pool.swim"
        case .mmaBoxing:    return "figure.boxing"
        case .wrestling:    return "figure.wrestling"
        case .trackAndField:return "figure.run"
        case .volleyball:   return "volleyball.fill"
        case .hockey:       return "hockey.puck.fill"
        case .golf:         return "figure.golf"
        case .lacrosse:     return "figure.lacrosse"
        }
    }
}

// MARK: - Input structs

struct EquipmentProfile {
    var machineRatio: Double    // 0.0–1.0, always normalized to sum 1.0 with the others
    var dumbbellRatio: Double
    var barbellRatio: Double

    static let balanced = EquipmentProfile(machineRatio: 0.33, dumbbellRatio: 0.34, barbellRatio: 0.33)

    /// Normalize so the three ratios sum to 1.0. If all zero, reset to balanced.
    mutating func normalize() {
        let sum = machineRatio + dumbbellRatio + barbellRatio
        if sum == 0 {
            machineRatio = 0.33; dumbbellRatio = 0.34; barbellRatio = 0.33
        } else {
            machineRatio   /= sum
            dumbbellRatio  /= sum
            barbellRatio   /= sum
        }
    }
}

struct InjuryEntry: Identifiable {
    let id = UUID()
    var part: InjuredPart
    var severity: InjurySeverity
}

struct SplitFinderInput {
    var goal: TrainingGoal          = .hypertrophy
    var daysPerWeek: Int            = 4
    var sessionMinutes: Int         = 60
    var equipment: EquipmentProfile = .balanced
    var gymSize: GymSize            = .commercial
    var sport: Sport?               = nil
    var sportFocusRatio: Double     = 0.0
    var injuries: [InjuryEntry]     = []
    var includeWarmups: Bool        = false
    var warmupStyle: WarmupStyle?   = nil
}

// MARK: - Output structs

struct RecommendedExercise: Identifiable {
    let id = UUID()
    var name: String
    var sets: Int
    var reps: String        // e.g. "8–10"
    var equipment: String   // "Barbell" | "Dumbbell" | "Machine" | "Bodyweight"
    var primaryMuscle: String
}

struct WarmupExercise: Identifiable {
    let id = UUID()
    var name: String
    var duration: String    // e.g. "30s" or "10 reps"
}

struct RecommendedDay: Identifiable {
    let id = UUID()
    var label: String               // "Push", "Upper A", "Rest"
    var isRest: Bool
    var exercises: [RecommendedExercise]
    var warmupBlock: [WarmupExercise]
}

struct SplitRecommendation: Identifiable {
    let id = UUID()
    var name: String
    var style: SplitStyle
    var days: [RecommendedDay]
    var estimatedMinutes: Int
    var matchScore: Double      // internal only
    var matchTags: [String]
}
```

- [ ] **Step 2: Add file to Xcode project**

Open Finder at `apps/elos-mobile/Elos/Elos/Features/Train/Programs/`, drag `SplitFinderModels.swift` into the Xcode project under the `Programs` group, ensuring "Add to target: Elos" is checked.

*(Alternative: use `xed` to open Xcode, then add the file manually in the project navigator.)*

- [ ] **Step 3: Build**
```bash
xcodebuild build -project apps/elos-mobile/Elos/Elos.xcodeproj -scheme Elos \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  2>&1 | grep -E "error:|BUILD SUCCEEDED|BUILD FAILED"
```

- [ ] **Step 4: Commit**
```bash
git add apps/elos-mobile/Elos/Elos/Features/Train/Programs/SplitFinderModels.swift
git commit -m "feat(split-finder): add SplitFinderModels — all enums and data structs"
```

---

## Task 3: Warmup Library (`WarmupLibrary.swift`)

**Files:**
- Create: `apps/elos-mobile/Elos/Elos/Features/Train/Programs/WarmupLibrary.swift`

- [ ] **Step 1: Create the file**

```swift
import Foundation

struct WarmupLibrary {

    // MARK: - Session budget

    /// Returns warmup minutes and minimum exercise count for a given session length.
    static func budget(sessionMinutes: Int) -> (warmupMinutes: Int, minExercises: Int) {
        switch sessionMinutes {
        case ..<45:  return (5, 3)
        case 45:     return (8, 4)
        case 60:     return (10, 5)
        case 75:     return (10, 6)
        default:     return (12, 6)  // 90 min
        }
    }

    /// Max exercises per day given session length (sets-based estimate: 3 min/set, 3 sets/exercise).
    static func maxExercises(sessionMinutes: Int) -> Int {
        let (warmup, minEx) = budget(sessionMinutes: sessionMinutes)
        let workingMinutes = sessionMinutes - warmup
        let totalSets = workingMinutes / 3
        let fromSets = totalSets / 3       // 3 sets per exercise default
        return max(minEx, fromSets)
    }

    // MARK: - Warmup blocks

    static func block(goal: TrainingGoal, style: WarmupStyle) -> [WarmupExercise] {
        switch style {
        case .dynamic:       return goal == .athletic ? athleticDynamic : liftingDynamic
        case .staticStretch: return staticBlock
        case .both:          return goal == .athletic ? athleticDynamic : liftingDynamic
        // Static post-session block is noted in day label; not returned here (not baked into pre-session budget)
        }
    }

    // MARK: - Block definitions

    private static let liftingDynamic: [WarmupExercise] = [
        WarmupExercise(name: "Band Pull-Apart",    duration: "15 reps"),
        WarmupExercise(name: "Leg Swings",         duration: "10 reps/side"),
        WarmupExercise(name: "Hip Circles",        duration: "10 reps/side"),
        WarmupExercise(name: "Cat-Cow",            duration: "10 reps"),
        WarmupExercise(name: "Shoulder Circles",   duration: "10 reps/side"),
    ]

    private static let athleticDynamic: [WarmupExercise] = [
        WarmupExercise(name: "High Knees",         duration: "30s"),
        WarmupExercise(name: "Lateral Shuffles",   duration: "30s"),
        WarmupExercise(name: "Arm Circles",        duration: "20 reps"),
        WarmupExercise(name: "Inchworm",           duration: "5 reps"),
        WarmupExercise(name: "Jump Rope",          duration: "60s"),
    ]

    private static let staticBlock: [WarmupExercise] = [
        WarmupExercise(name: "Chest Opener",       duration: "30s/side"),
        WarmupExercise(name: "Hip Flexor Stretch", duration: "30s/side"),
        WarmupExercise(name: "Hamstring Stretch",  duration: "30s/side"),
        WarmupExercise(name: "Thoracic Rotation",  duration: "30s/side"),
    ]
}
```

- [ ] **Step 2: Add to Xcode project** (same group as Task 2)

- [ ] **Step 3: Build**
```bash
xcodebuild build -project apps/elos-mobile/Elos/Elos.xcodeproj -scheme Elos \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  2>&1 | grep -E "error:|BUILD SUCCEEDED|BUILD FAILED"
```

- [ ] **Step 4: Commit**
```bash
git add apps/elos-mobile/Elos/Elos/Features/Train/Programs/WarmupLibrary.swift
git commit -m "feat(split-finder): add WarmupLibrary — session budget and warmup block definitions"
```

---

## Task 4: Split Recommender (`SplitRecommender.swift`)

**Files:**
- Create: `apps/elos-mobile/Elos/Elos/Features/Train/Programs/SplitRecommender.swift`

This is the largest file. It contains static exercise templates and the full scoring pipeline.

- [ ] **Step 1: Create the file**

```swift
import Foundation

// MARK: - Candidate template definition

private struct CandidateTemplate {
    let style: SplitStyle
    let compatibleDays: [Int]
    let days: [TemplateDay]
}

private struct TemplateDay {
    let label: String
    let isRest: Bool
    let exercises: [RecommendedExercise]
}

// MARK: - Recommender

struct SplitRecommender {

    // MARK: Public entry point

    /// Returns 1–3 scored SplitRecommendation values for the given input.
    static func recommend(input: SplitFinderInput) -> [SplitRecommendation] {
        let eligible = allTemplates
            .filter { $0.compatibleDays.contains(input.daysPerWeek) }
            .filter { passes(eligibility: $0, input: input) }

        let scored: [(CandidateTemplate, Double, Double, Double)] = eligible.map { template in
            let gs  = goalScore(template: template, goal: input.goal)
            let sm  = sportModifier(template: template, input: input)
            let es  = equipmentScore(template: template, equipment: input.equipment)
            let ip  = injuryPenalty(template: template, injuries: input.injuries)
            let final = (gs + sm) * 0.40 + es * 0.35 + (1.0 - ip) * 0.25
            return (template, gs, es, final)
        }
        .sorted { $0.3 > $1.3 }

        // Pick top 3 preferring distinct styles
        var chosen: [(CandidateTemplate, Double, Double, Double)] = []
        var seenStyles = Set<SplitStyle>()
        for item in scored {
            if chosen.count == 3 { break }
            if !seenStyles.contains(item.0.style) {
                chosen.append(item); seenStyles.insert(item.0.style)
            }
        }
        // Fill remaining slots with duplicates if needed
        if chosen.count < 3 {
            for item in scored where chosen.count < 3 {
                if !chosen.contains(where: { $0.0.style == item.0.style && $0.3 == item.3 }) {
                    chosen.append(item)
                }
            }
        }

        return chosen.map { (template, gs, es, finalScore) in
            build(template: template, input: input, goalScore: gs, equipmentScore: es, finalScore: finalScore)
        }
    }

    // MARK: - Eligibility

    private static func passes(eligibility template: CandidateTemplate, input: SplitFinderInput) -> Bool {
        if input.gymSize == .small {
            if template.style == .broSplit { return false }
            if input.equipment.barbellRatio > 0.5 {
                let barbellHeavy: [SplitStyle] = [.pushPullLegs, .arnold]
                if barbellHeavy.contains(template.style) { return false }
            }
        }
        return true
    }

    // MARK: - Scoring

    private static func goalScore(template: CandidateTemplate, goal: TrainingGoal) -> Double {
        let table: [SplitStyle: [TrainingGoal: Double]] = [
            .fullBody:     [.hypertrophy: 0.5, .strength: 0.6, .athletic: 0.6, .general: 1.0],
            .upperLower:   [.hypertrophy: 0.7, .strength: 1.0, .athletic: 0.7, .general: 0.7],
            .pushPullLegs: [.hypertrophy: 1.0, .strength: 0.6, .athletic: 0.5, .general: 0.6],
            .arnold:       [.hypertrophy: 0.95,.strength: 0.5, .athletic: 0.4, .general: 0.5],
            .broSplit:     [.hypertrophy: 0.85,.strength: 0.5, .athletic: 0.3, .general: 0.5],
            .athletic:     [.hypertrophy: 0.4, .strength: 0.7, .athletic: 1.0, .general: 0.6],
        ]
        return table[template.style]?[goal] ?? 0.5
    }

    private static func sportModifier(template: CandidateTemplate, input: SplitFinderInput) -> Double {
        guard input.sport != nil, input.sportFocusRatio > 0 else { return 0 }
        if template.style == .athletic { return input.sportFocusRatio * 0.3 }
        if input.sportFocusRatio > 0.5 { return -0.1 }
        return 0
    }

    private static func equipmentScore(template: CandidateTemplate, equipment: EquipmentProfile) -> Double {
        let allExercises = template.days.flatMap { $0.exercises }
        guard !allExercises.isEmpty else { return 1.0 }
        let matched = allExercises.filter { ex in
            switch ex.equipment {
            case "Machine":    return equipment.machineRatio >= 0.2
            case "Dumbbell":   return equipment.dumbbellRatio >= 0.2
            case "Barbell":    return equipment.barbellRatio >= 0.2
            case "Bodyweight": return true
            default:           return true
            }
        }
        return Double(matched.count) / Double(allExercises.count)
    }

    private static func injuryPenalty(template: CandidateTemplate, injuries: [InjuryEntry]) -> Double {
        let avoidParts = injuries.filter { $0.severity == .avoid }.map { $0.part }
        guard !avoidParts.isEmpty else { return 0 }

        let muscleMap: [InjuredPart: Set<String>] = [
            .shoulder: ["front_delts", "side_delts", "rear_delts"],
            .knee:     ["quads", "hamstrings"],
            .lowerBack:["lower_back", "glutes"],
            .wrist:    ["forearms"],
            .elbow:    ["biceps", "triceps"],
            .hip:      ["hip_flexors", "glutes"],
            .ankle:    ["calves"],
        ]
        let avoidMuscles = avoidParts.flatMap { muscleMap[$0] ?? [] }
        let avoidSet = Set(avoidMuscles)

        let allExercises = template.days.flatMap { $0.exercises }
        let conflicts = allExercises.filter { avoidSet.contains($0.primaryMuscle) }.count
        return min(Double(conflicts) * 0.05, 0.25)
    }

    // MARK: - Build recommendation

    private static func build(
        template: CandidateTemplate,
        input: SplitFinderInput,
        goalScore: Double,
        equipmentScore: Double,
        finalScore: Double
    ) -> SplitRecommendation {
        let maxEx = WarmupLibrary.maxExercises(sessionMinutes: input.sessionMinutes)
        let (warmupMin, _) = WarmupLibrary.budget(sessionMinutes: input.sessionMinutes)
        let warmupBlock: [WarmupExercise] = input.includeWarmups
            ? WarmupLibrary.block(goal: input.goal, style: input.warmupStyle ?? .dynamic)
            : []

        // Build days: only emit daysPerWeek workout days + fill to 7 with rest
        let workoutDays = template.days.filter { !$0.isRest }.prefix(input.daysPerWeek)
        var builtDays: [RecommendedDay] = workoutDays.map { tDay in
            let trimmed = Array(tDay.exercises.prefix(maxEx))
            return RecommendedDay(
                label: tDay.label,
                isRest: false,
                exercises: trimmed,
                warmupBlock: warmupBlock
            )
        }

        let tags = matchTags(
            finalScore: finalScore, goalScore: goalScore,
            equipmentScore: equipmentScore, input: input,
            template: template
        )
        let estMin = input.sessionMinutes - (input.includeWarmups ? 0 : warmupMin) + (input.includeWarmups ? warmupMin : 0)

        return SplitRecommendation(
            name: "\(input.daysPerWeek)-Day \(template.style.displayName)",
            style: template.style,
            days: builtDays,
            estimatedMinutes: estMin,
            matchScore: finalScore,
            matchTags: tags
        )
    }

    private static func matchTags(
        finalScore: Double, goalScore: Double, equipmentScore: Double,
        input: SplitFinderInput, template: CandidateTemplate
    ) -> [String] {
        var tags: [String] = []
        if finalScore >= 0.85    { tags.append("Excellent match") }
        if goalScore >= 0.9      { tags.append("Great for \(input.goal.displayName)") }
        if equipmentScore >= 0.9 { tags.append("Equipment-friendly") }
        if input.gymSize == .small && passes(eligibility: template, input: input) {
            tags.append("Works in any gym")
        }
        if input.sportFocusRatio >= 0.5 && template.style == .athletic {
            tags.append("Sport performance focus")
        }
        // Injury-safe tags
        let muscleMap: [InjuredPart: Set<String>] = [
            .shoulder: ["front_delts", "side_delts", "rear_delts"],
            .knee:     ["quads", "hamstrings"],
            .lowerBack:["lower_back", "glutes"],
            .wrist:    ["forearms"],
            .elbow:    ["biceps", "triceps"],
            .hip:      ["hip_flexors", "glutes"],
            .ankle:    ["calves"],
        ]
        let allMuscles = Set(template.days.flatMap { $0.exercises }.map { $0.primaryMuscle })
        for entry in input.injuries where entry.severity == .avoid {
            let riskyMuscles = muscleMap[entry.part] ?? []
            if riskyMuscles.isDisjoint(with: allMuscles) {
                tags.append("\(entry.part.displayName)-safe")
            }
        }
        return Array(tags.prefix(3))
    }

    // MARK: - Static exercise templates

    private static let allTemplates: [CandidateTemplate] = [

        // MARK: Full Body — 3 day
        CandidateTemplate(style: .fullBody, compatibleDays: [2, 3], days: [
            TemplateDay(label: "Full Body A", isRest: false, exercises: [
                RecommendedExercise(name: "Barbell Back Squat",    sets: 4, reps: "5",    equipment: "Barbell",    primaryMuscle: "quads"),
                RecommendedExercise(name: "Barbell Bench Press",   sets: 4, reps: "5",    equipment: "Barbell",    primaryMuscle: "chest"),
                RecommendedExercise(name: "Barbell Row",           sets: 4, reps: "5",    equipment: "Barbell",    primaryMuscle: "lats"),
                RecommendedExercise(name: "Dumbbell Lateral Raise",sets: 3, reps: "12",   equipment: "Dumbbell",   primaryMuscle: "side_delts"),
                RecommendedExercise(name: "Plank",                 sets: 3, reps: "30s",  equipment: "Bodyweight", primaryMuscle: "core"),
            ]),
            TemplateDay(label: "Full Body B", isRest: false, exercises: [
                RecommendedExercise(name: "Romanian Deadlift",     sets: 4, reps: "8",    equipment: "Barbell",    primaryMuscle: "hamstrings"),
                RecommendedExercise(name: "Incline Dumbbell Press",sets: 4, reps: "10",   equipment: "Dumbbell",   primaryMuscle: "chest"),
                RecommendedExercise(name: "Lat Pulldown",          sets: 4, reps: "10",   equipment: "Machine",    primaryMuscle: "lats"),
                RecommendedExercise(name: "Barbell Curl",          sets: 3, reps: "10",   equipment: "Barbell",    primaryMuscle: "biceps"),
                RecommendedExercise(name: "Calf Raise",            sets: 3, reps: "15",   equipment: "Machine",    primaryMuscle: "calves"),
            ]),
            TemplateDay(label: "Full Body C", isRest: false, exercises: [
                RecommendedExercise(name: "Leg Press",             sets: 4, reps: "10",   equipment: "Machine",    primaryMuscle: "quads"),
                RecommendedExercise(name: "Barbell Overhead Press",sets: 4, reps: "8",    equipment: "Barbell",    primaryMuscle: "front_delts"),
                RecommendedExercise(name: "Cable Row",             sets: 4, reps: "10",   equipment: "Machine",    primaryMuscle: "lats"),
                RecommendedExercise(name: "Tricep Pushdown",       sets: 3, reps: "12",   equipment: "Machine",    primaryMuscle: "triceps"),
                RecommendedExercise(name: "Dead Bug",              sets: 3, reps: "10/side", equipment: "Bodyweight", primaryMuscle: "core"),
            ]),
        ]),

        // MARK: Upper/Lower — 4 day
        CandidateTemplate(style: .upperLower, compatibleDays: [3, 4], days: [
            TemplateDay(label: "Upper A", isRest: false, exercises: [
                RecommendedExercise(name: "Barbell Bench Press",   sets: 4, reps: "6",    equipment: "Barbell",    primaryMuscle: "chest"),
                RecommendedExercise(name: "Barbell Row",           sets: 4, reps: "6",    equipment: "Barbell",    primaryMuscle: "lats"),
                RecommendedExercise(name: "Barbell Overhead Press",sets: 3, reps: "8",    equipment: "Barbell",    primaryMuscle: "front_delts"),
                RecommendedExercise(name: "Lat Pulldown",          sets: 3, reps: "10",   equipment: "Machine",    primaryMuscle: "lats"),
                RecommendedExercise(name: "Barbell Curl",          sets: 3, reps: "10",   equipment: "Barbell",    primaryMuscle: "biceps"),
                RecommendedExercise(name: "Skull Crushers",        sets: 3, reps: "10",   equipment: "Barbell",    primaryMuscle: "triceps"),
            ]),
            TemplateDay(label: "Lower A", isRest: false, exercises: [
                RecommendedExercise(name: "Barbell Back Squat",    sets: 4, reps: "6",    equipment: "Barbell",    primaryMuscle: "quads"),
                RecommendedExercise(name: "Romanian Deadlift",     sets: 4, reps: "8",    equipment: "Barbell",    primaryMuscle: "hamstrings"),
                RecommendedExercise(name: "Leg Press",             sets: 3, reps: "10",   equipment: "Machine",    primaryMuscle: "quads"),
                RecommendedExercise(name: "Leg Curl",              sets: 3, reps: "12",   equipment: "Machine",    primaryMuscle: "hamstrings"),
                RecommendedExercise(name: "Calf Raise",            sets: 4, reps: "15",   equipment: "Machine",    primaryMuscle: "calves"),
            ]),
            TemplateDay(label: "Upper B", isRest: false, exercises: [
                RecommendedExercise(name: "Incline Dumbbell Press",sets: 4, reps: "10",   equipment: "Dumbbell",   primaryMuscle: "chest"),
                RecommendedExercise(name: "Cable Row",             sets: 4, reps: "10",   equipment: "Machine",    primaryMuscle: "lats"),
                RecommendedExercise(name: "Dumbbell Shoulder Press",sets:3, reps: "10",   equipment: "Dumbbell",   primaryMuscle: "front_delts"),
                RecommendedExercise(name: "Machine Chest Press",   sets: 3, reps: "12",   equipment: "Machine",    primaryMuscle: "chest"),
                RecommendedExercise(name: "Hammer Curl",           sets: 3, reps: "12",   equipment: "Dumbbell",   primaryMuscle: "biceps"),
                RecommendedExercise(name: "Tricep Pushdown",       sets: 3, reps: "12",   equipment: "Machine",    primaryMuscle: "triceps"),
            ]),
            TemplateDay(label: "Lower B", isRest: false, exercises: [
                RecommendedExercise(name: "Barbell Deadlift",      sets: 4, reps: "5",    equipment: "Barbell",    primaryMuscle: "lower_back"),
                RecommendedExercise(name: "Hip Thrust",            sets: 4, reps: "10",   equipment: "Barbell",    primaryMuscle: "glutes"),
                RecommendedExercise(name: "Leg Extension",         sets: 3, reps: "12",   equipment: "Machine",    primaryMuscle: "quads"),
                RecommendedExercise(name: "Lateral Lunge",         sets: 3, reps: "10/side", equipment: "Dumbbell", primaryMuscle: "quads"),
                RecommendedExercise(name: "Calf Raise",            sets: 4, reps: "15",   equipment: "Machine",    primaryMuscle: "calves"),
            ]),
        ]),

        // MARK: PPL — 4 day (A/B)
        CandidateTemplate(style: .pushPullLegs, compatibleDays: [3, 4, 5, 6], days: [
            TemplateDay(label: "Push A", isRest: false, exercises: [
                RecommendedExercise(name: "Barbell Bench Press",   sets: 4, reps: "8",    equipment: "Barbell",    primaryMuscle: "chest"),
                RecommendedExercise(name: "Barbell Overhead Press",sets: 3, reps: "8",    equipment: "Barbell",    primaryMuscle: "front_delts"),
                RecommendedExercise(name: "Incline Dumbbell Press",sets: 3, reps: "10",   equipment: "Dumbbell",   primaryMuscle: "chest"),
                RecommendedExercise(name: "Dumbbell Lateral Raise",sets: 3, reps: "12",   equipment: "Dumbbell",   primaryMuscle: "side_delts"),
                RecommendedExercise(name: "Skull Crushers",        sets: 3, reps: "10",   equipment: "Barbell",    primaryMuscle: "triceps"),
            ]),
            TemplateDay(label: "Pull A", isRest: false, exercises: [
                RecommendedExercise(name: "Barbell Row",           sets: 4, reps: "8",    equipment: "Barbell",    primaryMuscle: "lats"),
                RecommendedExercise(name: "Lat Pulldown",          sets: 3, reps: "10",   equipment: "Machine",    primaryMuscle: "lats"),
                RecommendedExercise(name: "Cable Row",             sets: 3, reps: "10",   equipment: "Machine",    primaryMuscle: "lats"),
                RecommendedExercise(name: "Barbell Curl",          sets: 3, reps: "10",   equipment: "Barbell",    primaryMuscle: "biceps"),
                RecommendedExercise(name: "Face Pull",             sets: 3, reps: "15",   equipment: "Machine",    primaryMuscle: "rear_delts"),
            ]),
            TemplateDay(label: "Legs A", isRest: false, exercises: [
                RecommendedExercise(name: "Barbell Back Squat",    sets: 4, reps: "8",    equipment: "Barbell",    primaryMuscle: "quads"),
                RecommendedExercise(name: "Romanian Deadlift",     sets: 4, reps: "8",    equipment: "Barbell",    primaryMuscle: "hamstrings"),
                RecommendedExercise(name: "Leg Press",             sets: 3, reps: "10",   equipment: "Machine",    primaryMuscle: "quads"),
                RecommendedExercise(name: "Leg Curl",              sets: 3, reps: "12",   equipment: "Machine",    primaryMuscle: "hamstrings"),
                RecommendedExercise(name: "Calf Raise",            sets: 4, reps: "15",   equipment: "Machine",    primaryMuscle: "calves"),
            ]),
            TemplateDay(label: "Push B", isRest: false, exercises: [
                RecommendedExercise(name: "Incline Barbell Press", sets: 4, reps: "8",    equipment: "Barbell",    primaryMuscle: "chest"),
                RecommendedExercise(name: "Dumbbell Shoulder Press",sets:3, reps: "10",   equipment: "Dumbbell",   primaryMuscle: "front_delts"),
                RecommendedExercise(name: "Cable Fly",             sets: 3, reps: "12",   equipment: "Machine",    primaryMuscle: "chest"),
                RecommendedExercise(name: "Cable Lateral Raise",   sets: 3, reps: "15",   equipment: "Machine",    primaryMuscle: "side_delts"),
                RecommendedExercise(name: "Tricep Dips",           sets: 3, reps: "10",   equipment: "Bodyweight", primaryMuscle: "triceps"),
            ]),
            TemplateDay(label: "Pull B", isRest: false, exercises: [
                RecommendedExercise(name: "Lat Pulldown",          sets: 4, reps: "10",   equipment: "Machine",    primaryMuscle: "lats"),
                RecommendedExercise(name: "Cable Row",             sets: 4, reps: "10",   equipment: "Machine",    primaryMuscle: "lats"),
                RecommendedExercise(name: "Face Pull",             sets: 3, reps: "15",   equipment: "Machine",    primaryMuscle: "rear_delts"),
                RecommendedExercise(name: "Hammer Curl",           sets: 3, reps: "12",   equipment: "Dumbbell",   primaryMuscle: "biceps"),
                RecommendedExercise(name: "Dumbbell Curl",         sets: 3, reps: "12",   equipment: "Dumbbell",   primaryMuscle: "biceps"),
            ]),
            TemplateDay(label: "Legs B", isRest: false, exercises: [
                RecommendedExercise(name: "Barbell Deadlift",      sets: 4, reps: "5",    equipment: "Barbell",    primaryMuscle: "lower_back"),
                RecommendedExercise(name: "Hip Thrust",            sets: 4, reps: "10",   equipment: "Barbell",    primaryMuscle: "glutes"),
                RecommendedExercise(name: "Leg Extension",         sets: 3, reps: "12",   equipment: "Machine",    primaryMuscle: "quads"),
                RecommendedExercise(name: "Lateral Lunge",         sets: 3, reps: "10/side", equipment: "Dumbbell", primaryMuscle: "quads"),
                RecommendedExercise(name: "Calf Raise",            sets: 4, reps: "15",   equipment: "Machine",    primaryMuscle: "calves"),
            ]),
        ]),

        // MARK: Arnold Split — 3 day (can be run 3 or 6)
        CandidateTemplate(style: .arnold, compatibleDays: [3, 6], days: [
            TemplateDay(label: "Chest & Back", isRest: false, exercises: [
                RecommendedExercise(name: "Barbell Bench Press",   sets: 4, reps: "8",    equipment: "Barbell",    primaryMuscle: "chest"),
                RecommendedExercise(name: "Barbell Row",           sets: 4, reps: "8",    equipment: "Barbell",    primaryMuscle: "lats"),
                RecommendedExercise(name: "Incline Dumbbell Press",sets: 3, reps: "10",   equipment: "Dumbbell",   primaryMuscle: "chest"),
                RecommendedExercise(name: "Lat Pulldown",          sets: 3, reps: "10",   equipment: "Machine",    primaryMuscle: "lats"),
                RecommendedExercise(name: "Cable Fly",             sets: 3, reps: "12",   equipment: "Machine",    primaryMuscle: "chest"),
            ]),
            TemplateDay(label: "Shoulders & Arms", isRest: false, exercises: [
                RecommendedExercise(name: "Barbell Overhead Press",sets: 4, reps: "8",    equipment: "Barbell",    primaryMuscle: "front_delts"),
                RecommendedExercise(name: "Dumbbell Lateral Raise",sets: 3, reps: "12",   equipment: "Dumbbell",   primaryMuscle: "side_delts"),
                RecommendedExercise(name: "Barbell Curl",          sets: 3, reps: "10",   equipment: "Barbell",    primaryMuscle: "biceps"),
                RecommendedExercise(name: "Skull Crushers",        sets: 3, reps: "10",   equipment: "Barbell",    primaryMuscle: "triceps"),
                RecommendedExercise(name: "Face Pull",             sets: 3, reps: "15",   equipment: "Machine",    primaryMuscle: "rear_delts"),
            ]),
            TemplateDay(label: "Legs", isRest: false, exercises: [
                RecommendedExercise(name: "Barbell Back Squat",    sets: 4, reps: "8",    equipment: "Barbell",    primaryMuscle: "quads"),
                RecommendedExercise(name: "Romanian Deadlift",     sets: 4, reps: "8",    equipment: "Barbell",    primaryMuscle: "hamstrings"),
                RecommendedExercise(name: "Leg Press",             sets: 3, reps: "10",   equipment: "Machine",    primaryMuscle: "quads"),
                RecommendedExercise(name: "Hip Thrust",            sets: 3, reps: "10",   equipment: "Barbell",    primaryMuscle: "glutes"),
                RecommendedExercise(name: "Calf Raise",            sets: 4, reps: "15",   equipment: "Machine",    primaryMuscle: "calves"),
            ]),
        ]),

        // MARK: Bro Split — 5 day
        CandidateTemplate(style: .broSplit, compatibleDays: [5], days: [
            TemplateDay(label: "Chest", isRest: false, exercises: [
                RecommendedExercise(name: "Barbell Bench Press",   sets: 4, reps: "8",    equipment: "Barbell",    primaryMuscle: "chest"),
                RecommendedExercise(name: "Incline Dumbbell Press",sets: 4, reps: "10",   equipment: "Dumbbell",   primaryMuscle: "chest"),
                RecommendedExercise(name: "Machine Chest Press",   sets: 3, reps: "12",   equipment: "Machine",    primaryMuscle: "chest"),
                RecommendedExercise(name: "Cable Fly",             sets: 3, reps: "12",   equipment: "Machine",    primaryMuscle: "chest"),
                RecommendedExercise(name: "Dips",                  sets: 3, reps: "10",   equipment: "Bodyweight", primaryMuscle: "chest"),
            ]),
            TemplateDay(label: "Back", isRest: false, exercises: [
                RecommendedExercise(name: "Barbell Row",           sets: 4, reps: "8",    equipment: "Barbell",    primaryMuscle: "lats"),
                RecommendedExercise(name: "Lat Pulldown",          sets: 4, reps: "10",   equipment: "Machine",    primaryMuscle: "lats"),
                RecommendedExercise(name: "Cable Row",             sets: 3, reps: "10",   equipment: "Machine",    primaryMuscle: "lats"),
                RecommendedExercise(name: "Barbell Deadlift",      sets: 3, reps: "5",    equipment: "Barbell",    primaryMuscle: "lower_back"),
                RecommendedExercise(name: "Face Pull",             sets: 3, reps: "15",   equipment: "Machine",    primaryMuscle: "rear_delts"),
            ]),
            TemplateDay(label: "Shoulders", isRest: false, exercises: [
                RecommendedExercise(name: "Barbell Overhead Press",sets: 4, reps: "8",    equipment: "Barbell",    primaryMuscle: "front_delts"),
                RecommendedExercise(name: "Dumbbell Lateral Raise",sets: 4, reps: "12",   equipment: "Dumbbell",   primaryMuscle: "side_delts"),
                RecommendedExercise(name: "Dumbbell Shoulder Press",sets:3, reps: "10",   equipment: "Dumbbell",   primaryMuscle: "front_delts"),
                RecommendedExercise(name: "Cable Lateral Raise",   sets: 3, reps: "15",   equipment: "Machine",    primaryMuscle: "side_delts"),
                RecommendedExercise(name: "Face Pull",             sets: 3, reps: "15",   equipment: "Machine",    primaryMuscle: "rear_delts"),
            ]),
            TemplateDay(label: "Arms", isRest: false, exercises: [
                RecommendedExercise(name: "Barbell Curl",          sets: 4, reps: "10",   equipment: "Barbell",    primaryMuscle: "biceps"),
                RecommendedExercise(name: "Skull Crushers",        sets: 4, reps: "10",   equipment: "Barbell",    primaryMuscle: "triceps"),
                RecommendedExercise(name: "Hammer Curl",           sets: 3, reps: "12",   equipment: "Dumbbell",   primaryMuscle: "biceps"),
                RecommendedExercise(name: "Tricep Pushdown",       sets: 3, reps: "12",   equipment: "Machine",    primaryMuscle: "triceps"),
                RecommendedExercise(name: "Cable Curl",            sets: 3, reps: "12",   equipment: "Machine",    primaryMuscle: "biceps"),
            ]),
            TemplateDay(label: "Legs", isRest: false, exercises: [
                RecommendedExercise(name: "Barbell Back Squat",    sets: 4, reps: "8",    equipment: "Barbell",    primaryMuscle: "quads"),
                RecommendedExercise(name: "Romanian Deadlift",     sets: 4, reps: "8",    equipment: "Barbell",    primaryMuscle: "hamstrings"),
                RecommendedExercise(name: "Leg Press",             sets: 3, reps: "10",   equipment: "Machine",    primaryMuscle: "quads"),
                RecommendedExercise(name: "Hip Thrust",            sets: 3, reps: "10",   equipment: "Barbell",    primaryMuscle: "glutes"),
                RecommendedExercise(name: "Calf Raise",            sets: 4, reps: "15",   equipment: "Machine",    primaryMuscle: "calves"),
            ]),
        ]),

        // MARK: Athletic — 4 day
        CandidateTemplate(style: .athletic, compatibleDays: [3, 4, 5], days: [
            TemplateDay(label: "Power Lower", isRest: false, exercises: [
                RecommendedExercise(name: "Barbell Back Squat",    sets: 5, reps: "5",    equipment: "Barbell",    primaryMuscle: "quads"),
                RecommendedExercise(name: "Barbell Deadlift",      sets: 4, reps: "4",    equipment: "Barbell",    primaryMuscle: "lower_back"),
                RecommendedExercise(name: "Box Jump",              sets: 4, reps: "5",    equipment: "Bodyweight", primaryMuscle: "quads"),
                RecommendedExercise(name: "Lateral Lunge",         sets: 3, reps: "10/side", equipment: "Dumbbell", primaryMuscle: "quads"),
                RecommendedExercise(name: "Calf Raise",            sets: 3, reps: "15",   equipment: "Machine",    primaryMuscle: "calves"),
            ]),
            TemplateDay(label: "Power Upper", isRest: false, exercises: [
                RecommendedExercise(name: "Barbell Bench Press",   sets: 5, reps: "5",    equipment: "Barbell",    primaryMuscle: "chest"),
                RecommendedExercise(name: "Barbell Row",           sets: 4, reps: "5",    equipment: "Barbell",    primaryMuscle: "lats"),
                RecommendedExercise(name: "Barbell Overhead Press",sets: 3, reps: "6",    equipment: "Barbell",    primaryMuscle: "front_delts"),
                RecommendedExercise(name: "Pull-Ups",              sets: 3, reps: "8",    equipment: "Bodyweight", primaryMuscle: "lats"),
                RecommendedExercise(name: "Plank",                 sets: 3, reps: "45s",  equipment: "Bodyweight", primaryMuscle: "core"),
            ]),
            TemplateDay(label: "Hypertrophy Lower", isRest: false, exercises: [
                RecommendedExercise(name: "Romanian Deadlift",     sets: 4, reps: "8",    equipment: "Barbell",    primaryMuscle: "hamstrings"),
                RecommendedExercise(name: "Hip Thrust",            sets: 4, reps: "10",   equipment: "Barbell",    primaryMuscle: "glutes"),
                RecommendedExercise(name: "Leg Press",             sets: 3, reps: "10",   equipment: "Machine",    primaryMuscle: "quads"),
                RecommendedExercise(name: "Leg Curl",              sets: 3, reps: "12",   equipment: "Machine",    primaryMuscle: "hamstrings"),
                RecommendedExercise(name: "Jump Rope",             sets: 3, reps: "60s",  equipment: "Bodyweight", primaryMuscle: "calves"),
            ]),
            TemplateDay(label: "Hypertrophy Upper", isRest: false, exercises: [
                RecommendedExercise(name: "Incline Dumbbell Press",sets: 4, reps: "10",   equipment: "Dumbbell",   primaryMuscle: "chest"),
                RecommendedExercise(name: "Cable Row",             sets: 4, reps: "10",   equipment: "Machine",    primaryMuscle: "lats"),
                RecommendedExercise(name: "Dumbbell Lateral Raise",sets: 3, reps: "12",   equipment: "Dumbbell",   primaryMuscle: "side_delts"),
                RecommendedExercise(name: "Barbell Curl",          sets: 3, reps: "10",   equipment: "Barbell",    primaryMuscle: "biceps"),
                RecommendedExercise(name: "Dead Bug",              sets: 3, reps: "10/side", equipment: "Bodyweight", primaryMuscle: "core"),
            ]),
        ]),
    ]
}
```

- [ ] **Step 2: Add to Xcode project**

- [ ] **Step 3: Build**
```bash
xcodebuild build -project apps/elos-mobile/Elos/Elos.xcodeproj -scheme Elos \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  2>&1 | grep -E "error:|BUILD SUCCEEDED|BUILD FAILED"
```

- [ ] **Step 4: Commit**
```bash
git add apps/elos-mobile/Elos/Elos/Features/Train/Programs/SplitRecommender.swift
git commit -m "feat(split-finder): add SplitRecommender — templates and full scoring pipeline"
```

---

## Task 5: Injury Substitution Engine (`InjurySubstitutionEngine.swift`)

**Files:**
- Create: `apps/elos-mobile/Elos/Elos/Features/Train/Programs/InjurySubstitutionEngine.swift`

- [ ] **Step 1: Create the file**

```swift
import Foundation

struct InjurySubstitutionEngine {

    private struct InjuryKey: Hashable {
        let part: InjuredPart
        let severity: InjurySeverity
    }

    // nil value means remove the exercise entirely
    private static let map: [String: [InjuryKey: String?]] = [
        "Barbell Overhead Press": [
            InjuryKey(part: .shoulder, severity: .mild):     "Dumbbell Lateral Raise",
            InjuryKey(part: .shoulder, severity: .moderate): "Cable Face Pull",
            InjuryKey(part: .shoulder, severity: .avoid):    nil,
        ],
        "Dumbbell Shoulder Press": [
            InjuryKey(part: .shoulder, severity: .mild):     "Dumbbell Lateral Raise",
            InjuryKey(part: .shoulder, severity: .moderate): "Band Pull-Apart",
            InjuryKey(part: .shoulder, severity: .avoid):    nil,
        ],
        "Barbell Back Squat": [
            InjuryKey(part: .knee, severity: .mild):         "Leg Press",
            InjuryKey(part: .knee, severity: .moderate):     "Goblet Squat",
            InjuryKey(part: .knee, severity: .avoid):        nil,
        ],
        "Leg Press": [
            InjuryKey(part: .knee, severity: .moderate):     "Seated Leg Extension",
            InjuryKey(part: .knee, severity: .avoid):        nil,
        ],
        "Barbell Deadlift": [
            InjuryKey(part: .lowerBack, severity: .mild):    "Romanian Deadlift",
            InjuryKey(part: .lowerBack, severity: .moderate):"Cable Pull-Through",
            InjuryKey(part: .lowerBack, severity: .avoid):   nil,
        ],
        "Romanian Deadlift": [
            InjuryKey(part: .lowerBack, severity: .mild):    "Cable Pull-Through",
            InjuryKey(part: .lowerBack, severity: .avoid):   nil,
        ],
        "Barbell Curl": [
            InjuryKey(part: .wrist, severity: .mild):        "Hammer Curl",
            InjuryKey(part: .wrist, severity: .moderate):    "Cable Curl",
            InjuryKey(part: .wrist, severity: .avoid):       nil,
        ],
        "Dumbbell Curl": [
            InjuryKey(part: .wrist, severity: .moderate):    "Cable Curl",
            InjuryKey(part: .wrist, severity: .avoid):       nil,
        ],
        "Barbell Row": [
            InjuryKey(part: .lowerBack, severity: .mild):    "Cable Row",
            InjuryKey(part: .lowerBack, severity: .avoid):   nil,
        ],
        "Skull Crushers": [
            InjuryKey(part: .elbow, severity: .mild):        "Cable Tricep Pushdown",
            InjuryKey(part: .elbow, severity: .moderate):    "Tricep Dips (Assisted)",
            InjuryKey(part: .elbow, severity: .avoid):       nil,
        ],
        "Tricep Dips": [
            InjuryKey(part: .elbow, severity: .moderate):    "Cable Tricep Pushdown",
            InjuryKey(part: .elbow, severity: .avoid):       nil,
        ],
        "Hip Thrust": [
            InjuryKey(part: .hip, severity: .mild):          "Glute Bridge",
            InjuryKey(part: .hip, severity: .moderate):      "Glute Bridge",
            InjuryKey(part: .hip, severity: .avoid):         nil,
        ],
        "Barbell Hip Thrust": [
            InjuryKey(part: .hip, severity: .mild):          "Dumbbell Glute Bridge",
            InjuryKey(part: .hip, severity: .avoid):         nil,
        ],
        "Box Jump": [
            InjuryKey(part: .ankle, severity: .mild):        "Step-Up",
            InjuryKey(part: .ankle, severity: .avoid):       nil,
        ],
        "Jump Rope": [
            InjuryKey(part: .ankle, severity: .mild):        "Rowing Machine",
            InjuryKey(part: .ankle, severity: .avoid):       nil,
        ],
        "Calf Raise": [
            InjuryKey(part: .ankle, severity: .mild):        "Seated Calf Raise",
            InjuryKey(part: .ankle, severity: .avoid):       nil,
        ],
        "Lateral Lunge": [
            InjuryKey(part: .knee, severity: .mild):         "Sumo Squat",
            InjuryKey(part: .knee, severity: .avoid):        nil,
        ],
        "Incline Barbell Press": [
            InjuryKey(part: .shoulder, severity: .moderate): "Machine Chest Press",
            InjuryKey(part: .shoulder, severity: .avoid):    nil,
        ],
        "Incline Dumbbell Press": [
            InjuryKey(part: .shoulder, severity: .avoid):    nil,
        ],
    ]

    private static let safePool: [RecommendedExercise] = [
        RecommendedExercise(name: "Machine Chest Press", sets: 3, reps: "10–12", equipment: "Machine",    primaryMuscle: "chest"),
        RecommendedExercise(name: "Cable Fly",           sets: 3, reps: "12–15", equipment: "Machine",    primaryMuscle: "chest"),
        RecommendedExercise(name: "Lat Pulldown",        sets: 3, reps: "10–12", equipment: "Machine",    primaryMuscle: "lats"),
        RecommendedExercise(name: "Seated Cable Row",    sets: 3, reps: "10–12", equipment: "Machine",    primaryMuscle: "lats"),
        RecommendedExercise(name: "Leg Extension",       sets: 3, reps: "12–15", equipment: "Machine",    primaryMuscle: "quads"),
        RecommendedExercise(name: "Wall Sit",            sets: 3, reps: "30s",   equipment: "Bodyweight", primaryMuscle: "quads"),
        RecommendedExercise(name: "Leg Curl",            sets: 3, reps: "12–15", equipment: "Machine",    primaryMuscle: "hamstrings"),
        RecommendedExercise(name: "Cable Kickback",      sets: 3, reps: "15",    equipment: "Machine",    primaryMuscle: "glutes"),
        RecommendedExercise(name: "Band Pull-Apart",     sets: 3, reps: "20",    equipment: "Bodyweight", primaryMuscle: "rear_delts"),
        RecommendedExercise(name: "Face Pull",           sets: 3, reps: "15",    equipment: "Machine",    primaryMuscle: "rear_delts"),
        RecommendedExercise(name: "Cable Curl",          sets: 3, reps: "12",    equipment: "Machine",    primaryMuscle: "biceps"),
        RecommendedExercise(name: "Tricep Pushdown",     sets: 3, reps: "12–15", equipment: "Machine",    primaryMuscle: "triceps"),
        RecommendedExercise(name: "Plank",               sets: 3, reps: "30s",   equipment: "Bodyweight", primaryMuscle: "core"),
        RecommendedExercise(name: "Dead Bug",            sets: 3, reps: "10/side",equipment: "Bodyweight",primaryMuscle: "core"),
    ]

    /// Apply injury substitutions to a list of recommendations in place.
    static func apply(to recommendations: inout [SplitRecommendation], input: SplitFinderInput) {
        guard !input.injuries.isEmpty else { return }
        for i in recommendations.indices {
            for j in recommendations[i].days.indices {
                recommendations[i].days[j].exercises = processDay(
                    exercises: recommendations[i].days[j].exercises,
                    injuries: input.injuries,
                    minCount: WarmupLibrary.budget(sessionMinutes: input.sessionMinutes).minExercises,
                    equipment: input.equipment
                )
            }
        }
    }

    private static func processDay(
        exercises: [RecommendedExercise],
        injuries: [InjuryEntry],
        minCount: Int,
        equipment: EquipmentProfile
    ) -> [RecommendedExercise] {
        var result: [RecommendedExercise] = []
        for ex in exercises {
            if let sub = substitute(exercise: ex, injuries: injuries) {
                result.append(sub)
            }
            // nil from substitute means remove; slot left empty unless backfill needed
        }
        // Backfill if below minimum
        if result.count < minCount {
            let needed = minCount - result.count
            let existingNames = Set(result.map { $0.name })
            let candidates = safePool.filter { !existingNames.contains($0.name) }
                .sorted { equipmentScore($0, equipment: equipment) > equipmentScore($1, equipment: equipment) }
            result += candidates.prefix(needed)
        }
        return result
    }

    /// Returns nil if the exercise should be removed, the original if no substitution needed,
    /// or a new RecommendedExercise if a substitution applies.
    private static func substitute(exercise: RecommendedExercise, injuries: [InjuryEntry]) -> RecommendedExercise? {
        for injury in injuries {
            let key = InjuryKey(part: injury.part, severity: injury.severity)
            if let substitutions = map[exercise.name], let subResult = substitutions[key] {
                guard let subName = subResult else { return nil }  // nil means remove
                // Find the substitute in safePool for correct metadata, or create a basic one
                if let poolEx = safePool.first(where: { $0.name == subName }) {
                    return RecommendedExercise(name: poolEx.name, sets: exercise.sets,
                                               reps: exercise.reps, equipment: poolEx.equipment,
                                               primaryMuscle: poolEx.primaryMuscle)
                }
                return RecommendedExercise(name: subName, sets: exercise.sets,
                                           reps: exercise.reps, equipment: exercise.equipment,
                                           primaryMuscle: exercise.primaryMuscle)
            }
        }
        return exercise  // no substitution needed
    }

    private static func equipmentScore(_ ex: RecommendedExercise, equipment: EquipmentProfile) -> Double {
        switch ex.equipment {
        case "Machine":    return equipment.machineRatio
        case "Dumbbell":   return equipment.dumbbellRatio
        case "Barbell":    return equipment.barbellRatio
        case "Bodyweight": return 1.0
        default:           return 0.5
        }
    }
}
```

- [ ] **Step 2: Add to Xcode project**

- [ ] **Step 3: Build**
```bash
xcodebuild build -project apps/elos-mobile/Elos/Elos.xcodeproj -scheme Elos \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  2>&1 | grep -E "error:|BUILD SUCCEEDED|BUILD FAILED"
```

- [ ] **Step 4: Commit**
```bash
git add apps/elos-mobile/Elos/Elos/Features/Train/Programs/InjurySubstitutionEngine.swift
git commit -m "feat(split-finder): add InjurySubstitutionEngine — substitution map and safe-exercise backfill"
```

---

## Task 6: Update `AppViewModel` — pending promotion + weekday-pinned `gymDay`

**Files:**
- Modify: `apps/elos-mobile/Elos/Elos/AppViewModel.swift`

- [ ] **Step 1: Update `loadActiveSplit()` to promote pending splits first**

Replace the existing `loadActiveSplit()` function (line ~337) with:

```swift
func loadActiveSplit() {
    guard !currentUserID.isEmpty else { return }
    let uid = currentUserID

    // 1. Promote any pending splits whose scheduled start has arrived
    let pendingDesc = FetchDescriptor<UserSplitRecord>(
        predicate: #Predicate { $0.ownerID == uid && $0.isActive == false && $0.scheduledStartAt != nil }
    )
    let pending = (try? context.fetch(pendingDesc)) ?? []
    let now = Date()
    for record in pending {
        if let startAt = record.scheduledStartAt, startAt <= now {
            record.isActive = true
            record.activatedAt = Calendar.current.startOfDay(for: startAt)
            record.scheduledStartAt = nil
        }
    }
    if !pending.isEmpty { try? context.save() }

    // 2. Fetch active split
    let splitDesc = FetchDescriptor<UserSplitRecord>(
        predicate: #Predicate { $0.ownerID == uid && $0.isActive == true }
    )
    guard let split = try? context.fetch(splitDesc).first else {
        activeSplit = nil
        activeSplitDays = []
        return
    }
    activeSplit = split
    let splitID = split.id
    let daysDesc = FetchDescriptor<UserSplitDayRecord>(
        predicate: #Predicate { $0.splitID == splitID }
    )
    activeSplitDays = ((try? context.fetch(daysDesc)) ?? []).sorted { $0.orderIndex < $1.orderIndex }
}
```

- [ ] **Step 2: Update `gymDay(for:)` to handle weekday-pinned splits**

Find `gymDay(for date: Date)` (line ~512). Replace with:

```swift
func gymDay(for date: Date) -> UserSplitDayRecord? {
    guard let split = activeSplit else { return nil }

    // Weekday-pinned path (Split Finder splits)
    if let pinned = split.pinnedWeekdays {
        let weekday = Calendar.current.component(.weekday, from: date)
        // pinned[i] = weekday number for the i-th non-rest split day
        let nonRestDays = activeSplitDays.filter { !$0.isRest }
        guard let idx = pinned.firstIndex(of: weekday), idx < nonRestDays.count else {
            return nil  // rest day
        }
        return nonRestDays[idx]
    }

    // Ordinal rotation path (existing logic)
    guard let activatedAt = split.activatedAt, !activeSplitDays.isEmpty else { return nil }
    let cal = Calendar.current
    let start = cal.startOfDay(for: activatedAt)
    let target = cal.startOfDay(for: date)
    guard target >= start else { return nil }

    let fmt = DateFormatter(); fmt.dateFormat = "yyyy-MM-dd"
    let skipped = split.skippedDates
    let uid = currentUserID
    let examDesc = FetchDescriptor<ExamRecord>(predicate: #Predicate { $0.ownerID == uid })
    let examDateStrings: Set<String> = Set(((try? context.fetch(examDesc)) ?? []).map(\.dateString))

    var splitIndex = 0
    var d = start
    while d < target {
        let dStr = fmt.string(from: d)
        if !skipped.contains(dStr) {
            let dayRecord = activeSplitDays[splitIndex % activeSplitDays.count]
            if !dayRecord.isRest && examDateStrings.contains(dStr) {
                // push forward — don't consume split slot
            } else {
                splitIndex += 1
            }
        }
        d = cal.date(byAdding: .day, value: 1, to: d) ?? target
    }

    let dStr = fmt.string(from: target)
    if skipped.contains(dStr) { return nil }
    let dayRecord = activeSplitDays[splitIndex % activeSplitDays.count]
    if !dayRecord.isRest && examDateStrings.contains(dStr) { return nil }
    return dayRecord
}
```

- [ ] **Step 3: Build**
```bash
xcodebuild build -project apps/elos-mobile/Elos/Elos.xcodeproj -scheme Elos \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  2>&1 | grep -E "error:|BUILD SUCCEEDED|BUILD FAILED"
```

- [ ] **Step 4: Commit**
```bash
git add apps/elos-mobile/Elos/Elos/AppViewModel.swift
git commit -m "feat(split-finder): update loadActiveSplit() and gymDay() for pending activation and weekday-pinned mode"
```

---

## Task 7: `SplitFinderViewModel`

**Files:**
- Create: `apps/elos-mobile/Elos/Elos/Features/Train/Programs/SplitFinderViewModel.swift`

- [ ] **Step 1: Create the file**

```swift
import SwiftUI

@MainActor
final class SplitFinderViewModel: ObservableObject {

    // MARK: - Survey state
    @Published var currentStep: Int = 1
    @Published var input = SplitFinderInput()

    // Equipment slider raw values (0–100 each, normalized on commit)
    @Published var machineSlider: Double  = 33
    @Published var dumbbellSlider: Double = 34
    @Published var barbellSlider: Double  = 33

    // Sport step
    @Published var hasSport: Bool = false
    @Published var sportFocusStep: Int = 0   // 0–4 maps to 0.0/0.25/0.5/0.75/1.0
    private let focusStepValues: [Double] = [0.0, 0.25, 0.5, 0.75, 1.0]
    private let focusStepLabels: [String] = ["Hobby", "Enthusiast", "Competitive", "Semi-Pro", "Elite"]

    var sportFocusLabel: String { focusStepLabels[sportFocusStep] }

    // Injury step
    @Published var hasInjuries: Bool = false
    @Published var selectedInjuries: [InjuredPart: InjurySeverity] = [:]

    var injuryEntries: [InjuryEntry] {
        selectedInjuries.map { InjuryEntry(part: $0.key, severity: $0.value) }
    }

    // Warmup step
    @Published var hasWarmups: Bool = false

    // MARK: - Results
    @Published var recommendations: [SplitRecommendation] = []
    @Published var isComputing: Bool = false

    // MARK: - Navigation
    let totalSteps = 8

    var canGoNext: Bool {
        switch currentStep {
        case 6: return !hasSport || input.sport != nil
        default: return true
        }
    }

    func next() {
        commitCurrentStep()
        if currentStep == totalSteps {
            computeRecommendations()
        } else {
            currentStep += 1
        }
    }

    func back() {
        guard currentStep > 1 else { return }
        currentStep -= 1
    }

    // MARK: - Step commit (normalize equipment on step 4 exit)

    private func commitCurrentStep() {
        if currentStep == 4 {
            normalizeEquipment()
        }
        if currentStep == 6 {
            input.sport = hasSport ? input.sport : nil
            input.sportFocusRatio = hasSport ? focusStepValues[sportFocusStep] : 0.0
        }
        if currentStep == 7 {
            input.injuries = hasInjuries ? injuryEntries : []
        }
        if currentStep == 8 {
            input.includeWarmups = hasWarmups
            input.warmupStyle = hasWarmups ? input.warmupStyle : nil
        }
    }

    func normalizeEquipment() {
        let sum = machineSlider + dumbbellSlider + barbellSlider
        if sum == 0 {
            machineSlider = 33; dumbbellSlider = 34; barbellSlider = 33
        } else {
            machineSlider   = (machineSlider  / sum) * 100
            dumbbellSlider  = (dumbbellSlider / sum) * 100
            barbellSlider   = (barbellSlider  / sum) * 100
        }
        input.equipment = EquipmentProfile(
            machineRatio:  machineSlider  / 100,
            dumbbellRatio: dumbbellSlider / 100,
            barbellRatio:  barbellSlider  / 100
        )
    }

    // MARK: - Compute recommendations

    func computeRecommendations() {
        isComputing = true
        var recs = SplitRecommender.recommend(input: input)
        InjurySubstitutionEngine.apply(to: &recs, input: input)
        recommendations = recs
        isComputing = false
        currentStep = totalSteps + 1  // sentinel: show results screen
    }

    var showResults: Bool { currentStep > totalSteps }

    func reset() {
        currentStep     = 1
        input           = SplitFinderInput()
        machineSlider   = 33
        dumbbellSlider  = 34
        barbellSlider   = 33
        hasSport        = false
        sportFocusStep  = 0
        hasInjuries     = false
        selectedInjuries = [:]
        hasWarmups      = false
        recommendations = []
    }
}
```

- [ ] **Step 2: Add to Xcode project**

- [ ] **Step 3: Build**
```bash
xcodebuild build -project apps/elos-mobile/Elos/Elos.xcodeproj -scheme Elos \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  2>&1 | grep -E "error:|BUILD SUCCEEDED|BUILD FAILED"
```

- [ ] **Step 4: Commit**
```bash
git add apps/elos-mobile/Elos/Elos/Features/Train/Programs/SplitFinderViewModel.swift
git commit -m "feat(split-finder): add SplitFinderViewModel — survey state and recommendation orchestration"
```

---

## Task 8: `SplitFinderView` — 8-step survey UI

**Files:**
- Create: `apps/elos-mobile/Elos/Elos/Features/Train/Programs/SplitFinderView.swift`

- [ ] **Step 1: Create the file**

```swift
import SwiftUI

struct SplitFinderView: View {
    let dismissAll: () -> Void

    @StateObject private var vm = SplitFinderViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                if vm.showResults {
                    SplitFinderResultsView(
                        recommendations: vm.recommendations,
                        input: vm.input,
                        dismissAll: dismissAll
                    )
                    .transition(.move(edge: .trailing).combined(with: .opacity))
                } else {
                    surveyContent
                        .transition(.move(edge: .leading).combined(with: .opacity))
                }
            }
            .animation(.easeInOut(duration: 0.3), value: vm.showResults)
            .navigationTitle("Split Finder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismissAll() }
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: Survey wrapper

    private var surveyContent: some View {
        VStack(spacing: 0) {
            progressBar
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    stepContent
                        .padding(.horizontal, 20)
                        .padding(.top, 24)
                }
                .padding(.bottom, 120)
            }
            navButtons
        }
    }

    private var progressBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Rectangle().fill(Color.secondary.opacity(0.15)).frame(height: 3)
                Rectangle().fill(Color.tint)
                    .frame(width: geo.size.width * CGFloat(vm.currentStep) / CGFloat(vm.totalSteps), height: 3)
                    .animation(.easeInOut(duration: 0.25), value: vm.currentStep)
            }
        }
        .frame(height: 3)
    }

    private var navButtons: some View {
        HStack(spacing: 12) {
            if vm.currentStep > 1 {
                Button(action: { withAnimation { vm.back() } }) {
                    Text("Back")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.primary)
                        .frame(maxWidth: .infinity).frame(height: 50)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
            }
            Button(action: { withAnimation { vm.next() } }) {
                Text(vm.currentStep == vm.totalSteps ? "Find My Split" : "Next")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity).frame(height: 50)
                    .background(vm.canGoNext ? Color.tint : Color.secondary)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
            .disabled(!vm.canGoNext)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 32)
        .background(Color(.systemBackground).ignoresSafeArea(edges: .bottom))
    }

    // MARK: Step routing

    @ViewBuilder
    private var stepContent: some View {
        switch vm.currentStep {
        case 1: step1_goal
        case 2: step2_days
        case 3: step3_session
        case 4: step4_equipment
        case 5: step5_gym
        case 6: step6_sport
        case 7: step7_injuries
        case 8: step8_warmups
        default: EmptyView()
        }
    }

    // MARK: Step 1 — Goal

    private var step1_goal: some View {
        VStack(alignment: .leading, spacing: 16) {
            stepHeader("What's your primary goal?", subtitle: "This shapes every part of your split.")
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(TrainingGoal.allCases, id: \.self) { goal in
                    GoalCard(goal: goal, isSelected: vm.input.goal == goal) {
                        vm.input.goal = goal
                    }
                }
            }
        }
    }

    // MARK: Step 2 — Days/week

    private var step2_days: some View {
        VStack(alignment: .leading, spacing: 20) {
            stepHeader("How many days a week can you train?",
                       subtitle: "Be realistic — consistency beats ambition.")
            Picker("Days", selection: $vm.input.daysPerWeek) {
                ForEach([2, 3, 4, 5, 6], id: \.self) { d in
                    Text("\(d)").tag(d)
                }
            }
            .pickerStyle(.segmented)
            Text("\(vm.input.daysPerWeek) days/week")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    // MARK: Step 3 — Session length

    private var step3_session: some View {
        let steps = [30, 45, 60, 75, 90]
        let idx = steps.firstIndex(of: vm.input.sessionMinutes) ?? 2
        return VStack(alignment: .leading, spacing: 20) {
            stepHeader("How long is your ideal session?",
                       subtitle: "Including warmup time if enabled.")
            VStack(spacing: 8) {
                Slider(
                    value: Binding(
                        get: { Double(idx) },
                        set: { vm.input.sessionMinutes = steps[Int($0.rounded())] }
                    ),
                    in: 0...Double(steps.count - 1), step: 1
                )
                .tint(Color.tint)
                HStack {
                    ForEach(steps, id: \.self) { m in
                        Text("\(m)m")
                            .font(.caption2)
                            .foregroundStyle(vm.input.sessionMinutes == m ? Color.tint : .secondary)
                            .frame(maxWidth: .infinity)
                    }
                }
            }
            Text("~\(vm.input.sessionMinutes) minutes per session")
                .font(.subheadline).fontWeight(.semibold).foregroundStyle(Color.tint)
        }
    }

    // MARK: Step 4 — Equipment

    private var step4_equipment: some View {
        VStack(alignment: .leading, spacing: 20) {
            stepHeader("What equipment do you prefer?",
                       subtitle: "Drag each slider to set your preference. They auto-balance to 100%.")
            equipmentSlider(label: "Machine",   value: $vm.machineSlider,   color: .blue)
            equipmentSlider(label: "Dumbbell",  value: $vm.dumbbellSlider,  color: .purple)
            equipmentSlider(label: "Barbell",   value: $vm.barbellSlider,   color: Color.tint)
            Text("Tip: Most gyms work best with a mix of all three.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private func equipmentSlider(label: String, value: Binding<Double>, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(label).font(.subheadline).fontWeight(.semibold)
                Spacer()
                Text("\(Int(value.wrappedValue.rounded()))%")
                    .font(.system(size: 14, design: .monospaced)).foregroundStyle(color)
            }
            Slider(value: value, in: 0...100, step: 1)
                .tint(color)
                .simultaneousGesture(DragGesture(minimumDistance: 0).onEnded { _ in
                    vm.normalizeEquipment()
                })
        }
    }

    // MARK: Step 5 — Gym size

    private var step5_gym: some View {
        VStack(alignment: .leading, spacing: 16) {
            stepHeader("What type of gym do you use?",
                       subtitle: "This helps match equipment availability.")
            HStack(spacing: 12) {
                ForEach(GymSize.allCases, id: \.self) { size in
                    SelectionCard(
                        icon: size.icon, label: size.displayName,
                        isSelected: vm.input.gymSize == size
                    ) { vm.input.gymSize = size }
                }
            }
        }
    }

    // MARK: Step 6 — Sport

    private var step6_sport: some View {
        VStack(alignment: .leading, spacing: 16) {
            stepHeader("Are you training for a sport?",
                       subtitle: "Helps bias toward functional movements.")
            Toggle("Yes, I train for a sport", isOn: $vm.hasSport)
                .toggleStyle(SwitchToggleStyle(tint: Color.tint))

            if vm.hasSport {
                sportGrid
                Divider()
                focusPicker
            }
        }
    }

    private var sportGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 10) {
            ForEach(Sport.allCases, id: \.self) { sport in
                Button {
                    vm.input.sport = sport
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: sport.icon)
                            .font(.system(size: 20))
                            .foregroundStyle(vm.input.sport == sport ? .white : Color.tint)
                        Text(sport.displayName)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(vm.input.sport == sport ? .white : .primary)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                    }
                    .frame(maxWidth: .infinity).padding(.vertical, 10)
                    .background(vm.input.sport == sport ? Color.tint : Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var focusPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Training focus")
                .font(.subheadline).fontWeight(.semibold)
            Picker("Focus", selection: $vm.sportFocusStep) {
                ForEach(0..<5, id: \.self) { i in
                    Text(["Hobby","Enthusiast","Competitive","Semi-Pro","Elite"][i]).tag(i)
                }
            }
            .pickerStyle(.segmented)
            Text(vm.sportFocusLabel)
                .font(.caption).foregroundStyle(Color.tint)
        }
    }

    // MARK: Step 7 — Injuries

    private var step7_injuries: some View {
        VStack(alignment: .leading, spacing: 16) {
            stepHeader("Any injuries we should work around?",
                       subtitle: "We'll substitute or remove exercises that stress injured areas.")
            Toggle("Yes, I have injuries", isOn: $vm.hasInjuries)
                .toggleStyle(SwitchToggleStyle(tint: Color.tint))

            if vm.hasInjuries {
                ForEach(InjuredPart.allCases, id: \.self) { part in
                    injuryRow(part: part)
                }
            }
        }
    }

    private func injuryRow(part: InjuredPart) -> some View {
        let isSelected = vm.selectedInjuries[part] != nil
        return VStack(spacing: 8) {
            HStack {
                Button {
                    if isSelected {
                        vm.selectedInjuries.removeValue(forKey: part)
                    } else {
                        vm.selectedInjuries[part] = .mild
                    }
                } label: {
                    HStack {
                        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(isSelected ? Color.tint : .secondary)
                        Text(part.displayName).font(.subheadline)
                        Spacer()
                    }
                }
                .buttonStyle(.plain)
            }
            if isSelected {
                Picker("Severity", selection: Binding(
                    get: { vm.selectedInjuries[part] ?? .mild },
                    set: { vm.selectedInjuries[part] = $0 }
                )) {
                    ForEach(InjurySeverity.allCases, id: \.self) { s in
                        Text(s.displayName).tag(s)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.leading, 28)
            }
        }
        .padding(12)
        .background(isSelected ? Color.tintSoft : Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: Step 8 — Warmups

    private var step8_warmups: some View {
        VStack(alignment: .leading, spacing: 16) {
            stepHeader("Do you want warmups included?",
                       subtitle: "Time is reserved from your session budget for warm-up exercises.")
            Toggle("Include warmups", isOn: $vm.hasWarmups)
                .toggleStyle(SwitchToggleStyle(tint: Color.tint))

            if vm.hasWarmups {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    ForEach(WarmupStyle.allCases, id: \.self) { style in
                        SelectionCard(
                            icon: style == .dynamic ? "figure.run" : (style == .staticStretch ? "figure.flexibility" : "arrow.triangle.2.circlepath"),
                            label: style.displayName,
                            isSelected: vm.input.warmupStyle == style
                        ) { vm.input.warmupStyle = style }
                    }
                }
            }
        }
    }

    // MARK: Shared helpers

    private func stepHeader(_ title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Step \(vm.currentStep) of \(vm.totalSteps)")
                .font(.caption).foregroundStyle(.secondary).fontWeight(.semibold)
            Text(title).font(.system(size: 22, weight: .bold))
            Text(subtitle).font(.subheadline).foregroundStyle(.secondary)
        }
    }
}

// MARK: - Subviews

private struct GoalCard: View {
    let goal: TrainingGoal
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 10) {
                Image(systemName: goal.icon)
                    .font(.system(size: 28))
                    .foregroundStyle(isSelected ? .white : Color.tint)
                Text(goal.displayName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(isSelected ? .white : .primary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity).padding(.vertical, 20)
            .background(isSelected ? Color.tint : Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }
}

private struct SelectionCard: View {
    let icon: String
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundStyle(isSelected ? .white : Color.tint)
                Text(label)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(isSelected ? .white : .primary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity).padding(.vertical, 16)
            .background(isSelected ? Color.tint : Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}
```

- [ ] **Step 2: Add to Xcode project**

- [ ] **Step 3: Build**
```bash
xcodebuild build -project apps/elos-mobile/Elos/Elos.xcodeproj -scheme Elos \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  2>&1 | grep -E "error:|BUILD SUCCEEDED|BUILD FAILED"
```

- [ ] **Step 4: Commit**
```bash
git add apps/elos-mobile/Elos/Elos/Features/Train/Programs/SplitFinderView.swift
git commit -m "feat(split-finder): add SplitFinderView — 8-step survey UI"
```

---

## Task 9: `SplitFinderResultsView`

**Files:**
- Create: `apps/elos-mobile/Elos/Elos/Features/Train/Programs/SplitFinderResultsView.swift`

- [ ] **Step 1: Create the file**

```swift
import SwiftUI

struct SplitFinderResultsView: View {
    let recommendations: [SplitRecommendation]
    let input: SplitFinderInput
    let dismissAll: () -> Void

    @State private var selectedRec: SplitRecommendation?
    @State private var showSubscribe = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Your Splits")
                        .font(.system(size: 28, weight: .bold))
                    Text("Personalised to your answers. Tap a split to subscribe.")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)

                ForEach(recommendations) { rec in
                    RecommendationCard(rec: rec) {
                        selectedRec = rec
                        showSubscribe = true
                    }
                    .padding(.horizontal, 20)
                }
                Spacer(minLength: 40)
            }
        }
        .sheet(isPresented: $showSubscribe) {
            if let rec = selectedRec {
                SplitSubscribeSheet(
                    recommendation: rec,
                    daysPerWeek: input.daysPerWeek,
                    dismissAll: dismissAll
                )
            }
        }
    }
}

// MARK: - Recommendation Card

private struct RecommendationCard: View {
    let rec: SplitRecommendation
    let onSubscribe: () -> Void

    @State private var expanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(rec.name)
                        .font(.system(size: 20, weight: .bold))
                    Text(rec.style.displayName)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.tint)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(Color.tintSoft)
                        .clipShape(Capsule())
                }
                Spacer()
            }

            // Stats row
            HStack(spacing: 16) {
                Label("\(rec.days.filter { !$0.isRest }.count) days/wk", systemImage: "calendar")
                Label("~\(rec.estimatedMinutes) min", systemImage: "clock")
                if !rec.days.flatMap({ $0.warmupBlock }).isEmpty {
                    Label("Warmup", systemImage: "flame.fill")
                        .foregroundStyle(.orange)
                }
            }
            .font(.caption).foregroundStyle(.secondary)

            // Match tags
            if !rec.matchTags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(rec.matchTags, id: \.self) { tag in
                            Text(tag)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(Color.good)
                                .padding(.horizontal, 8).padding(.vertical, 4)
                                .background(Color.good.opacity(0.12))
                                .clipShape(Capsule())
                        }
                    }
                }
            }

            // Collapsible schedule
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { expanded.toggle() }
            } label: {
                HStack {
                    Text("See Schedule")
                        .font(.subheadline).fontWeight(.semibold)
                        .foregroundStyle(Color.tint)
                    Spacer()
                    Image(systemName: expanded ? "chevron.up" : "chevron.down")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)

            if expanded {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(rec.days) { day in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: day.isRest ? "moon.fill" : "dumbbell.fill")
                                .font(.caption)
                                .foregroundStyle(day.isRest ? Color.secondary : Color.tint)
                                .frame(width: 16)
                            if day.isRest {
                                Text("Rest").font(.caption).foregroundStyle(.secondary)
                            } else {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(day.label).font(.caption).fontWeight(.semibold)
                                    let preview = day.exercises.prefix(3).map { $0.name }.joined(separator: ", ")
                                    Text(preview).font(.caption2).foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
                .padding(10)
                .background(Color(.tertiarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            // Subscribe button
            Button(action: onSubscribe) {
                Text("Use This Split")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity).frame(height: 46)
                    .background(Color.tint)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}
```

- [ ] **Step 2: Add to Xcode project**

- [ ] **Step 3: Build**
```bash
xcodebuild build -project apps/elos-mobile/Elos/Elos.xcodeproj -scheme Elos \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  2>&1 | grep -E "error:|BUILD SUCCEEDED|BUILD FAILED"
```

- [ ] **Step 4: Commit**
```bash
git add apps/elos-mobile/Elos/Elos/Features/Train/Programs/SplitFinderResultsView.swift
git commit -m "feat(split-finder): add SplitFinderResultsView — recommendation cards and schedule preview"
```

---

## Task 10: `SplitSubscribeSheet`

**Files:**
- Create: `apps/elos-mobile/Elos/Elos/Features/Train/Programs/SplitSubscribeSheet.swift`

- [ ] **Step 1: Create the file**

```swift
import SwiftUI
import SwiftData

struct SplitSubscribeSheet: View {
    let recommendation: SplitRecommendation
    let daysPerWeek: Int
    let dismissAll: () -> Void

    @EnvironmentObject var vm: AppViewModel
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var conflictResolution: ConflictResolution? = nil
    @State private var selectedWeekdays: Set<Int> = []  // Calendar weekday numbers
    @State private var isSaving = false
    @State private var showConflictSheet = false

    private enum ConflictResolution { case now, nextMonday }

    // Calendar weekday numbers: 1=Sun, 2=Mon, 3=Tue, 4=Wed, 5=Thu, 6=Fri, 7=Sat
    private let weekdays: [(label: String, value: Int)] = [
        ("Mon", 2), ("Tue", 3), ("Wed", 4), ("Thu", 5), ("Fri", 6), ("Sat", 7), ("Sun", 1)
    ]

    private var defaultWeekdays: Set<Int> {
        switch daysPerWeek {
        case 2:  return [2, 5]
        case 3:  return [2, 4, 6]
        case 4:  return [2, 3, 5, 6]
        case 5:  return [2, 3, 4, 6, 7]
        case 6:  return [2, 3, 4, 5, 6, 7]
        default: return [2, 4, 6]
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Conflict resolution
                    if vm.activeSplit != nil, conflictResolution == nil {
                        conflictSection
                    } else {
                        dayAssignmentSection
                        confirmSection
                    }
                }
                .padding(20)
                .padding(.bottom, 40)
            }
            .navigationTitle("Subscribe")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(.secondary)
                }
            }
        }
        .onAppear {
            selectedWeekdays = defaultWeekdays
            // If no active split, skip conflict step
            if vm.activeSplit == nil { conflictResolution = .now }
        }
    }

    // MARK: Conflict section

    private var conflictSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("You already have an active split")
                .font(.system(size: 22, weight: .bold))
            if let name = vm.activeSplit?.name {
                Text("Currently on: \(name)")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            VStack(spacing: 10) {
                conflictButton("Switch Now", subtitle: "Activate \(recommendation.name) immediately", systemImage: "bolt.fill") {
                    conflictResolution = .now
                }
                conflictButton("Start Next Monday", subtitle: "\(recommendation.name) activates on the next Monday", systemImage: "calendar.badge.clock") {
                    conflictResolution = .nextMonday
                }
            }
        }
    }

    private func conflictButton(_ title: String, subtitle: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: systemImage)
                    .font(.title3).foregroundStyle(Color.tint)
                    .frame(width: 30)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.subheadline).fontWeight(.semibold)
                    Text(subtitle).font(.caption).foregroundStyle(.secondary)
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

    // MARK: Day assignment

    private var dayAssignmentSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Choose Your Training Days")
                    .font(.system(size: 22, weight: .bold))
                Text("Tap days to toggle. Minimum 2 training days.")
                    .font(.subheadline).foregroundStyle(.secondary)
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 8) {
                ForEach(weekdays, id: \.value) { day in
                    Button {
                        if selectedWeekdays.contains(day.value) {
                            if selectedWeekdays.count > 2 { selectedWeekdays.remove(day.value) }
                        } else {
                            selectedWeekdays.insert(day.value)
                        }
                    } label: {
                        VStack(spacing: 4) {
                            Text(day.label)
                                .font(.system(size: 11, weight: .semibold))
                            if selectedWeekdays.contains(day.value) {
                                Image(systemName: "dumbbell.fill")
                                    .font(.system(size: 12))
                                    .foregroundStyle(.white)
                            } else {
                                Image(systemName: "moon.fill")
                                    .font(.system(size: 12))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity).padding(.vertical, 10)
                        .foregroundStyle(selectedWeekdays.contains(day.value) ? .white : .primary)
                        .background(selectedWeekdays.contains(day.value) ? Color.tint : Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: Confirm

    private var confirmSection: some View {
        Button {
            Task { await saveAndDismiss() }
        } label: {
            Group {
                if isSaving {
                    ProgressView().tint(.white)
                } else {
                    Text("Start \(recommendation.name)")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
            .frame(maxWidth: .infinity).frame(height: 52)
            .background(selectedWeekdays.count >= 2 ? Color.tint : Color.secondary)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .disabled(selectedWeekdays.count < 2 || isSaving)
    }

    // MARK: Save logic

    private func saveAndDismiss() async {
        isSaving = true
        let ownerID = vm.currentUserID
        guard !ownerID.isEmpty else { isSaving = false; return }

        let isNow = conflictResolution == .now
        let startAt: Date? = isNow ? nil : nextMonday()

        // Deactivate current split if switching now
        if isNow, let current = vm.activeSplit {
            current.isActive = false
        }

        // Build pinnedWeekdays ordered array: sort by weekday order (Mon first in user's view)
        let sortedPinned = weekdays.filter { selectedWeekdays.contains($0.value) }.map { $0.value }

        // Create the split record
        let splitRecord = UserSplitRecord(
            ownerID: ownerID,
            name: recommendation.name,
            isActive: isNow,
            activatedAt: isNow ? Date() : nil,
            libraryKey: "",
            syncPending: true
        )
        splitRecord.scheduledStartAt   = startAt
        splitRecord.pinnedWeekdays     = sortedPinned
        modelContext.insert(splitRecord)

        // Create day records for non-rest days only
        let nonRestDays = recommendation.days.filter { !$0.isRest }
        for (idx, day) in nonRestDays.enumerated() {
            let exercisesJSON = (try? String(data: JSONEncoder().encode(
                day.exercises.map { DayExercise(id: UUID().uuidString, name: $0.name) }
            ), encoding: .utf8)) ?? "[]"

            let dayRecord = UserSplitDayRecord(
                splitID: splitRecord.id,
                orderIndex: idx,
                dayLabel: day.label,
                dayName: day.label,
                isRest: false,
                exercisesJSON: exercisesJSON
            )
            modelContext.insert(dayRecord)
        }

        try? modelContext.save()
        vm.loadActiveSplit()

        // Background API sync
        Task.detached { [splitRecord] in
            await vm.pushSplitToServer(splitRecord)
        }

        isSaving = false
        dismissAll()
    }

    private func nextMonday() -> Date {
        var cal = Calendar.current
        cal.firstWeekday = 2  // Monday
        let today = cal.startOfDay(for: Date())
        var comps = DateComponents(); comps.weekday = 2; comps.weekdayOrdinal = 1
        return cal.nextDate(after: today, matching: DateComponents(weekday: 2), matchingPolicy: .nextTime) ?? today
    }
}
```

**Note:** `pushSplitToServer` is `private` on `AppViewModel` — change it to `internal` (remove `private`) in `AppViewModel.swift` at line ~594.

- [ ] **Step 2: Make `pushSplitToServer` accessible — remove `private` from its declaration in `AppViewModel.swift`**

Find `private func pushSplitToServer` and change to `func pushSplitToServer`.

- [ ] **Step 3: Add `SplitSubscribeSheet.swift` to Xcode project**

- [ ] **Step 4: Build**
```bash
xcodebuild build -project apps/elos-mobile/Elos/Elos.xcodeproj -scheme Elos \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  2>&1 | grep -E "error:|BUILD SUCCEEDED|BUILD FAILED"
```

- [ ] **Step 5: Commit**
```bash
git add apps/elos-mobile/Elos/Elos/Features/Train/Programs/SplitSubscribeSheet.swift \
        apps/elos-mobile/Elos/Elos/AppViewModel.swift
git commit -m "feat(split-finder): add SplitSubscribeSheet — conflict resolution, day assignment, and subscribe"
```

---

## Task 11: Wire up entry point in `TrainView`

**Files:**
- Modify: `apps/elos-mobile/Elos/Elos/Views/TrainView.swift`

- [ ] **Step 1: Add `showSplitFinder` state variable**

Inside `struct TrainView: View`, after the existing `@State private var showCrew = false` line (line ~32), add:

```swift
@State private var showSplitFinder = false
```

- [ ] **Step 2: Add toolbar button**

In the `toolbar` block (line ~62), add a third button to the `HStack(spacing: 16)`:

```swift
Button { showSplitFinder = true } label: {
    Image(systemName: "wand.and.stars")
        .foregroundStyle(Color.tint)
}
```

- [ ] **Step 3: Add sheet**

After the existing `.sheet(isPresented: $showHistory)` line (~line 89), add:

```swift
.sheet(isPresented: $showSplitFinder) {
    SplitFinderView(dismissAll: { showSplitFinder = false })
}
```

- [ ] **Step 4: Build**
```bash
xcodebuild build -project apps/elos-mobile/Elos/Elos.xcodeproj -scheme Elos \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  2>&1 | grep -E "error:|BUILD SUCCEEDED|BUILD FAILED"
```

- [ ] **Step 5: Final commit**
```bash
git add apps/elos-mobile/Elos/Elos/Views/TrainView.swift
git commit -m "feat(split-finder): wire up wand toolbar button and sheet in TrainView"
```

---

## Manual Test Checklist

Run in iPhone 17 Pro simulator after all tasks complete.

- [ ] Wand icon appears in TrainView top-right toolbar
- [ ] Tapping wand opens Split Finder sheet
- [ ] Progress bar advances with each "Next" tap
- [ ] "Back" preserves all answers
- [ ] Equipment sliders normalize on release (sum stays ~100%)
- [ ] Step 6 sport grid only shows when toggle is on
- [ ] Step 7 injury severity picker appears per selected body part
- [ ] "Find My Split" triggers recommendation, transitions to results screen
- [ ] 1–3 recommendation cards appear
- [ ] "See Schedule" collapses/expands with exercise names
- [ ] "Use This Split" opens subscribe sheet
- [ ] If active split exists: conflict sheet appears first
- [ ] Day assignment grid pre-populates per daysPerWeek
- [ ] Cannot confirm with fewer than 2 days selected
- [ ] After confirm: TrainView shows new active split name in header
- [ ] Cancel at any point dismisses the whole sheet stack
