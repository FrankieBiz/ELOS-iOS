# Priority-Aware Exercise Sort Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let a user pick a muscle-group training priority (or "Overall Best Growth") in the template
and split builders, and re-sort that day's exercises so the priority muscle's work leads — while fixing
the underlying order-quality score so using the feature never lowers it.

**Architecture:** Extend one existing pure engine (`ExerciseOrderer`) with an optional `priority`
parameter that partitions exercises before applying the existing compound-before-isolation sort within
each partition; fix a scoring inconsistency in another existing pure engine (`FatigueModel.orderQuality`)
so it only penalizes same-muscle order inversions; add one small shared SwiftUI menu component; wire it
into two existing builder screens.

**Tech Stack:** Swift, SwiftUI, SwiftData, Swift Testing (`@testable import Elos`, `#expect`).

**Spec:** `docs/superpowers/specs/2026-08-11-priority-exercise-sort-design.md` — read this first for the
full rationale. This plan implements it section-by-section; section references (§4.1 etc.) below point
back to it.

**Working directory for all commands in this plan:** `apps/elos-mobile/Elos` (the Xcode project root).
All file paths below are relative to that directory unless stated otherwise.

**Build command** (authoritative — SourceKit/IDE squiggles are not; this repo's sandboxed environment
needs the `-disable-sandbox` flag for macro plugins to resolve):
```bash
xcodebuild build -scheme Elos -destination 'generic/platform=iOS Simulator' -quiet OTHER_SWIFT_FLAGS='$(inherited) -disable-sandbox'
```

**Test command** (compiles the test target; running the test *bodies* requires a booted simulator with a
pty, which a sandboxed session doesn't have — this plan's "run test" steps assume a normal, non-sandboxed
terminal or the user running them; if you're in a sandboxed session, compile with `build-for-testing` and
ask the user to run the actual suite):
```bash
xcodebuild test -scheme Elos -destination 'platform=iOS Simulator,name=iPhone 17' -quiet OTHER_SWIFT_FLAGS='$(inherited) -disable-sandbox' -only-testing:ElosTests/ExerciseOrdererTests -only-testing:ElosTests/FatigueModelTests
```
(Swap `-only-testing` targets per task; drop it entirely for a full-suite run in the final task.)

---

## File Structure

| File | Change |
|---|---|
| `Elos/Features/Train/Programs/Intelligence/ExerciseOrderer.swift` | Modify — add `priority: MuscleGroup? = nil` param |
| `ElosTests/Intelligence/ExerciseOrdererTests.swift` | Modify — already exists with 2 tests (`compoundsComeFirst`, `unknownExercisesSinkButArePreserved`); extend its shared `catalog` and add new priority tests alongside them |
| `Elos/Features/Train/Programs/Intelligence/FatigueModel.swift` | Modify — `orderQuality` scoring fix, drop `sharesPrimaryMuscle` |
| `Elos/Features/Train/Programs/Intelligence/FatigueScorer.swift` | Modify — line 50, `.first(where:)` → `.first` |
| `ElosTests/Intelligence/FatigueModelTests.swift` | Modify — rewrite one test, drop one assertion line, add one new test |
| `Elos/Features/Train/PriorityMenu.swift` | Create — shared `Menu` component, visible to both builders (sibling to their `Programs/`/`Templates/` subfolders) |
| `Elos/Features/Train/Templates/CreateTemplateView.swift` | Modify — new Sort header row above exercise list; extract shared re-mapping helper |
| `Elos/Features/Train/Programs/CreateSplitView.swift` | Modify — "Weekly Schedule" section header gets a trailing bulk-sort menu |

No SwiftData schema changes, no new files outside the above, no backend/network changes (per spec §3, §5).

---

## Task 1: Extend `ExerciseOrderer` with a priority parameter

**Files:**
- Modify: `Elos/Features/Train/Programs/Intelligence/ExerciseOrderer.swift`
- Modify: `ElosTests/Intelligence/ExerciseOrdererTests.swift`

`ExerciseOrdererTests.swift` already exists with a shared `catalog` and two tests
(`compoundsComeFirst`, `unknownExercisesSinkButArePreserved`) — **do not overwrite it.** Step 1 adds a
stub so the target keeps compiling while the new tests (which describe the *target* behavior) are added
alongside the existing ones, then Step 3 implements the real logic.

- [ ] **Step 1: Add the `priority` parameter with a passthrough stub (keeps target compiling)**

Replace the full contents of `ExerciseOrderer.swift` with:

```swift
import Foundation

enum ExerciseOrderer {
    static func order(_ exercises: [DayExercise], catalog: [ExerciseCandidate],
                       priority: MuscleGroup? = nil) -> [DayExercise] {
        let byID = Dictionary(catalog.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        let byName = Dictionary(catalog.map { (MuscleTaxonomy.normalize($0.name), $0) }, uniquingKeysWith: { a, _ in a })
        func rank(_ ex: DayExercise) -> Int {
            let c = byID[ex.id] ?? byName[MuscleTaxonomy.normalize(ex.name)]
            guard let c else { return 2 }
            return MuscleTaxonomy.isCompound(movementPattern: c.movementPattern) ? 0 : 1
        }
        func sorted(_ items: [DayExercise]) -> [DayExercise] {
            items.enumerated()
                .sorted { a, b in
                    let ra = rank(a.element), rb = rank(b.element)
                    return ra == rb ? a.offset < b.offset : ra < rb
                }
                .map { $0.element }
        }
        // STUB: priority is accepted but ignored for now — Task 1 Step 3 implements partitioning.
        return sorted(exercises)
    }
}
```

This is a pure refactor of the existing code (the old body extracted into a local `sorted(_:)` helper)
plus a new no-op parameter — behavior is unchanged from before this step.

- [ ] **Step 2: Build to confirm the stub compiles**

Run: `xcodebuild build -scheme Elos -destination 'generic/platform=iOS Simulator' -quiet OTHER_SWIFT_FLAGS='$(inherited) -disable-sandbox'`
Expected: `BUILD SUCCEEDED` (or silent success — `-quiet` suppresses non-error output).

- [ ] **Step 3: Extend the existing test file (new tests will fail against the stub)**

Replace the *entire* contents of `ElosTests/Intelligence/ExerciseOrdererTests.swift` with the following
— it keeps both existing tests verbatim, extends the shared `catalog` with entries the new tests need
(quads/biceps/triceps movements), and adds the new priority tests after the existing two:

```swift
import Testing
@testable import Elos

struct ExerciseOrdererTests {
    private let catalog: [ExerciseCandidate] = [
        .init(id: "fly", name: "Cable Fly", primaryMuscle: "chest", secondaryMuscles: [], equipment: "cable", movementPattern: "isolation", isCustom: false),
        .init(id: "bench", name: "Bench Press", primaryMuscle: "chest", secondaryMuscles: ["triceps"], equipment: "barbell", movementPattern: "push", isCustom: false),
        .init(id: "pushdown", name: "Tricep Pushdown", primaryMuscle: "triceps", secondaryMuscles: [], equipment: "cable", movementPattern: "isolation", isCustom: false),
        .init(id: "curl", name: "Bicep Curl", primaryMuscle: "biceps", secondaryMuscles: [], equipment: "dumbbell", movementPattern: "isolation", isCustom: false),
        .init(id: "closegrip", name: "Close-Grip Bench", primaryMuscle: "triceps", secondaryMuscles: ["chest"], equipment: "barbell", movementPattern: "push", isCustom: false),
        .init(id: "squat", name: "Squat", primaryMuscle: "quads", secondaryMuscles: [], equipment: "barbell", movementPattern: "squat", isCustom: false),
        .init(id: "legext", name: "Leg Extension", primaryMuscle: "quads", secondaryMuscles: [], equipment: "machine", movementPattern: "isolation", isCustom: false),
    ]
    @Test func compoundsComeFirst() {
        let day = [DayExercise(id: "fly", name: "Cable Fly"),
                   DayExercise(id: "pushdown", name: "Tricep Pushdown"),
                   DayExercise(id: "bench", name: "Bench Press")]
        let ordered = ExerciseOrderer.order(day, catalog: catalog)
        #expect(ordered.first?.id == "bench")
        #expect(ordered.map { $0.id }.firstIndex(of: "bench")! < ordered.map { $0.id }.firstIndex(of: "fly")!)
    }
    @Test func unknownExercisesSinkButArePreserved() {
        let day = [DayExercise(id: "ghost", name: "Mystery Move"), DayExercise(id: "bench", name: "Bench Press")]
        let ordered = ExerciseOrderer.order(day, catalog: catalog)
        #expect(ordered.first?.id == "bench")
        #expect(ordered.count == 2)
    }

    // MARK: Priority partitioning

    @Test func priorityGroupExercisesPrecedeEverythingElse() {
        let day = [DayExercise(id: "squat", name: "Squat"),
                   DayExercise(id: "curl", name: "Bicep Curl"),
                   DayExercise(id: "closegrip", name: "Close-Grip Bench")]
        let ordered = ExerciseOrderer.order(day, catalog: catalog, priority: .arms)
        let ids = ordered.map(\.id)
        // Arms exercises (curl, closegrip) first, quads (squat) last — regardless of compound-ness.
        #expect(Set(ids.prefix(2)) == Set(["curl", "closegrip"]))
        #expect(ids.last == "squat")
    }

    @Test func compoundBeforeIsolationHoldsWithinThePriorityGroup() {
        let day = [DayExercise(id: "curl", name: "Bicep Curl"),
                   DayExercise(id: "closegrip", name: "Close-Grip Bench"),
                   DayExercise(id: "squat", name: "Squat")]
        let ordered = ExerciseOrderer.order(day, catalog: catalog, priority: .arms)
        // Both arm exercises lead; the compound one (closegrip) leads *within* that group.
        #expect(ordered.map(\.id) == ["closegrip", "curl", "squat"])
    }

    @Test func compoundBeforeIsolationHoldsWithinTheRestGroup() {
        let day = [DayExercise(id: "curl", name: "Bicep Curl"),
                   DayExercise(id: "legext", name: "Leg Extension"),
                   DayExercise(id: "squat", name: "Squat")]
        let ordered = ExerciseOrderer.order(day, catalog: catalog, priority: .arms)
        // curl (arms) leads. Among the rest, squat (compound) leads legext (isolation).
        #expect(ordered.map(\.id) == ["curl", "squat", "legext"])
    }

    @Test func priorityWithNoMatchesBehavesLikeNoPriority() {
        let day = [DayExercise(id: "curl", name: "Bicep Curl"),
                   DayExercise(id: "bench", name: "Bench Press")]
        // Nothing here is a legs exercise — .legs priority should be a no-op vs. nil. DayExercise
        // isn't Equatable, so compare the id sequence rather than the arrays directly.
        let withPriority = ExerciseOrderer.order(day, catalog: catalog, priority: .legs)
        let withoutPriority = ExerciseOrderer.order(day, catalog: catalog, priority: nil)
        #expect(withPriority.map(\.id) == withoutPriority.map(\.id))
    }

    @Test func priorityGroupOrderIsStableAmongEqualRank() {
        let day = [DayExercise(id: "curl", name: "Bicep Curl"),
                   DayExercise(id: "pushdown", name: "Tricep Pushdown"),
                   DayExercise(id: "bench", name: "Bench Press")]
        let ordered = ExerciseOrderer.order(day, catalog: catalog, priority: .arms)
        // curl and pushdown are both arms, both isolation (equal rank) — relative order must survive.
        #expect(ordered.map(\.id) == ["curl", "pushdown", "bench"])
    }
}
```

- [ ] **Step 4: Run the tests to confirm the expected pass/fail split against the stub**

Run: `xcodebuild test -scheme Elos -destination 'platform=iOS Simulator,name=iPhone 17' -quiet OTHER_SWIFT_FLAGS='$(inherited) -disable-sandbox' -only-testing:ElosTests/ExerciseOrdererTests`
Expected: the two pre-existing tests (`compoundsComeFirst`, `unknownExercisesSinkButArePreserved`) PASS,
unaffected by this change. Of the five new tests, `priorityWithNoMatchesBehavesLikeNoPriority` also
PASSES against the stub (trivially — the stub ignores `priority` for both calls, so the two results are
identical by construction; this is a real invariant to keep testing, it just doesn't distinguish stub
from real). The other four new tests FAIL: the stub ignores `priority` entirely, so a `.arms`-prioritized
day still comes back in plain compound-first order with no arm exercises pulled to the front.

*(If running in a sandboxed session with no simulator pty available, skip running and instead read
through each test by hand against the Step 1 stub to confirm the expected pass/fail split, then proceed
— note this explicitly when reporting the step.)*

- [ ] **Step 5: Implement real partitioning (§4.1)**

Replace the stub body in `ExerciseOrderer.swift` with the full implementation:

```swift
import Foundation

enum ExerciseOrderer {
    static func order(_ exercises: [DayExercise], catalog: [ExerciseCandidate],
                       priority: MuscleGroup? = nil) -> [DayExercise] {
        let byID = Dictionary(catalog.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        let byName = Dictionary(catalog.map { (MuscleTaxonomy.normalize($0.name), $0) }, uniquingKeysWith: { a, _ in a })
        func rank(_ ex: DayExercise) -> Int {
            let c = byID[ex.id] ?? byName[MuscleTaxonomy.normalize(ex.name)]
            guard let c else { return 2 }
            return MuscleTaxonomy.isCompound(movementPattern: c.movementPattern) ? 0 : 1
        }
        func sorted(_ items: [DayExercise]) -> [DayExercise] {
            items.enumerated()
                .sorted { a, b in
                    let ra = rank(a.element), rb = rank(b.element)
                    return ra == rb ? a.offset < b.offset : ra < rb
                }
                .map { $0.element }
        }

        guard let priority else { return sorted(exercises) }

        // Resolve each exercise's muscle group through the same chain FatigueModel/TemplateQualityEngine
        // use, so "which group is this for" never disagrees with the rest of the Intelligence layer.
        let scored = exercises.map { ScoredExercise(day: $0) }
        let resolved = ExerciseResolver.resolve([scored], catalog: catalog).first ?? []

        var priorityGroup: [DayExercise] = []
        var rest: [DayExercise] = []
        for (exercise, resolvedExercise) in zip(exercises, resolved) {
            if resolvedExercise.muscleGroup == priority {
                priorityGroup.append(exercise)
            } else {
                rest.append(exercise)
            }
        }
        return sorted(priorityGroup) + sorted(rest)
    }
}
```

- [ ] **Step 6: Run the tests again to confirm they now pass**

Run: `xcodebuild test -scheme Elos -destination 'platform=iOS Simulator,name=iPhone 17' -quiet OTHER_SWIFT_FLAGS='$(inherited) -disable-sandbox' -only-testing:ElosTests/ExerciseOrdererTests`
Expected: all 7 tests PASS (2 pre-existing + 5 new).

- [ ] **Step 7: Commit**

```bash
git add Elos/Features/Train/Programs/Intelligence/ExerciseOrderer.swift ElosTests/Intelligence/ExerciseOrdererTests.swift
git commit -m "feat(train): add muscle-group priority to ExerciseOrderer"
```

---

## Task 2: Fix `FatigueModel.orderQuality` scoring + update `FatigueScorer`

**Files:**
- Modify: `Elos/Features/Train/Programs/Intelligence/FatigueModel.swift`
- Modify: `Elos/Features/Train/Programs/Intelligence/FatigueScorer.swift`
- Modify: `ElosTests/Intelligence/FatigueModelTests.swift`

Per spec §4.2/§6/§7: this fix changes two existing tests' expected behavior on purpose (not a
regression to chase down) — `isolationBeforeACompoundIsPenalised` drops one assertion line, and
`anUnrelatedIsolationIsNotFlaggedAsSameMuscle` gets rewritten. Confirmed against current source: these
are the *only* two places `sharesPrimaryMuscle` is referenced in the test suite, and `FatigueScorer.swift:50`
is the only production call site outside `FatigueModel.swift` itself.

- [ ] **Step 1: Update the two existing tests to their new expected behavior**

In `ElosTests/Intelligence/FatigueModelTests.swift`, change `isolationBeforeACompoundIsPenalised`
(currently lines 101-109) to drop its last assertion:

```swift
    @Test func isolationBeforeACompoundIsPenalised() {
        let day = [ex("Leg Extension", sets: 3, compound: false, primary: [.quads]),
                   ex("Squat", sets: 3, compound: true, primary: [.quads])]
        let report = FatigueModel.orderQuality(day: day)
        #expect(report.quality < 1.0)
        #expect(report.inversions.count == 1)
    }
```

Change `anUnrelatedIsolationIsNotFlaggedAsSameMuscle` (currently lines 111-115) to assert the new
behavior — a cross-muscle pair is no longer counted as an inversion at all:

```swift
    @Test func anUnrelatedIsolationIsNotCountedAsAnInversion() {
        let day = [ex("Curl", sets: 3, compound: false, primary: [.biceps]),
                   ex("Squat", sets: 3, compound: true, primary: [.quads])]
        let report = FatigueModel.orderQuality(day: day)
        #expect(report.inversions.isEmpty)
        #expect(report.quality == 1.0)
    }
```

Add one new test right after it, covering the mixed case the spec calls out in §7:

```swift
    @Test func qualityCountsOnlySameMuscleInversions() {
        // Curl-before-Squat: different muscles, doesn't count. Leg-Extension-before-Squat: same
        // muscle (quads), counts. Quality should reflect only the second pair.
        let day = [ex("Curl", sets: 3, compound: false, primary: [.biceps]),
                   ex("Leg Extension", sets: 3, compound: false, primary: [.quads]),
                   ex("Squat", sets: 3, compound: true, primary: [.quads])]
        let report = FatigueModel.orderQuality(day: day)
        #expect(report.inversions.count == 1)
        #expect(report.inversions.first?.isolationName == "Leg Extension")
        #expect(report.quality == 0.0)  // the one same-muscle pair, and it's inverted
    }
```

- [ ] **Step 2: Run the FatigueModel tests to confirm the expected failures**

Run: `xcodebuild test -scheme Elos -destination 'platform=iOS Simulator,name=iPhone 17' -quiet OTHER_SWIFT_FLAGS='$(inherited) -disable-sandbox' -only-testing:ElosTests/FatigueModelTests`
Expected: `isolationBeforeACompoundIsPenalised` still PASSES (nothing about its remaining assertions
changed). `anUnrelatedIsolationIsNotCountedAsAnInversion` and `qualityCountsOnlySameMuscleInversions` FAIL
against the current (unfixed) `orderQuality` — the first because `inversions` is currently non-empty for
a cross-muscle pair, the second because `quality` currently double-counts the unrelated pair in its
denominator.

*(Same sandboxed-session caveat as Task 1 Step 4 — verify by reading against current source if no
simulator is available.)*

- [ ] **Step 3: Implement the scoring fix (§4.2)**

In `FatigueModel.swift`, replace the `OrderInversion` struct (currently lines 64-70) — drop
`sharesPrimaryMuscle`:

```swift
    struct OrderInversion: Equatable {
        let isolationName: String
        let compoundName: String
    }
```

Replace `orderQuality` (currently lines 83-110) with the fixed version — denominator and inversion list
both restricted to same-muscle pairs, and the now-dead same-muscle-first sort removed:

```swift
    /// Compounds first, isolation after, among exercises that train the same muscle — an isolation
    /// exercise for a *different* muscle costs the compound nothing, so it was never really a same-day
    /// ordering problem. Scored as the fraction of same-muscle compound/isolation pairs that are in the
    /// right order, so one stray curl at the top of a long day is a small ding rather than a cliff, and
    /// a fully inverted same-muscle day scores 0.
    static func orderQuality(day: [ResolvedExercise]) -> OrderReport {
        let compoundIdx = day.indices.filter { day[$0].isCompound }
        let isolationIdx = day.indices.filter { !day[$0].isCompound }
        // Nothing to order: all one type, or fewer than two exercises.
        guard !compoundIdx.isEmpty, !isolationIdx.isEmpty else { return .perfect }

        var samePairs = 0
        var inversions: [OrderInversion] = []
        for c in compoundIdx {
            for i in isolationIdx {
                let iso = day[i], comp = day[c]
                let shared = !iso.targets.primary.isEmpty
                    && !comp.targets.primary.isEmpty
                    && !Set(iso.targets.primary).isDisjoint(with: Set(comp.targets.primary))
                guard shared else { continue }
                samePairs += 1
                if i < c {
                    inversions.append(OrderInversion(isolationName: iso.exercise.name,
                                                     compoundName: comp.exercise.name))
                }
            }
        }

        let quality = samePairs > 0
            ? 1.0 - Double(inversions.count) / Double(samePairs)
            : 1.0

        return OrderReport(quality: min(1, max(0, quality)), inversions: inversions)
    }
```

- [ ] **Step 4: Update the one production call site**

In `FatigueScorer.swift`, line 50, change:
```swift
            if let bad = f.order.inversions.first(where: { $0.sharesPrimaryMuscle }), tips.count < maxTips {
```
to:
```swift
            if let bad = f.order.inversions.first, tips.count < maxTips {
```
(Every remaining inversion is same-muscle by construction now, so the filter is redundant.)

- [ ] **Step 5: Build to confirm nothing else references the dropped field**

Run: `xcodebuild build -scheme Elos -destination 'generic/platform=iOS Simulator' -quiet OTHER_SWIFT_FLAGS='$(inherited) -disable-sandbox'`
Expected: `BUILD SUCCEEDED`. (Confirmed during spec review that `FatigueModel.swift` and
`FatigueScorer.swift:50` are the only production references to `sharesPrimaryMuscle` — if the build
surfaces any other reference, that's new since the spec was written; fix it the same way.)

- [ ] **Step 6: Run the full `FatigueModelTests` suite to confirm everything passes**

Run: `xcodebuild test -scheme Elos -destination 'platform=iOS Simulator,name=iPhone 17' -quiet OTHER_SWIFT_FLAGS='$(inherited) -disable-sandbox' -only-testing:ElosTests/FatigueModelTests`
Expected: all tests in the file PASS, including the untouched ones
(`aFreshSetIsWorthFullValue`, `aFullyInvertedDayScoresZero`, etc. — per spec §6, these are unaffected
since their fixtures are same-muscle by default).

- [ ] **Step 7: Commit**

```bash
git add Elos/Features/Train/Programs/Intelligence/FatigueModel.swift Elos/Features/Train/Programs/Intelligence/FatigueScorer.swift ElosTests/Intelligence/FatigueModelTests.swift
git commit -m "fix(train): order-quality score only penalizes same-muscle inversions"
```

---

## Task 3: Build the shared `PriorityMenu` component

**Files:**
- Create: `Elos/Features/Train/PriorityMenu.swift`

This is a plain SwiftUI view with no logic to unit test (per spec §7, "views get no new logic beyond
wiring a menu selection to an existing call") — no test file for this task, consistent with how the
existing Sort button isn't tested either.

- [ ] **Step 1: Write the component**

Create `Elos/Features/Train/PriorityMenu.swift`:

```swift
import SwiftUI

/// Shared entry point for the priority-aware exercise sort (see `ExerciseOrderer.order(priority:)`).
/// Presents "Overall Best Growth" plus every `MuscleGroup`; both the template builder's per-workout
/// sort and the split builder's bulk "auto-order all days" action open this same menu so there's one
/// place that defines what a training priority *is*, not two menus that could drift apart.
struct PriorityMenu<Label: View>: View {
    let onSelect: (MuscleGroup?) -> Void
    @ViewBuilder let label: () -> Label

    var body: some View {
        Menu {
            Button("Overall Best Growth") { onSelect(nil) }
            ForEach(MuscleGroup.allCases, id: \.self) { group in
                Button(group.displayName) { onSelect(group) }
            }
        } label: {
            label()
        }
    }
}
```

- [ ] **Step 2: Build to confirm it compiles**

Run: `xcodebuild build -scheme Elos -destination 'generic/platform=iOS Simulator' -quiet OTHER_SWIFT_FLAGS='$(inherited) -disable-sandbox'`
Expected: `BUILD SUCCEEDED`. (Nothing references `PriorityMenu` yet, so this only checks the file itself
is syntactically and type-valid — Swift doesn't warn on unused non-`private` types.)

- [ ] **Step 3: Commit**

```bash
git add Elos/Features/Train/PriorityMenu.swift
git commit -m "feat(train): add shared PriorityMenu component"
```

---

## Task 4: Wire `CreateTemplateView` (primary entry point, §4.4)

**Files:**
- Modify: `Elos/Features/Train/Templates/CreateTemplateView.swift`

No new automated tests for this task (UI wiring only, per spec §7) — verify with the manual smoke check
in Task 6.

- [ ] **Step 1: Extract the re-mapping logic into a priority-parameterized helper**

`reorderCompoundsFirst()` (currently lines 327-344) builds `asDays`, calls `ExerciseOrderer.order`, then
re-maps the ordered names back to real `TemplateExerciseEntry` values. Replace it with a shared helper
plus a thin wrapper that preserves the existing `.reorder` tip call site unchanged:

```swift
    /// Re-sorts `exercises` via `ExerciseOrderer`, preserving each entry's settings. Shared by the
    /// "poor order" tip's fix action (no priority — see §4.6 of the design spec) and the new priority
    /// menu below (§4.4), so the name-matching re-map logic exists in exactly one place.
    private func reorder(priority: MuscleGroup?) {
        let asDays = exercises.map {
            DayExercise(id: $0.exerciseID ?? "", name: $0.exerciseName,
                        sets: $0.targetSets, reps: $0.targetReps)
        }
        let ordered = ExerciseOrderer.order(asDays, catalog: exerciseCatalog, priority: priority)
        // Re-sort the real entries to match the ordered names, keeping any unmatched ones at the end.
        var remaining = exercises
        var result: [TemplateExerciseEntry] = []
        for d in ordered {
            let key = MuscleTaxonomy.normalize(d.name)
            if let i = remaining.firstIndex(where: { MuscleTaxonomy.normalize($0.exerciseName) == key }) {
                result.append(remaining.remove(at: i))
            }
        }
        result.append(contentsOf: remaining)
        withAnimation(.elosEmphasis) { exercises = result }
    }

    /// Apply `ExerciseOrderer` (compound-first, no priority) — the "poor order" tip's fix action has no
    /// context on which muscle the user cares about, so it always uses the default sort.
    private func reorderCompoundsFirst() {
        reorder(priority: nil)
    }
```

- [ ] **Step 2: Build to confirm the refactor alone compiles and changes nothing**

Run: `xcodebuild build -scheme Elos -destination 'generic/platform=iOS Simulator' -quiet OTHER_SWIFT_FLAGS='$(inherited) -disable-sandbox'`
Expected: `BUILD SUCCEEDED`. This step is a pure refactor — `reorderCompoundsFirst()` still exists with
the same behavior, still called only from the `.reorder` tip action (line 308); nothing else changed yet.

- [ ] **Step 3: Add the new Sort header row above the exercise list**

Find the exercise-cards `ForEach` (currently lines 416-426, right after the Quality Coach `Section`).
Insert a new row immediately before it:

```swift
                    // Priority sort — only useful with 2+ exercises to actually reorder.
                    if exercises.count > 1 {
                        HStack {
                            Text("Sort").elosSectionLabel()
                            Spacer()
                            PriorityMenu(onSelect: { reorder(priority: $0) }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "arrow.up.arrow.down")
                                        .font(.caption2)
                                    Text("Sort by priority")
                                        .font(.caption2)
                                }
                                .foregroundStyle(Color.tint)
                                .padding(.horizontal, 8).padding(.vertical, 4)
                                .background(Color.tint.opacity(0.1))
                                .clipShape(Capsule())
                            }
                        }
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(.init(top: 4, leading: 16, bottom: 4, trailing: 16))
                    }

                    // Exercise cards
                    ForEach($exercises) { $ex in
```

(Styling matches the existing per-day "Sort" chip in `CreateSplitView.swift:406-419` — same icon, same
capsule treatment — so the two builders' sort affordances read as the same control, just one is a plain
sort and this one opens the priority menu.)

- [ ] **Step 4: Build**

Run: `xcodebuild build -scheme Elos -destination 'generic/platform=iOS Simulator' -quiet OTHER_SWIFT_FLAGS='$(inherited) -disable-sandbox'`
Expected: `BUILD SUCCEEDED`.

- [ ] **Step 5: Commit**

```bash
git add Elos/Features/Train/Templates/CreateTemplateView.swift
git commit -m "feat(train): add priority sort menu to the template builder"
```

---

## Task 5: Wire `CreateSplitView` bulk action (§4.5)

**Files:**
- Modify: `Elos/Features/Train/Programs/CreateSplitView.swift`

- [ ] **Step 1: Give the "Weekly Schedule" section a custom header with a trailing menu**

Replace the plain-string section (currently lines 99-103):

```swift
                Section("Weekly Schedule") {
                    ForEach(0..<7, id: \.self) { i in
                        dayRow(index: i)
                    }
                }
```

with a custom header:

```swift
                Section {
                    ForEach(0..<7, id: \.self) { i in
                        dayRow(index: i)
                    }
                } header: {
                    HStack {
                        Text("Weekly Schedule")
                        Spacer()
                        PriorityMenu(onSelect: { autoOrderAllDays(priority: $0) }) {
                            Label("Auto-order all days", systemImage: "arrow.up.arrow.down")
                                .font(.caption)
                                .labelStyle(.iconOnly)
                        }
                    }
                }
```

(`.labelStyle(.iconOnly)` keeps the section header compact — a `Form` section header is a tight space,
unlike the template builder's dedicated row from Task 4. `accessibilityLabel` isn't lost: `Label` still
carries "Auto-order all days" for VoiceOver even with the icon-only visual style.)

- [ ] **Step 2: Add the bulk-order method**

Add this method near `dayRow` (or any private-methods section of the view):

```swift
    /// Applies one priority to every non-rest, non-empty day in the split at once — separate from the
    /// per-day "Sort" button inside `dayRow`, which stays a single-day, no-priority action.
    private func autoOrderAllDays(priority: MuscleGroup?) {
        withAnimation(.elosEmphasis) {
            for i in dayExercises.indices where !dayIsRest[i] && !dayExercises[i].isEmpty {
                dayExercises[i] = ExerciseOrderer.order(dayExercises[i], catalog: exerciseCatalog, priority: priority)
            }
        }
    }
```

- [ ] **Step 3: Build**

Run: `xcodebuild build -scheme Elos -destination 'generic/platform=iOS Simulator' -quiet OTHER_SWIFT_FLAGS='$(inherited) -disable-sandbox'`
Expected: `BUILD SUCCEEDED`.

- [ ] **Step 4: Commit**

```bash
git add Elos/Features/Train/Programs/CreateSplitView.swift
git commit -m "feat(train): add bulk priority-sort action to the split builder"
```

---

## Task 6: Full verification pass

**Files:** none (verification only)

- [ ] **Step 1: Full build**

Run: `xcodebuild build -scheme Elos -destination 'generic/platform=iOS Simulator' -quiet OTHER_SWIFT_FLAGS='$(inherited) -disable-sandbox'`
Expected: `BUILD SUCCEEDED`.

- [ ] **Step 2: Full test-target compile**

Run: `xcodebuild build-for-testing -scheme Elos -destination 'generic/platform=iOS Simulator' -quiet OTHER_SWIFT_FLAGS='$(inherited) -disable-sandbox'`
Expected: `** TEST BUILD SUCCEEDED **`.

- [ ] **Step 3: Full test suite**

Run: `xcodebuild test -scheme Elos -destination 'platform=iOS Simulator,name=iPhone 17' -quiet OTHER_SWIFT_FLAGS='$(inherited) -disable-sandbox'`
Expected: all tests pass, including the pre-existing suites untouched by this feature (regression check).
If this session is sandboxed and can't run tests (no pty for the simulator), hand this step to the user
explicitly rather than claiming it passed.

- [ ] **Step 4: Manual smoke check — template builder**

In the simulator: open Train → Templates → create or edit a template with 3+ exercises spanning at
least two muscle groups. Tap "Sort by priority" → pick a specific muscle group. Confirm: that muscle's
exercise(s) move to the top of the list; picking "Overall Best Growth" afterward restores plain
compound-first order.

- [ ] **Step 5: Manual smoke check — split builder**

In the simulator: open Train → Programs → create or edit a split with 2+ days populated with exercises.
Tap the "Weekly Schedule" header's sort icon → pick a muscle group. Confirm every populated, non-rest
day reorders; a rest day or an empty day is untouched (no crash, nothing to reorder).

- [ ] **Step 6: Manual smoke check — quality score doesn't regress**

In either builder, open the quality report for a day that has a priority-sorted, cross-muscle exercise
order (e.g. an arm isolation exercise sitting ahead of an unrelated leg compound). Confirm the "order"
dimension doesn't flag it — this is the Goal 4 guarantee from the spec, and the one thing that can't be
caught by a unit test alone since it depends on the full `TemplateQualityEngine`/`SplitQualityReportView`
pipeline the fix feeds into.

- [ ] **Step 7: Final commit (if any smoke-check fixes were needed) or confirm clean**

```bash
git status --short
```
Expected: clean (nothing to commit) if no smoke-check issues required fixes; if issues were found and
fixed in prior steps, commit those fixes individually with their own descriptive messages rather than
bundling here.
