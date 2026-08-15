# Quality Coach: Auto-Fix + Honest Per-Day Skips Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the per-day "Skip muscles" control actually change what the lifter sees (Phase 1),
then let every mechanically-fixable quality-coach suggestion be resolved with one tap, previewed,
confirmed or denied (Phase 2).

**Architecture:** Pure value-type engine additions under `Features/Train/Programs/Intelligence/`
(unit-tested with Swift Testing, no SwiftUI/SwiftData coupling), consumed by two existing builder
views (`CreateSplitView`, `CreateTemplateView`) that already hold everything as local `@State` and
never touch SwiftData until Save. No backend, schema, or `packages/elos-shared` change anywhere in
this plan.

**Tech Stack:** Swift, SwiftUI, SwiftData (untouched), Swift Testing.

**Spec:** `docs/superpowers/specs/2026-08-14-quality-autofix-and-day-skip-design.md` — read section
references (`§1.1`, `§2.3`, etc.) inline below; this plan does not repeat type definitions the spec
already gives verbatim, it tells you exactly which task installs them and how to verify each step.

**Verification reality (confirmed live, do not relitigate):** `xcodebuild build-for-testing
-project Elos.xcodeproj -scheme Elos -destination 'platform=iOS Simulator,name=iPhone 17'
OTHER_SWIFT_FLAGS='$(inherited) -disable-sandbox'` compiles cleanly and is the authoritative
compile check. `xcodebuild test` fails in this sandbox with a `Pseudo Terminal Setup Error` — do
not debug that error, it's environmental. Every task below verifies logic via a **swiftc harness**:
copy the touched `Intelligence/*.swift` files (+ `Programs/SplitHelpers.swift` when `DayExercise`
is involved) into `$TMPDIR/qfix-harness/`, add a small shim file defining only the two SwiftData
types the `init(record:)` adapters touch (`UserProfileRecord { trainingGoal, trainingExperience }`,
`ExerciseDefinitionRecord { id, name, primaryMuscle, secondaryMuscles, equipment, movementPattern,
isCustom }`), write the test assertions as a plain `main.swift` using `assert(...)` (Swift Testing's
`@Test`/`#expect` macros are not available outside the Xcode toolchain's test bundle in a bare
`swiftc` invocation — pin the harness to bare `assert`), then `swiftc -o harness *.swift &&
./harness`. **Also add the real Swift Testing file** to `ElosTests/Intelligence/` in the same task
— it won't run here, but it compiles under `build-for-testing` and is what runs in CI / on a real
machine. Every task's "run test" step therefore has two parts: the harness (proves the logic here,
now) and `build-for-testing` (proves the Testing-framework file compiles).

---

# Phase 1 — Honest per-day skips

## Task 1: `TemplateQualityEngine.score` — weekly intersection rule

**Files:**
- Modify: `Features/Train/Programs/Intelligence/TemplateQualityEngine.swift:40-56`
- Test: `ElosTests/Intelligence/TemplateQualityEngineTests.swift` (append)

Spec: `§1.1`.

- [ ] **Step 1: Write the failing tests**

Append to `ElosTests/Intelligence/TemplateQualityEngineTests.swift` (match the file's existing
style — `struct` suite already there, `@Test func` naming, use `QualityFixtures`):

```swift
@Test func muscleExcludedOnEveryActiveDayIsExcludedWeekly() {
    // Two active (non-rest, non-empty) days, both excluding lowerBack. No day trains it.
    let days = [
        [QualityFixtures.sx("bench", sets: 4), QualityFixtures.sx("row", sets: 4)],
        [QualityFixtures.sx("squat", sets: 4), QualityFixtures.sx("legpress", sets: 4)]
    ]
    let dayExclusions: [Set<FineMuscle>] = [[.lowerBack], [.lowerBack]]
    let dayIsRest = [false, false]
    let resolved = QualityFixtures.resolve(days)
    let report = TemplateQualityEngine.score(
        days: days, dayNames: ["Day1", "Day2"], scope: .weeklySplit,
        profile: QualityFixtures.intermediate, catalog: QualityFixtures.catalog,
        intent: nil, dayExclusions: dayExclusions, dayIsRest: dayIsRest)
    let lowerBackBar = report.volume.bars
        .flatMap { $0.children.isEmpty ? [$0] : $0.children }
        .first { $0.fine == .lowerBack }
    #expect(lowerBackBar?.isExcluded == true)
    #expect(!report.tips.contains { $0.id.contains("lowerBack") })
}

@Test func dayScopedExclusionOnSomeDaysDoesNotAffectWeeklySplitScore() {
    // Same shape, but only ONE of two active days excludes it — the other still expects it.
    let days = [
        [QualityFixtures.sx("bench", sets: 4), QualityFixtures.sx("row", sets: 4)],
        [QualityFixtures.sx("squat", sets: 4), QualityFixtures.sx("legpress", sets: 4)]
    ]
    let dayExclusions: [Set<FineMuscle>] = [[.lowerBack], []]
    let dayIsRest = [false, false]
    let withoutAny = TemplateQualityEngine.score(
        days: days, dayNames: ["Day1", "Day2"], scope: .weeklySplit,
        profile: QualityFixtures.intermediate, catalog: QualityFixtures.catalog,
        intent: nil, dayExclusions: [[], []], dayIsRest: dayIsRest)
    let withPartial = TemplateQualityEngine.score(
        days: days, dayNames: ["Day1", "Day2"], scope: .weeklySplit,
        profile: QualityFixtures.intermediate, catalog: QualityFixtures.catalog,
        intent: nil, dayExclusions: dayExclusions, dayIsRest: dayIsRest)
    #expect(withoutAny.overall == withPartial.overall)
}

@Test func restToggledDayHoldingExercisesDoesNotVoteInTheIntersection() {
    // dayIsRest[1] == true but days[1] is non-empty (the CreateSplitView "toggle rest, keep
    // exercises" case) — it must not count as a training day.
    let days = [
        [QualityFixtures.sx("bench", sets: 4)],
        [QualityFixtures.sx("squat", sets: 4)]   // leftover exercises on a "rest" day
    ]
    let dayExclusions: [Set<FineMuscle>] = [[.lowerBack], [.lowerBack]]
    let dayIsRest = [false, true]
    let report = TemplateQualityEngine.score(
        days: days, dayNames: ["Day1", "RestDay"], scope: .weeklySplit,
        profile: QualityFixtures.intermediate, catalog: QualityFixtures.catalog,
        intent: nil, dayExclusions: dayExclusions, dayIsRest: dayIsRest)
    // Only Day1 (the sole training day) votes, and it excludes lowerBack -> still excluded,
    // since there's exactly one voting day. This test's real job is the harness-level check
    // in Step 2b: with dayIsRest passed as all-false instead, the SAME dayExclusions would
    // still compute the same result here (only one truly active day either way) — so the
    // meaningful assertion is in the harness main.swift below, which varies the count.
    #expect(report.volume.bars.flatMap { $0.children.isEmpty ? [$0] : $0.children }
        .first { $0.fine == .lowerBack }?.isExcluded == true)
}

@Test func shortDayExclusionsArrayCannotWidenTheWeeklyExclusion() {
    // dayExclusions has only 1 entry for 2 active days. The missing index must vote as
    // "no exclusion" (killing the intersection), not be skipped (which would let one day's
    // skip stand in unchallenged).
    let days = [
        [QualityFixtures.sx("bench", sets: 4)],
        [QualityFixtures.sx("squat", sets: 4)]
    ]
    let report = TemplateQualityEngine.score(
        days: days, dayNames: ["Day1", "Day2"], scope: .weeklySplit,
        profile: QualityFixtures.intermediate, catalog: QualityFixtures.catalog,
        intent: nil, dayExclusions: [[.lowerBack]], dayIsRest: [false, false])
    #expect(report.volume.bars.flatMap { $0.children.isEmpty ? [$0] : $0.children }
        .first { $0.fine == .lowerBack }?.isExcluded == false)
}
```

- [ ] **Step 2: Confirm they fail to compile** (the params/field don't exist yet)

Run:
```bash
mkdir -p "$TMPDIR/qfix-harness" && cp \
  Elos/Features/Train/Programs/Intelligence/TemplateQualityEngine.swift \
  Elos/Features/Train/Programs/Intelligence/MuscleVolumeAnalyzer.swift \
  Elos/Features/Train/Programs/Intelligence/VolumeScorer.swift \
  Elos/Features/Train/Programs/Intelligence/BalanceScorer.swift \
  Elos/Features/Train/Programs/Intelligence/SelectionScorer.swift \
  Elos/Features/Train/Programs/Intelligence/RepRestScorer.swift \
  Elos/Features/Train/Programs/Intelligence/FrequencyScorer.swift \
  Elos/Features/Train/Programs/Intelligence/FatigueScorer.swift \
  Elos/Features/Train/Programs/Intelligence/FatigueModel.swift \
  Elos/Features/Train/Programs/Intelligence/MovementQualityAnalyzer.swift \
  Elos/Features/Train/Programs/Intelligence/ScoredExercise.swift \
  Elos/Features/Train/Programs/Intelligence/TrainingScience.swift \
  Elos/Features/Train/Programs/Intelligence/TrainingProfile.swift \
  Elos/Features/Train/Programs/Intelligence/TrainingIntent.swift \
  Elos/Features/Train/Programs/Intelligence/MuscleTaxonomy.swift \
  Elos/Features/Train/Programs/Intelligence/MuscleTargets.swift \
  Elos/Features/Train/Programs/Intelligence/QualityReport.swift \
  Elos/Features/Train/Programs/Intelligence/ExerciseCandidate.swift \
  Elos/Features/Train/Programs/SplitHelpers.swift \
  "$TMPDIR/qfix-harness/"
```
Then write `$TMPDIR/qfix-harness/Shim.swift` (SwiftData stand-ins the `init(record:)` adapters
touch — check `ScoredExercise.swift` and `ExerciseCandidate.swift` for the exact stored properties
each adapter reads before writing this, they must match field-for-field) and a `main.swift` with
`assert()` translations of the four tests above (translate `#expect` -> `assert`, `@Test func` ->
a call from `main.swift`). Run `swiftc -o harness *.swift 2>&1 | head -40` from inside the harness
dir — expect a compile error naming the missing `dayExclusions`/`dayIsRest` parameters or the
missing `isExcluded` field. This confirms the tests exercise code that doesn't exist yet.

- [ ] **Step 3: Implement `TemplateQualityEngine.score`'s new parameters**

In `Features/Train/Programs/Intelligence/TemplateQualityEngine.swift`, change the signature
(spec `§1.1`) and insert the intersection block before the existing `dayScopedExclusions` line:

```swift
static func score(days: [[ScoredExercise]],
                  dayNames: [String],
                  scope: QualityScope,
                  profile: TrainingProfile,
                  catalog: [ExerciseCandidate],
                  intent: TrainingIntent? = nil,
                  dayExclusions: [Set<FineMuscle>] = [],
                  dayIsRest: [Bool] = []) -> QualityReport {
    func isTrainingDay(_ i: Int) -> Bool {
        !(i < dayIsRest.count && dayIsRest[i]) && !days[i].isEmpty
    }
    func exclusions(_ i: Int) -> Set<FineMuscle> {
        i < dayExclusions.count ? dayExclusions[i] : []
    }
    // A muscle the lifter has skipped on every day they actually train is skipped for the
    // week — there is no remaining day that disagrees. Only training days vote: folding in a
    // rest/empty day's implicit empty exclusion set would intersect this to nothing and
    // disable the rule outright.
    let weeklyExclusions: Set<FineMuscle> = {
        guard scope == .weeklySplit else { return [] }
        let voting = days.indices.filter(isTrainingDay)
        guard let first = voting.first else { return [] }
        return voting.dropFirst().reduce(exclusions(first)) { $0.intersection(exclusions($1)) }
    }()

    let dayScopedExclusions: Set<FineMuscle> = scope == .singleSession ? (intent?.excludedMuscles ?? []) : []
    let excludedMuscles = profile.volumeOverrides.excludedMuscles
        .union(dayScopedExclusions)
        .union(weeklyExclusions)
    // ... rest of the function unchanged from here
```

Do not touch anything below the `excludedMuscles` computation — `effectiveOverrides`,
`resolvedDays`, the scorer calls, all stay exactly as they are.

- [ ] **Step 4: Add `isExcluded` to `MuscleVolumeBar` and compute it in `MuscleVolumeAnalyzer`**

In `Features/Train/Programs/Intelligence/MuscleVolumeAnalyzer.swift` (spec `§1.2`):

1. Add `let isExcluded: Bool` to `MuscleVolumeBar`'s stored properties (next to `isOptional`).
2. In `fineRow(...)`, compute `let isExcluded = profile.volumeOverrides.excludedMuscles.contains(fine)`
   and pass it into the returned `MuscleVolumeBar`.
3. In `groupRow(...)`, for **all three** return paths (single-child mirror, no-expected-children
   branch, normal path), pass `isExcluded: childBars.allSatisfy(\.isExcluded)`.

Every existing `MuscleVolumeBar(` construction site (all 4, all inside this file) must be updated
— the compiler will flag any missed.

- [ ] **Step 5: Run the harness and confirm all four tests pass**

Run: `cd "$TMPDIR/qfix-harness" && swiftc -o harness *.swift && ./harness`
Expected: exits 0, no assertion failures.

- [ ] **Step 6: Add the real Swift Testing file and confirm `build-for-testing` compiles**

Append the four `@Test` functions (verbatim from Step 1) to
`ElosTests/Intelligence/TemplateQualityEngineTests.swift`.

Run:
```bash
xcodebuild build-for-testing -project Elos.xcodeproj -scheme Elos \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  OTHER_SWIFT_FLAGS='$(inherited) -disable-sandbox' -quiet
```
Expected: exit 0.

- [ ] **Step 7: Commit**

```bash
git add Elos/Features/Train/Programs/Intelligence/TemplateQualityEngine.swift \
        Elos/Features/Train/Programs/Intelligence/MuscleVolumeAnalyzer.swift \
        ElosTests/Intelligence/TemplateQualityEngineTests.swift
git commit -m "feat(train): honor a muscle skipped on every training day, weekly

A per-day 'Skip muscles' set only ever reached a throwaway per-day
score. The weekly coverage bars and score never saw it, by design at
the wrong grain: intersect the per-day exclusion sets across every
training day and add it to the weekly excluded set, so a muscle
skipped everywhere is finally skipped for the week.

MuscleVolumeBar gains isExcluded, distinct from the science-driven
isOptional, so the coverage bars can render 'this muscle is muted
because you skipped it' honestly (wired to rendering in the next
commit)."
```

## Task 2: Fix `bal-noham` — the one gap tip that ignores exclusions

**Files:**
- Modify: `Features/Train/Programs/Intelligence/BalanceScorer.swift:52-57`
- Test: `ElosTests/Intelligence/BalanceScorerTests.swift` (append)

Spec: `§1.2`, "One exception to fix while here."

- [ ] **Step 1: Write the failing test**

Read `ElosTests/Intelligence/BalanceScorerTests.swift` first to match its existing `score(...)`
helper signature exactly (it already threads `excludedMuscles:` for the sibling gap checks — copy
that call shape). Append:

```swift
@Test func excludingHamstringsSuppressesTheNoHamstringTip() {
    let days = [[QualityFixtures.sx("squat", sets: 4)]]  // quads only, no hamstring work
    let withoutExclusion = score(days, excludedMuscles: [])
    let withExclusion = score(days, excludedMuscles: [.hamstrings])
    #expect(withoutExclusion.tips.contains { $0.id == "bal-noham" })
    #expect(!withExclusion.tips.contains { $0.id == "bal-noham" })
}
```

- [ ] **Step 2: Confirm it fails**

Run the harness (reuse `$TMPDIR/qfix-harness` from Task 1, it already has `BalanceScorer.swift`).
Add this test's `assert` translation to `main.swift`, run `swiftc -o harness *.swift && ./harness`.
Expected: assertion failure (`withExclusion.tips` still contains `bal-noham`).

- [ ] **Step 3: Implement**

In `BalanceScorer.swift:52-57`, the current condition is `quadSets > 0 && hamSets == 0`. Gate it
the same way the sibling checks at `:75`/`:93`/`:109` do — guard on
`!excludedMuscles.contains(.hamstrings)` before emitting the tip.

- [ ] **Step 4: Re-run harness, confirm pass. Then `build-for-testing`.**

- [ ] **Step 5: Commit**

```bash
git add Elos/Features/Train/Programs/Intelligence/BalanceScorer.swift \
        ElosTests/Intelligence/BalanceScorerTests.swift
git commit -m "fix(train): bal-noham was the one gap tip that ignored exclusions

Every sibling 'you're not training this muscle group' check already
guards on excludedMuscles; this one didn't, so excluding hamstrings
still produced 'add a hinge to balance the knee.'"
```

## Task 3: Coverage bars render "Skipped" instead of vanishing

**Files:**
- Modify: `Features/Train/Programs/MuscleCoverageBars.swift`

Spec: `§1.2`.

- [ ] **Step 1: Implement (no new pure-logic test — this is rendering; verify by inspection +
  build, matching this file's existing lack of a test target since it's a View)**

In `MuscleBarRow`'s `valueText` (currently returns `"\(sets)/\(target)"` or a bare set count),
add a branch at the top: `if bar.isExcluded { return "Skipped" }`. In `accessibilityValue`, add the
matching branch: `if bar.isExcluded { return "Excluded from coverage" }` ahead of the existing
`isOptional` check (so an excluded muscle doesn't also read "optional" — excluded is the more
specific, more important state to announce).

Leave `isMuted` (`!bar.isExpected || bar.isOptional`) untouched — an excluded muscle already has
`isOptional == true` on its forced-optional band (`TrainingScience.swift:175`), so it already mutes
correctly; this task only changes the *text*, not the color/dimming logic.

- [ ] **Step 2: Build-for-testing to confirm it compiles** (same command as Task 1 Step 6).

- [ ] **Step 3: Commit**

```bash
git add Elos/Features/Train/Programs/MuscleCoverageBars.swift
git commit -m "feat(train): render an excluded muscle's row as 'Skipped'

A muscle excluded (globally, per-day, or via the new weekly
intersection) must never just vanish or read as a plain zero — that's
indistinguishable from a real gap and, for the weekly intersection
specifically, can be flat wrong mid-build. Muting always stays
visible and explained."
```

## Task 4: `SplitDaySummary` carries its own report; BY DAY rows become tappable

**Files:**
- Modify: `Features/Train/Programs/CreateSplitView.swift:250-257,288-307`
- Modify: `Features/Train/Programs/SplitQualityReportView.swift:5-11,271-303`
- Create: `Features/Train/Programs/DayQualityReportView.swift`

Spec: `§1.1` (call site), `§1.3`.

- [ ] **Step 1: Update the weekly call site to pass the new params**

In `CreateSplitView.swift`, `qualityReport` (`:250-257`):

```swift
private var qualityReport: QualityReport {
    TemplateQualityEngine.score(days: dayExercises.map { $0.map(ScoredExercise.init(day:)) },
                                dayNames: dayNames,
                                scope: .weeklySplit,
                                profile: scoringProfile,
                                catalog: exerciseCatalog,
                                intent: intent,
                                dayExclusions: dayExcludedMuscles,
                                dayIsRest: dayIsRest)
}
```

- [ ] **Step 2: `SplitDaySummary` gains the full report**

In `SplitQualityReportView.swift:5-11`, add `let report: QualityReport` to `SplitDaySummary`.

- [ ] **Step 3: `daySummaries` stops discarding the report**

In `CreateSplitView.swift:288-307`, change the final `return SplitDaySummary(...)` to include
`report: r` (the value it already computes and currently only reads `.overall` from). No other
line in this function changes.

- [ ] **Step 4: `perDayCard` rows become buttons**

In `SplitQualityReportView.swift`, add `var onSelectDay: ((SplitDaySummary) -> Void)? = nil` to
`SplitQualityReportView`'s properties. In `perDayCard` (`:271-303`), wrap each row's `HStack` in:

```swift
Button {
    onSelectDay?(day)
} label: {
    // existing HStack content, unchanged
}
.buttonStyle(.plain)
.disabled(onSelectDay == nil)
```

Match the `Button`-over-`.onTapGesture` convention already used in `MuscleCoverageBars.groupRow`
(`MuscleCoverageBars.swift:206`) — same reasoning applies here (no `GeometryReader` in this row,
but consistency matters more than a `.onTapGesture` micro-optimization).

- [ ] **Step 5: Create `DayQualityReportView.swift`**

```swift
import SwiftUI

/// A single day's own quality report — reached by tapping a "BY DAY" row in the weekly report.
/// This is where a per-day muscle skip actually becomes visible: the aggregate weekly bars are
/// deliberately blind to a single day's own focus, but this view isn't.
struct DayQualityReportView: View {
    let dayName: String
    let report: QualityReport

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    HStack(spacing: 14) {
                        QualityScoreRing(score: report.overall, size: 64, lineWidth: 6)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(report.tier.rawValue)
                                .font(.elosTitle)
                                .foregroundStyle(QualityPalette.color(forScore: report.overall))
                            Text(dayName)
                                .font(.elosBody)
                                .foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(Space.card)
                    .elosCard()

                    if !report.dimensions.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("BREAKDOWN").elosSectionLabel()
                            QualityDimensionBars(dimensions: report.dimensions(for: .singleSession), labelWidth: 86)
                        }
                        .padding(Space.card)
                        .elosCard()
                    }

                    MuscleCoverageBars(report: report.volume, title: "MUSCLE COVERAGE",
                                       hidesUnexpected: true, showsLegend: true)
                        .padding(Space.card)
                        .elosCard()

                    if !report.tips.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("SUGGESTIONS").elosSectionLabel()
                            VStack(spacing: 0) {
                                ForEach(Array(report.tips.enumerated()), id: \.element.id) { i, tip in
                                    if i > 0 { Divider().padding(.vertical, 9) }
                                    TipRow(tip: tip)
                                }
                            }
                        }
                        .padding(Space.card)
                        .elosCard()
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(dayName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
```

`hidesUnexpected: true` here (vs. `false` for the weekly report) — for one focused day, a group the
day doesn't target isn't a finding, matching the doc comment already on
`MuscleCoverageBars.hidesUnexpected`.

- [ ] **Step 6: Wire the sheet in `CreateSplitView`**

Add `@State private var selectedDaySummary: SplitDaySummary? = nil` near the other `@State`
sheet-trigger properties. In the `SplitQualityReportView(...)` construction (`:224-238`), pass
`onSelectDay: { selectedDaySummary = $0 }`. Add a new `.sheet(item: $selectedDaySummary) { day in
DayQualityReportView(dayName: day.name, report: day.report) }` alongside the other `.sheet`
modifiers.

- [ ] **Step 7: Build-for-testing to confirm it all compiles**

- [ ] **Step 8: Commit**

```bash
git add Elos/Features/Train/Programs/CreateSplitView.swift \
        Elos/Features/Train/Programs/SplitQualityReportView.swift \
        Elos/Features/Train/Programs/DayQualityReportView.swift
git commit -m "feat(train): tap a day in the split report to see its own coverage

The per-day report was already computed in daySummaries and thrown
away except for the headline number. Keep it, and make the BY DAY rows
open it — this is where a day-scoped 'Skip muscles' choice is finally
visible where the lifter set it, instead of only nudging an unlabeled
integer."
```

**Phase 1 complete here.** This is a legitimate stopping/shipping point — Phase 2 depends on
nothing further from this phase beyond what's already landed.

---

# Phase 2 — Auto-fix

## Task 5: `Intelligence/QualityFix.swift` — the operation/proposal types

**Files:**
- Create: `Features/Train/Programs/Intelligence/QualityFix.swift`
- Test: `ElosTests/Intelligence/QualityFixTests.swift`

Spec: `§2.1`.

- [ ] **Step 1: Write the failing test** (pure struct/enum behavior — `Equatable`, `apply`)

```swift
@Test func insertOperationAppendsAtTheGivenIndex() {
    let day: [ScoredExercise] = [QualityFixtures.sx("bench", sets: 4)]
    let candidate = QualityFixtures.catalog.first { $0.id == "row" }!
    let op = FixOperation.insertExercise(InsertSpec(dayIndex: 0, insertAt: 1,
                                                    candidate: candidate, sets: 4, reps: "6-10"))
    let result = op.apply(to: [day])
    #expect(result[0].count == 2)
    #expect(result[0][1].name == candidate.name)
    #expect(result[0][1].sets == 4)
}

@Test func outOfRangeDayIndexReturnsInputUnchanged() {
    let days: [[ScoredExercise]] = [[QualityFixtures.sx("bench", sets: 4)]]
    let op = FixOperation.setReps(dayIndex: 9, exerciseIndex: 0, reps: "6-10")
    #expect(op.apply(to: days) == days)
}

@Test func reorderDayAppliesAPermutation() {
    let day: [ScoredExercise] = [QualityFixtures.sx("bench", sets: 4),
                                 QualityFixtures.sx("pushdown", sets: 3)]
    let op = FixOperation.reorderDay(dayIndex: 0, permutation: [1, 0])
    let result = op.apply(to: [day])
    #expect(result[0].map(\.id) == ["pushdown", "bench"])
}

@Test func nonBijectivePermutationIsRejected() {
    let day: [ScoredExercise] = [QualityFixtures.sx("bench", sets: 4),
                                 QualityFixtures.sx("pushdown", sets: 3)]
    let op = FixOperation.reorderDay(dayIndex: 0, permutation: [0, 0])  // not a bijection
    let result = op.apply(to: [day])
    #expect(result[0].map(\.id) == ["bench", "pushdown"])  // unchanged, not a crash
}
```

- [ ] **Step 2: Confirm they fail to compile** (types don't exist) — same harness pattern as
  Task 1 Step 2, this time the harness only needs
  `ScoredExercise/ExerciseCandidate/MuscleTargets/MuscleTaxonomy/TrainingScience/QualityReport`
  copied in (no `TemplateQualityEngine` needed for this file alone). Expect a compile error citing
  `FixOperation`/`InsertSpec` not found.

- [ ] **Step 3: Implement**

Create `Features/Train/Programs/Intelligence/QualityFix.swift` with exactly the types from spec
`§2.1` (`FixOperation`, `InsertSpec`, `FixProposal`, `FixSummary`), plus `FixOperation.apply(to:)`:

```swift
extension FixOperation {
    /// Pure `[[ScoredExercise]] -> [[ScoredExercise]]`. Out-of-range indices or a non-bijective
    /// permutation return the input unchanged rather than crashing or corrupting state — a stale
    /// preview re-applied after the plan changed underneath it must fail safe.
    func apply(to days: [[ScoredExercise]]) -> [[ScoredExercise]] {
        var result = days
        switch self {
        case .insertExercise(let spec):
            guard result.indices.contains(spec.dayIndex) else { return days }
            let insertAt = min(max(0, spec.insertAt), result[spec.dayIndex].count)
            let new = ScoredExercise(id: spec.candidate.id, name: spec.candidate.name,
                                     sets: spec.sets, repsText: spec.reps,
                                     equipmentId: nil, muscleTargets: nil)
            result[spec.dayIndex].insert(new, at: insertAt)
        case .reorderDay(let dayIndex, let permutation):
            guard result.indices.contains(dayIndex) else { return days }
            let day = result[dayIndex]
            guard permutation.count == day.count,
                  Set(permutation) == Set(0..<day.count) else { return days }
            result[dayIndex] = permutation.map { day[$0] }
        case .setReps(let dayIndex, let exerciseIndex, let reps):
            guard result.indices.contains(dayIndex),
                  result[dayIndex].indices.contains(exerciseIndex) else { return days }
            result[dayIndex][exerciseIndex].repsText = reps
        case .setRest(let dayIndex, let exerciseIndex, let seconds):
            guard result.indices.contains(dayIndex),
                  result[dayIndex].indices.contains(exerciseIndex) else { return days }
            result[dayIndex][exerciseIndex].restSeconds = seconds
        }
        return result
    }
}
```

`repsText`/`restSeconds`/`sets` must be `var` on `ScoredExercise` for the last two cases to
compile — check `ScoredExercise.swift` now; if they're `let`, change them to `var` in this task
(they're a local value type with no external invariant tying them to `let`).

- [ ] **Step 4: Run harness, confirm pass. Add the Testing file, confirm `build-for-testing`.**

- [ ] **Step 5: Commit**

```bash
git add Elos/Features/Train/Programs/Intelligence/QualityFix.swift \
        Elos/Features/Train/Programs/Intelligence/ScoredExercise.swift \
        ElosTests/Intelligence/QualityFixTests.swift
git commit -m "feat(train): typed fix operations + pure apply, no state mutation yet

FixOperation describes a change declaratively instead of returning a
mutated plan, because the two builders hold different state types
(TemplateExerciseEntry vs DayExercise) and a mutated-plan return would
force a lossy round-trip through a foreign type. Both builders will
translate these into their own state in a later task; this commit is
the shared, pure, fully-tested core."
```

## Task 6: `ExerciseOrderer.orderedIndices` — derive the reorder permutation

**Files:**
- Modify: `Features/Train/Programs/Intelligence/ExerciseOrderer.swift`
- Test: `ElosTests/Intelligence/ExerciseOrdererTests.swift` (append)

Spec: `§2.4` ("Deriving the reorder permutation").

- [ ] **Step 1: Write the failing (characterization) tests**

```swift
@Test func orderedIndicesProducesTheSameResultAsOrder() {
    let day = [DayExercise(id: "fly", name: "Cable Fly"),
               DayExercise(id: "pushdown", name: "Tricep Pushdown"),
               DayExercise(id: "bench", name: "Bench Press")]
    let viaIndices = ExerciseOrderer.orderedIndices(day, catalog: catalog).map { day[$0] }
    let viaOrder = ExerciseOrderer.order(day, catalog: catalog)
    #expect(viaIndices.map(\.id) == viaOrder.map(\.id))
}

@Test func orderedIndicesIsABijection() {
    let day = [DayExercise(id: "a", name: "Cable Fly"),
               DayExercise(id: "b", name: "Bench Press"),
               DayExercise(id: "c", name: "Tricep Pushdown")]
    let indices = ExerciseOrderer.orderedIndices(day, catalog: catalog)
    #expect(Set(indices) == Set(0..<day.count))
}

@Test func orderedIndicesWithPriorityMatchesOrderWithPriority() {
    let day = [DayExercise(id: "fly", name: "Cable Fly"),
               DayExercise(id: "squat", name: "Squat"),
               DayExercise(id: "pushdown", name: "Tricep Pushdown")]
    let viaIndices = ExerciseOrderer.orderedIndices(day, catalog: catalog, priority: .legs).map { day[$0] }
    let viaOrder = ExerciseOrderer.order(day, catalog: catalog, priority: .legs)
    #expect(viaIndices.map(\.id) == viaOrder.map(\.id))
}
```

Use whatever `catalog` fixture `ExerciseOrdererTests.swift` already defines at the top of the file
(read it first — do not invent a second one).

- [ ] **Step 2: Confirm failure** — `orderedIndices` doesn't exist. Harness or direct
  `build-for-testing` both work here since this file has no SwiftData coupling to shim; prefer the
  harness for speed (copy just `ExerciseOrderer.swift` + `MuscleTaxonomy.swift` +
  `ExerciseCandidate.swift` + `ScoredExercise.swift` + `SplitHelpers.swift`).

- [ ] **Step 3: Implement**

Read the current `ExerciseOrderer.order` implementation in full first. Refactor so the partition
and sort logic lives in a new `orderedIndices(_:catalog:priority:) -> [Int]`, and `order` becomes a
one-line composition: `orderedIndices(day, catalog: catalog, priority: priority).map { day[$0] }`.
The partition-then-sort logic itself must not change — this is a pure refactor, verified by Step 1's
characterization tests (which assert `orderedIndices`-derived output equals today's `order` output,
including the `priority` path where original indices, not sub-array-local offsets, must be threaded
through both partitions).

- [ ] **Step 4: Run harness, confirm pass. `build-for-testing`.** Also re-run the **existing**
  `ExerciseOrdererTests` suite through the harness (not just the three new tests) to confirm the
  refactor didn't change `order`'s behavior for any of its prior cases.

- [ ] **Step 5: Commit**

```bash
git add Elos/Features/Train/Programs/Intelligence/ExerciseOrderer.swift \
        ElosTests/Intelligence/ExerciseOrdererTests.swift
git commit -m "refactor(train): expose ExerciseOrderer's partition as orderedIndices

order() is now a composition over orderedIndices, which is what the
auto-fix reorder operation needs — a permutation, not a rearranged
array, so the operation stays positional instead of id-keyed (ids are
empty for any exercise with no catalog match, which made an id-keyed
reorder unable to disambiguate two of them on the same day)."
```

## Task 7: `Intelligence/FixDayChooser.swift`

**Files:**
- Create: `Features/Train/Programs/Intelligence/FixDayChooser.swift`
- Test: `ElosTests/Intelligence/FixDayChooserTests.swift`

Spec: `§2.2`.

- [ ] **Step 1: Write the failing tests**

```swift
@Test func vetoesRestDays() {
    let result = FixDayChooser.choose(forMuscles: ["hamstrings"],
        dayNames: ["Push", "Rest"], dayIsRest: [false, true],
        dayExercises: [[QualityFixtures.sx("bench", sets: 4)], []],
        dayExcludedMuscles: [[], []], intent: .default)
    #expect(result?.dayIndex == 0)
}

@Test func vetoesADayThatExcludesEveryTargetMuscle() {
    let result = FixDayChooser.choose(forMuscles: ["hamstrings"],
        dayNames: ["Legs", "Upper"], dayIsRest: [false, false],
        dayExercises: [[QualityFixtures.sx("squat", sets: 4)], [QualityFixtures.sx("bench", sets: 4)]],
        dayExcludedMuscles: [[.hamstrings], []], intent: .default)
    #expect(result?.dayIndex == 1)
}

@Test func prefersAFocusMatchingDayOverAnEmptierNonMatchingDay() {
    // Regression: today's firstOpenDayIndex() would route to the emptier arm day.
    let result = FixDayChooser.choose(forMuscles: ["hamstrings"],
        dayNames: ["Legs", "Arms"], dayIsRest: [false, false],
        dayExercises: [
            [QualityFixtures.sx("squat", sets: 4), QualityFixtures.sx("legpress", sets: 4)],
            [QualityFixtures.sx("curl", sets: 3)]
        ],
        dayExcludedMuscles: [[], []], intent: .default)
    #expect(result?.dayIndex == 0)
}

@Test func returnsNilWhenNoDayIsEligible() {
    let result = FixDayChooser.choose(forMuscles: ["hamstrings"],
        dayNames: ["Rest"], dayIsRest: [true],
        dayExercises: [[]], dayExcludedMuscles: [[]], intent: .default)
    #expect(result == nil)
}

@Test func deterministicUnderTies() {
    let a = FixDayChooser.choose(forMuscles: ["chest"],
        dayNames: ["A", "B"], dayIsRest: [false, false],
        dayExercises: [[], []], dayExcludedMuscles: [[], []], intent: .default)
    let b = FixDayChooser.choose(forMuscles: ["chest"],
        dayNames: ["A", "B"], dayIsRest: [false, false],
        dayExercises: [[], []], dayExcludedMuscles: [[], []], intent: .default)
    #expect(a?.dayIndex == b?.dayIndex)
}
```

- [ ] **Step 2: Confirm failure** (type doesn't exist).

- [ ] **Step 3: Implement** per spec `§2.2` — hard vetoes (rest day; every target muscle
  excluded), then score by focus match (archetype from `intent.focus ??
  MuscleTaxonomy.archetype(forDayName:)`), then `−0.5 × direct sets for the target muscles`, then
  `−0.2 × exercise count`, then `dayIndex` ascending as the final tiebreak. Return `(dayIndex: Int,
  reason: String)?`.

- [ ] **Step 4: Harness pass, `build-for-testing`.**

- [ ] **Step 5: Commit**

```bash
git add Elos/Features/Train/Programs/Intelligence/FixDayChooser.swift \
        ElosTests/Intelligence/FixDayChooserTests.swift
git commit -m "feat(train): FixDayChooser — sound day selection for auto-fix

Replaces firstOpenDayIndex()'s 'fewest exercises' heuristic for
automated fixes only (the manual picker keeps its current behavior).
Hard-vetoes rest days and any day that excludes every target muscle,
then prefers a day whose own focus actually trains the muscle, so a
hamstring fix can no longer land on an arm day or a day the lifter
explicitly skipped that muscle on."
```

## Task 8: `Intelligence/FixExercisePicker.swift`

**Files:**
- Create: `Features/Train/Programs/Intelligence/FixExercisePicker.swift`
- Test: `ElosTests/Intelligence/FixExercisePickerTests.swift`

Spec: `§2.3`.

**`Context`'s shape (define this first — the spec describes the pipeline but not this struct's
fields, and it must compose cleanly with `QualityFixEngine.Context` from Task 10 rather than
duplicate or fight it):**

```swift
extension FixExercisePicker {
    /// Everything needed to rank candidates for one specific day. Deliberately narrower than
    /// `QualityFixEngine.Context` (Task 10) — that struct describes the whole plan; this is what
    /// one day's ranking call needs, and `QualityFixEngine` builds one of these per call by
    /// slicing its own `Context` down to the chosen day's exercises. Picker code never needs to
    /// know about days it isn't ranking for.
    struct Context {
        let catalog: [ExerciseCandidate]
        let dayName: String
        let addedDay: [ScoredExercise]     // the target day's current exercises, for dup + coverage-gap terms
        let personalization: PersonalizationProvider
        let equipmentPreference: EquipmentPreference
    }
}
```

`QualityFixEngine.propose` (Task 10) constructs one of these as
`FixExercisePicker.Context(catalog: context.catalog, dayName: context.dayNames[dayIndex],
addedDay: context.days[dayIndex], personalization: context.personalization,
equipmentPreference: context.equipmentPreference)` after `FixDayChooser` has picked `dayIndex` —
so this task's `Context` is a strict subset of Task 10's fields, never a parallel definition that
could drift from it.

- [ ] **Step 1: Write the failing tests**

```swift
@Test func onlyReturnsPrimaryMuscleMatches() {
    // "row" has lats as primary, biceps as secondary — asking for biceps must not return it.
    let results = FixExercisePicker.candidates(forMuscles: ["biceps"],
        dayIndex: 0, context: sampleContext(), limit: 3)
    #expect(!results.contains { $0.id == "row" })
}

@Test func excludesByIdAndByNormalizedName() {
    let ctx = sampleContext(addedIDs: ["bench"], addedNames: ["Incline Bench Press"])
    let results = FixExercisePicker.candidates(forMuscles: ["chest"], dayIndex: 0, context: ctx, limit: 5)
    #expect(!results.contains { $0.id == "bench" })
    #expect(!results.contains { MuscleTaxonomy.normalize($0.name) == MuscleTaxonomy.normalize("Incline Bench Press") })
}

@Test func fallsBackRatherThanReturningEmptyWhenEquipmentOverConstrains() {
    let ctx = sampleContext(equipmentPreference: EquipmentPreference(posture: .home, customTypes: []))
    // Ask for a muscle only trained by barbell/machine work in the fixture catalog, if such
    // exists; otherwise assert non-empty for a muscle with mixed equipment coverage.
    let results = FixExercisePicker.candidates(forMuscles: ["chest"], dayIndex: 0, context: ctx, limit: 3)
    #expect(!results.isEmpty)
}

@Test func patternFilterMatchesMovementPattern() {
    let results = FixExercisePicker.candidates(forPattern: "hinge", dayIndex: 0, context: sampleContext(), limit: 3)
    #expect(!results.isEmpty)
    #expect(results.allSatisfy { $0.movementPattern == "hinge" })
}

@Test func alternatesAreDistinctFromThePick() {
    let results = FixExercisePicker.candidates(forMuscles: ["chest"], dayIndex: 0, context: sampleContext(), limit: 3)
    #expect(Set(results.map(\.id)).count == results.count)
}
```

Write a private `sampleContext(...)` helper at the top of the test file building a `FixExercisePicker.Context`
(or whatever inputs struct Task 8's Step 3 defines) from `QualityFixtures.catalog` plus sensible
defaults, with named overrides for `addedIDs`/`addedNames`/`equipmentPreference` used above.

- [ ] **Step 2: Confirm failure.**

- [ ] **Step 3: Implement** per spec `§2.3` — resolve payload via
  `MuscleTaxonomy.targetMuscles(forPayload:)`, filter candidates by **normalized** primary-muscle
  membership (or `movementPattern` equality for `forPattern`), hard-filter duplicates by id and
  normalized name, hard-filter (with fallback) by `EquipmentPreference.isAvailable`, rank via
  `ExerciseRankingEngine.rank` with a `DayContext` built for the target day, return the top
  `limit`.

  **Building the `DayContext`:** `DayContextInferrer.infer(dayName:added:catalog:)` is typed for
  `[DayExercise]`, but `Context.addedDay` here is `[ScoredExercise]` — don't force a conversion
  through `DayExercise` (same rule as Task 11: no round-trip through a type that drops fields).
  Build the four `DayContext` fields directly from `addedDay` instead: resolve each
  `ScoredExercise` against `catalog` (matching the same `candidate == nil` fallback
  `ExerciseResolver` already uses elsewhere) to get its `ResolvedExercise.targets`, then set
  `addedPrimaryMuscles` from each resolved exercise's primary muscles, `addedExerciseIDs`/
  `addedExerciseNames` from each exercise's `id`/normalized `name`, and `addedTargets` from each
  `targets` — this is what fixes `CreateTemplateView.openPicker`'s bug (empty
  `addedPrimaryMuscles`) rather than reproducing it. `targetMuscles` is the resolved payload set
  from this function's own muscle/pattern argument, not inferred from the day name — the picker
  already knows exactly what it's looking for.

- [ ] **Step 4: Harness pass, `build-for-testing`.**

- [ ] **Step 5: Commit**

```bash
git add Elos/Features/Train/Programs/Intelligence/FixExercisePicker.swift \
        ElosTests/Intelligence/FixExercisePickerTests.swift
git commit -m "feat(train): FixExercisePicker — headless top-N pick for auto-fix

Reuses ExerciseRankingEngine (no new ranking math) but adds the two
guarantees the engine alone doesn't provide: a hard primary-muscle
filter (bal-gap-* fires on direct sets, so a secondary-only pick
wouldn't clear the tip it claims to fix) and hard duplicate/equipment
filtering (the engine's own penalties are soft scores, not filters)."
```

## Task 9: `TrainingScience.maxAutoFixSetsPerExercise` + Tier 2 `TipAction` cases

**Files:**
- Modify: `Features/Train/Programs/Intelligence/TrainingScience.swift`
- Modify: `Features/Train/Programs/Intelligence/QualityReport.swift` (`TipAction`)
- Modify: `Features/Train/Programs/Intelligence/RepRestScorer.swift:30-33,53-56`
- Modify: `Features/Train/Programs/CreateSplitView.swift` (`handle(tip:)` switch)
- Modify: `Features/Train/Templates/CreateTemplateView.swift` (`handle(tip:)` switch)

Spec: `§2.5`.

- [ ] **Step 1: Write the failing test**

```swift
@Test func repRestTipsCarryRetuneActions() {
    let days = [[QualityFixtures.sx("bench", sets: 4, reps: "20-25")]]  // way outside hypertrophy range
    let resolved = QualityFixtures.resolve(days)
    let dims = RepRestScorer.score(resolvedDays: resolved, scope: .singleSession, profile: QualityFixtures.intermediate)
    let repTip = dims.tips.first { $0.id == "rr-reps" }
    #expect(repTip?.action == .retuneReps)
}
```

- [ ] **Step 2: Confirm failure** — `.retuneReps` doesn't exist on `TipAction` yet.

- [ ] **Step 3: Implement**

1. Add `case retuneReps` and `case retuneRest` to `TipAction` in `QualityReport.swift`.
2. In `RepRestScorer.swift`, change the `rr-reps` tip construction (`:30-33`) to pass
   `action: .retuneReps`, and `rr-rest` (`:53-56`) to pass `action: .retuneRest`.
3. Add `static let maxAutoFixSetsPerExercise = 5` to `TrainingScience.swift`, grouped with the
   other tunables (this constant is consumed in Task 10, adding it here keeps this task's diff
   focused on the enum/scorer change while the constant exists before it's needed).
4. **Both builders' `handle(tip:)` switches are now non-exhaustive** — that's the point (spec:
   "makes both builders' handle(tip:) switches non-exhaustive — a compile error, not a silent
   miss"). Add `case .retuneReps, .retuneRest: break` to both switches for now (Task 11 wires the
   real auto-fix sheet in; this task's job is only to make the enum change land without breaking
   the build, verified by the compile step below).

- [ ] **Step 4: Harness pass for the `RepRestScorer` test. Then run `build-for-testing` — this is
  the step that actually proves both builders still compile** with the widened enum.

- [ ] **Step 5: Commit**

```bash
git add Elos/Features/Train/Programs/Intelligence/QualityReport.swift \
        Elos/Features/Train/Programs/Intelligence/RepRestScorer.swift \
        Elos/Features/Train/Programs/Intelligence/TrainingScience.swift \
        Elos/Features/Train/Programs/CreateSplitView.swift \
        Elos/Features/Train/Templates/CreateTemplateView.swift \
        ElosTests/Intelligence/RepRestScorerTests.swift
git commit -m "feat(train): TipAction gains retuneReps/retuneRest for Tier 2 auto-fix

rr-reps and rr-rest carried no action before, so they could never be
auto-fixed even though they're the cheapest, most deterministic score
movers (a pure numeric edit to the target range for the lifter's
goal). Widening TipAction makes both builders' handle(tip:) switches
non-exhaustive by design — the compiler catches any switch this
enum change would otherwise silently under-handle."
```

## Task 10: `Intelligence/QualityFixEngine.swift` — orchestration

**Files:**
- Create: `Features/Train/Programs/Intelligence/QualityFixEngine.swift`
- Test: `ElosTests/Intelligence/QualityFixEngineTests.swift`

Spec: `§2.4`, `§2.7`.

- [ ] **Step 1: Write the failing tests** — this is the load-bearing suite

```swift
@Test func canFixMatchesTheWhitelistInTheSpec() {
    let fixable = ["bal-gap-back", "bal-focusgap-back", "bal-noham",
                   "vol-low-chest", "vol-light-chest", "sel-hinge", "sel-order",
                   "fatigue-order-0", "rr-reps", "rr-rest"]
    let notFixable = ["vol-high-chest", "vol-more", "sess-junk-chest", "sess-short",
                      "sess-long", "bal-pushpull", "bal-quadham", "bal-single-group",
                      "sel-compound", "fatigue-long-0", "freq-once-chest"]
    for id in fixable {
        #expect(QualityFixEngine.canFix(makeTip(id: id)), "\(id) should be fixable")
    }
    for id in notFixable {
        #expect(!QualityFixEngine.canFix(makeTip(id: id)), "\(id) should not be fixable")
    }
}

@Test func aBalGapProposalGenuinelyClearsTheTargetedTip() {
    // Weekly split, no back work at all -> bal-gap-back should fire, then clear after the fix.
    let ctx = weeklyContextWithNoBackWork()
    let before = TemplateQualityEngine.score(days: ctx.days, dayNames: ctx.dayNames,
        scope: .weeklySplit, profile: ctx.profile, catalog: ctx.catalog, intent: ctx.intent,
        dayExclusions: ctx.dayExcludedMuscles, dayIsRest: ctx.dayIsRest)
    let tip = before.tips.first { $0.id == "bal-gap-back" }!
    let proposal = QualityFixEngine.propose(for: tip, context: ctx)
    #expect(proposal?.resolvesTip == true)
    #expect(proposal!.after.tips.contains { $0.id == "bal-gap-back" } == false)
}

@Test func aSelOrderProposalOnASecondDayCountsAsResolvedEvenThoughIdRepeats() {
    let ctx = weeklyContextWithInversionsOnTwoDays()
    let before = TemplateQualityEngine.score(days: ctx.days, dayNames: ctx.dayNames,
        scope: .weeklySplit, profile: ctx.profile, catalog: ctx.catalog, intent: ctx.intent,
        dayExclusions: ctx.dayExcludedMuscles, dayIsRest: ctx.dayIsRest)
    let tip = before.tips.first { $0.id == "sel-order" }!  // points at the FIRST offending day
    let proposal = QualityFixEngine.propose(for: tip, context: ctx)
    #expect(proposal?.resolvesTip == true)
    // A second day's inversion re-emits the SAME id with a different dayIndex — must not be
    // mistaken for "not resolved."
    if case .reorder(let fixedDay) = tip.action, let after = proposal?.after {
        let stillSameProblem = after.tips.contains { $0.id == "sel-order" && $0.action == .reorder(dayIndex: fixedDay) }
        #expect(!stillSameProblem)
    }
}

@Test func reorderProposalTouchesOnlyItsOwnDay() {
    let ctx = weeklyContextWithInversionOnOneDay()
    let tip = QualityTip(id: "sel-order", dimension: .selection, severity: .info,
                         message: "", action: .reorder(dayIndex: 0))
    let proposal = QualityFixEngine.propose(for: tip, context: ctx)
    #expect(proposal != nil)
    if case .reorderDay(let dayIndex, _) = proposal!.operations.first {
        #expect(dayIndex == 0)
    } else {
        Issue.record("expected a reorderDay operation for day 0")
    }
}

@Test func doseFixThatCannotCloseTheGapReportsResolvesTipFalseWithACaveat() {
    // Construct a context where the catalog's best single exercise for the muscle can't reach
    // mev even at maxAutoFixSetsPerExercise.
    let ctx = weeklyContextWithSevereShortfall()
    let tip = ctx.currentReport.tips.first { $0.id.hasPrefix("vol-low-") }!
    let proposal = QualityFixEngine.propose(for: tip, context: ctx)
    #expect(proposal?.resolvesTip == false)
    #expect(proposal?.summary.caveat != nil)
}

@Test func proposeReturnsNilWhenNothingHelpsAndNothingClears() {
    let ctx = contextWhereNoCandidateTrainsTheMuscle()
    let tip = QualityTip(id: "bal-gap-core", dimension: .balance, severity: .warn,
                         message: "", action: .addMuscle("core"))
    #expect(QualityFixEngine.propose(for: tip, context: ctx) == nil)
}

@Test func tier2RetuneMovesRrRepsOutOfTheTipList() {
    let ctx = singleSessionContextWithOutOfRangeReps()
    let before = TemplateQualityEngine.score(days: ctx.days, dayNames: ctx.dayNames,
        scope: .singleSession, profile: ctx.profile, catalog: ctx.catalog, intent: ctx.intent)
    let tip = before.tips.first { $0.id == "rr-reps" }!
    let proposal = QualityFixEngine.propose(for: tip, context: ctx)
    #expect(proposal?.resolvesTip == true)
}
```

Write the `weeklyContextWith*`/`singleSessionContextWith*`/`contextWhere*` builders and `makeTip`
helper at the top of the test file, each constructing a minimal `QualityFixEngine.Context` from
`QualityFixtures` data — same pattern `TemplateQualityEngineTests.swift` already uses for its own
multi-day fixtures (read that file's existing helpers before writing new ones; reuse its shape).

- [ ] **Step 2: Confirm failure** (type doesn't exist).

- [ ] **Step 3: Implement `QualityFixEngine`** per spec `§2.4` and the `canFix` whitelist in
  `§2.7`. `propose(for:context:)`:
  1. Return `nil` immediately if `!canFix(tip)`.
  2. Branch on `tip.action` to build `[FixOperation]` using `FixDayChooser` (for `.addMuscle`/
     `.addPattern`) and `FixExercisePicker` (to pick the candidate), or directly from
     `tip.action`'s `dayIndex` (for `.reorder`, using `ExerciseOrderer.orderedIndices`), or from a
     full scan of the scope's exercises (for `.retuneReps`/`.retuneRest`, rewriting every
     out-of-range exercise to `TrainingScience.repRange(for:)`/`restRange(for:)`).
  3. Simulate: `let simulated = operations.reduce(context.days) { days, op in op.apply(to: days) }`.
  4. Re-score with **identical parameters** to how the builder scores today, **including
     `dayIsRest: context.dayIsRest`** (the spec calls this out explicitly — an omitted `dayIsRest`
     here would make the after-score use a different weekly exclusion set than the before-score,
     making the delta meaningless).
  5. `let resolvesTip = !after.tips.contains { $0.id == tip.id && $0.action == tip.action }`.
  6. `guard resolvesTip || after.overall > before.overall else { return nil }` — the suppression
     rule from spec `§2.4`.
  7. Build `FixSummary` (headline/detail/placement/caveat) and return the `FixProposal`.

- [ ] **Step 4: Harness pass (this is the expensive one — budget real time for it). Then
  `build-for-testing`.**

- [ ] **Step 5: Commit**

```bash
git add Elos/Features/Train/Programs/Intelligence/QualityFixEngine.swift \
        ElosTests/Intelligence/QualityFixEngineTests.swift
git commit -m "feat(train): QualityFixEngine — propose, simulate, self-verify

The orchestrator behind the auto-fix button. Builds operations per tip
type, simulates them against a hypothetical copy of the plan (never
the real one), re-scores with the exact parameters the builder itself
uses, and only returns a proposal if it can prove the targeted tip
actually clears — matched on (id, action), since sel-order reuses one
id across days and a naive id-only check would report false success.
A change that neither clears the tip nor improves the score is
suppressed rather than offered."
```

## Task 11: UI — preview sheet, TipRow wiring, both builders' `apply`

**Files:**
- Create: `Features/Train/Programs/QualityFixPreviewSheet.swift`
- Modify: `Features/Train/Programs/SplitQualityReportView.swift` (`TipRow`)
- Modify: `Features/Train/Programs/TemplateQualityPanel.swift` (pass-through)
- Modify: `Features/Train/Programs/CreateSplitView.swift`
- Modify: `Features/Train/Templates/CreateTemplateView.swift`

Spec: `§2.6`.

- [ ] **Step 1: `TipRow` gains `onAutoFix`**

In `SplitQualityReportView.swift`, add `var onAutoFix: ((QualityTip) -> Void)? = nil` to `TipRow`.
Change its tap logic: if `QualityFixEngine.canFix(tip)` and `onAutoFix` is set, tap calls
`onAutoFix?(tip)`; else fall back to today's `onTap?(tip)` behavior unchanged. One tap target per
row — no second button.

- [ ] **Step 2: Create `QualityFixPreviewSheet.swift`**

A SwiftUI view taking a `FixProposal` (or an optional, re-computed on "try a different exercise")
and closures `onConfirm: ([FixOperation]) -> Void`, `onDeny: () -> Void`,
`onTryAnother: (ExerciseCandidate) -> FixProposal?`, `onChooseManually: () -> Void`. Layout per
spec `§2.6`/the earlier mockup: tip text; score ring before → after; non-zero dimension deltas
(regressions in red); the change + placement reason; "Use a different exercise" (only shown when
`proposal.alternates` is non-empty) cycling alternates and re-proposing via `onTryAnother`;
"Choose manually instead" calling `onChooseManually`; Deny / Confirm buttons.
`.presentationDetents([.medium, .large])`.

- [ ] **Step 3: Wire into `CreateSplitView`**

Add `@State private var pendingFix: FixProposal? = nil`. Add
`.sheet(item: $pendingFix) { proposal in QualityFixPreviewSheet(proposal: proposal, onConfirm: {
apply($0); pendingFix = nil }, onDeny: { pendingFix = nil }, onTryAnother: { candidate in
QualityFixEngine.propose(for: proposal.tip, context: currentContext(), using: candidate) },
onChooseManually: { pendingFix = nil; handle(tip: proposal.tip) }) }`. Wire `onAutoFix: { tip in
pendingFix = QualityFixEngine.propose(for: tip, context: currentContext()) ?? { handle(tip: tip);
return nil }() }` — falling back to today's manual `handle(tip:)` when `propose` returns `nil`
(no eligible day / no candidate), per the spec's edge-case table. Add `private func
currentContext() -> QualityFixEngine.Context` building the struct from existing `@State`. Add
`private func apply(_ operations: [FixOperation])` that switches over each operation and mutates
`dayExercises` **directly, in `DayExercise` terms, never by converting a pre-existing element
through `ScoredExercise` and back.** `ScoredExercise` does not carry `equipmentDedupeKey`,
`equipmentBrandName`, or `restSeconds`-as-persisted — a round-trip through it would silently drop
those fields from any exercise an operation touches, which is exactly the "carries a name but
drops the rest of an exercise's identity" bug class this design's own
"Why operations rather than a mutated copy" section exists to avoid. Per case:
- `.insertExercise` — build a genuinely new `DayExercise` from `InsertSpec.candidate`
  (id/name/equipmentId/equipmentDedupeKey/equipmentBrandName/muscleTargets), mirroring
  `CreateSplitView.swift:189-194`'s own construction. Lossless because there's no pre-existing
  element to lose fields from.
- `.reorderDay` — apply the permutation directly to `dayExercises[dayIndex]`
  (`permutation.map { dayExercises[dayIndex][$0] }`), exactly like `handle(tip:)`'s existing
  `.reorder` case already does via `ExerciseOrderer.order`. No conversion, so every field survives
  because nothing is rebuilt.
- `.setReps` — mutate `dayExercises[dayIndex][exerciseIndex].reps` in place (a `DayExercise`
  field).
- `.setRest` — intentional no-op here, one-line comment: `DayExercise` has no rest field, and
  `rr-rest` only fires at single-session scope on exercises with non-nil rest, which a
  split-sourced day never has.

Re-validate indices at apply time (mirrors `handle(tip:)`'s existing
`guard dayExercises.indices.contains(...)` pattern), wrapped in `withAnimation(.elosEmphasis)`.

- [ ] **Step 4: Wire into `CreateTemplateView`**

Same shape: `pendingFix`, sheet, `onAutoFix`, `currentContext()`, `apply(_:)`. Apply the same rule
as Step 3 — mutate `exercises: [TemplateExerciseEntry]` directly in its own terms, never through a
`ScoredExercise` round-trip (`TemplateExerciseEntry` additionally carries `targetRPE`, which
`ScoredExercise` has no field for at all, so a round-trip here would drop it silently). This
builder's `apply` DOES implement `setRest` for real (mutate `exercises[i].restSeconds` directly),
since `TemplateExerciseEntry.restSeconds` exists. Add the one-line `equipmentPreference` computed
property the spec calls out (`profiles.first?.equipmentPreference ?? .fullGym`, matching
`CreateSplitView:11`'s shape) to build `Context`.

- [ ] **Step 5: Thread `onAutoFix` through `TemplateQualityPanel`** so the inline coach (not just
  the full report) can trigger auto-fix — add the same optional closure parameter and pass it to
  its own `TipRow` construction.

- [ ] **Step 6: Build-for-testing.** This task is UI-only; there is no new pure-logic test here
  (the engine underneath was proven in Task 10). Confirm compilation is the verification.

- [ ] **Step 7: Commit**

```bash
git add Elos/Features/Train/Programs/QualityFixPreviewSheet.swift \
        Elos/Features/Train/Programs/SplitQualityReportView.swift \
        Elos/Features/Train/Programs/TemplateQualityPanel.swift \
        Elos/Features/Train/Programs/CreateSplitView.swift \
        Elos/Features/Train/Templates/CreateTemplateView.swift
git commit -m "feat(train): wire auto-fix into both builders with preview/confirm

Tapping a fixable suggestion now opens a preview (before/after score,
what changes, why that day) instead of either doing nothing or
mutating state blind. Confirm applies through each builder's own
apply(_:), which speaks its native state type — TemplateExerciseEntry
or DayExercise — never a value handed back from the shared engine.
Deny is a pure no-op: neither builder persists anything before Save,
so there's nothing to roll back."
```

## Task 12: Adjacent bug fix — `CreateTemplateView`'s manual-add default sets/reps

**Files:**
- Modify: `Features/Train/Templates/CreateTemplateView.swift` (multi-add path)

Spec: `§2.6`, "One adjacent bug fixed deliberately."

- [ ] **Step 1: Manual verification test** (behavioral, not unit — this is a call-site fix)

Read the current multi-add closure in `CreateTemplateView.swift` (the `onConfirmMulti` handler).
Confirm it constructs `TemplateExerciseEntry` without calling `SetRepDefaults`. This is the
"failing test" step for a call-site bug: the observation itself is the repro.

- [ ] **Step 2: Implement**

Mirror `CreateSplitView.swift:187-188`'s pattern exactly: look up
`exerciseCatalog.first { $0.id == ex.id }?.movementPattern ?? ""`, call
`SetRepDefaults.defaults(forMovementPattern:)`, and use `def.sets`/`def.reps` instead of the
struct's generic defaults when constructing each `TemplateExerciseEntry`.

- [ ] **Step 3: Build-for-testing to confirm compilation.**

- [ ] **Step 4: Commit** (deliberately separate, per the spec, so it can be reverted alone)

```bash
git add Elos/Features/Train/Templates/CreateTemplateView.swift
git commit -m "fix(train): template builder's manual add now uses movement-aware defaults

CreateSplitView's manual add already looks up SetRepDefaults by
movement pattern (a squat gets 4x5-8); CreateTemplateView's multi-add
path never did, so the same squat got a flat 3x8-10 there instead.
Found while building the auto-fix engine, which needs both builders to
size an inserted exercise identically. Separate commit — this changes
existing manual-add behavior that nobody asked to change, so it should
be revertable on its own if it surprises anyone."
```

## Task 13: Full-suite build verification and final review

- [ ] **Step 1: Full clean build-for-testing**

```bash
xcodebuild build-for-testing -project Elos.xcodeproj -scheme Elos \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  OTHER_SWIFT_FLAGS='$(inherited) -disable-sandbox' -quiet
```
Expected: exit 0, zero warnings introduced by this plan's files (check the tail of the log for any
new warning mentioning a file this plan touched).

- [ ] **Step 2: Re-run every harness test from Tasks 1–10 together in one combined harness dir** to
  catch any cross-file interaction the per-task harnesses (built incrementally) might have missed —
  copy the full final set of touched `Intelligence/*.swift` files fresh from the working tree,
  rebuild `main.swift` from all the `assert` blocks written across this plan, `swiftc -o harness
  *.swift && ./harness`.

- [ ] **Step 3: Dispatch `adversarial-verifier`** with a self-contained prompt (file paths, what
  changed, what to try to break) covering: the weekly intersection rule against a fresh half-built
  split scenario not in the unit tests; whether `QualityFixEngine.propose` can ever produce a
  proposal whose `operations` are stale relative to `context` by the time `apply` runs in the UI;
  and whether the `TipAction` enum widening missed any other exhaustive switch in the codebase
  (`grep -rn "case .noAction" Elos/` to find every switch over `TipAction` and confirm each one
  either handles the two new cases or the compiler already forced it to).

- [ ] **Step 4: Fix anything real the verifier finds; re-run Steps 1–2; commit any fixes.**

- [ ] **Step 5: Final commit — update the muscle-coverage-coach-bugfix-pass memory** (if the
  memory tool is available in this session) noting this pass, or skip silently if not — this step
  is not build-blocking.
