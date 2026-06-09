# Smart Exercise Sort & Intelligent Split Builder — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the exercise picker's alphabetical sort with a context-aware "Smart Sort" that knows which split day is being built, and add coverage guidance, equipment filtering, best-practice ordering, starter scaffolds, and weekly balance analysis on top of it.

**Architecture:** All ranking/guidance logic lives in small, pure, value-type engines under `Features/Train/Programs/Intelligence/`, each unit-tested in isolation with Swift Testing. `ExercisePickerView` and `CreateSplitView` become thin consumers that build value-type inputs and render ranked output. No backend contract changes.

**Tech Stack:** Swift 5.9+, SwiftUI, SwiftData, Swift Testing (`import Testing`). Xcode 16 file-system-synchronized groups. iOS 26 SDK.

Spec: `docs/superpowers/specs/2026-06-09-smart-exercise-sort-design.md`

---

## Conventions (read once before starting)

**Adding files — no pbxproj edits.** The Xcode project uses `PBXFileSystemSynchronizedRootGroup`. Any `.swift` file you create under `apps/elos-mobile/Elos/Elos/…` is automatically compiled into the `Elos` app target; any file under `apps/elos-mobile/Elos/ElosTests/…` is automatically part of the `ElosTests` unit-test bundle. Just create the file on disk — do **not** touch `Elos.xcodeproj/project.pbxproj`.

**Engines are `internal`** (default access). Tests reach them via `@testable import Elos`. Do not mark engine types `private`.

**Test framework is Swift Testing**, matching `ElosTests/ElosTests.swift`:
```swift
import Testing
import Foundation
@testable import Elos

struct SomethingTests {
    @Test func doesThing() {
        #expect(actual == expected)
    }
}
```

**Running tests.** From the repo root, the canonical command (replace `<Suite>` with the test struct name):
```bash
xcodebuild test \
  -project apps/elos-mobile/Elos/Elos.xcodeproj \
  -scheme Elos \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:ElosTests/<Suite> \
  2>&1 | tail -40
```
A full run drops the `-only-testing:` line. If the simulator name differs, pick one from `xcrun simctl list devices available | grep iPhone`.

**Commit cadence:** one commit per task (after its tests pass). Branch is already `feat/core-functionality-hardening`; stay on it. Commit message footer:
```
Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
```
Only `git add` the files the task created/changed — the working tree has unrelated in-progress changes; never `git add -A`.

**DRY/YAGNI/TDD:** write the failing test first, minimal code to pass, commit. Do not build Phase N+1 types in Phase N.

---

## File structure

**New engine files** (`apps/elos-mobile/Elos/Elos/Features/Train/Programs/Intelligence/`):

| File | Responsibility | Phase |
|------|----------------|-------|
| `ExerciseCandidate.swift` | Shared value type the engines rank over; maps from `ExerciseDefinitionRecord` and VM responses | 1 |
| `MuscleTaxonomy.swift` | Muscle→group, compound classification, antagonists, archetype maps, day-name aliasing | 1 |
| `ExerciseSearch.swift` | Extracted search normalize/tokens/score (moved out of `ExercisePickerView`) | 1 |
| `DayContext.swift` | `DayContext` value type + `DayContextInferrer` | 1 |
| `PersonalizationProvider.swift` | favorite + recency + frequency → 0…1 score | 1 |
| `ExerciseRankingEngine.swift` | Smart Sort composite scoring + sort modes | 1 |
| `SetRepDefaults.swift` | movementPattern → default sets/reps | 1 |
| `EquipmentPreference.swift` | posture enum + `isAvailable(equipment:)` | 2 |
| `MuscleCoverage.swift` | coverage chips for the live strip | 2 |
| `ExerciseOrderer.swift` | order a day compounds → isolation | 2 |
| `SplitScaffolds.swift` | archetype → recommended `[DayExercise]` | 3 |
| `WeeklyBalanceAnalyzer.swift` | push/pull balance + weekly volume landmarks | 3 |
| `GuidanceLevel.swift` | trainingExperience → guidance verbosity | 3 |

**New test files** (`apps/elos-mobile/Elos/ElosTests/Intelligence/`): one `<Engine>Tests.swift` per engine.

**Modified files:**
- `Elos/Features/Train/ExercisePicker/ExercisePickerView.swift` — consume `ExerciseSearch`; add sort control; rank via engine; accept an optional `DayContext`; coverage strip (Phase 2).
- `Elos/Features/Train/Programs/CreateSplitView.swift` — pass `DayContext` into picker; apply `SetRepDefaults`; drag-reorder + "Sort exercises" (Phase 2); auto-fill + balance banner (Phase 3).
- `Elos/SwiftData/ElosSchema.swift` — add `equipmentPreferenceJSON` to `UserProfileRecord` (Phase 2).
- `Elos/Features/.../ProfileEditView.swift` — equipment posture picker (Phase 2).

---

## Task 0: Verify the test harness

**Files:** none (setup only)

- [ ] **Step 1: Ensure the `Elos` scheme exists and is shared.** Run:
```bash
xcodebuild -list -project apps/elos-mobile/Elos/Elos.xcodeproj
```
Expected: a `Schemes:` list containing `Elos`. If it is missing, open the project in Xcode once (it auto-generates schemes), then Product ▸ Scheme ▸ Manage Schemes ▸ tick **Shared** for `Elos`, and re-run the list command.

- [ ] **Step 2: Run the existing test suite to confirm a green baseline.**
```bash
xcodebuild test -project apps/elos-mobile/Elos/Elos.xcodeproj -scheme Elos \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:ElosTests/FormattersTests 2>&1 | tail -20
```
Expected: `** TEST SUCCEEDED **`. If the simulator name is unavailable, substitute an available one. Do not proceed until this passes — it proves the command and the toolchain work.

---

# Phase 1 — Smart Sort core

## Task 1: `ExerciseCandidate` shared value type

**Files:**
- Create: `apps/elos-mobile/Elos/Elos/Features/Train/Programs/Intelligence/ExerciseCandidate.swift`
- Test: `apps/elos-mobile/Elos/ElosTests/Intelligence/ExerciseCandidateTests.swift`

- [ ] **Step 1: Write the failing test**
```swift
import Testing
import Foundation
@testable import Elos

struct ExerciseCandidateTests {
    @Test func mapsFromDefinitionRecord() {
        let rec = ExerciseDefinitionRecord(
            id: "x1", name: "Barbell Bench Press", primaryMuscle: "chest",
            secondaryMusclesJSON: "[\"triceps\",\"front_delts\"]",
            equipment: "barbell", movementPattern: "push", isCustom: false)
        let c = ExerciseCandidate(record: rec)
        #expect(c.id == "x1")
        #expect(c.name == "Barbell Bench Press")
        #expect(c.primaryMuscle == "chest")
        #expect(c.secondaryMuscles == ["triceps", "front_delts"])
        #expect(c.equipment == "barbell")
        #expect(c.movementPattern == "push")
    }
}
```

- [ ] **Step 2: Run test, verify it fails** (`-only-testing:ElosTests/ExerciseCandidateTests`). Expected: compile failure (`ExerciseCandidate` undefined).

- [ ] **Step 3: Implement**
```swift
import Foundation

/// The unit the ranking/guidance engines operate on. Both `ExerciseDefinitionRecord`
/// and the picker's server responses map into this so engines never touch SwiftData or the network.
struct ExerciseCandidate: Hashable, Identifiable {
    let id: String
    let name: String
    let primaryMuscle: String
    let secondaryMuscles: [String]
    let equipment: String
    let movementPattern: String
    let isCustom: Bool

    init(id: String, name: String, primaryMuscle: String, secondaryMuscles: [String],
         equipment: String, movementPattern: String, isCustom: Bool) {
        self.id = id; self.name = name; self.primaryMuscle = primaryMuscle
        self.secondaryMuscles = secondaryMuscles; self.equipment = equipment
        self.movementPattern = movementPattern; self.isCustom = isCustom
    }

    init(record r: ExerciseDefinitionRecord) {
        self.init(id: r.id, name: r.name, primaryMuscle: r.primaryMuscle,
                  secondaryMuscles: r.secondaryMuscles, equipment: r.equipment,
                  movementPattern: r.movementPattern, isCustom: r.isCustom)
    }
}
```

- [ ] **Step 4: Run test, verify it passes.**

- [ ] **Step 5: Commit**
```bash
git add apps/elos-mobile/Elos/Elos/Features/Train/Programs/Intelligence/ExerciseCandidate.swift \
        apps/elos-mobile/Elos/ElosTests/Intelligence/ExerciseCandidateTests.swift
git commit -m "feat(ios): ExerciseCandidate value type for ranking engines"
```

## Task 2: `MuscleTaxonomy`

**Files:**
- Create: `…/Intelligence/MuscleTaxonomy.swift`
- Test: `…/ElosTests/Intelligence/MuscleTaxonomyTests.swift`

- [ ] **Step 1: Write the failing test**
```swift
import Testing
@testable import Elos

struct MuscleTaxonomyTests {
    @Test func normalizesUnderscoresAndCase() {
        #expect(MuscleTaxonomy.normalize("Rear_Delts") == "rear delts")
    }
    @Test func classifiesCompoundVsIsolation() {
        #expect(MuscleTaxonomy.isCompound(movementPattern: "push"))
        #expect(MuscleTaxonomy.isCompound(movementPattern: "hinge"))
        #expect(!MuscleTaxonomy.isCompound(movementPattern: "isolation"))
        #expect(!MuscleTaxonomy.isCompound(movementPattern: "rotation"))
    }
    @Test func mapsMuscleToGroup() {
        #expect(MuscleTaxonomy.group(forMuscle: "front_delts") == .shoulders)
        #expect(MuscleTaxonomy.group(forMuscle: "lats") == .back)
        #expect(MuscleTaxonomy.group(forMuscle: "rear_delts") == .back) // posterior chain grouping
        #expect(MuscleTaxonomy.group(forMuscle: "quads") == .legs)
    }
    @Test func aliasesDayNameToArchetype() {
        #expect(MuscleTaxonomy.archetype(forDayName: "Push") == .push)
        #expect(MuscleTaxonomy.archetype(forDayName: "Chest & Tri") == .push)
        #expect(MuscleTaxonomy.archetype(forDayName: "Back & Bi") == .pull)
        #expect(MuscleTaxonomy.archetype(forDayName: "Leg Day") == .legs)
        #expect(MuscleTaxonomy.archetype(forDayName: "Upper") == .upper)
        #expect(MuscleTaxonomy.archetype(forDayName: "") == nil)
        #expect(MuscleTaxonomy.archetype(forDayName: "Cardio") == nil)
    }
    @Test func pushArchetypeTargetsPressingMuscles() {
        let t = MuscleTaxonomy.targetMuscles(forArchetype: .push)
        #expect(t.contains("chest"))
        #expect(t.contains("triceps"))
        #expect(!t.contains("lats"))
    }
}
```

- [ ] **Step 2: Run, verify fail.**

- [ ] **Step 3: Implement**
```swift
import Foundation

enum MuscleGroup: String, CaseIterable {
    case chest, back, shoulders, arms, legs, glutes, core
}

enum SplitArchetype: String, CaseIterable {
    case push, pull, legs, upper, lower, fullBody, arms, core
}

enum MuscleTaxonomy {
    static func normalize(_ s: String) -> String {
        s.lowercased()
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
            .trimmingCharacters(in: .whitespaces)
    }

    private static let compoundPatterns: Set<String> = ["push", "pull", "squat", "hinge", "carry"]
    static func isCompound(movementPattern p: String) -> Bool {
        compoundPatterns.contains(p.lowercased().trimmingCharacters(in: .whitespaces))
    }

    /// Map a primaryMuscle string to a broad group. Mirrors BodyPartFilter.from but centralised.
    static func group(forMuscle muscle: String) -> MuscleGroup? {
        let m = normalize(muscle)
        if m.contains("pec") || m.contains("chest") { return .chest }
        if m.contains("rear delt") { return .back }      // posterior delts trained on pull days
        if m.contains("lat") || m.contains("back") || m.contains("trap") || m.contains("rhomboid") { return .back }
        if m.contains("delt") || m.contains("shoulder") { return .shoulders }
        if m.contains("bicep") || m.contains("tricep") || m.contains("forearm") || m.contains("brachialis") { return .arms }
        if m.contains("glute") || m.contains("hip") || m.contains("adductor") || m.contains("abductor") { return .glutes }
        if m.contains("quad") || m.contains("hamstring") || m.contains("calf") || m.contains("calves") || m.contains("leg") || m.contains("tibialis") { return .legs }
        if m.contains("ab") || m.contains("oblique") || m.contains("core") { return .core }
        return nil
    }

    static func targetMuscles(forArchetype a: SplitArchetype) -> Set<String> {
        switch a {
        case .push:     return ["chest", "front delts", "side delts", "triceps"]
        case .pull:     return ["lats", "back", "traps", "rear delts", "biceps", "forearms"]
        case .legs, .lower: return ["quads", "hamstrings", "glutes", "calves", "adductors"]
        case .upper:    return ["chest", "back", "lats", "front delts", "side delts", "rear delts", "biceps", "triceps", "traps"]
        case .fullBody: return ["chest", "back", "lats", "quads", "hamstrings", "glutes", "front delts", "biceps", "triceps", "core"]
        case .arms:     return ["biceps", "triceps", "forearms", "brachialis"]
        case .core:     return ["abs", "core", "obliques", "hip flexors"]
        }
    }

    /// Free-text day name → archetype. Returns nil when nothing matches.
    static func archetype(forDayName name: String) -> SplitArchetype? {
        let n = normalize(name)
        guard !n.isEmpty else { return nil }
        if n.contains("full body") || n.contains("full-body") { return .fullBody }
        if n.contains("upper") { return .upper }
        if n.contains("lower") { return .lower }
        if n.contains("push") || (n.contains("chest") && n.contains("tri")) { return .push }
        if n.contains("pull") || (n.contains("back") && n.contains("bi")) { return .pull }
        if n.contains("leg") || n.contains("quad") || n.contains("hamstring") { return .legs }
        if n.contains("arm") && !n.contains("warm") { return .arms }
        if n.contains("core") || n.contains("abs") { return .core }
        // single-group day names
        if n.contains("chest") { return .push }
        if n.contains("back") { return .pull }
        if n.contains("shoulder") || n.contains("delt") { return .push }
        return nil
    }

    static func antagonist(of group: MuscleGroup) -> MuscleGroup? {
        switch group {
        case .chest: return .back
        case .back: return .chest
        case .legs: return .glutes
        case .glutes: return .legs
        default: return nil
        }
    }
}
```

- [ ] **Step 4: Run, verify pass.**

- [ ] **Step 5: Commit** (`feat(ios): MuscleTaxonomy — grouping, archetypes, compound classification`).

## Task 3: `ExerciseSearch` (extract existing search logic)

This moves the search helpers currently `private static` inside `ExercisePickerView` (`normalize`, `searchTokens`, `gymAliases`, `exerciseScore`, `machineScore`) into one reusable place, with tests that pin the **current** 100/90/80/70/50 behaviour so nothing regresses. `ExercisePickerView` is rewired to call it in Task 7.

**Files:**
- Create: `…/Intelligence/ExerciseSearch.swift`
- Test: `…/ElosTests/Intelligence/ExerciseSearchTests.swift`

- [ ] **Step 1: Write the failing test** (pins current behaviour)
```swift
import Testing
@testable import Elos

struct ExerciseSearchTests {
    private func cand(_ name: String, muscle: String = "chest", equip: String = "barbell", pattern: String = "push") -> ExerciseCandidate {
        ExerciseCandidate(id: name, name: name, primaryMuscle: muscle, secondaryMuscles: [],
                          equipment: equip, movementPattern: pattern, isCustom: false)
    }
    @Test func exactNameScoresHighest() {
        let s = ExerciseSearch.tokens(from: "bench press")
        #expect(ExerciseSearch.score(cand("Bench Press"), tokens: s, query: "bench press") == 100)
    }
    @Test func prefixBeatsContains() {
        let s = ExerciseSearch.tokens(from: "bench")
        #expect(ExerciseSearch.score(cand("Bench Press"), tokens: s, query: "bench") == 90)
        let s2 = ExerciseSearch.tokens(from: "press")
        #expect(ExerciseSearch.score(cand("Bench Press"), tokens: s2, query: "press") == 80)
    }
    @Test func aliasExpands() {
        let s = ExerciseSearch.tokens(from: "rdl")
        #expect(s.contains("romanian"))
    }
    @Test func nonMatchReturnsNil() {
        let s = ExerciseSearch.tokens(from: "squat")
        #expect(ExerciseSearch.score(cand("Bench Press"), tokens: s, query: "squat") == nil)
    }
    @Test func matchesViaMuscleField() {
        let s = ExerciseSearch.tokens(from: "chest")
        #expect(ExerciseSearch.score(cand("Weird Lift", muscle: "chest"), tokens: s, query: "chest") == 50)
    }
}
```

- [ ] **Step 2: Run, verify fail.**

- [ ] **Step 3: Implement** — copy the existing logic verbatim from `ExercisePickerView.swift` lines 360–413, retyped to operate on `ExerciseCandidate`:
```swift
import Foundation

enum ExerciseSearch {
    static let gymAliases: [String: String] = [
        "rdl": "romanian deadlift", "ohp": "overhead press", "cgbp": "close grip bench press",
        "bp": "bench press", "dl": "deadlift", "pd": "pulldown", "db": "dumbbell",
        "bb": "barbell", "bw": "bodyweight", "bis": "bicep", "tris": "tricep",
        "hams": "hamstring", "quads": "quad", "delts": "delt", "glutes": "glute",
        "calves": "calf", "abs": "core abdominal", "pecs": "chest pec", "lats": "lat",
        "traps": "trap", "shoulders": "delt shoulder", "arms": "bicep tricep",
        "legs": "quad hamstring leg",
    ]

    static func normalize(_ text: String) -> String {
        text.lowercased().replacingOccurrences(of: "_", with: " ").replacingOccurrences(of: "-", with: " ")
    }

    static func tokens(from raw: String) -> [String] {
        let lower = raw.lowercased().trimmingCharacters(in: .whitespaces)
        let expanded = gymAliases[lower] ?? lower
        return expanded.components(separatedBy: .whitespaces)
            .map { $0.trimmingCharacters(in: .punctuationCharacters) }
            .filter { $0.count >= 2 }
    }

    static func normalizedQuery(_ raw: String) -> String {
        normalize(gymAliases[raw.lowercased().trimmingCharacters(in: .whitespaces)] ?? raw)
    }

    /// Generic-exercise relevance. nil = no match. Mirrors the previous ExercisePickerView.exerciseScore.
    static func score(_ c: ExerciseCandidate, tokens: [String], query: String) -> Int? {
        let nq = normalizedQuery(query)
        let name = normalize(c.name)
        let full = "\(name) \(normalize(c.primaryMuscle)) \(normalize(c.equipment)) \(normalize(c.movementPattern))"
        guard tokens.allSatisfy({ full.contains($0) }) else { return nil }
        if name == nq { return 100 }
        if name.hasPrefix(nq) { return 90 }
        if name.contains(nq) { return 80 }
        if tokens.allSatisfy({ name.contains($0) }) { return 70 }
        return 50
    }
}
```
> Note: machine (`EquipmentRecord`) scoring stays in `ExercisePickerView` for now (it is only used there). Moving it is out of scope (YAGNI).

- [ ] **Step 4: Run, verify pass.**

- [ ] **Step 5: Commit** (`feat(ios): extract ExerciseSearch from picker, pin scoring behavior`).

## Task 4: `DayContext` + `DayContextInferrer`

**Files:**
- Create: `…/Intelligence/DayContext.swift`
- Test: `…/ElosTests/Intelligence/DayContextTests.swift`

- [ ] **Step 1: Write the failing test**
```swift
import Testing
@testable import Elos

struct DayContextTests {
    private let catalog: [ExerciseCandidate] = [
        .init(id: "1", name: "Barbell Bench Press", primaryMuscle: "chest", secondaryMuscles: ["triceps"], equipment: "barbell", movementPattern: "push", isCustom: false),
        .init(id: "2", name: "Lat Pulldown", primaryMuscle: "lats", secondaryMuscles: ["biceps"], equipment: "cable", movementPattern: "pull", isCustom: false),
    ]
    @Test func infersArchetypeFromName() {
        let ctx = DayContextInferrer.infer(dayName: "Push Day", added: [], catalog: catalog)
        #expect(ctx.archetype == .push)
        #expect(ctx.targetMuscles.contains("chest"))
        #expect(ctx.hasFocus)
    }
    @Test func emptyNameNoAddedHasNoFocus() {
        let ctx = DayContextInferrer.infer(dayName: "", added: [], catalog: catalog)
        #expect(ctx.archetype == nil)
        #expect(!ctx.hasFocus)
        #expect(ctx.targetMuscles.isEmpty)
    }
    @Test func infersFocusFromAddedWhenNameBlank() {
        let added = [DayExercise(id: "2", name: "Lat Pulldown")]
        let ctx = DayContextInferrer.infer(dayName: "", added: added, catalog: catalog)
        #expect(ctx.hasFocus)                       // muscles came from the added exercise
        #expect(ctx.targetMuscles.contains("lats"))
        #expect(ctx.addedPrimaryMuscles.contains("lats"))
        #expect(ctx.addedExerciseIDs.contains("2"))
    }
}
```

- [ ] **Step 2: Run, verify fail.**

- [ ] **Step 3: Implement**
```swift
import Foundation

struct DayContext: Equatable {
    let dayName: String
    let archetype: SplitArchetype?
    let targetMuscles: Set<String>     // normalized muscle strings
    let addedPrimaryMuscles: [String]  // normalized, includes duplicates for coverage counting
    let addedExerciseIDs: Set<String>
    let addedExerciseNames: Set<String> // normalized

    var hasFocus: Bool { !targetMuscles.isEmpty }

    static let empty = DayContext(dayName: "", archetype: nil, targetMuscles: [],
                                  addedPrimaryMuscles: [], addedExerciseIDs: [], addedExerciseNames: [])
}

enum DayContextInferrer {
    static func infer(dayName: String, added: [DayExercise], catalog: [ExerciseCandidate]) -> DayContext {
        let archetype = MuscleTaxonomy.archetype(forDayName: dayName)
        var targets = archetype.map { MuscleTaxonomy.targetMuscles(forArchetype: $0) } ?? []

        // Resolve added exercises to their muscles via the catalog (match by id, then normalized name).
        let byID = Dictionary(catalog.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        let byName = Dictionary(catalog.map { (MuscleTaxonomy.normalize($0.name), $0) }, uniquingKeysWith: { a, _ in a })
        var addedPrimaries: [String] = []
        for ex in added {
            let match = byID[ex.id] ?? byName[MuscleTaxonomy.normalize(ex.name)]
            guard let c = match else { continue }
            let primary = MuscleTaxonomy.normalize(c.primaryMuscle)
            addedPrimaries.append(primary)
            targets.insert(primary)
            for s in c.secondaryMuscles { targets.insert(MuscleTaxonomy.normalize(s)) }
        }

        return DayContext(
            dayName: dayName,
            archetype: archetype,
            targetMuscles: targets,
            addedPrimaryMuscles: addedPrimaries,
            addedExerciseIDs: Set(added.map { $0.id }),
            addedExerciseNames: Set(added.map { MuscleTaxonomy.normalize($0.name) })
        )
    }
}
```

- [ ] **Step 4: Run, verify pass.**

- [ ] **Step 5: Commit** (`feat(ios): DayContext + inferrer for split-day focus`).

## Task 5: `PersonalizationProvider`

**Files:**
- Create: `…/Intelligence/PersonalizationProvider.swift`
- Test: `…/ElosTests/Intelligence/PersonalizationProviderTests.swift`

- [ ] **Step 1: Write the failing test**
```swift
import Testing
@testable import Elos

struct PersonalizationProviderTests {
    @Test func favoriteBeatsUnknown() {
        let p = PersonalizationProvider(signals: .init(
            favoriteNames: ["bench press"], recentOrder: [], frequency: [:]))
        #expect(p.score(forName: "Bench Press") > p.score(forName: "Leg Curl"))
    }
    @Test func moreFrequentScoresHigher() {
        let p = PersonalizationProvider(signals: .init(
            favoriteNames: [], recentOrder: [], frequency: ["squat": 10, "curl": 1]))
        #expect(p.score(forName: "Squat") > p.score(forName: "Curl"))
    }
    @Test func recentScoresHigherThanNotRecent() {
        let p = PersonalizationProvider(signals: .init(
            favoriteNames: [], recentOrder: ["row", "press"], frequency: [:]))
        #expect(p.score(forName: "Row") > p.score(forName: "Deadlift"))
    }
    @Test func scoreIsClampedZeroToOne() {
        let p = PersonalizationProvider(signals: .init(
            favoriteNames: ["a"], recentOrder: ["a"], frequency: ["a": 100]))
        #expect(p.score(forName: "A") <= 1.0)
        #expect(p.score(forName: "Z") >= 0.0)
    }
}
```

- [ ] **Step 2: Run, verify fail.**

- [ ] **Step 3: Implement**
```swift
import Foundation

struct PersonalizationSignals {
    var favoriteNames: Set<String>   // normalized
    var recentOrder: [String]        // normalized, most-recent first
    var frequency: [String: Int]     // normalized name → set count

    init(favoriteNames: Set<String> = [], recentOrder: [String] = [], frequency: [String: Int] = [:]) {
        self.favoriteNames = Set(favoriteNames.map { MuscleTaxonomy.normalize($0) })
        self.recentOrder = recentOrder.map { MuscleTaxonomy.normalize($0) }
        self.frequency = Dictionary(frequency.map { (MuscleTaxonomy.normalize($0.key), $0.value) },
                                    uniquingKeysWith: { a, _ in a })
    }
}

struct PersonalizationProvider {
    let signals: PersonalizationSignals
    private let maxFreq: Int

    init(signals: PersonalizationSignals) {
        self.signals = signals
        self.maxFreq = max(signals.frequency.values.max() ?? 0, 1)
    }

    /// 0…1. Weights: favorite 0.4, recency ≤0.3, frequency ≤0.3.
    func score(forName name: String) -> Double {
        let n = MuscleTaxonomy.normalize(name)
        var s = 0.0
        if signals.favoriteNames.contains(n) { s += 0.4 }
        if let idx = signals.recentOrder.firstIndex(of: n) {
            let depth = Double(signals.recentOrder.count)
            s += 0.3 * (1.0 - Double(idx) / max(depth, 1))
        }
        if let f = signals.frequency[n] {
            s += 0.3 * (Double(f) / Double(maxFreq))
        }
        return min(max(s, 0.0), 1.0)
    }
}
```

- [ ] **Step 4: Run, verify pass.**

- [ ] **Step 5: Commit** (`feat(ios): PersonalizationProvider scoring`).

## Task 6: `ExerciseRankingEngine` (Smart Sort)

**Files:**
- Create: `…/Intelligence/ExerciseRankingEngine.swift`
- Test: `…/ElosTests/Intelligence/ExerciseRankingEngineTests.swift`

- [ ] **Step 1: Write the failing test**
```swift
import Testing
@testable import Elos

struct ExerciseRankingEngineTests {
    private let bench   = ExerciseCandidate(id: "bench", name: "Barbell Bench Press", primaryMuscle: "chest", secondaryMuscles: ["triceps"], equipment: "barbell", movementPattern: "push", isCustom: false)
    private let fly     = ExerciseCandidate(id: "fly", name: "Cable Fly", primaryMuscle: "chest", secondaryMuscles: [], equipment: "cable", movementPattern: "isolation", isCustom: false)
    private let curl    = ExerciseCandidate(id: "curl", name: "Leg Curl", primaryMuscle: "hamstrings", secondaryMuscles: [], equipment: "machine", movementPattern: "isolation", isCustom: false)

    private func inputs(_ ctx: DayContext, query: String = "",
                        avail: @escaping (String) -> Bool = { _ in true }) -> RankingInputs {
        RankingInputs(context: ctx,
                      personalization: PersonalizationProvider(signals: .init()),
                      isEquipmentAvailable: avail, query: query)
    }

    @Test func pushDayRanksPushAboveLegs() {
        let ctx = DayContextInferrer.infer(dayName: "Push", added: [], catalog: [bench, fly, curl])
        let ranked = ExerciseRankingEngine.rank([curl, fly, bench], inputs: inputs(ctx))
        #expect(ranked.first?.id == "bench")          // compound + on-target
        #expect(ranked.last?.id == "curl")            // off-target
    }
    @Test func compoundBeatsIsolationAtEqualTarget() {
        let ctx = DayContextInferrer.infer(dayName: "Push", added: [], catalog: [bench, fly])
        let ranked = ExerciseRankingEngine.rank([fly, bench], inputs: inputs(ctx))
        #expect(ranked.first?.id == "bench")
    }
    @Test func alreadyAddedIsDemoted() {
        let added = [DayExercise(id: "bench", name: "Barbell Bench Press")]
        let ctx = DayContextInferrer.infer(dayName: "Push", added: added, catalog: [bench, fly])
        let ranked = ExerciseRankingEngine.rank([bench, fly], inputs: inputs(ctx))
        #expect(ranked.first?.id == "fly")            // bench is on the day already → pushed down
    }
    @Test func queryDominatesAndMatchesSearchOrder() {
        let ctx = DayContext.empty
        let ranked = ExerciseRankingEngine.rank([curl, fly, bench], inputs: inputs(ctx, query: "bench"))
        #expect(ranked.first?.id == "bench")
        #expect(!ranked.contains { $0.id == "curl" }) // non-matches filtered out when searching
    }
    @Test func unavailableEquipmentDemotedNotRemoved() {
        let ctx = DayContextInferrer.infer(dayName: "Push", added: [], catalog: [bench, fly])
        let ranked = ExerciseRankingEngine.rank([fly, bench],
            inputs: inputs(ctx, avail: { $0.lowercased() != "barbell" }))
        #expect(ranked.contains { $0.id == "bench" }) // still present
        #expect(ranked.first?.id == "fly")            // available cable fly outranks demoted barbell
    }
    @Test func alphabeticalModeIgnoresContext() {
        let ranked = ExerciseRankingEngine.rank([fly, bench, curl],
            inputs: inputs(.empty), mode: .alphabetical)
        #expect(ranked.map { $0.name } == ["Barbell Bench Press", "Cable Fly", "Leg Curl"])
    }
}
```

- [ ] **Step 2: Run, verify fail.**

- [ ] **Step 3: Implement**
```swift
import Foundation

enum ExerciseSortMode: String, CaseIterable {
    case smart = "Smart", alphabetical = "A–Z", mostUsed = "Most used", byMuscle = "By muscle"
}

struct RankingInputs {
    var context: DayContext
    var personalization: PersonalizationProvider
    var isEquipmentAvailable: (String) -> Bool = { _ in true }
    var query: String = ""
}

enum ExerciseRankingEngine {
    // Weights. Browsing regime; query term is scaled to dominate when present (see score()).
    private static let wDay = 3.0, wCompound = 1.5, wPers = 1.0, wGap = 1.2, wDup = 4.0, wEquip = 2.0

    static func rank(_ candidates: [ExerciseCandidate], inputs: RankingInputs,
                     mode: ExerciseSortMode = .smart) -> [ExerciseCandidate] {
        let searching = inputs.query.trimmingCharacters(in: .whitespaces).count >= 2

        switch mode {
        case .alphabetical:
            return candidates.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        case .mostUsed:
            return candidates.sorted { inputs.personalization.score(forName: $0.name) > inputs.personalization.score(forName: $1.name) }
        case .byMuscle:
            return candidates.sorted {
                let a = $0.primaryMuscle, b = $1.primaryMuscle
                return a == b ? $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending : a < b
            }
        case .smart:
            break
        }

        // When searching, drop non-matches (preserves today's behaviour) and rank by composite.
        let scored: [(ExerciseCandidate, Double)] = candidates.compactMap { c in
            if searching {
                let toks = ExerciseSearch.tokens(from: inputs.query)
                guard let s = ExerciseSearch.score(c, tokens: toks, query: inputs.query) else { return nil }
                // Query dominates: scale the 50–100 ladder far above browsing terms, then add a small browsing nudge for ties.
                return (c, Double(s) * 10.0 + smartBrowseScore(c, inputs))
            }
            return (c, smartBrowseScore(c, inputs))
        }
        return scored.sorted { a, b in
            a.1 == b.1 ? a.0.name.localizedCaseInsensitiveCompare(b.0.name) == .orderedAscending : a.1 > b.1
        }.map { $0.0 }
    }

    private static func smartBrowseScore(_ c: ExerciseCandidate, _ inputs: RankingInputs) -> Double {
        let ctx = inputs.context
        var s = 0.0

        if ctx.hasFocus {
            s += wDay * dayMatch(c, ctx)
            s += wGap * coverageGap(c, ctx)
            s -= wDup * duplicatePenalty(c, ctx)
        }
        s += wCompound * (MuscleTaxonomy.isCompound(movementPattern: c.movementPattern) ? 1.0 : 0.0)
        s += wPers * inputs.personalization.score(forName: c.name)
        if !inputs.isEquipmentAvailable(c.equipment) { s -= wEquip }
        return s
    }

    private static func muscles(of c: ExerciseCandidate) -> [String] {
        [MuscleTaxonomy.normalize(c.primaryMuscle)] + c.secondaryMuscles.map { MuscleTaxonomy.normalize($0) }
    }

    /// 1.0 if primary is on-target, 0.5 if only a secondary is, else 0.
    private static func dayMatch(_ c: ExerciseCandidate, _ ctx: DayContext) -> Double {
        if ctx.targetMuscles.contains(MuscleTaxonomy.normalize(c.primaryMuscle)) { return 1.0 }
        if muscles(of: c).contains(where: { ctx.targetMuscles.contains($0) }) { return 0.5 }
        return 0.0
    }

    /// Boost if this exercise's primary muscle is a target not yet covered by an added exercise.
    private static func coverageGap(_ c: ExerciseCandidate, _ ctx: DayContext) -> Double {
        let p = MuscleTaxonomy.normalize(c.primaryMuscle)
        guard ctx.targetMuscles.contains(p) else { return 0.0 }
        return ctx.addedPrimaryMuscles.contains(p) ? 0.0 : 1.0
    }

    /// Penalise exact re-adds and same-primary-muscle duplicates.
    private static func duplicatePenalty(_ c: ExerciseCandidate, _ ctx: DayContext) -> Double {
        if ctx.addedExerciseIDs.contains(c.id) || ctx.addedExerciseNames.contains(MuscleTaxonomy.normalize(c.name)) { return 1.0 }
        if ctx.addedPrimaryMuscles.contains(MuscleTaxonomy.normalize(c.primaryMuscle)) { return 0.5 }
        return 0.0
    }
}
```

- [ ] **Step 4: Run, verify pass.** Tune any weight only if a test fails for the wrong reason; keep the relative ordering described in the spec.

- [ ] **Step 5: Commit** (`feat(ios): ExerciseRankingEngine smart sort`).

## Task 7: `SetRepDefaults`

**Files:**
- Create: `…/Intelligence/SetRepDefaults.swift`
- Test: `…/ElosTests/Intelligence/SetRepDefaultsTests.swift`

- [ ] **Step 1: Write the failing test**
```swift
import Testing
@testable import Elos

struct SetRepDefaultsTests {
    @Test func heavyCompoundsLowerReps() {
        let squat = SetRepDefaults.defaults(forMovementPattern: "squat")
        #expect(squat.sets == 4)
        #expect(squat.reps == "5-8")
    }
    @Test func isolationHigherReps() {
        let iso = SetRepDefaults.defaults(forMovementPattern: "isolation")
        #expect(iso.sets == 3)
        #expect(iso.reps == "10-15")
    }
    @Test func unknownPatternFallsBackToIsolationDefault() {
        #expect(SetRepDefaults.defaults(forMovementPattern: "").reps == "10-15")
    }
}
```

- [ ] **Step 2: Run, verify fail.**

- [ ] **Step 3: Implement**
```swift
import Foundation

enum SetRepDefaults {
    static func defaults(forMovementPattern pattern: String) -> (sets: Int, reps: String) {
        switch pattern.lowercased().trimmingCharacters(in: .whitespaces) {
        case "squat", "hinge": return (4, "5-8")
        case "push", "pull":   return (4, "6-10")
        case "carry":          return (3, "10")
        default:               return (3, "10-15") // isolation, rotation, unknown
        }
    }
}
```

- [ ] **Step 4: Run, verify pass.**

- [ ] **Step 5: Commit** (`feat(ios): SetRepDefaults by movement pattern`).

## Task 8: Wire `ExercisePickerView` to Smart Sort + sort control

Integration task — no unit test (SwiftUI view). Verify by build + manual run.

**Files:**
- Modify: `Elos/Features/Train/ExercisePicker/ExercisePickerView.swift`
- Modify: `Elos/Features/Train/Programs/CreateSplitView.swift` (pass context + apply defaults)

- [ ] **Step 1: Add inputs to the picker.** Near the other stored properties (after `prefilterMachineName`, line ~21) add:
```swift
/// Split-day focus for Smart Sort. nil/empty when the picker is opened outside split building.
var dayContext: DayContext = .empty
```
And a sort-mode state alongside the other `@State` (line ~35):
```swift
@State private var sortMode: ExerciseSortMode = .smart
```

- [ ] **Step 2: Replace the inline search helpers with `ExerciseSearch`.** Delete the `private static let gymAliases`, `normalize`, `searchTokens`, and `exerciseScore` definitions (lines ~360–413). Update the two call sites:
  - In `filtered` (lines ~338–349): replace the token/score block with a call into the engine (next step).
  - In `prominentMachineResults` / `machineResults`: replace `Self.searchTokens` → `ExerciseSearch.tokens`, `Self.normalize(Self.gymAliases[...] ?? query)` → `ExerciseSearch.normalizedQuery(query)`, and `Self.machineScore` stays (it remains defined in this file — keep `normalize` available by calling `ExerciseSearch.normalize` inside `machineScore`).

- [ ] **Step 3: Rank the generic list through the engine.** Replace the body of `filtered`'s tail so that, after the equipment/bodypart/muscle/movement filters build `result: [Row]`, it ranks via the engine. Add a computed `rankingInputs` and convert `Row`↔`ExerciseCandidate`. Simplest approach: build candidates from `result`, rank, then map back to rows by id. Add:
```swift
private var personalizationSignals: PersonalizationSignals {
    PersonalizationSignals(
        favoriteNames: Set(vm.favorites.map { $0.name }),
        recentOrder: vm.recent.map { $0.name },
        frequency: [:]   // local-frequency wiring is Phase 1 optional; left empty until a fetch is added
    )
}
private func candidate(from row: Row) -> ExerciseCandidate {
    ExerciseCandidate(id: row.id, name: row.name, primaryMuscle: row.primaryMuscle,
                      secondaryMuscles: [], equipment: row.equipment,
                      movementPattern: row.movementPattern, isCustom: row.isCustom)
}
```
Then in `filtered`, after applying the chip filters, replace the `if !query.isEmpty { … }` block and trailing `return result` with:
```swift
let candidates = result.map(candidate(from:))
let inputs = RankingInputs(context: dayContext,
                           personalization: PersonalizationProvider(signals: personalizationSignals),
                           isEquipmentAvailable: { _ in true },   // Phase 2 wires EquipmentPreference
                           query: query)
let rankedIDs = ExerciseRankingEngine.rank(candidates, inputs: inputs, mode: sortMode).map { $0.id }
let byID = Dictionary(result.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
return rankedIDs.compactMap { byID[$0] }
```
> The engine already preserves search behaviour (filters non-matches, query dominates), so deleting the old query block is safe.

- [ ] **Step 4: Add the sort control UI.** In `filterArea`, after the "Body Part" row (line ~219) add a compact menu. Keep it unobtrusive:
```swift
HStack {
    Spacer()
    Menu {
        Picker("Sort", selection: $sortMode) {
            ForEach(ExerciseSortMode.allCases, id: \.self) { Text($0.rawValue).tag($0) }
        }
    } label: {
        HStack(spacing: 4) {
            Image(systemName: "arrow.up.arrow.down")
            Text(sortMode.rawValue)
        }
        .font(.caption).foregroundStyle(Color.tint)
    }
    .padding(.trailing, 16).padding(.vertical, 4)
}
```

- [ ] **Step 5: Pass `dayContext` from `CreateSplitView`.** Fully **replace** the existing `.exercise(let i)` case (CreateSplitView lines ~134–143 — the current block appends a `DayExercise` with no sets/reps; do not leave it duplicated) with the version below. It passes the inferred context and applies `SetRepDefaults` on add:
```swift
case .exercise(let i):
    ExercisePickerView(
        onPickSingle: { picked in
            if !dayExercises[i].contains(where: { $0.id == picked.id }) {
                let pattern = exerciseCatalog.first { $0.id == picked.id }?.movementPattern ?? ""
                let def = SetRepDefaults.defaults(forMovementPattern: pattern)
                dayExercises[i].append(DayExercise(id: picked.id, name: picked.name,
                    sets: def.sets, reps: def.reps,
                    equipmentId: picked.equipmentId,
                    equipmentDedupeKey: picked.equipmentDedupeKey,
                    equipmentBrandName: picked.equipmentBrandName))
            }
        },
        dayContext: DayContextInferrer.infer(dayName: dayNames[i], added: dayExercises[i], catalog: exerciseCatalog)
    )
```
Add a `@Query` for the catalog at the top of `CreateSplitView` and a mapped accessor:
```swift
@Query(sort: \ExerciseDefinitionRecord.name) private var exerciseDefs: [ExerciseDefinitionRecord]
private var exerciseCatalog: [ExerciseCandidate] { exerciseDefs.map(ExerciseCandidate.init(record:)) }
```
(Delete the `let catalog = …` placeholder line; it was only to mark the spot.)

- [ ] **Step 6: Build the app target.**
```bash
xcodebuild build -project apps/elos-mobile/Elos/Elos.xcodeproj -scheme Elos \
  -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | tail -25
```
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 7: Manual smoke (use the `verify` or `run` skill / Xcode).** Open Create Split → name a day "Push" → tap Add exercises. Confirm pressing/chest/triceps movements and compounds surface at the top before legs; switch the sort control to A–Z and confirm alphabetical; type "bench" and confirm search still works.

- [ ] **Step 8: Commit** (`feat(ios): smart-sorted exercise picker with day context + sort control`).

---

# Phase 2 — Guidance

## Task 9: `EquipmentPreference`

**Files:**
- Create: `…/Intelligence/EquipmentPreference.swift`
- Test: `…/ElosTests/Intelligence/EquipmentPreferenceTests.swift`

- [ ] **Step 1: Write the failing test**
```swift
import Testing
@testable import Elos

struct EquipmentPreferenceTests {
    @Test func fullGymAllowsEverything() {
        let p = EquipmentPreference.fullGym
        #expect(p.isAvailable(equipment: "machine"))
        #expect(p.isAvailable(equipment: "barbell"))
    }
    @Test func homeExcludesMachines() {
        let p = EquipmentPreference(posture: .home, customTypes: [])
        #expect(p.isAvailable(equipment: "dumbbell"))
        #expect(p.isAvailable(equipment: "barbell"))
        #expect(!p.isAvailable(equipment: "machine"))
    }
    @Test func customUsesExplicitSet() {
        let p = EquipmentPreference(posture: .custom, customTypes: ["dumbbell"])
        #expect(p.isAvailable(equipment: "dumbbell"))
        #expect(!p.isAvailable(equipment: "barbell"))
    }
    @Test func roundTripsThroughJSON() {
        let p = EquipmentPreference(posture: .custom, customTypes: ["cable", "dumbbell"])
        #expect(EquipmentPreference(json: p.json) == p)
        #expect(EquipmentPreference(json: "") == .fullGym)  // unset → full gym
    }
}
```

- [ ] **Step 2: Run, verify fail.**

- [ ] **Step 3: Implement**
```swift
import Foundation

enum EquipmentPosture: String, Codable, CaseIterable { case fullGym, home, custom }

struct EquipmentPreference: Codable, Equatable {
    var posture: EquipmentPosture
    var customTypes: Set<String>   // normalized equipment type tokens, used when posture == .custom

    static let fullGym = EquipmentPreference(posture: .fullGym, customTypes: [])
    // Home default: free weights + bodyweight, no machines/cables. Tunable (spec open question).
    static let homeAllowed: Set<String> = ["barbell", "dumbbell", "kettlebell", "bodyweight"]

    func isAvailable(equipment: String) -> Bool {
        let e = equipment.lowercased().trimmingCharacters(in: .whitespaces)
        let key = e.isEmpty ? "bodyweight" : e
        switch posture {
        case .fullGym: return true
        case .home:    return Self.homeAllowed.contains { key.contains($0) }
        case .custom:  return customTypes.contains { key.contains($0) }
        }
    }

    var json: String {
        (try? String(data: JSONEncoder().encode(self), encoding: .utf8)) ?? ""
    }
    init(posture: EquipmentPosture, customTypes: Set<String>) {
        self.posture = posture; self.customTypes = customTypes
    }
    init(json: String) {
        guard !json.isEmpty, let data = json.data(using: .utf8),
              let p = try? JSONDecoder().decode(EquipmentPreference.self, from: data) else {
            self = .fullGym; return
        }
        self = p
    }
}
```

- [ ] **Step 4: Run, verify pass.**

- [ ] **Step 5: Commit** (`feat(ios): EquipmentPreference posture + availability`).

## Task 10: Persist `EquipmentPreference` on the profile + settings picker

**Files:**
- Modify: `Elos/SwiftData/ElosSchema.swift` (UserProfileRecord)
- Modify: the profile edit screen (find with `grep -rn "trainingExperience" Elos/Elos/Features` — likely `ProfileEditView.swift`)
- Modify: `ExercisePickerView.swift` (use the preference in `isEquipmentAvailable`)

- [ ] **Step 1: Add a stored field with a default** (default keeps SwiftData lightweight migration automatic). In `UserProfileRecord` add after `useImperial` (line ~706):
```swift
var equipmentPreferenceJSON: String = ""
```
Add the matching parameter (defaulted) to the initializer and assign it.

- [ ] **Step 2: Add a computed accessor** on `UserProfileRecord`:
```swift
var equipmentPreference: EquipmentPreference {
    get { EquipmentPreference(json: equipmentPreferenceJSON) }
    set { equipmentPreferenceJSON = newValue.json }
}
```

- [ ] **Step 3: Build** to confirm the model + migration compile (`xcodebuild build … | tail -20`). Expected: `BUILD SUCCEEDED`.

- [ ] **Step 4: Add a posture Picker** to the profile edit screen (a `Picker` bound to a `@State` mapped to `profile.equipmentPreference.posture`, persisted on change). Keep `.custom` simple for v1: a multi-select of `EquipmentFilter` cases — when writing into `EquipmentPreference.customTypes` (a `Set<String>` of normalized tokens), map each selected case via `EquipmentFilter.rawValue.lowercased()` so it lines up with `isAvailable`'s `contains` matching (e.g. `"machine"`, `"barbell"`). Build again.

- [ ] **Step 5: Use the preference in the picker.** In `ExercisePickerView`, read the profile and pass a real closure. Add:
```swift
@Query private var profiles: [UserProfileRecord]
private var equipmentPreference: EquipmentPreference { profiles.first?.equipmentPreference ?? .fullGym }
```
and in `filtered`'s `RankingInputs`, set `isEquipmentAvailable: { equipmentPreference.isAvailable(equipment: $0) }`.

- [ ] **Step 6: Build + manual smoke** — set Home posture, confirm machine exercises sink (not vanish) in Smart sort.

- [ ] **Step 7: Commit** (`feat(ios): persist equipment preference and apply to ranking`).

## Task 11: `MuscleCoverage`

**Files:**
- Create: `…/Intelligence/MuscleCoverage.swift`
- Test: `…/ElosTests/Intelligence/MuscleCoverageTests.swift`

- [ ] **Step 1: Write the failing test**
```swift
import Testing
@testable import Elos

struct MuscleCoverageTests {
    private let catalog: [ExerciseCandidate] = [
        .init(id: "1", name: "Bench Press", primaryMuscle: "chest", secondaryMuscles: ["triceps"], equipment: "barbell", movementPattern: "push", isCustom: false),
        .init(id: "2", name: "Incline Press", primaryMuscle: "chest", secondaryMuscles: ["front_delts"], equipment: "dumbbell", movementPattern: "push", isCustom: false),
    ]
    @Test func uncoveredTargetReportsNone() {
        let ctx = DayContextInferrer.infer(dayName: "Push", added: [], catalog: catalog)
        let chips = MuscleCoverage.chips(context: ctx, addedCandidates: [])
        // Chips are keyed by broad MuscleGroup (.capitalized), e.g. "Chest"/"Shoulders"/"Arms" —
        // NOT individual muscles like "triceps" (which maps to the Arms group). With nothing added,
        // every target group is uncovered.
        #expect(chips.first { $0.muscleGroup == "Chest" }?.level == CoverageLevel.none)
        #expect(chips.first { $0.muscleGroup == "Arms" }?.level == CoverageLevel.none) // triceps → Arms
    }
    @Test func twoExercisesGiveGoodCoverage() {
        let added = [DayExercise(id: "1", name: "Bench Press"), DayExercise(id: "2", name: "Incline Press")]
        let ctx = DayContextInferrer.infer(dayName: "Push", added: added, catalog: catalog)
        let chips = MuscleCoverage.chips(context: ctx, addedCandidates: [catalog[0], catalog[1]])
        #expect(chips.first { $0.muscleGroup == "Chest" }?.level == CoverageLevel.good)
    }
}
```

- [ ] **Step 2: Run, verify fail.**

- [ ] **Step 3: Implement** — count added exercises whose primary (weight 1) or secondary (weight 1, but only promotes none→some) hits each target group:
```swift
import Foundation

enum CoverageLevel { case none, some, good }

struct CoverageChip: Identifiable, Equatable {
    var id: String { muscleGroup }
    let muscleGroup: String
    let level: CoverageLevel
}

enum MuscleCoverage {
    static func chips(context: DayContext, addedCandidates: [ExerciseCandidate]) -> [CoverageChip] {
        // Derive the ordered set of target groups from the context's target muscles.
        var groups: [MuscleGroup] = []
        for m in context.targetMuscles.sorted() {
            if let g = MuscleTaxonomy.group(forMuscle: m), !groups.contains(g) { groups.append(g) }
        }
        return groups.map { group in
            var primaryHits = 0, secondaryHits = 0
            for c in addedCandidates {
                if MuscleTaxonomy.group(forMuscle: c.primaryMuscle) == group { primaryHits += 1 }
                else if c.secondaryMuscles.contains(where: { MuscleTaxonomy.group(forMuscle: $0) == group }) { secondaryHits += 1 }
            }
            let level: CoverageLevel = primaryHits >= 2 ? .good
                : (primaryHits == 1 || secondaryHits >= 1) ? .some : .none
            return CoverageChip(muscleGroup: group.rawValue.capitalized, level: level)
        }
    }
}
```

- [ ] **Step 4: Run, verify pass.**

- [ ] **Step 5: Commit** (`feat(ios): MuscleCoverage chips`).

## Task 12: Coverage strip UI in the picker

Integration — build + manual verify.

**Files:** Modify `ExercisePickerView.swift`.

- [ ] **Step 1: Add a collapsible coverage strip** above `exerciseList` (line ~138), shown only when `dayContext.hasFocus`. Use `MuscleCoverage.chips(context: dayContext, addedCandidates:)` where addedCandidates are resolved from the catalog the view already has (build candidates from `dbExercises` filtered to `dayContext.addedExerciseIDs`). Render chips with ✓✓ / ✓ / ✗ glyphs and color (`Color.good` / `Color.warn` / `Color.secondary`). Tapping a chip sets `bodyPartFilter` to that group.
- [ ] **Step 2: Default expanded/collapsed** off a `@State private var coverageExpanded` (Phase 3 will seed it from guidance level; default `true` for now).
- [ ] **Step 3: Build + manual smoke** — add one chest exercise on a Push day, confirm Chest chip shows ✓ and Triceps shows ✗.
- [ ] **Step 4: Commit** (`feat(ios): live muscle-coverage strip in picker`).

## Task 13: `ExerciseOrderer`

**Files:**
- Create: `…/Intelligence/ExerciseOrderer.swift`
- Test: `…/ElosTests/Intelligence/ExerciseOrdererTests.swift`

- [ ] **Step 1: Write the failing test**
```swift
import Testing
@testable import Elos

struct ExerciseOrdererTests {
    private let catalog: [ExerciseCandidate] = [
        .init(id: "fly", name: "Cable Fly", primaryMuscle: "chest", secondaryMuscles: [], equipment: "cable", movementPattern: "isolation", isCustom: false),
        .init(id: "bench", name: "Bench Press", primaryMuscle: "chest", secondaryMuscles: ["triceps"], equipment: "barbell", movementPattern: "push", isCustom: false),
        .init(id: "pushdown", name: "Tricep Pushdown", primaryMuscle: "triceps", secondaryMuscles: [], equipment: "cable", movementPattern: "isolation", isCustom: false),
    ]
    @Test func compoundsComeFirst() {
        let day = [DayExercise(id: "fly", name: "Cable Fly"),
                   DayExercise(id: "pushdown", name: "Tricep Pushdown"),
                   DayExercise(id: "bench", name: "Bench Press")]
        let ordered = ExerciseOrderer.order(day, catalog: catalog)
        #expect(ordered.first?.id == "bench")     // only compound → first
        #expect(ordered.map { $0.id }.firstIndex(of: "bench")! < ordered.map { $0.id }.firstIndex(of: "fly")!)
    }
    @Test func unknownExercisesSinkButArePreserved() {
        let day = [DayExercise(id: "ghost", name: "Mystery Move"), DayExercise(id: "bench", name: "Bench Press")]
        let ordered = ExerciseOrderer.order(day, catalog: catalog)
        #expect(ordered.first?.id == "bench")
        #expect(ordered.count == 2)
    }
}
```

- [ ] **Step 2: Run, verify fail.**

- [ ] **Step 3: Implement** (stable sort by compound-first, then keep original relative order):
```swift
import Foundation

enum ExerciseOrderer {
    static func order(_ exercises: [DayExercise], catalog: [ExerciseCandidate]) -> [DayExercise] {
        let byID = Dictionary(catalog.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        let byName = Dictionary(catalog.map { (MuscleTaxonomy.normalize($0.name), $0) }, uniquingKeysWith: { a, _ in a })
        func rank(_ ex: DayExercise) -> Int {
            let c = byID[ex.id] ?? byName[MuscleTaxonomy.normalize(ex.name)]
            guard let c else { return 2 }                                  // unknown → last
            return MuscleTaxonomy.isCompound(movementPattern: c.movementPattern) ? 0 : 1
        }
        return exercises.enumerated()
            .sorted { a, b in
                let ra = rank(a.element), rb = rank(b.element)
                return ra == rb ? a.offset < b.offset : ra < rb           // stable
            }
            .map { $0.element }
    }
}
```

- [ ] **Step 4: Run, verify pass.**

- [ ] **Step 5: Commit** (`feat(ios): ExerciseOrderer compound-first ordering`).

## Task 14: Drag-reorder + "Sort exercises" in `CreateSplitView`

Integration — build + manual verify.

**Files:** Modify `CreateSplitView.swift`.

- [ ] **Step 1:** The per-day exercise list is currently a horizontal `ScrollView` of capsules (lines ~198–242). Add a small "Sort" button next to "Add exercises" that calls `dayExercises[i] = ExerciseOrderer.order(dayExercises[i], catalog: exerciseCatalog)` inside `withAnimation`. Show it only when `dayExercises[i].count > 1`.
- [ ] **Step 2:** Add manual reordering. The simplest robust option that fits the current capsule layout: long-press a capsule to enter a reorder mode, or add up/down "move" buttons in the per-exercise `Menu` (which already exists for sets). Add `Button("Move left")`/`Button("Move right")` that swap indices in `dayExercises[i]`. (A full drag-and-drop `List` is a larger change; the move-buttons keep the existing layout and satisfy the manual-reorder requirement. Note this deviation from "drag" in the commit.)
- [ ] **Step 3: Build + manual smoke** — add fly then bench, tap Sort, confirm bench moves first.
- [ ] **Step 4: Commit** (`feat(ios): order/reorder exercises within a split day`).

---

# Phase 3 — Intelligence

## Task 15: `SplitScaffolds`

**Files:**
- Create: `…/Intelligence/SplitScaffolds.swift`
- Test: `…/ElosTests/Intelligence/SplitScaffoldsTests.swift`

- [ ] **Step 1: Write the failing test**
```swift
import Testing
@testable import Elos

struct SplitScaffoldsTests {
    private let catalog: [ExerciseCandidate] = [
        .init(id: "bench", name: "Bench Press", primaryMuscle: "chest", secondaryMuscles: ["triceps"], equipment: "barbell", movementPattern: "push", isCustom: false),
        .init(id: "fly", name: "Cable Fly", primaryMuscle: "chest", secondaryMuscles: [], equipment: "cable", movementPattern: "isolation", isCustom: false),
        .init(id: "ohp", name: "Overhead Press", primaryMuscle: "front_delts", secondaryMuscles: ["triceps"], equipment: "barbell", movementPattern: "push", isCustom: false),
        .init(id: "lateral", name: "Lateral Raise", primaryMuscle: "side_delts", secondaryMuscles: [], equipment: "dumbbell", movementPattern: "isolation", isCustom: false),
        .init(id: "pushdown", name: "Tricep Pushdown", primaryMuscle: "triceps", secondaryMuscles: [], equipment: "cable", movementPattern: "isolation", isCustom: false),
        .init(id: "curl", name: "Leg Curl", primaryMuscle: "hamstrings", secondaryMuscles: [], equipment: "machine", movementPattern: "isolation", isCustom: false),
    ]
    private let pers = PersonalizationProvider(signals: .init())

    @Test func coversTargetMusclesCompoundFirstNoDupes() {
        let picks = SplitScaffolds.recommend(archetype: .push, catalog: catalog,
            personalization: pers, isEquipmentAvailable: { _ in true }, count: 4)
        #expect(picks.count == 4)
        #expect(Set(picks.map { $0.id }).count == 4)            // no duplicates
        #expect(picks.first?.id == "bench" || picks.first?.id == "ohp")  // a compound leads
        #expect(!picks.contains { $0.id == "curl" })            // off-archetype excluded
    }
    @Test func respectsEquipmentAvailability() {
        let picks = SplitScaffolds.recommend(archetype: .push, catalog: catalog,
            personalization: pers, isEquipmentAvailable: { $0.lowercased() != "machine" }, count: 5)
        #expect(!picks.contains { $0.id == "curl" })            // machine + off-target anyway
    }
    @Test func deterministic() {
        let a = SplitScaffolds.recommend(archetype: .push, catalog: catalog, personalization: pers, isEquipmentAvailable: { _ in true }, count: 4)
        let b = SplitScaffolds.recommend(archetype: .push, catalog: catalog, personalization: pers, isEquipmentAvailable: { _ in true }, count: 4)
        #expect(a.map { $0.id } == b.map { $0.id })
    }
}
```

- [ ] **Step 2: Run, verify fail.**

- [ ] **Step 3: Implement** — greedy: rank on-target available candidates with the engine (compound-first via the same scoring), then pick to cover each target primary muscle once before allowing a second hit. Apply `SetRepDefaults`.
```swift
import Foundation

enum SplitScaffolds {
    static func recommend(archetype: SplitArchetype, catalog: [ExerciseCandidate],
                          personalization: PersonalizationProvider,
                          isEquipmentAvailable: @escaping (String) -> Bool,
                          count: Int = 5) -> [DayExercise] {
        let targets = MuscleTaxonomy.targetMuscles(forArchetype: archetype)
        // Candidates whose primary muscle is on-target.
        let pool = catalog.filter { targets.contains(MuscleTaxonomy.normalize($0.primaryMuscle)) }
        let ctx = DayContext(dayName: archetype.rawValue, archetype: archetype, targetMuscles: targets,
                             addedPrimaryMuscles: [], addedExerciseIDs: [], addedExerciseNames: [])
        let ranked = ExerciseRankingEngine.rank(pool,
            inputs: RankingInputs(context: ctx, personalization: personalization,
                                  isEquipmentAvailable: isEquipmentAvailable, query: ""))

        var picks: [ExerciseCandidate] = []
        var coveredPrimaries = Set<String>()
        // Pass 1: one exercise per uncovered target muscle (compound-first via ranked order).
        for c in ranked where picks.count < count {
            let p = MuscleTaxonomy.normalize(c.primaryMuscle)
            if !coveredPrimaries.contains(p) { picks.append(c); coveredPrimaries.insert(p) }
        }
        // Pass 2: fill remaining slots with the next best ranked, no exact dupes.
        for c in ranked where picks.count < count {
            if !picks.contains(c) { picks.append(c) }
        }
        return picks.map { c in
            let def = SetRepDefaults.defaults(forMovementPattern: c.movementPattern)
            return DayExercise(id: c.id, name: c.name, sets: def.sets, reps: def.reps)
        }
    }
}
```

- [ ] **Step 4: Run, verify pass.**

- [ ] **Step 5: Commit** (`feat(ios): SplitScaffolds archetype auto-fill`).

## Task 16: Auto-fill UI in `CreateSplitView`

Integration — build + manual verify.

**Files:** Modify `CreateSplitView.swift`.

- [ ] **Step 1:** In `dayRow`, when `!dayIsRest[i]`, `dayExercises[i].isEmpty`, and `MuscleTaxonomy.archetype(forDayName: dayNames[i]) != nil`, show an "✨ Auto-fill recommended" button. On tap:
```swift
if let arch = MuscleTaxonomy.archetype(forDayName: dayNames[i]) {
    dayExercises[i] = SplitScaffolds.recommend(
        archetype: arch, catalog: exerciseCatalog,
        personalization: PersonalizationProvider(signals: .init()),
        isEquipmentAvailable: { (profileEquipmentPreference).isAvailable(equipment: $0) })
}
```
(Read the profile preference as in Task 10; if not readily available here, default `.fullGym`.)
- [ ] **Step 2: Build + manual smoke** — type "Push" as a day name on an empty day, tap Auto-fill, confirm 4–6 balanced exercises appear with sensible sets/reps.
- [ ] **Step 3: Commit** (`feat(ios): auto-fill recommended exercises for archetype days`).

## Task 17: `WeeklyBalanceAnalyzer`

**Files:**
- Create: `…/Intelligence/WeeklyBalanceAnalyzer.swift`
- Test: `…/ElosTests/Intelligence/WeeklyBalanceAnalyzerTests.swift`

- [ ] **Step 1: Write the failing test**
```swift
import Testing
@testable import Elos

struct WeeklyBalanceAnalyzerTests {
    private let catalog: [ExerciseCandidate] = [
        .init(id: "bench", name: "Bench Press", primaryMuscle: "chest", secondaryMuscles: [], equipment: "barbell", movementPattern: "push", isCustom: false),
        .init(id: "row", name: "Barbell Row", primaryMuscle: "back", secondaryMuscles: [], equipment: "barbell", movementPattern: "pull", isCustom: false),
    ]
    @Test func flagsLowVolumeMuscle() {
        // One day, only chest, 2 sets → chest is below the low landmark.
        let days = [[DayExercise(id: "bench", name: "Bench Press", sets: 2, reps: "8")]]
        let warnings = WeeklyBalanceAnalyzer.analyze(days: days, catalog: catalog)
        #expect(warnings.contains { $0.message.lowercased().contains("chest") })
    }
    @Test func balancedWeekHasNoPushPullWarning() {
        let days = [
            [DayExercise(id: "bench", name: "Bench Press", sets: 4, reps: "8")],
            [DayExercise(id: "row", name: "Barbell Row", sets: 4, reps: "8")],
        ]
        let warnings = WeeklyBalanceAnalyzer.analyze(days: days, catalog: catalog)
        #expect(!warnings.contains { $0.message.lowercased().contains("push") && $0.message.lowercased().contains("pull") })
    }
}
```

- [ ] **Step 2: Run, verify fail.**

- [ ] **Step 3: Implement** — tally weekly sets per group, compare to named landmarks, plus a push/pull ratio check:
```swift
import Foundation

struct BalanceWarning: Identifiable, Equatable {
    enum Severity { case info, warn }
    var id: String { message }
    let severity: Severity
    let message: String
}

enum WeeklyBalanceAnalyzer {
    static let lowSetLandmark = 10
    static let highSetLandmark = 22
    static let pushPullRatioLimit = 1.5

    static func analyze(days: [[DayExercise]], catalog: [ExerciseCandidate]) -> [BalanceWarning] {
        let byID = Dictionary(catalog.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        let byName = Dictionary(catalog.map { (MuscleTaxonomy.normalize($0.name), $0) }, uniquingKeysWith: { a, _ in a })
        func lookup(_ ex: DayExercise) -> ExerciseCandidate? { byID[ex.id] ?? byName[MuscleTaxonomy.normalize(ex.name)] }

        var setsPerGroup: [MuscleGroup: Int] = [:]
        var pushSets = 0, pullSets = 0
        for day in days {
            for ex in day {
                guard let c = lookup(ex) else { continue }
                if let g = MuscleTaxonomy.group(forMuscle: c.primaryMuscle) {
                    setsPerGroup[g, default: 0] += ex.sets
                }
                switch c.movementPattern.lowercased() {
                case "push": pushSets += ex.sets
                case "pull": pullSets += ex.sets
                default: break
                }
            }
        }

        var warnings: [BalanceWarning] = []
        for g in MuscleGroup.allCases {
            let s = setsPerGroup[g] ?? 0
            if s > 0 && s < lowSetLandmark {
                warnings.append(.init(severity: .info, message: "\(g.rawValue.capitalized): only \(s) weekly sets — consider adding volume."))
            } else if s > highSetLandmark {
                warnings.append(.init(severity: .warn, message: "\(g.rawValue.capitalized): \(s) weekly sets — that's a lot; watch recovery."))
            }
        }
        if pushSets > 0 && pullSets > 0 {
            let ratio = Double(max(pushSets, pullSets)) / Double(min(pushSets, pullSets))
            if ratio > pushPullRatioLimit {
                let heavier = pushSets > pullSets ? "push" : "pull"
                warnings.append(.init(severity: .warn, message: "Push/pull imbalance — \(heavier) volume is \(String(format: "%.1f", ratio))× the other."))
            }
        }
        return warnings
    }
}
```

- [ ] **Step 4: Run, verify pass.**

- [ ] **Step 5: Commit** (`feat(ios): WeeklyBalanceAnalyzer`).

## Task 18: `GuidanceLevel` + balance banner + adaptive verbosity

**Files:**
- Create: `…/Intelligence/GuidanceLevel.swift`
- Test: `…/ElosTests/Intelligence/GuidanceLevelTests.swift`
- Modify: `CreateSplitView.swift`, `ExercisePickerView.swift`

- [ ] **Step 1: Write the failing test**
```swift
import Testing
@testable import Elos

struct GuidanceLevelTests {
    @Test func beginnerIsFull() {
        #expect(GuidanceLevel(trainingExperience: "beginner") == .full)
    }
    @Test func intermediateAndAdvancedAreMinimal() {
        #expect(GuidanceLevel(trainingExperience: "intermediate") == .minimal)
        #expect(GuidanceLevel(trainingExperience: "advanced") == .minimal)
    }
    @Test func unknownDefaultsToFull() {
        #expect(GuidanceLevel(trainingExperience: "") == .full)
    }
}
```

- [ ] **Step 2: Run, verify fail.**

- [ ] **Step 3: Implement**
```swift
import Foundation

enum GuidanceLevel {
    case full, minimal
    init(trainingExperience: String) {
        switch trainingExperience.lowercased() {
        case "intermediate", "advanced": self = .minimal
        default: self = .full
        }
    }
}
```

- [ ] **Step 4: Run, verify pass.** Commit the engine (`feat(ios): GuidanceLevel from training experience`).

- [ ] **Step 5: Wire the balance banner.** In `CreateSplitView`, in the existing muscle-panel `Section` (line ~68), append a view that renders `WeeklyBalanceAnalyzer.analyze(days: dayExercises, catalog: exerciseCatalog)`. For `GuidanceLevel.full` show warnings inline; for `.minimal` show a single collapsed badge with the count. Read training experience the same way Task 10 reads the profile — `AppViewModel.userProfile` is a `UserProfileSnapshot` that has **no** `trainingExperience`, so do **not** use `vm.userProfile`. Instead add `@Query private var profiles: [UserProfileRecord]` to `CreateSplitView` (if not already present) and compute `GuidanceLevel(trainingExperience: profiles.first?.trainingExperience ?? "")`.

- [ ] **Step 6: Wire adaptive verbosity** in `ExercisePickerView`: seed `coverageExpanded` (Task 12) from `GuidanceLevel`. `ExercisePickerView` has no `vm.userProfile`; source the experience from the `@Query private var profiles: [UserProfileRecord]` added in Task 10 — `GuidanceLevel(trainingExperience: profiles.first?.trainingExperience ?? "")` → `.full` expands the strip, `.minimal` collapses it.

- [ ] **Step 7: Build + manual smoke** — build a lopsided week (all pressing) and confirm a push/pull warning shows; confirm a beginner profile sees expanded coverage and inline warnings, an advanced profile sees the collapsed badge.

- [ ] **Step 8: Commit** (`feat(ios): adaptive guidance — balance banner + verbosity by experience`).

---

## Final verification

- [ ] **Run the full unit suite:**
```bash
xcodebuild test -project apps/elos-mobile/Elos/Elos.xcodeproj -scheme Elos \
  -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | tail -30
```
Expected: `** TEST SUCCEEDED **`, all `Intelligence/*Tests` green.

- [ ] **Manual end-to-end:** Create a "Push / Pull / Legs" split using auto-fill for each day; confirm Smart Sort ordering, coverage chips, equipment preference effect, reorder, and the weekly balance banner all behave per the spec.

- [ ] **Update the memory** note (`equipment-machine-tracking.md` / a new `exercise-sort-intelligence.md`) with the engine layout and the `Intelligence/` folder convention.
