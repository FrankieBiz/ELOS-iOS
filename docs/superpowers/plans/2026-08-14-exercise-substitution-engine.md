# Smart Exercise Substitution Engine + Evidence Hierarchy Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** When a user swaps an exercise mid-workout, rank the catalog by muscle/pattern/equipment
match to the exercise being replaced and show the top 5 with a plain-language reason, above the
existing manual picker — paired with a small reusable "evidence hierarchy" badge that honestly
labels how solid the underlying claim is.

**Architecture:** One new pure-logic engine (`ExerciseSubstitutionEngine`, Foundation-only, no
SwiftUI/SwiftData) scores `ExerciseCandidate`s — the unit already shared by every other
Intelligence engine in this codebase. One static `EvidenceLibrary` + a small reusable
`EvidenceBadge`/`EvidenceSheet` component pair. `ExerciseSwapSheet` gains a "Suggested for you"
section that calls the engine and renders results above its existing, unchanged manual picker.

**Tech Stack:** Swift, SwiftUI, SwiftData, Swift Testing (`import Testing`, `@Test`, `#expect`).

**Spec:** `docs/superpowers/specs/2026-08-14-exercise-substitution-engine-design.md` — read this
first for the full rationale (why these scoring weights, why injury-awareness is out of scope,
why equipment isn't in the reason text).

---

## Before you start

- Sandboxed `xcodebuild` sessions on this machine hit two known environment walls (not code bugs):
  macro-plugin failure (fixed by adding `OTHER_SWIFT_FLAGS='$(inherited) -disable-sandbox'` to every
  `xcodebuild` invocation) and **test execution cannot run at all** (`Pseudo Terminal Setup Error` —
  the iOS test host needs a pty the sandbox blocks). Compilation is verifiable from this session;
  running the Swift Testing suite is not. Task 8 below uses a `swiftc` harness workaround that runs
  the pure engine natively (no simulator, no pty) to get real pass/fail signal despite this — it is
  a verification aid, not a replacement for the real `ElosTests` run, which still needs to happen
  (ask the user to run it, or run it in CI).
- All new files are pure Foundation or SwiftUI — no SwiftData model changes, no migration, no
  backend/`elos-shared` contract changes anywhere in this plan.

---

### Task 1: `SubstitutionSuggestion` + source resolution

**Files:**
- Create: `apps/elos-mobile/Elos/Elos/Features/Train/Programs/Intelligence/ExerciseSubstitutionEngine.swift`
- Test: `apps/elos-mobile/Elos/ElosTests/Intelligence/ExerciseSubstitutionEngineTests.swift`

- [ ] **Step 1: Write the failing tests for source resolution**

```swift
import Testing
@testable import Elos

struct ExerciseSubstitutionEngineTests {
    private static let squat = ExerciseCandidate(
        id: "1", name: "Barbell Back Squat", primaryMuscle: "quads",
        secondaryMuscles: ["glutes", "hamstrings"], equipment: "barbell",
        movementPattern: "squat", isCustom: false)
    private static let goblet = ExerciseCandidate(
        id: "2", name: "Goblet Squat", primaryMuscle: "quads",
        secondaryMuscles: ["glutes"], equipment: "dumbbell",
        movementPattern: "squat", isCustom: false)

    @Test func resolveSourceMatchesByNormalizedName() {
        let resolved = ExerciseSubstitutionEngine.resolveSource(
            name: "barbell   back squat", candidates: [Self.squat, Self.goblet])
        #expect(resolved?.id == Self.squat.id)
    }

    @Test func resolveSourceReturnsNilForUnresolvableName() {
        let resolved = ExerciseSubstitutionEngine.resolveSource(
            name: "Some Totally Custom Thing", candidates: [Self.squat, Self.goblet])
        #expect(resolved == nil)
    }
}
```

- [ ] **Step 2: Confirm the test target doesn't build yet**

Run: `xcodebuild build-for-testing -project apps/elos-mobile/Elos/Elos.xcodeproj -scheme Elos -destination 'generic/platform=iOS Simulator' -quiet OTHER_SWIFT_FLAGS='$(inherited) -disable-sandbox'`
Expected: FAIL — `ExerciseSubstitutionEngine` does not exist.

- [ ] **Step 3: Write the minimal implementation**

```swift
import Foundation

struct SubstitutionSuggestion: Identifiable, Equatable {
    let id: String
    let name: String
    let score: Int
    let reason: String
}

enum ExerciseSubstitutionEngine {
    /// Resolves the session `Exercise` being swapped (known only by name) to its catalog
    /// candidate. Returns nil for custom exercises, renamed lifts, or any name that doesn't
    /// resolve — callers treat that the same as "nothing to suggest," not a special case.
    static func resolveSource(name: String, candidates: [ExerciseCandidate]) -> ExerciseCandidate? {
        let key = MuscleTaxonomy.normalize(name)
        return candidates.first { MuscleTaxonomy.normalize($0.name) == key }
    }
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `xcodebuild test -project apps/elos-mobile/Elos/Elos.xcodeproj -scheme Elos -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:ElosTests/ExerciseSubstitutionEngineTests -quiet OTHER_SWIFT_FLAGS='$(inherited) -disable-sandbox'`
Expected: this will hit the pty wall in a sandboxed session (see "Before you start"). If it does,
skip to Task 8's harness to get real pass/fail signal now, then continue — don't assume pass or
fail without one of the two verification paths actually running.

- [ ] **Step 5: Commit**

```bash
git add apps/elos-mobile/Elos/Elos/Features/Train/Programs/Intelligence/ExerciseSubstitutionEngine.swift apps/elos-mobile/Elos/ElosTests/Intelligence/ExerciseSubstitutionEngineTests.swift
git commit -m "feat(train): add exercise substitution engine source resolution"
```

---

### Task 2: Scoring function

**Files:**
- Modify: `.../Intelligence/ExerciseSubstitutionEngine.swift`
- Modify: `.../ElosTests/Intelligence/ExerciseSubstitutionEngineTests.swift`

- [ ] **Step 1: Write the failing scoring tests**

Add to the test struct (reuse `squat`/`goblet` fixtures from Task 1, add more):

```swift
    private static let legExtension = ExerciseCandidate(
        id: "4", name: "Leg Extension", primaryMuscle: "quads",
        secondaryMuscles: [], equipment: "machine", movementPattern: "isolation", isCustom: false)
    private static let legCurl = ExerciseCandidate(
        id: "5", name: "Leg Curl", primaryMuscle: "hamstrings",
        secondaryMuscles: [], equipment: "machine", movementPattern: "isolation", isCustom: false)
    private static let rdl = ExerciseCandidate(
        id: "6", name: "Romanian Deadlift", primaryMuscle: "hamstrings",
        secondaryMuscles: ["glutes", "lower_back"], equipment: "barbell",
        movementPattern: "hinge", isCustom: false)

    @Test func exactMuscleMatchPlusPatternMatchDoesNotDoubleCountViaCompoundClass() {
        // Same primary muscle (+3) + same "squat" pattern (+1) + overlapping secondary "glutes"
        // (+1, both fixtures list it) = 5. Compound-class must NOT also fire here — patterns are
        // identical, not merely both-compound, so this stays 5, not 6.
        let (score, _) = ExerciseSubstitutionEngine.scoreCandidate(source: Self.squat, candidate: Self.goblet)
        #expect(score == 5)
    }

    @Test func crossPatternCompoundSimilarityScoresIndependently() {
        // Different muscle (group-only, +1) + shared secondary "glutes" (+1) + both compound but
        // different pattern, squat vs hinge (+1) = 3.
        let (score, _) = ExerciseSubstitutionEngine.scoreCandidate(source: Self.squat, candidate: Self.rdl)
        #expect(score == 3)
    }

    @Test func genericIsolationPatternIsNotATrueSignal() {
        // Antagonists (quads vs hamstrings) that happen to both be "isolation" pattern must NOT
        // get a pattern-match point — group-only (+1) is all they share.
        let (score, _) = ExerciseSubstitutionEngine.scoreCandidate(source: Self.legExtension, candidate: Self.legCurl)
        #expect(score == 1)
    }
```

- [ ] **Step 2: Run to verify failure**

Same build command as Task 1 Step 2. Expected: FAIL — `scoreCandidate` does not exist.

- [ ] **Step 3: Implement scoring**

Add to `ExerciseSubstitutionEngine`:

```swift
    /// Movement patterns specific enough that sharing one is a real signal. `isolation` is a
    /// generic bucket covering unrelated muscles (a leg extension and a bicep curl are both
    /// "isolation") — matching on it tells you nothing, so it's deliberately excluded.
    private static let specificPatterns: Set<String> = ["squat", "hinge", "push", "pull", "carry", "rotation"]

    /// Scores one candidate against the source being swapped out. Returns the total score and the
    /// plain-language reason fragments that fired, in priority order. Internal (not private) so
    /// tests can verify scoring in isolation rather than reverse-engineering it from ranked output.
    static func scoreCandidate(source: ExerciseCandidate, candidate: ExerciseCandidate) -> (score: Int, reasons: [String]) {
        var score = 0
        var reasons: [String] = []

        // Muscle tiers are mutually exclusive — a candidate earns exactly one.
        if MuscleTaxonomy.normalize(source.primaryMuscle) == MuscleTaxonomy.normalize(candidate.primaryMuscle) {
            score += 3
            reasons.append("Same primary muscle (\(candidate.primaryMuscle))")
        } else if let sFine = MuscleTaxonomy.fine(forMuscle: source.primaryMuscle),
                  let cFine = MuscleTaxonomy.fine(forMuscle: candidate.primaryMuscle),
                  sFine == cFine {
            score += 2
            reasons.append("Trains the same muscle (\(cFine.displayName.lowercased()))")
        } else if let sGroup = MuscleTaxonomy.group(forMuscle: source.primaryMuscle),
                  let cGroup = MuscleTaxonomy.group(forMuscle: candidate.primaryMuscle),
                  sGroup == cGroup {
            score += 1
            reasons.append("Same muscle group (\(cGroup.displayName))")
        }

        let patternsMatch = source.movementPattern == candidate.movementPattern
        if patternsMatch && specificPatterns.contains(candidate.movementPattern.lowercased()) {
            score += 1
            reasons.append("Same \(candidate.movementPattern) pattern")
        }

        let sourceSecondary = Set(source.secondaryMuscles.map(MuscleTaxonomy.normalize))
        let candidateSecondary = Set(candidate.secondaryMuscles.map(MuscleTaxonomy.normalize))
        if !sourceSecondary.isDisjoint(with: candidateSecondary) {
            score += 1
            reasons.append("Overlapping secondary muscles")
        }

        // Only rewards CROSS-pattern compound similarity (e.g. squat vs. hinge). When patterns
        // are identical, the point above already captured that — awarding both double-counts
        // one signal as two.
        if !patternsMatch,
           MuscleTaxonomy.isCompound(movementPattern: source.movementPattern),
           MuscleTaxonomy.isCompound(movementPattern: candidate.movementPattern) {
            score += 1
            reasons.append("Similar compound movement")
        }

        return (score, reasons)
    }
```

- [ ] **Step 4: Verify the three new tests pass** (build-for-testing, then Task 8's harness for
  actual execution — see "Before you start")

- [ ] **Step 5: Commit**

```bash
git add apps/elos-mobile/Elos/Elos/Features/Train/Programs/Intelligence/ExerciseSubstitutionEngine.swift apps/elos-mobile/Elos/ElosTests/Intelligence/ExerciseSubstitutionEngineTests.swift
git commit -m "feat(train): score exercise substitution candidates by muscle/pattern/equipment"
```

---

### Task 3: `suggest()` — filter, threshold, rank, reason string

**Files:**
- Modify: `.../Intelligence/ExerciseSubstitutionEngine.swift`
- Modify: `.../ElosTests/Intelligence/ExerciseSubstitutionEngineTests.swift`

- [ ] **Step 1: Write the failing integration tests**

```swift
    @Test func barbellSquatUnavailablePrefersEquipmentMatchedQuadCompounds() {
        let equipment = EquipmentPreference(posture: .custom, customTypes: ["dumbbell", "machine"])
        let all = [Self.squat, Self.goblet, Self.legExtension, Self.legCurl, Self.rdl]
        let results = ExerciseSubstitutionEngine.suggest(for: Self.squat, candidates: all, equipment: equipment)
        let names = results.map(\.name)
        #expect(names.first == "Goblet Squat")
        #expect(!names.contains("Leg Curl"))          // unrelated muscle+pattern, score 1, excluded
        #expect(!names.contains("Romanian Deadlift"))  // uses barbell, hard-filtered by equipment
    }

    @Test func legExtensionAndLegCurlNeverSuggestEachOther() {
        let results = ExerciseSubstitutionEngine.suggest(for: Self.legExtension, candidates: [Self.legCurl], equipment: .fullGym)
        #expect(results.isEmpty)
    }

    @Test func tiesBreakAlphabeticallyByName() {
        let zebra = ExerciseCandidate(id: "z", name: "Zebra Press", primaryMuscle: "quads",
            secondaryMuscles: [], equipment: "machine", movementPattern: "squat", isCustom: false)
        let apple = ExerciseCandidate(id: "a", name: "Apple Squat", primaryMuscle: "quads",
            secondaryMuscles: [], equipment: "machine", movementPattern: "squat", isCustom: false)
        let results = ExerciseSubstitutionEngine.suggest(for: Self.squat, candidates: [zebra, apple], equipment: .fullGym)
        #expect(results.map(\.name) == ["Apple Squat", "Zebra Press"])
    }

    @Test func sourceExcludedFromItsOwnSuggestions() {
        let results = ExerciseSubstitutionEngine.suggest(for: Self.squat, candidates: [Self.squat, Self.goblet], equipment: .fullGym)
        #expect(!results.map(\.name).contains("Barbell Back Squat"))
    }

    @Test func limitCapsResultCount() {
        let many = (0..<10).map { i in
            ExerciseCandidate(id: "m\(i)", name: "Quad Move \(i)", primaryMuscle: "quads",
                secondaryMuscles: [], equipment: "machine", movementPattern: "squat", isCustom: false)
        }
        let results = ExerciseSubstitutionEngine.suggest(for: Self.squat, candidates: many, equipment: .fullGym, limit: 5)
        #expect(results.count == 5)
    }
```

(Note: deliberately not asserting 2nd place — Leg Extension also scores above threshold for a
squat swap, so the only ordering claim that matters is "Goblet Squat is top and Leg Curl/Romanian
Deadlift are absent.")

- [ ] **Step 2: Run to verify failure** — `suggest` does not exist yet.

- [ ] **Step 3: Implement `suggest`**

```swift
    static func suggest(
        for source: ExerciseCandidate,
        candidates: [ExerciseCandidate],
        equipment: EquipmentPreference,
        limit: Int = 5
    ) -> [SubstitutionSuggestion] {
        let scored: [(candidate: ExerciseCandidate, score: Int, reason: String)] = candidates
            .filter { $0.id != source.id }
            .filter { equipment.isAvailable(equipment: $0.equipment) }
            .compactMap { candidate in
                let (score, reasons) = scoreCandidate(source: source, candidate: candidate)
                guard score >= 2 else { return nil }
                return (candidate, score, reasons.joined(separator: " · "))
            }
            .sorted { lhs, rhs in
                lhs.score != rhs.score ? lhs.score > rhs.score : lhs.candidate.name < rhs.candidate.name
            }

        return scored.prefix(limit).map {
            SubstitutionSuggestion(id: $0.candidate.id, name: $0.candidate.name, score: $0.score, reason: $0.reason)
        }
    }
```

- [ ] **Step 4: Verify all tests pass** (harness — see Task 8)

- [ ] **Step 5: Commit**

```bash
git add apps/elos-mobile/Elos/Elos/Features/Train/Programs/Intelligence/ExerciseSubstitutionEngine.swift apps/elos-mobile/Elos/ElosTests/Intelligence/ExerciseSubstitutionEngineTests.swift
git commit -m "feat(train): rank and threshold exercise substitution suggestions"
```

---

### Task 4: `EvidenceLibrary`

**Files:**
- Create: `apps/elos-mobile/Elos/Elos/Features/Train/Programs/Intelligence/EvidenceLibrary.swift`
- Test: `apps/elos-mobile/Elos/ElosTests/Intelligence/EvidenceLibraryTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
import Testing
@testable import Elos

struct EvidenceLibraryTests {
    @Test func exerciseSubstitutionEntryIsMediumLowCertainty() {
        let entry = EvidenceLibrary.entry(for: .exerciseSubstitution)
        #expect(entry.certainty == .mediumLow)
        #expect(!entry.claim.isEmpty)
        #expect(!entry.explanation.isEmpty)
    }
}
```

- [ ] **Step 2: Run to verify failure** — `EvidenceLibrary` does not exist.

- [ ] **Step 3: Implement**

```swift
import Foundation

enum EvidenceCertainty: String {
    case high, medium, mediumLow, low

    var displayLabel: String {
        switch self {
        case .high:      return "High certainty"
        case .medium:    return "Medium certainty"
        case .mediumLow: return "Medium-low certainty"
        case .low:       return "Low certainty"
        }
    }
}

enum EvidenceTopic: String {
    case exerciseSubstitution
}

struct EvidenceEntry {
    let claim: String
    let certainty: EvidenceCertainty
    let explanation: String
}

/// One place for every "backed by science" claim in the app, each honestly rated — not every
/// claim here is strongly supported, and the point of this library is to say so rather than bury
/// the caveat in a code comment. Add an entry per topic as new science-backed features ship.
enum EvidenceLibrary {
    static func entry(for topic: EvidenceTopic) -> EvidenceEntry {
        switch topic {
        case .exerciseSubstitution:
            return EvidenceEntry(
                claim: "Suggestions are ranked by matching primary muscle, movement pattern, and available equipment.",
                certainty: .mediumLow,
                explanation: "This is a practical heuristic, not a proven-equivalent substitution. " +
                    "No study has directly tested whether matching movement signature preserves " +
                    "results better than a simple same-muscle swap — in fact, one study found a hip " +
                    "thrust and a back squat produced similar hypertrophy and similar deadlift " +
                    "transfer despite very different muscle activation. Treat these as reasonable " +
                    "starting points, not guarantees."
            )
        }
    }
}
```

- [ ] **Step 4: Verify test passes** (harness — see Task 8)

- [ ] **Step 5: Commit**

```bash
git add apps/elos-mobile/Elos/Elos/Features/Train/Programs/Intelligence/EvidenceLibrary.swift apps/elos-mobile/Elos/ElosTests/Intelligence/EvidenceLibraryTests.swift
git commit -m "feat(train): add evidence hierarchy library with exercise-substitution entry"
```

---

### Task 5: `EvidenceBadge` + `EvidenceSheet`

**Files:**
- Create: `apps/elos-mobile/Elos/Elos/Components/EvidenceBadge.swift`

No unit test — this is a small SwiftUI view; correctness is verified visually in Task 9. Match
the existing `Components/` style (check `ProgressBar.swift` or `RingView.swift` briefly for the
file's header-comment convention before writing this).

- [ ] **Step 1: Write the component**

```swift
import SwiftUI

/// Small ⓘ affordance that opens a certainty-rated science explanation. Shared by every feature
/// that makes a "backed by science" claim — one place to render this, not one sheet per feature.
struct EvidenceBadge: View {
    let topic: EvidenceTopic
    @State private var showingSheet = false

    var body: some View {
        Button {
            showingSheet = true
        } label: {
            Label("Why", systemImage: "info.circle")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .sheet(isPresented: $showingSheet) {
            EvidenceSheet(entry: EvidenceLibrary.entry(for: topic))
        }
    }
}

private struct EvidenceSheet: View {
    let entry: EvidenceEntry
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(entry.certainty.displayLabel)
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(.secondary.opacity(0.15), in: Capsule())
                    Text(entry.claim)
                        .font(.headline)
                    Text(entry.explanation)
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
                .padding()
            }
            .navigationTitle("The science")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }
}
```

- [ ] **Step 2: Confirm it compiles**

Run: `xcodebuild build -project apps/elos-mobile/Elos/Elos.xcodeproj -scheme Elos -destination 'generic/platform=iOS Simulator' -quiet OTHER_SWIFT_FLAGS='$(inherited) -disable-sandbox'`
Expected: BUILD SUCCEEDED.

- [ ] **Step 3: Commit**

```bash
git add apps/elos-mobile/Elos/Elos/Components/EvidenceBadge.swift
git commit -m "feat(components): add evidence badge and sheet for science-backed claims"
```

---

### Task 6: Wire into `ExerciseSwapSheet`

**Files:**
- Modify: `apps/elos-mobile/Elos/Elos/Features/Train/ExerciseSwapSheet.swift`

Current file (for reference, full contents at time of writing):

```swift
import SwiftUI
import SwiftData

struct ExerciseSwapSheet: View {
    @Binding var exercise: Exercise
    var existingNames: [String] = []
    @Environment(\.modelContext) private var modelContext
    @State private var duplicateName: String?

    var body: some View {
        ExercisePickerView(onPickSingle: { picked in
            if existingNames.contains(picked.name) {
                duplicateName = picked.name
                return
            }
            exercise.adopt(picked, in: modelContext)
        })
        .alert("Already in this workout", isPresented: Binding(
            get: { duplicateName != nil },
            set: { if !$0 { duplicateName = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("\(duplicateName ?? "That exercise") is already part of this session.")
        }
    }
}
```

- [ ] **Step 1: Replace with the version below**

```swift
import SwiftUI
import SwiftData

struct ExerciseSwapSheet: View {
    @Binding var exercise: Exercise
    var existingNames: [String] = []
    @Environment(\.modelContext) private var modelContext
    @State private var duplicateName: String?

    @Query(sort: \ExerciseDefinitionRecord.name) private var dbExercises: [ExerciseDefinitionRecord]
    @Query private var profiles: [UserProfileRecord]

    private var equipmentPreference: EquipmentPreference { profiles.first?.equipmentPreference ?? .fullGym }

    private var suggestions: [SubstitutionSuggestion] {
        let candidates = dbExercises.map(ExerciseCandidate.init(record:))
        guard let source = ExerciseSubstitutionEngine.resolveSource(name: exercise.name, candidates: candidates) else {
            return []
        }
        return ExerciseSubstitutionEngine.suggest(for: source, candidates: candidates, equipment: equipmentPreference)
    }

    private func adopt(_ suggestion: SubstitutionSuggestion) {
        if existingNames.contains(suggestion.name) {
            duplicateName = suggestion.name
            return
        }
        exercise.adopt(PickedExercise(id: suggestion.id, name: suggestion.name), in: modelContext)
    }

    var body: some View {
        VStack(spacing: 0) {
            if !suggestions.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Suggested for you")
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                        EvidenceBadge(topic: .exerciseSubstitution)
                    }
                    ForEach(suggestions) { suggestion in
                        Button {
                            adopt(suggestion)
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(suggestion.name)
                                    .font(.body.weight(.medium))
                                Text(suggestion.reason)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.plain)
                        Divider()
                    }
                    Text("Or choose manually")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.top, 4)
                }
                .padding()
            }

            ExercisePickerView(onPickSingle: { picked in
                if existingNames.contains(picked.name) {
                    duplicateName = picked.name
                    return
                }
                exercise.adopt(picked, in: modelContext)
            })
        }
        .alert("Already in this workout", isPresented: Binding(
            get: { duplicateName != nil },
            set: { if !$0 { duplicateName = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("\(duplicateName ?? "That exercise") is already part of this session.")
        }
    }
}
```

- [ ] **Step 2: Build to confirm it compiles**

Run: `xcodebuild build -project apps/elos-mobile/Elos/Elos.xcodeproj -scheme Elos -destination 'generic/platform=iOS Simulator' -quiet OTHER_SWIFT_FLAGS='$(inherited) -disable-sandbox'`
Expected: BUILD SUCCEEDED. If `EquipmentPreference` isn't imported/visible, double-check
`UserProfileRecord.equipmentPreference` is a computed property in scope (it's used the same way in
`ExercisePickerView.swift:33` — mirror that exactly).

- [ ] **Step 3: Commit**

```bash
git add apps/elos-mobile/Elos/Elos/Features/Train/ExerciseSwapSheet.swift
git commit -m "feat(train): surface smart substitution suggestions in the swap sheet"
```

---

### Task 7: Full project build verification

- [ ] **Step 1: Run a full build-for-testing pass**

Run: `xcodebuild build-for-testing -project apps/elos-mobile/Elos/Elos.xcodeproj -scheme Elos -destination 'generic/platform=iOS Simulator' -quiet OTHER_SWIFT_FLAGS='$(inherited) -disable-sandbox'`
Expected: BUILD SUCCEEDED, with the `ElosTests` target (including the two new test files)
compiling cleanly. This is authoritative for "does it typecheck," per this project's own rule that
`xcodebuild` is the ground truth over SourceKit/IDE errors — don't "fix" a squiggle that isn't a
real build failure.

- [ ] **Step 2: If it fails, fix and re-run** — do not proceed to Task 8 on a red build.

---

### Task 8: Run the tests for real (swiftc harness workaround)

Sandboxed `xcodebuild test` cannot execute in this session (pty blocked). `ExerciseSubstitutionEngine`
and `EvidenceLibrary` are both pure `Foundation`-only code (like the rest of `Intelligence/`), so they
can run as a plain macOS binary instead — this is the established workaround for this exact wall.

- [ ] **Step 1: Stage a temp harness directory**

```bash
mkdir -p /tmp/elos-harness
cp apps/elos-mobile/Elos/Elos/Features/Train/Programs/Intelligence/MuscleTaxonomy.swift \
   apps/elos-mobile/Elos/Elos/Features/Train/Programs/Intelligence/ExerciseCandidate.swift \
   apps/elos-mobile/Elos/Elos/Features/Train/Programs/Intelligence/EquipmentPreference.swift \
   apps/elos-mobile/Elos/Elos/Features/Train/Programs/Intelligence/ExerciseSubstitutionEngine.swift \
   apps/elos-mobile/Elos/Elos/Features/Train/Programs/Intelligence/EvidenceLibrary.swift \
   /tmp/elos-harness/
```

`ExerciseCandidate.swift` references `ExerciseDefinitionRecord` in its `init(record:)` — a
SwiftData `@Model` type from `ElosSchema.swift` that isn't copied and can't compile standalone.
The harness's tests never call that initializer (they use the plain memberwise init), but the
file must still compile as a unit, so add a minimal stub for just the property shape:

```bash
cat > /tmp/elos-harness/Stubs.swift << 'EOF'
import Foundation

struct ExerciseDefinitionRecord {
    let id: String
    let name: String
    let primaryMuscle: String
    let secondaryMuscles: [String]
    let equipment: String
    let movementPattern: String
    let isCustom: Bool
}
EOF
```

- [ ] **Step 2: Add a `main.swift` with the same assertions as the Swift Testing suite**

Create `/tmp/elos-harness/main.swift` — translate every `@Test`/`#expect` from
`ExerciseSubstitutionEngineTests.swift` and `EvidenceLibraryTests.swift` into plain
`assert(...)` calls (same fixtures, same expected values). This is mechanical — same logic, no
`Testing` import, no `@testable import Elos` (there's no module here, just files).

- [ ] **Step 3: Compile and run**

```bash
cd /tmp/elos-harness && swiftc -o harness *.swift && ./harness && echo "ALL ASSERTIONS PASSED"
```

Expected: `ALL ASSERTIONS PASSED` with no crash. A Swift `assert` failure crashes the binary with a
line number — when that happens, check both possibilities before changing anything: either
`ExerciseSubstitutionEngine.swift`'s logic is wrong, or the test's expected value was hand-traced
incorrectly (this happened once already during planning — see Task 2's corrected 5-not-4 score).
Re-derive the expected score by hand from the scoring rules before deciding which side to fix.

- [ ] **Step 4: Report status honestly**

This harness verifies the pure logic only — it cannot cover the `ExerciseSwapSheet` SwiftUI/SwiftData
wiring from Task 6. Tell the user the harness passed (or didn't) and that the real `ElosTests`
target still needs to run on a simulator or in CI for full confidence — do not claim "tests pass"
unqualified from a build-only or harness-only result.

---

### Task 9: Manual verification in simulator

- [ ] **Step 1:** Launch the app in the iOS Simulator (attach the live panel first if showing the
  user).
- [ ] **Step 2:** Start or open an in-progress workout, tap "swap" on any exercise.
- [ ] **Step 3:** Confirm the "Suggested for you" section renders above the manual picker, each row
  shows a name and a reason, and the evidence badge opens a sheet with a certainty pill and
  explanation.
- [ ] **Step 4:** Tap a suggestion, confirm it adopts correctly (name changes, no crash, sets
  preserved per `Exercise.adopt`'s existing contract).
- [ ] **Step 5:** Test the empty case — swap out an exercise with no good matches available (e.g. a
  custom exercise, or a very restrictive equipment profile) and confirm the section simply doesn't
  render rather than showing something broken.
- [ ] **Step 6:** Confirm the existing manual picker below still works unchanged (search, filters,
  direct adopt).

---

## Out of scope (per spec — do not build in this plan)

Split/template-builder integration, the equipment-constrained full-session generator,
per-suggestion evidence badges, PubMed-link citations, injury-aware in-session substitution
(blocked on persisting a per-user injury profile, which doesn't exist yet).
