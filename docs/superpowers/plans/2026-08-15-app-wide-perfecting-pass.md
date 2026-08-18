# App-Wide Perfecting Pass Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Four real gaps found by a four-area parallel audit (Stats, Today/Plan, Onboarding/Settings,
Social/Discover) run after the split-ratings/gyms/variants feature shipped — each one matches the
exact failure pattern that motivated that whole feature: a good capability exists and works in one
place, but a second place that should read the same data either never learned it exists, or reads a
disconnected copy.

**Architecture:** Client-side only, no backend/contract changes except the one existing endpoint
(`/templates`, `/splits`) already used elsewhere. Two engine-layer additions (both pure, harness-
tested); one UI extraction (DRY, removes duplication this plan would otherwise create); two small
targeted fixes.

**Tech Stack:** Swift, SwiftUI, SwiftData, Swift Testing.

**Verification:** Same as every prior plan on this branch — `xcodebuild build-for-testing -project
Elos.xcodeproj -scheme Elos -destination 'platform=iOS Simulator,name=iPhone 17'
OTHER_SWIFT_FLAGS='$(inherited) -disable-sandbox'` is the compile check; pure logic runs through the
swiftc harness (copy `Intelligence/*.swift` + `SplitHelpers.swift`, shim the two SwiftData types the
`init(record:)` adapters touch, plain `assert()`s, `swiftc -o harness *.swift && ./harness`).
`xcodebuild test` cannot execute in this sandbox — environmental, don't debug it. Build-lock
conflicts with a background auto-checker: `lsof` the `XCBuildData/build.db` first; wait-and-retry if
a live process holds it, delete only on a confirmed-empty result.

## What audit found and what this plan does NOT touch

Four areas were audited in parallel. Two real findings are **deliberately excluded** because
they're product decisions, not engineering gaps, and this pass isn't the place to make them
unilaterally:

- **Quality score never reaches the social feed** (`FeedPayload`/`shareSplit` carry volume/PRs but
  no score). Plausibly intentional — quality-as-personal-coaching vs. quality-as-bragging is a real
  product question. Not touched.
- **`EquipmentPreference` (global posture) and `GymRecord` (per-location) are two unconnected
  systems.** `GymsView.swift`'s own doc comment already flags this as future "Phase 3" work,
  deliberately deferred when gyms shipped. Not a regression to fix now; a roadmap item.
- **Onboarding never asks about gyms.** Audited and judged correct as-is: onboarding runs before any
  split exists, so there's nothing yet to attach a gym variant to. Not touched.

One audit finding was **investigated and found to already be fixed** — do not re-attempt: the
Social/Discover audit flagged `DiscoverViewModel` as conflating network failure with an empty state
(no distinct failure flag). Read the current file: `DiscoverViewModel.swift:81,108` already has
`syncFailed`, and `DiscoverLibraryView.swift:27-28` already branches on it. This was fixed in an
earlier session (see memory `app-wide-sweep`); the audit's citation was stale. **Do not
"fix" this again.**

What's left — four real items, ordered by value:

1. Discover's "Add to Plan" creates disconnected templates with no split, no day ordering, no
   scoring, no gym-variant participation — the biggest, clearest instance of the pattern.
2. The gym switcher (shipped last session) is reachable only by drilling into a specific split's
   detail view; Today/Plan never show which variant is active. The daily-use surface for a feature
   whose entire point is daily use doesn't use it.
3. Settings' two equipment-adjacent screens (global `EquipmentPreference` in Edit Profile, per-gym
   `GymsView` in Training) don't cross-link, so a user checking one has no signal the other exists.
4. `LoggedVolumeAnalyzer.MuscleRow` (Stats) has no `isExcluded` flag, unlike `MuscleVolumeAnalyzer`
   (coverage bars) — scoring is already correct (excluded muscles don't nag), only the muted
   rendering is missing, so an excluded muscle's Stats bar looks like an ordinary gap.

---

## Task 1: Discover's "Add to Plan" creates a real split, not disconnected templates

**Files:**
- Modify: `Features/Discover/Creators/WorkoutDetailView.swift:57,187,222-308`
- Test: `ElosTests/WorkoutDetailAddToPlanTests.swift`

**Background.** `WorkoutDetailViewModel.addToMyPlan()` (`:281-308`) forks each program day into an
independent `POST /templates` call and does nothing else — no `UserSplitRecord`, no day ordering, no
local persistence at all (contrast its sibling `toggleSave(ownerID:context:)` at `:259`, which
already takes `ownerID`/`context` and writes locally-first). Consequence: imported content never
gets a quality score (`TemplateQualityEngine`/`SavedSplitScoring` both operate on split-shaped data),
never shows the coaching panel, and can't participate in gym-variant switching — it's invisible to
every system this branch just built.

**The fix reuses two things already built and tested on this branch**, rather than inventing a third
split-construction path:
- `SplitDayPersistence.upsertDays(...)` (`Features/Train/Programs/SplitDayPersistence.swift`) already
  turns a 7-slot day description into `UserSplitDayRecord`s. A creator program's N days (≤7) become
  the first N slots; the rest are rest days — exactly what `CreateSplitView.saveSplit()` produces
  today for a partially-filled week.
- `TemplateIDRepointing.repointDays(...)` (shipped this session, Task 12 of the split-overhaul plan)
  already exists specifically for "a template's local id differs from its eventual server id, and a
  split day referenced it" — which is exactly the state a freshly-created local template is in until
  `TemplatesView.reconcileUnconfirmed` (runs on every Templates load) pushes it. No new reconciliation
  code needed; the machinery already exists and was built for this.

- [ ] **Step 1: Write the failing test**

```swift
@Test @MainActor func addToMyPlanCreatesASplitWithOneDayPerProgramDay() {
    let context = makeContext()  // in-memory ModelContainer, schema: [UserSplitRecord, UserSplitDayRecord,
                                  // WorkoutTemplateRecord, TemplateExerciseRecord]
    let vm = WorkoutDetailViewModel()
    vm.workout = sampleWorkout(dayCount: 3)  // helper building a WorkoutDetailAPIResponse fixture

    vm.buildLocalSplit(ownerID: "u1", context: context)  // the new, testable, network-free half

    let splits = (try? context.fetch(FetchDescriptor<UserSplitRecord>())) ?? []
    #expect(splits.count == 1)
    let days = (try? context.fetch(FetchDescriptor<UserSplitDayRecord>(
        predicate: #Predicate { $0.splitID == splits[0].id }))) ?? []
    #expect(days.count == 7)                              // full week, matching SplitDayPersistence's shape
    #expect(days.filter { !$0.isRest }.count == 3)         // one per program day
    #expect(days.filter { $0.isRest }.count == 4)
}

@Test @MainActor func eachTrainingDayGetsItsOwnLocalTemplateWithExercisesInOrder() {
    let context = makeContext()
    let vm = WorkoutDetailViewModel()
    vm.workout = sampleWorkout(dayCount: 2)

    vm.buildLocalSplit(ownerID: "u1", context: context)

    let templates = (try? context.fetch(FetchDescriptor<WorkoutTemplateRecord>())) ?? []
    #expect(templates.count == 2)
    #expect(templates.allSatisfy { !$0.serverConfirmed })   // local-first: not yet pushed
    for t in templates {
        let exs = (try? context.fetch(FetchDescriptor<TemplateExerciseRecord>(
            predicate: #Predicate { $0.templateID == t.id }, sortBy: [SortDescriptor(\.orderIndex)]))) ?? []
        #expect(!exs.isEmpty)
    }
}

@Test @MainActor func aProgramWithMoreThanSevenDaysTakesOnlyTheFirstSeven() {
    let context = makeContext()
    let vm = WorkoutDetailViewModel()
    vm.workout = sampleWorkout(dayCount: 10)

    vm.buildLocalSplit(ownerID: "u1", context: context)

    let templates = (try? context.fetch(FetchDescriptor<WorkoutTemplateRecord>())) ?? []
    #expect(templates.count == 7, "SplitDayPersistence's shape is a fixed 7 slots — extra days are dropped, not silently truncating mid-week")
}

@Test @MainActor func doesNothingForAnEmptyProgram() {
    let context = makeContext()
    let vm = WorkoutDetailViewModel()
    vm.workout = sampleWorkout(dayCount: 0)
    vm.buildLocalSplit(ownerID: "u1", context: context)
    #expect(((try? context.fetch(FetchDescriptor<UserSplitRecord>())) ?? []).isEmpty)
}
```

- [ ] **Step 2: Confirm they fail** (the method doesn't exist / has the old signature).

- [ ] **Step 3: Implement.** Split `addToMyPlan` into a **testable local half** (`buildLocalSplit`,
  pure SwiftData writes, no networking — this is what the tests above exercise) and a **thin async
  wrapper** that calls it then pushes:

```swift
/// Builds the local split + templates from the loaded program. Network-free and synchronous so it's
/// directly testable; `addToMyPlan` (below) is the thin async wrapper that calls this then pushes.
@discardableResult
func buildLocalSplit(ownerID: String, context: ModelContext) -> UserSplitRecord? {
    guard let w = workout, !w.days.isEmpty else { return nil }

    let dayLabels = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
    var dayNames = Array(repeating: "", count: 7)
    var dayTemplateIDs = Array(repeating: "", count: 7)
    var dayIsRest = Array(repeating: true, count: 7)

    for (i, day) in w.days.sorted(by: { $0.order_index < $1.order_index }).prefix(7).enumerated() {
        let template = WorkoutTemplateRecord(ownerID: ownerID, name: "\(w.creator_name): \(day.name)")
        context.insert(template)
        for ex in day.exercises {
            context.insert(TemplateExerciseRecord(
                ownerID: ownerID, templateID: template.id, exerciseName: ex.exercise_name,
                orderIndex: ex.order_index, targetSets: ex.sets ?? 3, targetReps: ex.reps ?? "8-10",
                restSeconds: ex.rest_seconds ?? 90))
        }
        dayNames[i] = day.name
        dayTemplateIDs[i] = template.id
        dayIsRest[i] = false
    }

    let split = UserSplitRecord(ownerID: ownerID, name: w.title)
    context.insert(split)
    let indexToWeekday = [2, 3, 4, 5, 6, 7, 1]   // same convention as CreateSplitView.saveSplit()
    split.pinnedWeekdays = (0..<7).filter { !dayIsRest[$0] }.map { indexToWeekday[$0] }
    SplitDayPersistence.upsertDays(
        splitID: split.id, dayLabels: dayLabels, dayNames: dayNames,
        dayTemplateIDs: dayTemplateIDs, dayIsRest: dayIsRest,
        dayExercises: Array(repeating: [], count: 7),   // ad-hoc unused — every day is template-backed
        dayExcludedMuscles: Array(repeating: [], count: 7),
        existing: [], modelContext: context)
    try? context.save()
    return split
}

func addToMyPlan(ownerID: String, context: ModelContext, vm: AppViewModel) {
    guard let split = buildLocalSplit(ownerID: ownerID, context: context) else { return }
    isAddingToPlan = true
    Task {
        defer { isAddingToPlan = false }
        await vm.pushSplitToServer(split)
        addedToPlan = true
    }
}
```

  **Not activated by default** — matches the existing convention (`muscle-coverage-coach-bugfix-pass`
  memory: "the blank 'Create Split' button... just adds to My Splits, unactivated"). A user browsing
  Discover tapping "Add to my plan" is saving it for later, not necessarily replacing whatever they're
  running today; they can hit "Set as Active" from My Splits same as any other split.

  Update the call site (`:187`): `detailVM.addToMyPlan(ownerID: appVM.currentUserID, context:
  modelContext, vm: appVM)`.

  **Templates push via the existing mechanism, not a new one.** They're created `serverConfirmed:
  false` (the default) and `TemplatesView.reconcileUnconfirmed` — which the file's own comment says
  "Runs on every load, so a template can never be stranded on-device" — pushes them and, if the
  server assigns a different id, `TemplateIDRepointing.repointDays` (already shipped) re-points this
  new split's day `templateID`s automatically. No new reconciliation code.

  **Accepted residual risk, not fixed here:** if a template's id does get rewritten after this split
  is already pushed, the *server's* copy of that day's `template_id` stays stale (only the local copy
  gets corrected) until the split is edited and re-saved. Low severity — the app is client-
  authoritative for exercise resolution on the device that created the split — and closing it fully
  would mean teaching `TemplateIDRepointing` to re-push affected splits, which is out of scope for
  this pass. Noted so it isn't rediscovered as a surprise.

- [ ] **Step 4: Harness pass (the `buildLocalSplit` half only needs `SplitDayPersistence`/
  `SplitHelpers`/an in-memory `ModelContainer`, not the full Intelligence harness — use the same
  in-memory-`ModelContainer` pattern as `SplitEditPreservesDayDataTests.swift`, not the bare-swiftc
  harness, since this touches SwiftData directly) → `build-for-testing` → commit.**

```bash
git commit -m "fix(train): Add to Plan creates a real split, not disconnected templates

WorkoutDetailViewModel.addToMyPlan() forked every creator-program day
into its own independent template with no split wrapper, no local
persistence, and no day ordering — imported content never got a
quality score, never showed the coaching panel, and couldn't
participate in gym-variant switching, because every one of those
systems operates on split-shaped data.

Reuses SplitDayPersistence.upsertDays (the same 7-slot day-persistence
this branch already built and tested) and leans on
TemplateIDRepointing (shipped earlier this session) to handle the
template-id-rewrite-on-first-push case for free. Not activated by
default, matching the existing 'blank Create Split just adds to My
Splits' convention.

Split into a testable buildLocalSplit(ownerID:context:) — pure
SwiftData writes, no networking — and a thin async addToMyPlan
wrapper, so the actual construction logic is unit-tested rather than
only reachable through a live network call."
```

---

## Task 2: Extract the gym switcher into a reusable control, wire it into Today

**Files:**
- Create: `Features/Train/Programs/GymSwitcherControl.swift`
- Modify: `Features/Train/Programs/ProgramsView.swift` (replace inline gym-switcher code)
- Modify: `Elos/Views/TodayView.swift`
- Test: none new (this is a UI extraction of already-tested logic; `GymSwitchPreview`'s consumer
  changes, its own preview-vs-apply consistency was already adversarially verified in the split-
  overhaul plan)

**Background.** `UserSplitDetailView` (`ProgramsView.swift`) has its own inline `gymSwitcherSection`,
`@State private var pendingGymSwitch`, `gymSwitchChanges(for:)`, `afterGymSwitchScore(for:)`, and
`applyGymSwitch(_:)` — the entire gym-switching capability, tied to that one screen's local
properties (`sortedDays`, `exerciseCatalog`, `scoringProfile`, `splitIntent`). The audit found this
switcher is reachable only via Train tab → Programs → My Splits → a specific split's detail view —
three taps deep from the screen a user actually opens every day. Today/Plan show a day's name with
no indication of which gym-variant is active, and offer no way to switch.

**Extracting rather than duplicating.** Copying the switching logic into `TodayView` would recreate
exactly the kind of "same concept, second disconnected path" bug this whole branch exists to fix.
Instead, extract it once into a self-contained view that owns its own data (mirroring how
`UserSplitDetailView` itself already fetches its own days/catalog/profile via `@Query` in its own
`init`), so both screens embed the same component rather than each computing gym-switch state their
own way.

- [ ] **Step 1: Create `GymSwitcherControl`**

```swift
import SwiftUI
import SwiftData

/// The gym switcher, as a drop-in component — a Menu showing the active gym plus a before/after
/// preview before committing (`GymSwitchPreview`). Self-contained: takes only a `split` and derives
/// everything else via its own queries, so any screen that has a `UserSplitRecord` can embed it
/// without threading catalog/profile/days through from the host view.
struct GymSwitcherControl: View {
    let split: UserSplitRecord
    @EnvironmentObject var vm: AppViewModel
    @Environment(\.modelContext) private var modelContext
    @Query private var allDays: [UserSplitDayRecord]
    @Query(sort: \ExerciseDefinitionRecord.name) private var exerciseDefs: [ExerciseDefinitionRecord]
    @Query private var profiles: [UserProfileRecord]
    @Query(sort: \GymRecord.createdAt) private var gyms: [GymRecord]

    @State private var pendingGymSwitch: GymRecord? = nil

    init(split: UserSplitRecord) {
        self.split = split
        let id = split.id
        _allDays = Query(filter: #Predicate<UserSplitDayRecord> { $0.splitID == id }, sort: \.orderIndex)
    }

    private var sortedDays: [UserSplitDayRecord] { allDays }   // already sorted by the @Query
    private var exerciseCatalog: [ExerciseCandidate] { exerciseDefs.map(ExerciseCandidate.init(record:)) }
    private var splitIntent: TrainingIntent {
        split.intent ?? TrainingIntent(profile: TrainingProfile(record: profiles.first))
    }
    private var scoringProfile: TrainingProfile {
        TrainingProfile(goal: splitIntent.goal, experience: TrainingProfile(record: profiles.first).experience,
                        volumeOverrides: vm.volumeOverrides)
    }
    private var qualityReport: QualityReport {
        SavedSplitScoring.report(days: sortedDays, templateExercises: { vm.fetchTemplateExercises(templateID: $0) },
                                 catalog: exerciseCatalog, profile: scoringProfile, intent: splitIntent)
    }

    var body: some View {
        // Body, gymSwitchChanges(for:), afterGymSwitchScore(for:), applyGymSwitch(_:), and the
        // .sheet(item: $pendingGymSwitch) wiring are moved VERBATIM from ProgramsView.swift's
        // current gymSwitcherSection / gymSwitchChanges / afterGymSwitchScore / applyGymSwitch —
        // no logic changes, only the host type and how `split`/`sortedDays`/etc. are sourced.
        Group {
            if !gyms.isEmpty { gymSwitcherMenu }
        }
        .sheet(item: $pendingGymSwitch) { gym in
            GymSwitchPreview(gymName: gym.name,
                            changes: gymSwitchChanges(for: gym),
                            beforeScore: qualityReport.isScored ? qualityReport.overall : nil,
                            afterScore: afterGymSwitchScore(for: gym),
                            onConfirm: { applyGymSwitch(gym) },
                            onCancel: {})
        }
    }

    // ... gymSwitcherMenu, gymSwitchChanges(for:), afterGymSwitchScore(for:), applyGymSwitch(_:) —
    // moved verbatim, see Step 2.
}
```

- [ ] **Step 2: Move the logic verbatim.** Cut `gymSwitcherSection` (rename to `gymSwitcherMenu`),
  `gymSwitchChanges(for:)`, `afterGymSwitchScore(for:)`, `applyGymSwitch(_:)`, and the
  `pendingGymSwitch` state + its `.sheet` out of `ProgramsView.swift`'s `UserSplitDetailView`, into
  `GymSwitcherControl`. **Do not change any logic during the move** — this is a pure extraction; any
  behavior change belongs in a separate, reviewable diff. `UserSplitDetailView` replaces its
  `gymSwitcherSection` call and its own `.sheet(item: $pendingGymSwitch)` with a single
  `GymSwitcherControl(split: split)` embedded where the section used to render, and drops the now-
  unused properties/state.

- [ ] **Step 3: Verify `UserSplitDetailView` still compiles and behaves identically** — the extraction
  should be invisible from that screen's behavior. `build-for-testing`.

- [ ] **Step 4: Wire into `TodayView`.** Add near the header (not inside `scheduleSection`, which is
  a plain `VStack` of rows with no natural slot for a Menu control):

```swift
if let split = vm.activeSplit {
    GymSwitcherControl(split: split)
        .padding(.horizontal, Space.gutter)   // match this screen's existing horizontal rhythm
}
```

  Reachable in one tap from the screen a user actually opens daily, instead of three.
  `vm.activeSplit`/`vm.activeSplitDays` are already exposed on `AppViewModel` — no new `@Query` needed
  in `TodayView` itself for the split reference; `GymSwitcherControl` fetches its own days/catalog/
  profile/gyms via its own `@Query`s regardless of host.

- [ ] **Step 5: `build-for-testing` → commit.**

```bash
git commit -m "refactor(train): extract the gym switcher into a reusable control, add it to Today

The switcher (Menu + before/after preview + apply) lived entirely
inside UserSplitDetailView, reachable only by drilling into a specific
split's detail screen — three taps from the screen a user actually
opens every day. Today/Plan showed a day's name with zero indication
of which gym-variant was active and no way to switch.

Extracted into GymSwitcherControl, a self-contained view that derives
its own days/catalog/profile/gyms from a UserSplitRecord via its own
@Query — the same shape UserSplitDetailView already uses in its own
init — rather than threading state through from each host. No logic
changed in the move; this is a pure extraction plus one new embed
site (Today), closing the discoverability gap the audit found."
```

---

## Task 3: Enrich day names with the active variant, in Today/Plan

**Files:**
- Modify: `Features/Train/Programs/DayVariants.swift` (extract `activeVariantName(for:)`)
- Modify: `Features/Train/Programs/ProgramsView.swift` (use the extracted function)
- Modify: `Elos/AppViewModel.swift:1016-1059` (`buildScheduleRows`)
- Modify: `Elos/Views/PlanView.swift:230-231` (`loadSummaryCard`)

- [ ] **Step 1: Extract the existing private logic.** `ProgramsView.swift`'s `activeVariantName(for:)`
  (guards `variants.count > 1`, returns the active variant's name) becomes a `DayVariants` static
  function — the same reasoning as everything else in this file: one place, not a copy per caller.

```swift
extension DayVariants {
    /// The active variant's name, only when the day genuinely has more than one — a day with zero
    /// or one variant returns nil, so the common case (no gym-splitting) shows nothing extra.
    static func activeVariantName(for day: UserSplitDayRecord) -> String? {
        guard let vs = set(for: day), vs.variants.count > 1 else { return nil }
        return vs.variants.first { $0.id == vs.activeID }?.name
    }
}
```

  `ProgramsView.swift`'s own `activeVariantName(for:)` becomes a one-line call to
  `DayVariants.activeVariantName(for:)` (or is removed entirely in favor of calling the shared one
  directly at its two call sites).

- [ ] **Step 2: `AppViewModel.buildScheduleRows`** (`:1048-1051`) — the single place that builds the
  "gym" `ScheduleRow` for BOTH `TodayView` and `PlanView`'s timeline (both consume `row.title`
  directly, confirmed by reading both files: neither has a separate mapping that would need its own
  fix):

```swift
if let gymDay = gymDay(for: date), !gymDay.isRest {
    var gymTitle = gymDay.dayName.isEmpty ? "Workout" : gymDay.dayName
    if let variant = DayVariants.activeVariantName(for: gymDay) {
        gymTitle += " · \(variant)"
    }
    rows.append(ScheduleRow(time: "15:30", title: gymTitle, moduleType: "gym", durationMinutes: 60, isDone: false))
}
```

- [ ] **Step 3: `PlanView.loadSummaryCard`** (`:230-231`) — same enrichment for the "Training day:
  ..." copy, which reads `gd.dayName` directly rather than through `buildScheduleRows`:

```swift
let variantSuffix = DayVariants.activeVariantName(for: gd).map { " (\($0))" } ?? ""
return "Training day: \(gd.dayName.isEmpty ? "Workout" : gd.dayName)\(variantSuffix). Tap Start in the Train tab when ready."
```

- [ ] **Step 4: `build-for-testing` → commit** (no new pure-logic test — `activeVariantName` is
  already exercised indirectly by `DayVariantsTests`'s coverage of `set(for:)`; this task is wiring a
  presentation string, not new logic).

```bash
git commit -m "feat(train): show the active gym-variant name in Today/Plan

buildScheduleRows (feeding both Today's schedule and Plan's timeline)
and PlanView's day-summary copy both showed a day's plain name with no
indication of which gym-variant was active — switching gyms changed
what you'd actually do today with zero visible confirmation.

activeVariantName(for:) moved from a ProgramsView-private helper to
DayVariants, so Today/Plan use the exact same 'does this day have more
than one variant' rule the split detail view's chip already uses,
rather than a second copy of the logic."
```

---

## Task 4: Cross-link Settings' two equipment-adjacent screens

**Files:**
- Modify: `Features/You/SettingsView.swift:128-132` (Gyms row)
- Modify: `Features/You/ProfileEditView.swift:285-303` (Equipment section)

Two systems, no shared UI signal they're related: global `EquipmentPreference` lives in Edit Profile
under "Account"; per-gym `GymRecord` lives in Settings → Training as "Gyms". A user checking one has
no reason to suspect the other exists.

- [ ] **Step 1:** Add a one-line footnote under the Gyms row in `SettingsView.swift`'s Training
  section: `Text("General equipment access is set in Edit Profile.").font(.elosMicro)
  .foregroundStyle(.secondary)`.

- [ ] **Step 2:** Add the mirror-image footnote under the Equipment section in `ProfileEditView.swift`
  (`:285-303`): `Text("Manage the specific gyms you train at in Settings > Training >
  Gyms.").font(.elosMicro).foregroundStyle(.secondary)`.

- [ ] **Step 3: `build-for-testing` → commit.**

```bash
git commit -m "fix(train): cross-link the two equipment-adjacent settings screens

Global EquipmentPreference (Edit Profile > Account) and per-gym
GymRecord (Settings > Training > Gyms) are unrelated systems with zero
UI signal pointing a user from one to the other. A one-line footnote
each way — cheapest fix that closes the discoverability gap without
unifying the two systems, which is a real feature (GymsView's own doc
comment already flags it as future work), not a quick fix."
```

---

## Task 5: `LoggedVolumeAnalyzer.MuscleRow` gets an `isExcluded` flag; Stats renders it muted

**Files:**
- Modify: `Features/Train/Programs/Intelligence/LoggedVolumeAnalyzer.swift`
- Modify: `Features/Stats/StatsView.swift`
- Test: `ElosTests/Intelligence/LoggedVolumeAnalyzerTests.swift` (append)

**Background.** `MuscleVolumeAnalyzer.fineRow` (the split/template builders' coverage bars) already
distinguishes `isExcluded` (lifter-chosen, via `VolumeOverrides.excludedMuscles`) from `isOptional`
(science-driven, rotator cuff/forearms) — shipped this session specifically so an excluded muscle
renders "Skipped" instead of a bare gap. `LoggedVolumeAnalyzer.MuscleRow` (Stats' equivalent) has no
such field. Scoring is already correct — `gaps()` filters `!$0.band.isOptional`, and a globally
excluded muscle's band is forced `asOptional` via the same `TrainingScience.weeklyBand` path, so it's
never nagged. Only the *rendering* is missing: if that muscle picks up any incidental secondary
credit, its Stats bar looks like an ordinary in-progress muscle, not "you told me to skip this."

- [ ] **Step 1: Write the failing test.** `MuscleRow` only exists for a muscle with `credit.total > 0`
  (`rows(...)`'s `guard let c = credit[fine], c.total > 0 else { return nil }`) — a muscle with zero
  logged credit never becomes a row regardless of exclusion, so the test must give the excluded
  muscle some *incidental* credit (secondary, from an exercise targeting something else), matching
  the audit's exact scenario ("if it picks up any incidental secondary credit from other lifts"):

```swift
@Test func excludedMuscleWithIncidentalCreditIsFlaggedExcluded() {
    let profile = TrainingProfile(goal: .hypertrophy, experience: .intermediate,
                                  volumeOverrides: VolumeOverrides(excludedMuscles: [.lowerBack]))
    // Primary lats, secondary lower back — a row/deadlift-shaped movement. Lower back gets
    // incidental indirect credit even though the lifter has told the app to skip it.
    let targets = MuscleTargets(primary: [.lats], secondary: [.lowerBack])
    let sets = [LoggedVolumeAnalyzer.LoggedSet(targets: targets, completedAt: Date())]
    let rows = LoggedVolumeAnalyzer.rows(sets: sets, since: Date().addingTimeInterval(-7*86400), profile: profile)
    let lowerBackRow = rows.first { $0.fine == .lowerBack }
    #expect(lowerBackRow != nil, "incidental secondary credit must still produce a row")
    #expect(lowerBackRow?.isExcluded == true)
    #expect(rows.first { $0.fine == .lats }?.isExcluded == false)
}

@Test func nonExcludedMuscleRowReportsIsExcludedFalse() {
    let profile = TrainingProfile(goal: .hypertrophy, experience: .intermediate)
    let targets = MuscleTargets(primary: [.lats])
    let sets = [LoggedVolumeAnalyzer.LoggedSet(targets: targets, completedAt: Date())]
    let rows = LoggedVolumeAnalyzer.rows(sets: sets, since: Date().addingTimeInterval(-7*86400), profile: profile)
    #expect(rows.first { $0.fine == .lats }?.isExcluded == false)
}
```

- [ ] **Step 2: Confirm failure.**

- [ ] **Step 3: Implement.** Add `let isExcluded: Bool` to `MuscleRow`
  (`LoggedVolumeAnalyzer.swift:30-42`), and set it in `rows(...)` (`:64`) the same way
  `MuscleVolumeAnalyzer.fineRow` computes it — `profile.volumeOverrides.excludedMuscles.contains(fine)`:

```swift
return MuscleRow(fine: fine, credit: c, band: band,
                 status: MuscleVolumeAnalyzer.status(sets: c.total, band: band),
                 isExcluded: profile.volumeOverrides.excludedMuscles.contains(fine))
```

- [ ] **Step 4: In `StatsView.swift`**, wherever a `MuscleRow` renders its fill/label (near
  `volumeRows`, `:76-93`), branch on `isExcluded` the same way `MuscleCoverageBars` does: render
  "Skipped" muted instead of the normal fill/label.

- [ ] **Step 5: Harness pass** (this file is pure — copy alongside the existing
  Intelligence harness set) **→ `build-for-testing` → commit.**

```bash
git commit -m "feat(train): Stats mutes a muscle you've told the app to skip

MuscleVolumeAnalyzer (the builder's coverage bars) already renders an
excluded muscle as 'Skipped' rather than a bare gap — shipped this
session specifically so a lifter-chosen exclusion never reads the same
as an unaddressed hole. LoggedVolumeAnalyzer (Stats' own volume rows)
had no equivalent field, so the same muscle's Stats bar looked like an
ordinary in-progress row if it picked up any incidental secondary
credit. Scoring was already correct — gaps() already filters excluded
muscles out — only the rendering was missing."
```

---

## Risks

- **Task 1** is the only one touching persistence beyond what's already tested elsewhere. Verify with
  the in-memory-`ModelContainer` pattern (`SplitEditPreservesDayDataTests.swift`'s shape), not the
  bare-swiftc harness, since `buildLocalSplit` calls `context.insert`/`context.fetch` directly.
- **Task 2**'s extraction must not change `GymSwitchPreview`'s inputs/behavior — the preview-vs-apply
  consistency was already adversarially verified against the *old* call site; changing the call site
  without changing the underlying computation preserves that guarantee, but re-read the moved code
  once after the move to confirm nothing was altered in transit.
- **Task 1's accepted residual risk** (stale server-side `template_id` after a post-push id rewrite)
  is deliberately not closed — flagged in Task 1 so it isn't mistaken for an oversight later.

## Out of scope

- Quality score on the social feed (product decision).
- Unifying `EquipmentPreference`/`GymRecord` (real feature, already flagged as future work in
  `GymsView.swift`'s own doc comment).
- Adding a gym question to onboarding (judged correct as-is — no split exists yet to attach to).
- Wiring `GymEquipmentIndex`'s picker bias into the live `ExercisePickerView` (already deferred
  deliberately in the prior plan, for the same perf reason — nothing new changes that tradeoff).
- Per-gym volume breakdown in Stats (no data is wrong today, just aggregated across gyms — a real
  feature idea, not a gap to close in this pass).
- `MachineDetailView` referencing `GymEquipmentIndex` ("available at your gym") — lower value than
  the four items above; can be picked up separately if there's appetite for it.
