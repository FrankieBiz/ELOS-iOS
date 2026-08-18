# Muscle exclusion, rater on/off, and cited volume recommendations — implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let a lifter mark specific muscles as intentionally skipped on a given day/template (without hurting that day's quality score), turn the 0–100 quality rating on/off globally, and see cited, plain-English reasoning behind each muscle group's recommended weekly sets — plus a matching global "not training this" option in the existing Volume Targets screen.

**Architecture:** Reuses the existing `isOptional` mechanism (already silences nagging for rotator cuff/forearms) by making it dynamically settable via two `Set<FineMuscle>` fields — one global (`VolumeOverrides.excludedMuscles`, profile-level) and one per-day (`TrainingIntent.excludedMuscles`) — merged inside `TemplateQualityEngine.score` with a scope-aware guard so day-scoped exclusions can never leak into a weekly split score. All new logic is pure value types under `Intelligence/`; UI additions reuse proven patterns already in the codebase (`MuscleTargetSheet`'s Button-row picker, `TrainingIntentRow`'s `showsFocus`-style chip gating, `GroupTargetEditor`'s sentinel-tag `Picker`).

**Tech Stack:** SwiftUI + SwiftData (Elos iOS app), Swift Testing for unit tests.

**Spec:** `docs/superpowers/specs/2026-08-11-muscle-exclusion-rater-toggle-and-citations-design.md`

---

## Before you start

- Working directory for all commands below: `/Users/frankbisignano/dev/elos/apps/elos-mobile/Elos` (contains `Elos.xcodeproj`, `Elos/`, `ElosTests/`).
- Branch: `feat/muscle-coverage-coach` (already has a large uncommitted diff from prior work on this same feature — that's expected, not something to clean up here).
- `xcodebuild test` may be blocked in this sandbox (`openpty`/pty setup error — see the `sandboxed-xcodebuild` memory). If so:
  - `xcodebuild build` and `xcodebuild build-for-testing -scheme Elos -destination 'generic/platform=iOS Simulator'` are the compile-correctness gate.
  - Fall back to a standalone `swiftc` harness for the pure `Intelligence/` logic (compile the relevant files + a small shim for `UserProfileRecord`/`ResolvedExercise`, run assertions natively) if you need to actually execute the new unit tests and the simulator test host won't launch.
  - Always try `xcodebuild test -scheme Elos -destination 'id=<booted-simulator-udid>' -parallel-testing-enabled NO` first — `-parallel-testing-enabled NO` is mandatory (parallel sim clones intermittently report false failures) — and only fall back if it errors on pty setup.
- Two implementation-level refinements beyond the spec's pseudocode (both are safety/simplicity improvements, not scope changes — noted so you don't "fix" them back to the spec's literal wording):
  1. Excluding a muscle **flips `isOptional` on the band that would otherwise have been computed** (same treatment as the existing `rotatorCuff`/`forearms` bands), rather than zeroing `targetLow`/`targetHigh`/`mrv` to literal `0`. Zeroing risked a divide-by-zero in the coverage bars' fill-percentage calculation if an excluded muscle still receives incidental indirect credit from another exercise. Flipping the flag is what every consumer (`VolumeScorer`, `FrequencyScorer`, the bars) already keys off of, so behavior is identical to the spec's intent with no numeric edge case.
  2. Only `weeklyBand` needs a code change. `sessionBand` already derives `isOptional` from calling `weeklyBand` first (`return VolumeBand(..., isOptional: weekly.isOptional)`), so it inherits the exclusion for free — the spec says "both change" but the second one falls out automatically.

---

## Phase 1 — Engine

### Task 1: `VolumeOverrides.excludedMuscles` + backward-compatible decode

**Files:**
- Modify: `Elos/Features/Train/Programs/Intelligence/TrainingProfile.swift:75-84`
- Test: `ElosTests/Intelligence/VolumeTargetTests.swift`

- [ ] **Step 1: Write the failing test**

Add to `ElosTests/Intelligence/VolumeTargetTests.swift` (new `// MARK: Exclusion` section at the end of the `VolumeTargetTests` struct, before the closing `}`):

```swift
    // MARK: Exclusion

    @Test func excludedMuscleIsOptionalRegardlessOfGroupTarget() {
        // A stale numeric target left over from before a muscle was excluded must not un-exclude it.
        let profile = TrainingProfile(
            goal: .hypertrophy, experience: .intermediate,
            volumeOverrides: VolumeOverrides(
                groupWeeklyTarget: [MuscleGroup.back.rawValue: 30],
                excludedMuscles: [.lowerBack]))
        #expect(TrainingScience.weeklyBand(for: .lowerBack, profile: profile).isOptional)
        // Lats, in the same group, are unaffected.
        #expect(!TrainingScience.weeklyBand(for: .lats, profile: profile).isOptional)
    }

    @Test func excludingAMuscleDoesNotZeroItsBandNumbers() {
        // Flag-flip, not zeroing — avoids a divide-by-zero in the bars if the muscle still gets
        // incidental indirect credit from another exercise.
        let excluded = VolumeOverrides(excludedMuscles: [.lowerBack])
        let profile = TrainingProfile(goal: .hypertrophy, experience: .intermediate, volumeOverrides: excluded)
        let band = TrainingScience.weeklyBand(for: .lowerBack, profile: profile)
        let unexcludedBand = TrainingScience.weeklyBand(for: .lowerBack, profile: standard)
        #expect(band.isOptional)
        #expect(band.targetLow == unexcludedBand.targetLow)
        #expect(band.targetHigh == unexcludedBand.targetHigh)
    }

    @Test func excludedMusclesRoundTripThroughJSON() {
        let overrides = VolumeOverrides(preference: .aggressive,
                                        groupWeeklyTarget: ["chest": 20],
                                        excludedMuscles: [.lowerBack, .forearms])
        let data = try! JSONEncoder().encode(overrides)
        let decoded = try! JSONDecoder().decode(VolumeOverrides.self, from: data)
        #expect(decoded == overrides)
    }

    @Test func decodingPreExclusionJSONDefaultsToNoExclusions() {
        // A user upgrading has a stored blob with no "excludedMuscles" key at all. This must not
        // throw and must not silently drop `preference`/`groupWeeklyTarget` (AppViewModel decodes
        // this with `try?`, so a thrown decode would silently reset the user's saved settings).
        let legacyJSON = """
        {"preference":"aggressive","groupWeeklyTarget":{"chest":20}}
        """.data(using: .utf8)!
        let decoded = try! JSONDecoder().decode(VolumeOverrides.self, from: legacyJSON)
        #expect(decoded.preference == .aggressive)
        #expect(decoded.groupWeeklyTarget["chest"] == 20)
        #expect(decoded.excludedMuscles.isEmpty)
    }

    @Test func isCustomizedIncludesExclusion() {
        var o = VolumeOverrides.none
        #expect(!o.isCustomized)
        o.excludedMuscles = [.lowerBack]
        #expect(o.isCustomized)
    }
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `xcodebuild build-for-testing -scheme Elos -destination 'generic/platform=iOS Simulator' 2>&1 | tail -40`
Expected: FAIL to compile — `VolumeOverrides` has no member `excludedMuscles`, no `excludedMuscles:` init parameter.

- [ ] **Step 3: Implement `VolumeOverrides.excludedMuscles` + custom Codable init**

Replace lines 70–84 of `TrainingProfile.swift` (the `VolumeOverrides` doc comment + struct) with:

```swift
/// The lifter's deviations from the science defaults.
///
/// Deliberately group-level for numeric targets, not per-fine-muscle: there are sixteen fine muscles
/// and a sixteen-field form is a worse product than one multiplier plus a handful of group targets.
/// `TrainingScience` distributes a group target across its children in the science table's own
/// proportions. `excludedMuscles` is fine-muscle-level, not group-level, because it's a different
/// (much lower-cognitive-load) kind of control — a yes/no checklist, not a number to pick.
struct VolumeOverrides: Equatable, Codable {
    var preference: VolumePreference = .standard
    /// `MuscleGroup.rawValue` → the lifter's own weekly set target for that whole group.
    /// Present means "use my number"; absent means "use the derived one".
    var groupWeeklyTarget: [String: Int] = [:]
    /// Muscles the lifter has explicitly said they're not training, anywhere, ever — distinct from
    /// `TrainingIntent.excludedMuscles`, which is day/template-scoped. Forces `isOptional` on the
    /// muscle's band wherever it's read (`TrainingScience.weeklyBand`), so it's silently skipped by
    /// every scorer and shown muted (not as a red gap) in the coverage bars.
    var excludedMuscles: Set<FineMuscle> = []

    static let none = VolumeOverrides()

    var isCustomized: Bool {
        preference != .standard || !groupWeeklyTarget.isEmpty || !excludedMuscles.isEmpty
    }

    init(preference: VolumePreference = .standard,
         groupWeeklyTarget: [String: Int] = [:],
         excludedMuscles: Set<FineMuscle> = []) {
        self.preference = preference
        self.groupWeeklyTarget = groupWeeklyTarget
        self.excludedMuscles = excludedMuscles
    }

    // MARK: Backward-compatible decode
    //
    // Synthesized `Decodable` throws `keyNotFound` on a JSON blob saved before `excludedMuscles`
    // existed. `AppViewModel` decodes this with `try?` (`JSONDecoder().decode(VolumeOverrides.self,
    // ...)`), so a thrown decode doesn't crash — it silently resets `preference` and
    // `groupWeeklyTarget` back to defaults too, on every existing user's upgrade. Writing this
    // `init(from:)` by hand suppresses the synthesized memberwise init, which is why the explicit
    // one above exists.

    private enum CodingKeys: String, CodingKey {
        case preference, groupWeeklyTarget, excludedMuscles
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        preference = try c.decodeIfPresent(VolumePreference.self, forKey: .preference) ?? .standard
        groupWeeklyTarget = try c.decodeIfPresent([String: Int].self, forKey: .groupWeeklyTarget) ?? [:]
        excludedMuscles = try c.decodeIfPresent(Set<FineMuscle>.self, forKey: .excludedMuscles) ?? []
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `xcodebuild build-for-testing -scheme Elos -destination 'generic/platform=iOS Simulator' 2>&1 | tail -40`
Expected: builds clean.

Run (on a booted simulator; get a UDID with `xcrun simctl list devices booted`):
`xcodebuild test -scheme Elos -destination 'id=<udid>' -parallel-testing-enabled NO -only-testing:ElosTests/VolumeTargetTests 2>&1 | tail -60`
Expected: PASS. If the pty error blocks this, verify by reading the diff carefully and proceed — Task 13 covers full-suite verification.

- [ ] **Step 5: Commit**

```bash
git add Elos/Features/Train/Programs/Intelligence/TrainingProfile.swift ElosTests/Intelligence/VolumeTargetTests.swift
git commit -m "feat(volume): add VolumeOverrides.excludedMuscles with backward-compatible decode"
```

---

### Task 2: `TrainingIntent.excludedMuscles` + backward-compatible decode

**Files:**
- Modify: `Elos/Features/Train/Programs/Intelligence/TrainingIntent.swift:11-49`
- Test: Create `ElosTests/Intelligence/TrainingIntentTests.swift`

- [ ] **Step 1: Write the failing test**

Create `ElosTests/Intelligence/TrainingIntentTests.swift`:

```swift
import Foundation
import Testing
@testable import Elos

struct TrainingIntentTests {
    @Test func defaultHasNoExclusions() {
        #expect(TrainingIntent.default.excludedMuscles.isEmpty)
    }

    @Test func excludedMusclesRoundTripThroughJSON() {
        let intent = TrainingIntent(goal: .strength, focus: .upper, excludedMuscles: [.lowerBack])
        let restored = TrainingIntent(jsonString: intent.jsonString)
        #expect(restored == intent)
    }

    @Test func decodingPreExclusionJSONDefaultsToNoExclusions() {
        // A template saved before this field existed. Must not fail to decode (which would make
        // `TrainingIntent(jsonString:)` return nil and silently drop the lifter's saved goal/focus).
        let legacyJSON = """
        {"goal":"strength","focus":"upper"}
        """
        let restored = TrainingIntent(jsonString: legacyJSON)
        #expect(restored?.goal == .strength)
        #expect(restored?.focus == .upper)
        #expect(restored?.excludedMuscles.isEmpty == true)
    }

    @Test func decodingLegacyJSONWithNoFocusKeyStillWorks() {
        // `focus` was already optional before this change; synthesized Codable omits nil optionals
        // from the JSON entirely, so plenty of existing saved blobs have no "focus" key at all.
        let legacyJSON = """
        {"goal":"hypertrophy"}
        """
        let restored = TrainingIntent(jsonString: legacyJSON)
        #expect(restored?.goal == .hypertrophy)
        #expect(restored?.focus == nil)
        #expect(restored?.excludedMuscles.isEmpty == true)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `xcodebuild build-for-testing -scheme Elos -destination 'generic/platform=iOS Simulator' 2>&1 | tail -40`
Expected: FAIL — `TrainingIntent` has no member `excludedMuscles`, no such init parameter.

- [ ] **Step 3: Implement `TrainingIntent.excludedMuscles` + custom Codable init**

Replace lines 11–21 of `TrainingIntent.swift` (the `TrainingIntent` struct's stored properties + init) with:

```swift
struct TrainingIntent: Equatable, Codable {
    /// Drives rep/rest targets. Defaults from `UserProfileRecord.trainingGoal`.
    var goal: LiftingGoal
    /// The session's focus. `nil` = let the engine infer from the day name (the pre-intent behavior).
    /// Always `nil` at weekly scope — a whole week has no single focus.
    var focus: SplitArchetype?
    /// Muscles the lifter has said they're not training on *this* day/template — distinct from
    /// `VolumeOverrides.excludedMuscles`, which is global. Only takes effect when this intent is
    /// scored at `.singleSession` scope (see `TemplateQualityEngine.score`); a `.weeklySplit`-scope
    /// call ignores it entirely, by design.
    var excludedMuscles: Set<FineMuscle> = []

    init(goal: LiftingGoal, focus: SplitArchetype? = nil, excludedMuscles: Set<FineMuscle> = []) {
        self.goal = goal
        self.focus = focus
        self.excludedMuscles = excludedMuscles
    }
```

Then, immediately after the existing `init?(jsonString:)` block (after the closing `}` that currently ends the struct, i.e. right before line 49's closing `}`), add the backward-compatible decode:

```swift

    // MARK: Backward-compatible decode
    //
    // Synthesized `Decodable` throws `keyNotFound` on a template saved before `excludedMuscles`
    // existed, which would make `init?(jsonString:)` return nil and drop the lifter's saved
    // goal/focus entirely, not just the new field. Writing this by hand suppresses the synthesized
    // memberwise init, which is why the explicit `init(goal:focus:excludedMuscles:)` above exists.

    private enum CodingKeys: String, CodingKey {
        case goal, focus, excludedMuscles
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        goal = try c.decode(LiftingGoal.self, forKey: .goal)
        focus = try c.decodeIfPresent(SplitArchetype.self, forKey: .focus)
        excludedMuscles = try c.decodeIfPresent(Set<FineMuscle>.self, forKey: .excludedMuscles) ?? []
    }
```

(The `init(profile:focus:)` convenience init and everything below it in the file is unchanged.)

- [ ] **Step 4: Run tests to verify they pass**

Run: `xcodebuild build-for-testing -scheme Elos -destination 'generic/platform=iOS Simulator' 2>&1 | tail -40`
Expected: builds clean.
Run: `xcodebuild test -scheme Elos -destination 'id=<udid>' -parallel-testing-enabled NO -only-testing:ElosTests/TrainingIntentTests 2>&1 | tail -60`
Expected: PASS (or verify by careful read if blocked by the pty issue).

- [ ] **Step 5: Commit**

```bash
git add Elos/Features/Train/Programs/Intelligence/TrainingIntent.swift ElosTests/Intelligence/TrainingIntentTests.swift
git commit -m "feat(quality): add TrainingIntent.excludedMuscles with backward-compatible decode"
```

---

### Task 3: `TrainingScience` exclusion-aware bands + citations + group rationale

**Files:**
- Modify: `Elos/Features/Train/Programs/Intelligence/TrainingScience.swift:95-123` (VolumeBand), `:161-175` (weeklyBand)
- Test: `ElosTests/Intelligence/VolumeTargetTests.swift`

- [ ] **Step 1: Write the failing test**

Add to `VolumeTargetTests.swift`, in the same `// MARK: Exclusion` section added in Task 1 (these two are already covered by `excludedMuscleIsOptionalRegardlessOfGroupTarget` and `excludingAMuscleDoesNotZeroItsBandNumbers` written in Task 1 — no *new* test needed here, but re-run them now since they currently fail against `TrainingProfile.swift`'s changes alone, since `weeklyBand` doesn't read `excludedMuscles` yet).

Also add, in `ElosTests/Intelligence/MuscleTaxonomyTests.swift` (append to the existing test struct — read the file first to match its exact struct name and add inside it):

```swift
    @Test func everyGroupHasAVolumeRationale() {
        for g in MuscleGroup.allCases {
            #expect(!g.volumeRationale.isEmpty)
        }
    }

    @Test func citationsAreNonEmptyAndDistinct() {
        #expect(TrainingScience.citations.count >= 2)
        let titles = Set(TrainingScience.citations.map(\.title))
        #expect(titles.count == TrainingScience.citations.count)
    }
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `xcodebuild build-for-testing -scheme Elos -destination 'generic/platform=iOS Simulator' 2>&1 | tail -40`
Expected: FAIL — `MuscleGroup` has no member `volumeRationale`, `TrainingScience` has no member `citations`; and (once that's fixed) `excludedMuscleIsOptionalRegardlessOfGroupTarget` fails at runtime because `weeklyBand` doesn't consult `excludedMuscles` yet.

- [ ] **Step 3a: Add `VolumeBand.asOptional`**

In `TrainingScience.swift`, inside `struct VolumeBand` (after the existing `scaled(_:)` method, before its closing `}` — currently ending at line 122):

```swift
        /// Same numbers, forced optional — used when a muscle is explicitly excluded. Deliberately
        /// does not zero the targets: `isOptional` is what every consumer (`VolumeScorer`,
        /// `FrequencyScorer`, the coverage bars) actually branches on to skip grading/nagging, and
        /// keeping real numbers avoids a divide-by-zero in the bars' fill-percentage math if the
        /// muscle still receives incidental indirect credit from another exercise.
        var asOptional: VolumeBand {
            VolumeBand(mev: mev, targetLow: targetLow, targetHigh: targetHigh, mrv: mrv, isOptional: true)
        }
```

- [ ] **Step 3b: Make `weeklyBand` consult `excludedMuscles`**

Replace the current `weeklyBand(for:profile:)` (lines 161–175):

```swift
    static func weeklyBand(for m: FineMuscle, profile: TrainingProfile) -> VolumeBand {
        let o = profile.volumeOverrides

        // An explicit per-group weekly target is the lifter's own number and replaces the derived
        // one outright — experience and preference already had their say when they chose it.
        // The group's requested total is distributed across its children in the same proportion the
        // science table uses, so "18 sets for Back" doesn't hand lats and lower back equal shares.
        if let requested = o.groupWeeklyTarget[m.group.rawValue], requested > 0 {
            let baseGroupLow = m.group.children.reduce(0.0) { $0 + baseWeeklyBand($1).targetLow }
            if baseGroupLow > 0 {
                return baseWeeklyBand(m).scaled(Double(requested) / baseGroupLow)
            }
        }
        return baseWeeklyBand(m).scaled(experienceScale(profile.experience) * o.preference.scale)
    }
```

with:

```swift
    static func weeklyBand(for m: FineMuscle, profile: TrainingProfile) -> VolumeBand {
        let band = derivedWeeklyBand(for: m, profile: profile)
        // An explicit exclusion always wins, even over a numeric group target left over from before
        // the muscle was excluded — the UI (`VolumeTargetsView`) keeps the two mutually exclusive,
        // but the engine doesn't rely on that alone.
        return profile.volumeOverrides.excludedMuscles.contains(m) ? band.asOptional : band
    }

    private static func derivedWeeklyBand(for m: FineMuscle, profile: TrainingProfile) -> VolumeBand {
        let o = profile.volumeOverrides

        // An explicit per-group weekly target is the lifter's own number and replaces the derived
        // one outright — experience and preference already had their say when they chose it.
        // The group's requested total is distributed across its children in the same proportion the
        // science table uses, so "18 sets for Back" doesn't hand lats and lower back equal shares.
        if let requested = o.groupWeeklyTarget[m.group.rawValue], requested > 0 {
            let baseGroupLow = m.group.children.reduce(0.0) { $0 + baseWeeklyBand($1).targetLow }
            if baseGroupLow > 0 {
                return baseWeeklyBand(m).scaled(Double(requested) / baseGroupLow)
            }
        }
        return baseWeeklyBand(m).scaled(experienceScale(profile.experience) * o.preference.scale)
    }
```

(`sessionBand` is unchanged — it already does `return VolumeBand(mev: 0, targetLow: low, targetHigh: high, mrv: junk, isOptional: weekly.isOptional)`, so it inherits the exclusion automatically once `weekly.isOptional` is `true`.)

- [ ] **Step 3c: Add `ResearchCitation` + `citations`**

At the end of `TrainingScience.swift`, before the enum's closing `}` (after the `minVolumeEfficiency` constant):

```swift

    // MARK: - Citations
    //
    // Real, named sources — the point of showing "cited studies" to a lifter is that the citation is
    // checkable. Kept to 2–3 shared references rather than one per muscle group, because the
    // literature reports these findings per *muscle group*, not per fine muscle — inventing 16
    // fine-muscle-specific studies would be dishonest, not more rigorous.
    static let citations: [ResearchCitation] = [
        .init(authors: "Schoenfeld, Grgic & Krieger", year: 2017,
              title: "Dose-response relationship between weekly resistance training volume and increases in muscle mass",
              finding: "More weekly sets per muscle (up to roughly 20) reliably produced more muscle growth across the studies reviewed."),
        .init(authors: "Schoenfeld, Grgic & Krieger", year: 2019,
              title: "How many times per week should a muscle be trained to maximize muscle hypertrophy?",
              finding: "Spreading the same weekly volume across two or more sessions tended to build more muscle than cramming it into one."),
        .init(authors: "Israetel & Renaissance Periodization", year: 2019,
              title: "The Renaissance Periodization volume-landmarks framework (MEV / MAV / MRV)",
              finding: "Frames a productive training range between a minimum that's worth doing and a maximum you can still recover from."),
    ]
}

/// One cited source behind the volume recommendations, shown in `VolumeTargetsView`.
struct ResearchCitation: Equatable {
    let authors: String
    let year: Int
    let title: String
    /// One plain-English sentence — what the source actually found, not academic phrasing.
    let finding: String
}
```

- [ ] **Step 3d: Add `MuscleGroup.volumeRationale`**

In `Elos/Features/Train/Programs/Intelligence/MuscleTaxonomy.swift`, after the `MuscleGroup` enum's closing `}` (it currently ends right after the `children` computed property, around line 14):

```swift

extension MuscleGroup {
    /// One plain-English sentence tying this group's recommended volume back to the shared
    /// `TrainingScience.citations` — not a separate study per group, a contextual gloss on the same
    /// two or three sources.
    var volumeRationale: String {
        switch self {
        case .chest:
            return "Chest responds reliably to more weekly sets up to a point, and hitting it from a couple of angles (flat, incline) recruits it more completely than one."
        case .back:
            return "Back covers more muscle mass than any other group and different pulling angles (rows, pulldowns) reach different parts of it, so it tends to reward higher volume and training it twice a week."
        case .shoulders:
            return "Front delts already get heavily worked by any pressing you do, so direct shoulder volume mainly needs to cover side and rear delts."
        case .arms:
            return "Biceps and triceps get real secondary work from pressing and pulling, so their direct-set targets sit a bit lower than the big compound-heavy groups."
        case .legs:
            return "Quads, hamstrings and calves are large, resilient muscles that generally tolerate — and benefit from — higher volume than upper-body muscles."
        case .glutes:
            return "Glutes respond to both squat- and hinge-pattern work, so their volume often overlaps with leg day rather than needing a dedicated block."
        case .core:
            return "A small amount of direct core work goes a long way once your compound lifts are already providing indirect bracing volume."
        }
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `xcodebuild build-for-testing -scheme Elos -destination 'generic/platform=iOS Simulator' 2>&1 | tail -40`
Expected: builds clean.
Run: `xcodebuild test -scheme Elos -destination 'id=<udid>' -parallel-testing-enabled NO -only-testing:ElosTests/VolumeTargetTests -only-testing:ElosTests/MuscleTaxonomyTests 2>&1 | tail -80`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Elos/Features/Train/Programs/Intelligence/TrainingScience.swift Elos/Features/Train/Programs/Intelligence/MuscleTaxonomy.swift ElosTests/Intelligence/VolumeTargetTests.swift ElosTests/Intelligence/MuscleTaxonomyTests.swift
git commit -m "feat(volume): exclusion-aware weeklyBand, cited sources, per-group rationale"
```

---

### Task 4: `TemplateQualityEngine.score` — scope-aware exclusion merge

**Files:**
- Modify: `Elos/Features/Train/Programs/Intelligence/TemplateQualityEngine.swift:40-75`
- Test: `ElosTests/Intelligence/TemplateQualityEngineTests.swift`

- [ ] **Step 1: Write the failing test**

Add to `TemplateQualityEngineTests.swift` (append inside the `TemplateQualityEngineTests` struct):

```swift
    @Test func daySpecificExclusionAffectsSingleSessionScore() {
        // Excluding a muscle that's genuinely missing removes the coverage-gap penalty for it.
        let day = [
            QualityFixtures.sx("bench", sets: 4),
            QualityFixtures.sx("incline", sets: 4),
        ]
        let withoutExclusion = TemplateQualityEngine.score(
            days: [day], dayNames: ["Push Day"], scope: .singleSession,
            profile: profile, catalog: QualityFixtures.catalog,
            intent: TrainingIntent(goal: .hypertrophy, focus: .push))
        let withExclusion = TemplateQualityEngine.score(
            days: [day], dayNames: ["Push Day"], scope: .singleSession,
            profile: profile, catalog: QualityFixtures.catalog,
            intent: TrainingIntent(goal: .hypertrophy, focus: .push, excludedMuscles: [.sideDelts, .frontDelts, .rotatorCuff, .biceps, .triceps, .forearms]))
        let gapTips = { (r: QualityReport) in r.tips.filter { $0.id.hasPrefix("bal-focusgap-") } }
        #expect(!gapTips(withoutExclusion).isEmpty)
        #expect(gapTips(withExclusion).isEmpty)
    }

    @Test func dayScopedExclusionDoesNotAffectWeeklySplitScore() {
        // D1: a per-day exclusion must be provably inert at `.weeklySplit` scope, regardless of what
        // the intent passed in carries. This is the direct regression test for that guarantee.
        let days: [[ScoredExercise]] = [
            [QualityFixtures.sx("bench", sets: 6), QualityFixtures.sx("ohp", sets: 6)],
            [QualityFixtures.sx("row", sets: 6), QualityFixtures.sx("pulldown", sets: 6)],
            [QualityFixtures.sx("squat", sets: 6), QualityFixtures.sx("rdl", sets: 6)],
        ]
        let dayNames = ["Push", "Pull", "Legs"]
        let withoutExclusion = TemplateQualityEngine.score(
            days: days, dayNames: dayNames, scope: .weeklySplit,
            profile: profile, catalog: QualityFixtures.catalog,
            intent: TrainingIntent(goal: .hypertrophy))
        let withExclusion = TemplateQualityEngine.score(
            days: days, dayNames: dayNames, scope: .weeklySplit,
            profile: profile, catalog: QualityFixtures.catalog,
            intent: TrainingIntent(goal: .hypertrophy, excludedMuscles: [.quads, .hamstrings, .chest, .lats]))
        #expect(withoutExclusion.overall == withExclusion.overall)
    }

    @Test func globalExclusionDoesAffectWeeklySplitScore() {
        // Contrast with the test above: the *global* exclusion lever (VolumeOverrides) is not
        // scope-gated — only the day-scoped one (TrainingIntent) is.
        let days: [[ScoredExercise]] = [
            [QualityFixtures.sx("squat", sets: 3)],
        ]
        let dayNames = ["Legs"]
        let withoutExclusion = TemplateQualityEngine.score(
            days: days, dayNames: dayNames, scope: .weeklySplit,
            profile: profile, catalog: QualityFixtures.catalog)
        let excludedProfile = TrainingProfile(
            goal: .hypertrophy, experience: .intermediate,
            volumeOverrides: VolumeOverrides(excludedMuscles: [.quads, .glutes]))
        let withExclusion = TemplateQualityEngine.score(
            days: days, dayNames: dayNames, scope: .weeklySplit,
            profile: excludedProfile, catalog: QualityFixtures.catalog)
        #expect(withoutExclusion.overall != withExclusion.overall)
    }
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `xcodebuild build-for-testing -scheme Elos -destination 'generic/platform=iOS Simulator' 2>&1 | tail -40`
Expected: compiles (the `intent:excludedMuscles:` init already exists from Task 2), but `daySpecificExclusionAffectsSingleSessionScore` and `globalExclusionDoesAffectWeeklySplitScore` FAIL at runtime — `TemplateQualityEngine.score` doesn't read `excludedMuscles` from either source yet. `dayScopedExclusionDoesNotAffectWeeklySplitScore` trivially passes right now (nothing reads the field at all) — that's fine, it'll stay passing after the real implementation for the *right* reason instead of by accident.

- [ ] **Step 3: Implement the merge**

Replace lines 40–55 of `TemplateQualityEngine.swift` (the start of `score(...)` through the `movement` analyzer call) with:

```swift
    static func score(days: [[ScoredExercise]],
                      dayNames: [String],
                      scope: QualityScope,
                      profile: TrainingProfile,
                      catalog: [ExerciseCandidate],
                      intent: TrainingIntent? = nil) -> QualityReport {
        // Day-scoped exclusions only apply at the scope a single day actually has — this makes D1
        // (a day-level "skip this muscle" never affects a split's weekly score) an engine-level
        // guarantee rather than something every call site has to remember to withhold. The *global*
        // exclusion set (`profile.volumeOverrides.excludedMuscles`) is not scope-gated.
        let dayScopedExclusions: Set<FineMuscle> = scope == .singleSession ? (intent?.excludedMuscles ?? []) : []
        let excludedMuscles = profile.volumeOverrides.excludedMuscles.union(dayScopedExclusions)
        var effectiveOverrides = profile.volumeOverrides
        effectiveOverrides.excludedMuscles = excludedMuscles
        let profile = TrainingProfile(goal: profile.goal, experience: profile.experience,
                                      volumeOverrides: effectiveOverrides)

        let resolvedDays = ExerciseResolver.resolve(days, catalog: catalog)
        let totalExercises = resolvedDays.reduce(0) { $0 + $1.count }

        // Shared analyzers — run once, consumed by several scorers and by the UI.
        let volume = MuscleVolumeAnalyzer.analyze(resolvedDays: resolvedDays, scope: scope,
                                                  intent: intent, dayNames: dayNames,
                                                  profile: profile, catalog: catalog)
        let movement = MovementQualityAnalyzer.analyze(resolvedDays: resolvedDays, scope: scope,
                                                       intent: intent, dayNames: dayNames,
                                                       catalog: catalog)
```

Then, in the `dimensions` array a few lines below, add the new parameter to the `BalanceScorer.score` call:

```swift
        let dimensions = [
            VolumeScorer.score(volume: volume, scope: scope, profile: profile),
            BalanceScorer.score(resolvedDays: resolvedDays, scope: scope, dayNames: dayNames,
                                intent: intent, volume: volume, catalog: catalog,
                                excludedMuscles: excludedMuscles),
            SelectionScorer.score(resolvedDays: resolvedDays, scope: scope, profile: profile,
                                  movement: movement),
            RepRestScorer.score(resolvedDays: resolvedDays, scope: scope, profile: profile),
            FrequencyScorer.score(volume: volume, scope: scope, profile: profile),
            FatigueScorer.score(resolvedDays: resolvedDays, dayNames: dayNames, scope: scope),
        ]
```

(This won't compile yet — `BalanceScorer.score` doesn't have an `excludedMuscles:` parameter. That's Task 5, next. Leave it; you'll build both together.)

- [ ] **Step 4: Move to Task 5 before attempting to build** — Task 5 adds the parameter this call needs. Come back and run the build/test commands for both tasks together at the end of Task 5's Step 4.

---

### Task 5: `BalanceScorer` — `excludedMuscles` param + all-children-excluded group skip

**Files:**
- Modify: `Elos/Features/Train/Programs/Intelligence/BalanceScorer.swift:12-133`
- Test: `ElosTests/Intelligence/BalanceScorerTests.swift`

- [ ] **Step 1: Write the failing test**

Add to `BalanceScorerTests.swift`. First, update the private `score` helper (lines 6–17) to accept and forward the new param:

```swift
    /// Score days at a scope, building the shared muscle report the scorer now reads.
    private func score(_ days: [[ScoredExercise]],
                       scope: QualityScope,
                       dayNames: [String],
                       intent: TrainingIntent? = nil,
                       excludedMuscles: Set<FineMuscle> = []) -> DimensionScore {
        let resolved = QualityFixtures.resolve(days)
        let volume = QualityFixtures.volume(resolved, scope: scope,
                                            intent: intent, dayNames: dayNames)
        return BalanceScorer.score(resolvedDays: resolved, scope: scope, dayNames: dayNames,
                                   intent: intent, volume: volume,
                                   catalog: QualityFixtures.catalog,
                                   excludedMuscles: excludedMuscles)
    }
```

Then add these tests inside the `BalanceScorerTests` struct:

```swift
    @Test func excludingEveryChildOfAMissingGroupSuppressesTheGapTip() {
        let d = score([[QualityFixtures.sx("bench", sets: 12)]],
                      scope: .weeklySplit, dayNames: [""],
                      excludedMuscles: Set(MuscleGroup.legs.children))
        #expect(!d.tips.contains { $0.id == "bal-gap-legs" })
        // Back is untouched — still missing, still flagged.
        #expect(d.tips.contains { $0.id == "bal-gap-back" })
    }

    @Test func excludingOnlySomeChildrenOfAGroupDoesNotSuppressTheGapTip() {
        // Excluding calves alone doesn't excuse "no legs work at all" — quads/hamstrings are still
        // expected.
        let d = score([[QualityFixtures.sx("bench", sets: 12)]],
                      scope: .weeklySplit, dayNames: [""],
                      excludedMuscles: [.calves])
        #expect(d.tips.contains { $0.id == "bal-gap-legs" })
    }

    @Test func excludingAFocusedSessionsMissingGroupSuppressesTheInfoTip() {
        let d = score([[
            QualityFixtures.sx("bench", sets: 4),
            QualityFixtures.sx("incline", sets: 4),
        ]], scope: .singleSession, dayNames: ["Push Day"],
            excludedMuscles: [.sideDelts, .frontDelts, .rotatorCuff])
        #expect(!d.tips.contains { $0.id.hasPrefix("bal-focusgap-shoulders") })
    }
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `xcodebuild build-for-testing -scheme Elos -destination 'generic/platform=iOS Simulator' 2>&1 | tail -60`
Expected: FAIL to compile — `BalanceScorer.score` has no `excludedMuscles:` parameter (this is also what's blocking Task 4's edit from compiling).

- [ ] **Step 3: Implement the new parameter + group skip**

In `BalanceScorer.swift`, change the `score(...)` signature (lines 12–17):

```swift
    static func score(resolvedDays: [[ResolvedExercise]],
                      scope: QualityScope,
                      dayNames: [String],
                      intent: TrainingIntent?,
                      volume: MuscleVolumeReport,
                      catalog: [ExerciseCandidate],
                      excludedMuscles: Set<FineMuscle> = []) -> DimensionScore {
```

In the `.weeklySplit` case's major-groups loop and core check (lines 71–97), guard each:

```swift
        case .weeklySplit:
            let major: [MuscleGroup] = [.chest, .back, .legs, .shoulders, .arms]
            for g in major where volume.directSets(forGroup: g) == 0 {
                if g.children.allSatisfy({ excludedMuscles.contains($0) }) { continue }
                // A group can have zero *direct* work yet real indirect volume (arms off presses and
                // rows). That's a lighter problem than a true blind spot, so say so and penalise less.
                let indirect = volume.sets(forGroup: g)
                if indirect > 0 {
                    penalties += 0.08
                    tips.append(QualityTip(
                        id: "bal-gap-\(g.rawValue)", dimension: .balance, severity: .info,
                        message: "\(g.displayName) only gets indirect work from your compounds. Add a direct \(g.rawValue) movement to actually drive growth there.",
                        action: .addMuscle(g.rawValue)))
                } else {
                    penalties += 0.14
                    tips.append(QualityTip(
                        id: "bal-gap-\(g.rawValue)", dimension: .balance, severity: .warn,
                        message: "No \(g.rawValue) work this week — every major muscle should be trained. Add a \(g.rawValue) movement or day.",
                        action: .addMuscle(g.rawValue)))
                }
            }
            if volume.directSets(forGroup: .core) == 0, !MuscleGroup.core.children.allSatisfy({ excludedMuscles.contains($0) }) {
                penalties += 0.05
                tips.append(QualityTip(
                    id: "bal-gap-core", dimension: .balance, severity: .info,
                    message: "No direct core work — a couple of ab/anti-rotation sets round out the week.",
                    action: .addMuscle("core")))
            }
```

In the `.singleSession` case's archetype-groups loop (lines 99–113), guard the target group set:

```swift
        case .singleSession:
            let trained = Set(MuscleGroup.allCases.filter { volume.directSets(forGroup: $0) > 0 })
            // Explicit intent wins; fall back to inferring from the day name.
            // Day name only — see the note on `MuscleVolumeAnalyzer.inferredArchetype`.
            let archetype: SplitArchetype? = intent?.focus
                ?? MuscleTaxonomy.archetype(forDayName: dayNames.first ?? "")
            if let arch = archetype {
                let targetGroups = archetypeGroups(arch)
                    .filter { !$0.children.allSatisfy({ excludedMuscles.contains($0) }) }
                for g in targetGroups.subtracting(trained) {
                    penalties += 0.12
                    tips.append(QualityTip(
                        id: "bal-focusgap-\(g.rawValue)", dimension: .balance, severity: .info,
                        message: "This looks like a \(arch.rawValue) day, but \(g.rawValue) isn't covered yet — add a \(g.rawValue) movement.",
                        action: .addMuscle(g.rawValue)))
                }
            } else if trained.count == 1, all.count >= 3, let only = trained.first {
```

(Everything else in the file — the push/pull check, the quad/hamstring check, the `unfocusedSingleGroupSessionFlagged` branch, `archetypeGroups(_:)` — is unchanged.)

- [ ] **Step 4: Run all affected tests (Tasks 4 and 5 together)**

Run: `xcodebuild build-for-testing -scheme Elos -destination 'generic/platform=iOS Simulator' 2>&1 | tail -60`
Expected: builds clean now that both `TemplateQualityEngine.swift` and `BalanceScorer.swift` compile together.

Run: `xcodebuild test -scheme Elos -destination 'id=<udid>' -parallel-testing-enabled NO -only-testing:ElosTests/BalanceScorerTests -only-testing:ElosTests/TemplateQualityEngineTests 2>&1 | tail -100`
Expected: PASS, including every pre-existing test in both files (they all call with the new param defaulted to `[]`, so behavior for them is unchanged).

- [ ] **Step 5: Commit**

```bash
git add Elos/Features/Train/Programs/Intelligence/TemplateQualityEngine.swift Elos/Features/Train/Programs/Intelligence/BalanceScorer.swift ElosTests/Intelligence/BalanceScorerTests.swift ElosTests/Intelligence/TemplateQualityEngineTests.swift
git commit -m "feat(quality): scope-aware exclusion merge in TemplateQualityEngine + BalanceScorer group skip"
```

---

## Phase 2 — Template UI

### Task 6: `SkipMusclesSheet`

**Files:**
- Create: `Elos/Features/Train/Programs/SkipMusclesSheet.swift`

- [ ] **Step 1: Write the file**

```swift
import SwiftUI

/// Lets the lifter say "I'm not training this muscle here" for one day/template — the coach never
/// nags about a gap that's intentional. Grouped by `MuscleGroup`, live-editing straight into the
/// bound `Set<FineMuscle>` (no separate Save step, same philosophy as `VolumeTargetsView`'s
/// `GroupTargetEditor`: edits apply immediately).
///
/// Button rows with a checkmark, deliberately not `Toggle` — mirrors `MuscleTargetSheet`, the proven
/// working pattern for "pick several muscles from a grouped list" in this codebase. A `Toggle` inside
/// a `List` in a very similar sheet context (`VolumeTargetsView.GroupTargetEditor`) has previously
/// failed to fire at all.
struct SkipMusclesSheet: View {
    @Binding var selection: Set<FineMuscle>
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Muscles checked here are left out of this day's coverage checks and quality score — use it for muscles you're training on a different day, or not training at all on purpose.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .listRowBackground(Color.clear)
                }
                ForEach(MuscleGroup.allCases, id: \.self) { group in
                    Section(group.displayName) {
                        ForEach(group.children, id: \.self) { muscle in
                            muscleRow(muscle)
                        }
                    }
                }
            }
            .navigationTitle("Skip Muscles")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
    }

    private func muscleRow(_ m: FineMuscle) -> some View {
        let isOn = selection.contains(m)
        return Button {
            HapticManager.impact(.light)
            if isOn { selection.remove(m) } else { selection.insert(m) }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isOn ? Color.tint : Color.secondary)
                Text(m.displayName)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
```

- [ ] **Step 2: Verify it compiles**

This file has no test of its own (it's a thin SwiftUI view over a `Set<FineMuscle>` binding — the actual exclusion *logic* is already covered by Tasks 1–5's unit tests). Just confirm it builds:

Run: `xcodebuild build -scheme Elos -destination 'generic/platform=iOS Simulator' 2>&1 | tail -40`
Expected: builds clean. (It's not referenced from anywhere yet, so this only checks the file's own syntax/types — `HapticManager.impact`, `Color.tint`, `Color.secondary` all already exist and are used the same way in `MuscleTargetSheet.swift`.)

- [ ] **Step 3: Commit**

```bash
git add Elos/Features/Train/Programs/SkipMusclesSheet.swift
git commit -m "feat(quality): add SkipMusclesSheet for per-day muscle exclusion"
```

---

### Task 7: `TrainingIntentRow` — `showsSkip` chip

**Files:**
- Modify: `Elos/Features/Train/Programs/TrainingIntentRow.swift`

- [ ] **Step 1: Implement**

Replace the whole file with:

```swift
import SwiftUI

/// The "what are you building?" control. Chips that make the coach's targets explicit instead of
/// guessed from the day name.
///
/// `focus` is optional: `nil` means "let it work that out from the name", which is exactly the
/// pre-intent behaviour, so this never becomes a required step. `excludedMuscles` is opt-in the same
/// way: an empty set means every scoring dimension behaves exactly as before this feature shipped.
struct TrainingIntentRow: View {
    @Binding var intent: TrainingIntent
    /// Shown as the auto option's subtitle, e.g. the day name we'd infer from.
    var inferredFocus: SplitArchetype? = nil
    /// Weekly scope has no single focus — show only the goal chip.
    var showsFocus: Bool = true
    /// The weekly split panel binds this row to the split-wide `TrainingIntent`, whose
    /// `excludedMuscles` the engine ignores at `.weeklySplit` scope (see
    /// `TemplateQualityEngine.score`) — the chip is hidden there too, so there's no control on
    /// screen that would silently do nothing. Per-day exclusion in that context is a separate
    /// per-day binding, not this row's `intent`.
    var showsSkip: Bool = true

    @State private var showingSkipSheet = false

    var body: some View {
        // Two/three chips side by side until the labels no longer fit, then stacked. Squeezed onto
        // one row at larger text sizes they truncated to "Any f…" and "Muscl…" — a control whose
        // entire job is to state the current focus and goal, unable to state either.
        ViewThatFits(in: .horizontal) {
            HStack(spacing: Space.s) {
                if showsFocus { focusChip }
                goalChip
                if showsSkip { skipChip }
                Spacer(minLength: 0)
            }
            VStack(alignment: .leading, spacing: Space.s) {
                if showsFocus { focusChip }
                goalChip
                if showsSkip { skipChip }
            }
        }
        .sheet(isPresented: $showingSkipSheet) {
            SkipMusclesSheet(selection: $intent.excludedMuscles)
        }
    }

    // MARK: Focus

    private var focusChip: some View {
        Menu {
            Button {
                intent.focus = nil
            } label: {
                Label(inferredFocus.map { "Automatic (\($0.displayName))" } ?? "Automatic",
                      systemImage: "wand.and.stars")
            }
            Divider()
            ForEach(SplitArchetype.allCases, id: \.self) { f in
                Button {
                    intent.focus = f
                } label: {
                    Label(f.displayName, systemImage: f.icon)
                }
            }
        } label: {
            chip(icon: resolvedFocus?.icon ?? "wand.and.stars",
                 text: resolvedFocus?.displayName ?? "Any focus",
                 isSet: intent.focus != nil)
        }
        .accessibilityLabel("Session focus")
        .accessibilityValue(resolvedFocus?.displayName ?? "Automatic")
    }

    private var resolvedFocus: SplitArchetype? { intent.focus ?? inferredFocus }

    // MARK: Goal

    private var goalChip: some View {
        Menu {
            ForEach(LiftingGoal.allCases, id: \.self) { g in
                Button { intent.goal = g } label: { Text(g.pickerLabel) }
            }
        } label: {
            chip(icon: "target", text: intent.goal.pickerLabel, isSet: true)
        }
        .accessibilityLabel("Training goal")
        .accessibilityValue(intent.goal.pickerLabel)
    }

    // MARK: Skip muscles

    private var skipChip: some View {
        Button {
            showingSkipSheet = true
        } label: {
            chip(icon: "eye.slash",
                 text: intent.excludedMuscles.isEmpty ? "Skip muscles" : "Skip (\(intent.excludedMuscles.count))",
                 isSet: !intent.excludedMuscles.isEmpty)
        }
        .accessibilityLabel("Skip muscles")
        .accessibilityValue(intent.excludedMuscles.isEmpty ? "None" : "\(intent.excludedMuscles.count) selected")
    }

    // MARK: Chip

    private func chip(icon: String, text: String, isSet: Bool) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(.caption2, weight: .semibold))
            Text(text)
                .font(.system(.caption, weight: .semibold))
                .lineLimit(1)
            Image(systemName: "chevron.down")
                .font(.system(.caption2, weight: .bold))
                .foregroundStyle(.tertiary)
        }
        // The chip sizes to its label; the row above decides whether both fit on one line.
        .fixedSize()
        .foregroundStyle(isSet ? Color.tint : Color.secondary)
        .padding(.horizontal, 11)
        .padding(.vertical, 6)
        .background(isSet ? Color.tintSoft : Color(.tertiarySystemGroupedBackground))
        .overlay(Capsule().stroke(isSet ? Color.tint.opacity(0.25) : .clear, lineWidth: 1))
        .clipShape(Capsule())
    }
}
```

Note: the `skipChip`'s trailing chevron (via `chip(...)`) is slightly misleading since it opens a sheet, not a menu — leave it as-is for this pass (shared helper, consistent chip look across all three); not worth a bespoke chip shape for one control.

- [ ] **Step 2: Update the one call site that must suppress the new chip**

In `Elos/Features/Train/Programs/CreateSplitView.swift`, line 249, change:

```swift
                TrainingIntentRow(intent: $intent, showsFocus: false)
```

to:

```swift
                TrainingIntentRow(intent: $intent, showsFocus: false, showsSkip: false)
```

This is the split's *weekly* panel — its `intent` feeds the `.weeklySplit` score, and Task 4 made that scope ignore `excludedMuscles` entirely, so showing the chip there would offer a control that silently does nothing. (`CreateTemplateView.swift:378`'s call, `TrainingIntentRow(intent: $intent, inferredFocus: inferredFocus)`, is unchanged — both new params default to `true`, which is correct there.)

- [ ] **Step 3: Verify it compiles and the existing call sites still work**

Run: `xcodebuild build -scheme Elos -destination 'generic/platform=iOS Simulator' 2>&1 | tail -60`
Expected: builds clean.

- [ ] **Step 4: Manual verification in the simulator**

- [ ] Boot the simulator and run the app (or use `mcp__Claude_Code_iOS_Simulator__control`).
- [ ] Open Train → new template (or edit an existing one). Confirm three chips now appear: Focus, Goal, Skip muscles.
- [ ] Tap "Skip muscles", check a couple of boxes (e.g. Lower back), tap Done. Confirm the chip now reads "Skip (N)" and is tinted.
- [ ] Confirm the quality score/tips for that template don't flag the excluded muscle(s) as a gap.
- [ ] Open Train → Programs → a split, and in the split's own top-level quality panel, confirm there is **no** "Skip muscles" chip next to the Goal chip (only two chips, per the `showsSkip: false` change).

- [ ] **Step 5: Commit**

```bash
git add Elos/Features/Train/Programs/TrainingIntentRow.swift Elos/Features/Train/Programs/CreateSplitView.swift
git commit -m "feat(quality): wire Skip-muscles chip into TrainingIntentRow, suppressed on the weekly row"
```

---

## Phase 3 — Split UI (per-day exclusion for individual split days)

### Task 8: `UserSplitDayRecord.excludedMusclesJSON` (SwiftData lightweight migration)

**Files:**
- Modify: `Elos/SwiftData/ElosSchema.swift:644-668`

- [ ] **Step 1: Implement**

Replace the `UserSplitDayRecord` class (lines 644–668):

```swift
@Model
final class UserSplitDayRecord {
    var id: String
    var splitID: String
    var orderIndex: Int
    var dayLabel: String
    var dayName: String
    var templateID: String
    var isRest: Bool
    var exercisesJSON: String  // JSON array of {id, name} for directly-assigned exercises
    /// Muscles the lifter has said this specific day isn't training — local-only JSON, same
    /// lightweight-migration trick as `WorkoutTemplateRecord.intentJSON`. Defaulted so existing rows
    /// pick up the new column with no exclusions.
    var excludedMusclesJSON: String = ""

    var excludedMuscles: Set<FineMuscle> {
        get {
            guard !excludedMusclesJSON.isEmpty,
                  let data = excludedMusclesJSON.data(using: .utf8),
                  let decoded = try? JSONDecoder().decode(Set<FineMuscle>.self, from: data)
            else { return [] }
            return decoded
        }
        set {
            guard let data = try? JSONEncoder().encode(newValue),
                  let s = String(data: data, encoding: .utf8) else { return }
            excludedMusclesJSON = s
        }
    }

    init(id: String = UUID().uuidString, splitID: String,
         orderIndex: Int, dayLabel: String,
         dayName: String = "", templateID: String = "", isRest: Bool = false,
         exercisesJSON: String = "[]") {
        self.id            = id
        self.splitID       = splitID
        self.orderIndex    = orderIndex
        self.dayLabel      = dayLabel
        self.dayName       = dayName
        self.templateID    = templateID
        self.isRest        = isRest
        self.exercisesJSON = exercisesJSON
    }
}
```

(`excludedMusclesJSON` is set via the computed property after construction at the one call site that builds these records — see Task 9 — rather than adding a fourth JSON param to this initializer.)

- [ ] **Step 2: Verify it compiles**

Run: `xcodebuild build -scheme Elos -destination 'generic/platform=iOS Simulator' 2>&1 | tail -40`
Expected: builds clean. This is additive-only (new `var` with a default, matching `WorkoutTemplateRecord.intentJSON`'s exact precedent) — SwiftData handles it as a lightweight migration with no explicit migration code needed, the same way `intentJSON` itself was introduced.

- [ ] **Step 3: Commit**

```bash
git add Elos/SwiftData/ElosSchema.swift
git commit -m "feat(splits): add UserSplitDayRecord.excludedMusclesJSON (lightweight migration)"
```

---

### Task 9: `CreateSplitView` — per-day exclusion state, load/save, chip, scoring

**Files:**
- Modify: `Elos/Features/Train/Programs/CreateSplitView.swift`

- [ ] **Step 1: Add the per-day state array**

Near the other per-day `@State` arrays (around line 38, right after `dayExercises`):

```swift
    @State private var dayExercises: [[DayExercise]] = Array(repeating: [], count: 7)
    @State private var dayExcludedMuscles: [Set<FineMuscle>] = Array(repeating: [], count: 7)
```

- [ ] **Step 2: Load from `editDays` in `.onAppear`**

In the `.onAppear` block's `else if let s = editSplit` branch (around line 118–131), add one line inside the `for day in editDays` loop:

```swift
                } else if let s = editSplit {
                    splitName = s.name
                    for day in editDays {
                        let i = day.orderIndex
                        guard i < 7 else { continue }
                        dayIsRest[i] = day.isRest
                        dayNames[i] = day.isRest ? "" : (day.dayName == dayLabels[i] ? "" : day.dayName)
                        dayTemplateIDs[i] = day.templateID
                        dayExcludedMuscles[i] = day.excludedMuscles
                        if let data = day.exercisesJSON.data(using: .utf8),
                           let decoded = try? JSONDecoder().decode([DayExercise].self, from: data) {
                            dayExercises[i] = decoded
                        }
                    }
                }
```

- [ ] **Step 3: Save in `buildDays(for:)`**

Replace `buildDays(for:)` (currently lines 510–525):

```swift
        func buildDays(for splitID: String) {
            for (i, label) in dayLabels.enumerated() {
                let exData = try? encoder.encode(dayExercises[i])
                let exJSON = exData.flatMap { String(data: $0, encoding: .utf8) } ?? "[]"
                let rest = isEffectivelyRest(i)
                let day = UserSplitDayRecord(
                    splitID: splitID,
                    orderIndex: i,
                    dayLabel: label,
                    dayName: rest ? "Rest" : (dayNames[i].isEmpty ? label : dayNames[i]),
                    templateID: rest ? "" : dayTemplateIDs[i],
                    isRest: rest,
                    exercisesJSON: rest ? "[]" : exJSON
                )
                day.excludedMuscles = rest ? [] : dayExcludedMuscles[i]
                modelContext.insert(day)
            }
        }
```

- [ ] **Step 4: Fold the day's exclusions into `daySummaries`' per-day scoring call**

Replace the body of `daySummaries` (currently lines 262–278):

```swift
    private var daySummaries: [SplitDaySummary] {
        (0..<min(7, dayExercises.count)).compactMap { i in
            let day = dayExercises[i]
            guard !dayIsRest[i], !day.isEmpty else { return nil }
            let scored = day.map(ScoredExercise.init(day:))
            let dayIntent = TrainingIntent(goal: intent.goal, focus: nil,
                                          excludedMuscles: dayExcludedMuscles[i])
            let r = TemplateQualityEngine.score(days: [scored], dayNames: [dayNames[i]],
                                                scope: .singleSession,
                                                profile: scoringProfile,
                                                catalog: exerciseCatalog,
                                                intent: dayIntent)
            return SplitDaySummary(
                id: i,
                name: dayNames[i].isEmpty ? dayLabels[i] : dayNames[i],
                exerciseCount: day.count,
                sets: day.reduce(0) { $0 + $1.sets },
                score: r.isScored ? r.overall : nil)
        }
    }
```

(`focus: nil` is deliberate — per-day focus isn't a feature this split builder has; the day name still drives `BalanceScorer`'s archetype inference the same way it did before this change, since `intent?.focus` is `nil` here just as passing no intent at all left it `nil` before.)

- [ ] **Step 5: Add the per-day "Skip muscles" chip + sheet**

Add a tiny `Identifiable` wrapper near the existing `MuscleEdit` struct (around line 49–53):

```swift
    private struct MuscleEdit: Identifiable {
        let dayIndex: Int
        let exerciseIndex: Int
        var id: String { "\(dayIndex)-\(exerciseIndex)" }
    }

    private struct SkipMusclesDay: Identifiable {
        let dayIndex: Int
        var id: Int { dayIndex }
    }
```

Add the matching `@State` near `muscleEdit` (around line 47):

```swift
    @State private var muscleEdit: MuscleEdit? = nil
    @State private var skipMusclesDay: SkipMusclesDay? = nil
```

In `dayRow(index:)`, right after the day-name/template `HStack` (after line 374's closing `}`, before the "Auto-fill recommended" block that starts at line 376), add the chip — same small-capsule style as the existing "Sort" / "Auto-fill recommended" buttons in this same function:

```swift
                HStack(spacing: 8) {
                    Button {
                        skipMusclesDay = SkipMusclesDay(dayIndex: i)
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "eye.slash")
                                .font(.caption2)
                            Text(dayExcludedMuscles[i].isEmpty
                                 ? "Skip muscles" : "Skip muscles (\(dayExcludedMuscles[i].count))")
                                .font(.caption2)
                        }
                        .foregroundStyle(Color.tint)
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(Color.tint.opacity(0.1))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    Spacer()
                }
```

Add the sheet presentation alongside the view's other `.sheet` modifiers (near `.sheet(item: $muscleEdit) { ... }`, around line 186–197):

```swift
            .sheet(item: $skipMusclesDay) { day in
                SkipMusclesSheet(selection: $dayExcludedMuscles[day.dayIndex])
            }
```

- [ ] **Step 6: Verify it compiles**

Run: `xcodebuild build -scheme Elos -destination 'generic/platform=iOS Simulator' 2>&1 | tail -60`
Expected: builds clean.

- [ ] **Step 7: Manual verification in the simulator**

- [ ] Open Train → Programs → New Split (or edit an existing one). Add exercises to at least 2 days (e.g. an "Upper" day and a "Lower" day) so the weekly panel appears.
- [ ] On the "Upper" day row, tap the new "Skip muscles" chip, check "Lower back", Done. Confirm the chip now reads "Skip muscles (1)".
- [ ] Open the split's full report ("See full report" in the weekly panel). Confirm the Upper day's own mini score doesn't flag lower back as a gap, while the Lower day (untouched) is unaffected.
- [ ] Save the split, re-open it for editing, confirm the Upper day's "Skip muscles (1)" persisted.
- [ ] Confirm the split's overall weekly score is unchanged by the per-day exclusion (compare the weekly score before and after checking the box — same number).

- [ ] **Step 8: Commit**

```bash
git add Elos/Features/Train/Programs/CreateSplitView.swift
git commit -m "feat(splits): per-day muscle exclusion — state, persistence, chip, scoring"
```

---

## Phase 4 — Rater on/off

### Task 10: `AppViewModel.showQualityRater` + Settings toggle

**Files:**
- Modify: `Elos/AppViewModel.swift` (near `volumeOverrides`, around line 113)
- Modify: `Elos/Features/You/SettingsView.swift:100-128` (the "Training" section)

- [ ] **Step 1: Implement the preference**

In `AppViewModel.swift`, add near the `volumeOverrides` property (after its `didSet` block, before `private static let volumeOverridesKey`):

```swift
    /// Global on/off for the 0–100 quality score + tips layer (`TemplateQualityPanel` and everything
    /// it opens). Coverage bars stay visible either way — this only hides the *rating*, not the
    /// underlying muscle-coverage data. Defaults to `true`; `UserDefaults.bool(forKey:)` alone would
    /// default a never-set key to `false`, which is backwards from the intended default, so this
    /// reads `.object(forKey:)` first to tell "never set" apart from "explicitly turned off".
    @Published var showQualityRater: Bool = (UserDefaults.standard.object(forKey: "elos.showQualityRater") as? Bool) ?? true {
        didSet { UserDefaults.standard.set(showQualityRater, forKey: "elos.showQualityRater") }
    }
```

- [ ] **Step 2: Add the Settings toggle**

In `SettingsView.swift`, inside the existing `Section("Training") { ... }` block (lines 100–128), add the toggle after the "Volume Targets" `NavigationLink` (right before the section's closing `}` at line 128):

```swift
                    NavigationLink {
                        VolumeTargetsView().environmentObject(vm)
                    } label: {
                        HStack {
                            Label("Volume Targets", systemImage: "chart.bar")
                            if vm.volumeOverrides.isCustomized {
                                Spacer()
                                Text("Custom")
                                    .font(.elosCaption)
                                    .foregroundStyle(Color.tint)
                            }
                        }
                    }
                    Toggle(isOn: $vm.showQualityRater) {
                        Label("Show Quality Rating", systemImage: "gauge.with.dots.needle.67percent")
                    }
                    .tint(Color.tint)
                }
```

- [ ] **Step 3: Verify it compiles**

Run: `xcodebuild build -scheme Elos -destination 'generic/platform=iOS Simulator' 2>&1 | tail -40`
Expected: builds clean. (If `"gauge.with.dots.needle.67percent"` isn't available on the deployment target's SF Symbols version, substitute `"gauge.medium"` — already used elsewhere in this codebase per the `readinessPromptCard` icon choice, so it's a known-safe symbol.)

- [ ] **Step 4: Commit**

```bash
git add Elos/AppViewModel.swift Elos/Features/You/SettingsView.swift
git commit -m "feat(settings): add Show Quality Rating toggle, defaulting on"
```

---

### Task 11: Gate `TemplateQualityPanel` in both builders

**Files:**
- Modify: `Elos/Features/Train/Templates/CreateTemplateView.swift:384-414`
- Modify: `Elos/Features/Train/Programs/CreateSplitView.swift:241-258`

- [ ] **Step 1: `CreateTemplateView` — wrap only the panel, not the bars**

Replace the block at lines 384–414:

```swift
                    // Quality coach — score + dimension bars + actionable tips, then the muscle bars.
                    // Computed once here and passed down; the engine is pure but resolving the
                    // catalog per row would be wasteful.
                    if !exercises.isEmpty {
                        let report = qualityReport
                        Section {
                            VStack(spacing: 12) {
                                if vm.showQualityRater, report.isScored {
                                    TemplateQualityPanel(report: report, guidance: guidanceLevel,
                                                         title: "Template Quality",
                                                         scope: .singleSession,
                                                         onTapTip: { handle(tip: $0) })
                                }
                                MuscleCoverageBars(
                                    report: report.volume,
                                    title: "MUSCLE COVERAGE",
                                    hidesUnexpected: true,
                                    showsLegend: true,
                                    onTapMuscle: { bar in
                                        let payload = bar.fine?.rawValue ?? bar.group.rawValue
                                        openPicker(biasedToMuscles: MuscleTaxonomy.targetMuscles(forPayload: payload))
                                    })
                                .padding(Space.card)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .elosCard()
                            }
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .listRowInsets(.init(top: 4, leading: 16, bottom: 8, trailing: 16))
                        }
                    }
```

(Only the `if report.isScored` condition changed, to `if vm.showQualityRater, report.isScored` — `MuscleCoverageBars` is untouched and stays unconditional.)

- [ ] **Step 2: `CreateSplitView` — wrap `qualityPanel`'s call site**

`qualityPanel` (lines 241–258) is already its own `@ViewBuilder` var, called once from `body` (inside the `if hasAnyDay` section, line 95: `qualityPanel`). Wrap that one call site:

```swift
                        MuscleGroupPanelWeekly(
                            dayTemplateIDs: dayTemplateIDs,
                            dayIsRest: dayIsRest,
                            dayExercises: dayExercises
                        )
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                        .listRowBackground(Color.clear)

                        if vm.showQualityRater {
                            qualityPanel
                        }
```

(`qualityPanel`'s own body is unchanged — it still computes `qualityReport` and gates on `populatedDays >= 2 && report.isScored` internally; the new `if vm.showQualityRater` wraps the whole thing one level up, so when off, `MuscleGroupPanelWeekly` still renders and `qualityPanel`'s `TrainingIntentRow`/`TemplateQualityPanel` don't.)

- [ ] **Step 3: Verify it compiles**

Run: `xcodebuild build -scheme Elos -destination 'generic/platform=iOS Simulator' 2>&1 | tail -40`
Expected: builds clean.

- [ ] **Step 4: Manual verification in the simulator**

- [ ] Settings → Training → turn off "Show Quality Rating".
- [ ] Open the template builder with some exercises added — confirm the score ring/tier/tips card is gone, but the "MUSCLE COVERAGE" bars are still there.
- [ ] Open the split builder with 2+ populated days — confirm the "Split Quality" panel (score + tips + "See full report") is gone, but `MuscleGroupPanelWeekly`'s bars are still there.
- [ ] Turn the toggle back on, confirm both panels reappear.

- [ ] **Step 5: Commit**

```bash
git add Elos/Features/Train/Templates/CreateTemplateView.swift Elos/Features/Train/Programs/CreateSplitView.swift
git commit -m "feat(settings): gate TemplateQualityPanel on showQualityRater in both builders"
```

---

## Phase 5 — Volume Targets: citations + global exclusion sentinel

### Task 12: `VolumeTargetsView` — mutually-exclusive exclusion picker + citations

**Files:**
- Modify: `Elos/Features/You/VolumeTargetsView.swift`

- [ ] **Step 1: Add the exclusion binding + wire it into `groupRow`**

Add a new binding function next to `overrideBinding(for:)` (around line 83–94):

```swift
    /// Whether *every* child of this group is currently in the global exclusion set. Group-level by
    /// necessity here — this is the picker's "Not training this" sentinel, one control per group, not
    /// a per-fine-muscle checklist (that's what the per-day `SkipMusclesSheet` is for).
    private func excludedBinding(for group: MuscleGroup) -> Binding<Bool> {
        Binding(
            get: { group.children.allSatisfy { vm.volumeOverrides.excludedMuscles.contains($0) } },
            set: { newValue in
                if newValue {
                    vm.volumeOverrides.excludedMuscles.formUnion(group.children)
                } else {
                    vm.volumeOverrides.excludedMuscles.subtract(group.children)
                }
            }
        )
    }
```

Update `groupRow(_:)` (around line 101–119) to show "Not training" and pass the new binding through:

```swift
    private func groupRow(_ group: MuscleGroup) -> some View {
        let isExcluded = group.children.allSatisfy { vm.volumeOverrides.excludedMuscles.contains($0) }
        let isCustom = vm.volumeOverrides.groupWeeklyTarget[group.rawValue] != nil
        let derived = derivedTarget(for: group)
        return NavigationLink {
            GroupTargetEditor(group: group,
                              derived: derived,
                              override: overrideBinding(for: group),
                              excluded: excludedBinding(for: group))
        } label: {
            HStack {
                Text(group.displayName)
                Spacer()
                if isExcluded {
                    Text("Not training")
                        .font(.elosNumeric(.subheadline))
                        .foregroundStyle(.secondary)
                } else {
                    Text(isCustom ? "\(effectiveTarget(for: group)) sets" : "\(derived.low)–\(derived.high) sets")
                        .font(.elosNumeric(.subheadline))
                        .foregroundStyle(isCustom ? Color.tint : .secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
            }
        }
    }
```

- [ ] **Step 2: Extend `GroupTargetEditor` with the sentinel + citations**

Replace `GroupTargetEditor` in full (currently lines 133–187):

```swift
private struct GroupTargetEditor: View {
    let group: MuscleGroup
    let derived: (low: Int, high: Int)
    @Binding var override: Int?
    @Binding var excluded: Bool

    private var useCustom: Bool { override != nil }

    /// `0` = "use the derived default", `-1` = "not training this" — two sentinels so one `Picker`
    /// covers all three states. This is the one place that keeps `override`/`excluded` mutually
    /// exclusive: every selection change writes both, so a group is never simultaneously "excluded"
    /// and "has a stale numeric target" (which would otherwise leave `weeklyBand` to decide which one
    /// wins based on function-call order rather than the lifter's actual last choice).
    private var selection: Binding<Int> {
        Binding(
            get: { excluded ? -1 : (override ?? 0) },
            set: { newValue in
                if newValue == -1 {
                    excluded = true
                    override = nil
                } else {
                    excluded = false
                    override = newValue == 0 ? nil : newValue
                }
            }
        )
    }

    /// 4…40 in steps of 2 spans a maintenance dose through a specialisation block for a single
    /// fine-muscle band — but this editor is shown per *group*, and a multi-child group's target is
    /// the sum across its children (e.g. Back = lats + upperBack + lowerBack + rearDelts), which
    /// regularly exceeds 40 outright (Back's own science default already runs 44–68). Anchor the
    /// ceiling to this group's derived high so every group can reach at least its own default, with
    /// headroom above it for an intentional specialisation block.
    private var options: [Int] {
        let ceiling = max(40, derived.high + 20)
        let evenCeiling = ceiling + (ceiling % 2)
        return Array(stride(from: 4, through: evenCeiling, by: 2))
    }

    var body: some View {
        List {
            // An inline Picker rather than a Toggle plus a Slider.
            //
            // The Toggle would not fire at all here: taps on it never invoked its setter (verified —
            // the stored overrides stayed empty while the preference Picker on the parent screen wrote
            // through fine), as both a sheet with local @State and a pushed view with a live binding.
            // A Picker is the control that demonstrably works in this exact context, and folding
            // "default, my own number, or not training this" into a single list is less machinery.
            Section {
                Picker("Weekly sets", selection: selection) {
                    Text("Default (\(derived.low)–\(derived.high))").tag(0)
                    ForEach(options, id: \.self) { n in
                        Text("\(n) sets").tag(n)
                    }
                    Text("Not training this").tag(-1)
                }
                .pickerStyle(.inline)
                .labelsHidden()
            } header: {
                Text("Weekly sets for \(group.displayName)")
            } footer: {
                Text(footerText)
            }

            Section {
                Text(group.volumeRationale)
                    .font(.elosCaption)
                    .foregroundStyle(.secondary)
                DisclosureGroup("Sources") {
                    ForEach(TrainingScience.citations, id: \.title) { citation in
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(citation.authors) (\(citation.year))")
                                .font(.caption).fontWeight(.semibold)
                            Text(citation.title)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .italic()
                            Text(citation.finding)
                                .font(.caption2)
                        }
                        .padding(.vertical, 2)
                    }
                }
                .font(.elosCaption)
            } header: {
                Text("Why this number")
            }
        }
        .navigationTitle(group.displayName)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var footerText: String {
        if excluded {
            return "\(group.displayName) is excluded from your coverage checks and quality score everywhere — every template and every split. To skip it on just one day instead, use that day's own \"Skip muscles\" option."
        }
        return useCustom
            ? "Split across \(group.children.count == 1 ? "this muscle" : "the \(group.children.count) muscles in \(group.displayName)") in science-table proportion. Applies to the coverage bars and the quality score straight away."
            : "Using the science default for your experience level and preference: \(derived.low)–\(derived.high) sets a week."
    }
}
```

- [ ] **Step 2: Verify it compiles**

Run: `xcodebuild build -scheme Elos -destination 'generic/platform=iOS Simulator' 2>&1 | tail -60`
Expected: builds clean.

- [ ] **Step 3: Manual verification in the simulator**

- [ ] Settings → Volume Targets. Tap "Back" (or any group).
- [ ] Confirm the new "Why this number" section shows a one-sentence rationale, and tapping "Sources" expands 3 citations with author/year/title/finding.
- [ ] Select "Not training this". Go back — confirm the row now shows "Not training" instead of a set range, and the footer explained the global scope.
- [ ] Re-open the same group, pick a numeric value (e.g. "20 sets") — confirm this clears the exclusion (row no longer shows "Not training", shows "20 sets" tinted instead).
- [ ] Re-select "Not training this", then check the group's parent `VolumeTargetsView` row for the "Custom" badge in Settings (via `vm.volumeOverrides.isCustomized`) — confirm it shows "Custom" even though no numeric target is set.
- [ ] Confirm "Reset to science defaults" (shown when `isCustomized`) clears the exclusion along with everything else (it already sets `vm.volumeOverrides = .none`, so this should already work with no further code change — just verify).

- [ ] **Step 4: Commit**

```bash
git add Elos/Features/You/VolumeTargetsView.swift
git commit -m "feat(volume): cited rationale + mutually-exclusive global exclusion sentinel"
```

---

## Final verification

### Task 13: Full build + test suite

- [ ] **Step 1: Full clean build**

```bash
xcodebuild clean build -scheme Elos -destination 'generic/platform=iOS Simulator' 2>&1 | tail -60
```
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 2: Build for testing**

```bash
xcodebuild build-for-testing -scheme Elos -destination 'generic/platform=iOS Simulator' 2>&1 | tail -60
```
Expected: `** TEST BUILD SUCCEEDED **` (both the app target and `ElosTests` compile).

- [ ] **Step 3: Run the full test suite**

```bash
xcrun simctl list devices booted
xcodebuild test -scheme Elos -destination 'id=<booted-simulator-udid>' -parallel-testing-enabled NO 2>&1 | tail -150
```
Expected: all tests pass, including every new test from Tasks 1–5 and every pre-existing test (none of the signature changes drop a default, so nothing else should need updating).

If this fails with a pty/`openpty` setup error (sandbox limitation, not a real failure — see the `sandboxed-xcodebuild` memory):
- Confirm Step 1 and Step 2 both succeeded (compile-correctness is verified).
- Fall back to a standalone `swiftc` harness: copy `MuscleTaxonomy.swift`, `TrainingScience.swift`, `TrainingProfile.swift`, `TrainingIntent.swift`, `BalanceScorer.swift`, `TemplateQualityEngine.swift` and their transitive dependencies (`ScoredExercise.swift`, `QualityReport.swift`, `MuscleVolumeAnalyzer.swift`, `MovementQualityAnalyzer.swift`, `FrequencyScorer.swift`, `SelectionScorer.swift`, `RepRestScorer.swift`, `FatigueScorer.swift`, `FatigueModel.swift`, `DayContext.swift`) into a temp dir with a small shim for `UserProfileRecord`/`ResolvedExercise`/`ExerciseCandidate`, rewrite the new Swift Testing `@Test` functions as plain assertions, and run natively on macOS. This is the documented workaround from the original muscle-coverage-coach implementation — reuse it rather than re-deriving it.
- Report which path (real `xcodebuild test` vs. the harness) actually verified the new logic, and how many assertions ran.

- [ ] **Step 4: Report the outcome**

State: build status, test status (and which method verified it), and a one-line summary of what shipped (per-day/per-template muscle exclusion, the rater on/off toggle, cited volume recommendations + global exclusion in Volume Targets).
