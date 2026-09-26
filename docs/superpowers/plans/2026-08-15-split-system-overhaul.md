# Split System Overhaul — Design & Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Three things, in dependency order.
1. The screen you actually live in when you open a split shows the same ratings, coverage, suggestions and auto-fix the builder already has.
2. A split day can hold more than one version — "Leg Day @ Fairless" and "Leg Day @ Warminster" — and switching gyms switches all of them at once.
3. The app learns what's at each gym from what you log there, and uses it to bias suggestions.

**Architecture:** Everything is client-side. No backend, migration, or `packages/elos-shared` change — a hard constraint, not a preference (see *Three constraints that shape everything* below). New persistence follows the established local-only pattern (`intentJSON`, `excludedMusclesJSON`, `draftJSON`, `muscleTargetsJSON`): defaulted columns, lightweight SwiftData migration, never sent over the wire.

**Tech Stack:** Swift, SwiftUI, SwiftData, Swift Testing.

**Verification:** `xcodebuild test` cannot execute in this sandbox (pty error — environmental, don't debug it). Compile check is
```bash
xcodebuild build-for-testing -project Elos.xcodeproj -scheme Elos -destination 'platform=iOS Simulator,name=iPhone 17' OTHER_SWIFT_FLAGS='$(inherited) -disable-sandbox' -quiet
```
Pure logic is verified via the swiftc harness (copy `Intelligence/*.swift` + `SplitHelpers.swift` to a temp dir, shim the two SwiftData types the `init(record:)` adapters touch, `main.swift` of bare `assert()`s, `swiftc -o harness *.swift && ./harness`). Real Swift Testing files still get written and committed — they run in CI / on a real machine. If a `build.db is locked` error appears, run `lsof` on it first: delete `XCBuildData` only on a confirmed-empty result, otherwise wait and retry.

---

## Decisions (locked by the user)

- **Variants are built by hand**, not auto-translated. The app never guesses a substitute exercise for another gym. You build "Leg Day @ Warminster" yourself; the app remembers it and switches to it.
- **Gym equipment is learned from logged workouts**, not catalogued up front.
- **Active gym is a manual switch that persists** until changed.

### The consequence of "build both versions myself" — and why it's the right call

Auto-translation was the only feature that *needed* precise per-gym equipment data. Without it, learned equipment stops being load-bearing and becomes an assist: bias the exercise picker toward machines you've actually used at this gym, and flag when a variant references something never logged there. That means **Phase 3 is genuinely optional** — Phases 1 and 2 are a complete, shippable feature without it. It's sequenced last for exactly that reason and can be dropped without touching anything above it.

---

## Background: what exists, and what doesn't

Established by reading the code, not assumed.

### The screen you're describing has no coaching UI at all

`UserSplitDetailView` — a struct at the bottom of `Features/Train/Programs/ProgramsView.swift:468-585`, not its own file — is what you reach by tapping a split under "My Splits." It renders an Active/Set-Active button, `MuscleGroupPanelWeekly` (raw weekly muscle targets, **no scoring**), and a list of day rows with Start buttons. It has **no score, no tier, no `TemplateQualityPanel`, no `MuscleCoverageBars`, no tips, no auto-fix**.

The "83 / Dialed in" you saw comes from `CreateSplitView.qualityReport` (`CreateSplitView.swift:272-281`) — a computed property that runs `TemplateQualityEngine.score` live. You only see it by tapping **Edit**, which opens the builder. The score is **never stored**; `UserSplitRecord` has no score field. The entire coaching stack exists and works; it is simply not wired into the screen you use day to day.

There is also **no way to see a day's exercise list** from the split view without either starting the session or entering the full builder (`dayRow`, `:557-584`).

`ProgramsView`'s "My Splits" rows (`:402-435`) show name, a text descriptor and a pattern strip — **no score** either.

### There is no notion of a gym anywhere in the app

Searched exhaustively across iOS, backend, and shared package. Definitively **does not exist**:
- `EquipmentPreference` (`Intelligence/EquipmentPreference.swift:1-35`) is a **single global posture** — `fullGym`/`home`/`custom` + a set of coarse type tokens. One per user, JSON on `UserProfileRecord.equipmentPreferenceJSON`. It cannot express "I train at two places."
- `GymSize` (`SplitFinderModels.swift:27-31`) is a transient Split-Finder wizard input, never persisted. Same dead-end shape as `InjuryEntry`, which the substitution-engine spec already had to drop for exactly this reason.
- The 1,697-record `EquipmentDatabase` (`Models/EquipmentDatabase.swift`) is a hardcoded Swift array of **machine models** (brand + machine name + model series). No location field. The backend's separate `machines` catalog likewise.

**The crux:** `equipmentId` / `equipmentDedupeKey` identify a *machine model*, not a physical unit. A Hammer Strength Iso-Lateral Row at Fairless and the same model at Warminster are the **identical record** today, and `TrainViewModel.swift:315-318` deliberately scopes progressive overload and PRs to that model identity. This is *correct and should not change* — you genuinely want your Hammer Strength row history to follow you between gyms. Gyms answer "what's available here," never "is this a different lift."

### Three constraints that shape everything

From the sync path — all three make "variants as extra day rows" impossible:

1. **The backend caps a split at 7 days.** `days: z.array(splitDaySchema).max(7)` — `splitDaySchema` at `apps/elos-api/src/schemas.ts:126-133`, the `.max(7)` on both `createSplitSchema` (`:139`) and `updateSplitSchema` (`:145`). Two variants on four real days blows the cap.
2. **Sync matches days by position.** `syncSplitsFromServer` pairs remote to local via `$0.orderIndex == remoteDay.order_index` (`AppViewModel.swift:1326`). Two rows sharing an `orderIndex` collide — first wins, rest silently orphaned.
3. **Unknown fields are silently dropped.** `splitDaySchema` is not `.strict()`, so zod strips anything outside its six fields. A new day field would appear to sync (`syncPending` clears) while never reaching the database — *worse* than an error.

Also: `updateSplit` does `DELETE FROM user_split_days WHERE split_id = $1` then re-inserts (`splitService.ts:133-146`), regenerating every server-side day UUID on every save. Nothing may key off a server day id across a save.

**Therefore: variants live in a local-only defaulted column on `UserSplitDayRecord`, and the six wire fields keep meaning exactly what they mean today.**

### A real pre-existing bug this work would multiply

`TemplatesView.swift:111-123` rewrites a template's local `id` to the server's id on first successful push, and re-points its `TemplateExerciseRecord.templateID` rows — but **never re-points any `UserSplitDayRecord.templateID` that referenced the old local id**. That day's `fetchTemplateExercises` then returns `[]`, and `prepareExercises` (`AppViewModel.swift:682-719`) drops through its guard loading **zero exercises, with no error surfaced**.

One silent breakage point today. With N variant templates per day it becomes N. Fixed in Task 12, independently of the rest.

---

## Architecture

### The projection invariant (the load-bearing idea in Phase 2)

`UserSplitDayRecord` gains **one** local-only column:

```swift
var variantsJSON: String = ""   // JSON: { activeID: String, variants: [DayVariant] }
```

```swift
struct DayVariant: Codable, Identifiable, Equatable {
    let id: String
    var name: String            // "Fairless" — display name, usually the gym's
    var gymID: String?          // nil = "no particular gym" (the default/original version)
    var exercises: [DayExercise]
    var templateID: String
}
```

**The active variant is always mirrored into the day's existing `exercisesJSON` and `templateID`.** Those two fields stay the single source of truth for everything that already reads them — `prepareExercises(for:)`, the sync payload, `MuscleGroupPanelWeekly`, scoring, the builder. Nothing downstream learns that variants exist.

Consequences, all of them good:
- Zero changes to session start, scheduling, or the wire format.
- The server sees "what you're doing now," which is the correct thing for it to see.
- A day with no variants is byte-identical to today (`variantsJSON == ""`).
- Switching variants is: write the outgoing variant's edits back into its slot → copy the incoming variant into `exercisesJSON`/`templateID` → `syncPending = true`.

**The one hazard, and its rule:** `syncSplitsFromServer` overwrites local day fields from the server, including `exercisesJSON`. If a remote edit lands, `exercisesJSON` can diverge from what `variantsJSON` says the active variant contains. **Reconciliation rule: the wire fields win, and the active variant is updated to match them.** The server reflects a real edit made somewhere; a local variant cache must never overwrite it. Task 6 implements and tests this explicitly.

### Gyms

```swift
@Model final class GymRecord {
    var id: String
    var ownerID: String        // String, never UUID — #Predicate requirement
    var name: String
    var createdAt: Date
    var lastUsedAt: Date?
}
```

Local-only, no backend — the same call `EquipmentPreference` and `VolumeOverrides` already make. Active gym is `AppViewModel.activeGymID` in UserDefaults (`elos.activeGymID`), matching how `volumeOverrides` is persisted.

**Known limitation, stated plainly:** local-only means gyms and variants do not survive a reinstall or reach a second device, exactly like a lifter's per-set muscle check-off today. The upgrade path is a backend table + contract change, and it is a real decision to make later, not something to sneak in now.

### Learned equipment (Phase 3)

`WorkoutSessionRecord` gains `var gymID: String = ""` — one more defaulted local-only field alongside `draftJSON` and `exportedToHealth`, set from `activeGymID` when a session starts.

The inventory is then a **pure derivation, no new storage**: for a gym, the set of `equipmentDedupeKey` values on `ExerciseSetRecord`s whose session carries that `gymID`. `ExerciseSetRecord` already persists `equipmentId`/`equipmentDedupeKey`/`equipmentBrandName` (`ElosSchema.swift:192-194`).

---

# Phase 1 — The split view gets the coaching stack

## Task 1: Extract shared "score a saved split" logic

**Files:**
- Create: `Features/Train/Programs/Intelligence/SavedSplitScoring.swift`
- Test: `ElosTests/Intelligence/SavedSplitScoringTests.swift`

`CreateSplitView` builds `[[ScoredExercise]]` from its `@State` arrays. `UserSplitDetailView` has `[UserSplitDayRecord]`. Rather than copy the logic (the repeated bug shape in this repo — `TemplatesView.startSession` duplicating `prepareExercises` cost real data loss), extract one path both use.

- [ ] **Step 1: Write the failing tests**

```swift
@Test func resolvesAdHocExercisesOverTemplate() {
    // A day with BOTH exercisesJSON and templateID must use exercisesJSON — matching
    // prepareExercises(for:)'s precedence exactly. If these two ever disagree, the score
    // describes a workout different from the one that actually starts.
}

@Test func fallsBackToTemplateWhenExercisesJSONIsAnEmptyArray() { }   // "[]"
@Test func fallsBackToTemplateWhenExercisesJSONIsAnEmptyString() { }  // ""
@Test func fallsBackToTemplateWhenExercisesJSONIsMalformed() { }      // "{not json"

@Test func restDaysContributeNoExercises() { }

@Test func producesTheSameReportAsTheBuilderForEquivalentInput() {
    // The anti-drift test: build the same 3-day split as @State-shaped input and as
    // UserSplitDayRecord-shaped input, assert identical overall score.
    // Build the record-shaped side with the REAL stored dayName values ("Monday", "Rest") —
    // not the builder's normalized "" — or the test masks the very question it exists to ask.
}
```

**The precedence is a decode guard, not a string check.** `prepareExercises` selects ad-hoc only
when `exercisesJSON` decodes to a **non-empty array**; an empty array, an empty string, *and*
malformed JSON all fall through to the template. Copy the guard verbatim —
`if let data = ..., let infos = try? JSONDecoder().decode([DayExercise].self, from: data),
!infos.isEmpty` — rather than testing `exercisesJSON.isEmpty`, which would diverge on the
malformed case.

- [ ] **Step 2: Confirm they fail** (type doesn't exist) via the swiftc harness.

- [ ] **Step 3: Implement**

```swift
enum SavedSplitScoring {
    /// One day's exercises, resolved with the SAME precedence `prepareExercises(for:)` uses:
    /// ad-hoc `exercisesJSON` wins outright; `templateID` is consulted only when it's empty.
    /// Any divergence here means the score describes a different workout than the one that starts.
    static func dayExercises(for day: UserSplitDayRecord,
                             templateExercises: (String) -> [TemplateExerciseRecord]) -> [DayExercise]

    static func report(days: [UserSplitDayRecord],
                       templateExercises: (String) -> [TemplateExerciseRecord],
                       catalog: [ExerciseCandidate],
                       profile: TrainingProfile,
                       intent: TrainingIntent) -> QualityReport

    static func daySummaries(days: [UserSplitDayRecord], ...) -> [SplitDaySummary]
}
```

Template lookup is injected as a closure so the type stays pure and harness-testable — it must not reach for a `ModelContext`.

`report` passes `dayExclusions:` (from each day's `excludedMuscles`) and `dayIsRest:` (from `isRest`) so the weekly skip rule shipped yesterday applies here identically.

- [ ] **Step 4: Harness pass → `build-for-testing` → commit.**

```bash
git commit -m "feat(train): one shared path for scoring a saved split

CreateSplitView scored from @State; the split detail view has
UserSplitDayRecords and no scoring at all. Extract the resolution +
scoring both need rather than letting a second copy drift — the same
shape that cost logged-set data when TemplatesView.startSession
duplicated prepareExercises. Resolution precedence is pinned by test
against prepareExercises's own: ad-hoc wins, template is the fallback."
```

## Task 2: Wire the panel into `UserSplitDetailView`

**Files:**
- Modify: `Features/Train/Programs/ProgramsView.swift:468-585`

- [ ] **Step 1: Add the scoring properties**, mirroring `CreateSplitView.scoringProfile` (`:283-289`) — goal from the split's own `intent`, experience from the profile, **`volumeOverrides: vm.volumeOverrides`** (a documented trap: any new `TrainingProfile(...)` that drops overrides makes the Volume Targets screen silently stop affecting scores).

- [ ] **Step 2: Render the panel** — `TemplateQualityPanel(report:guidance:title: "Split Quality", scope: .weeklySplit, onTapTip:onSeeFullReport:)`, gated on `vm.showQualityRater` and on the split having ≥2 populated days, matching the builder's gate (`CreateSplitView.swift:291-299`).

- [ ] **Step 3: Wire `SplitQualityReportView`** via `showFullReport`, passing `daySummaries` and `onSelectDay` → `DayQualityReportView` (both shipped yesterday, reused as-is).

- [ ] **Step 4: Per-day score on each day row.** `dayRow(_:)` gains the day's score from `daySummaries`, styled with `QualityPalette.color(forScore:)`.

- [ ] **Step 5: Make day rows open the day report** rather than only offering Start — this also closes the "can't see a day's exercises without starting it or editing" gap. Keep Start as a distinct control; **do not** make the whole row ambiguous between "look at this" and "begin training."

- [ ] **Step 6: `build-for-testing` → commit.**

## Task 3: Auto-fix from the saved-split view

**Files:**
- Modify: `Features/Train/Programs/ProgramsView.swift`

The engine, preview sheet, and confirm/deny flow all exist. **One real difference:** the builder mutates `@State` and persists on Save; here there is no Save button — applying a fix must write straight to SwiftData.

- [ ] **Step 1: Implement `apply(_ operations:)` for saved days.** For each operation, mutate the corresponding `UserSplitDayRecord`'s decoded `[DayExercise]`, re-encode to `exercisesJSON`, set `split.syncPending = true`, `try? modelContext.save()`, then push via the same `Task.detached` shape `saveSplit` uses (`CreateSplitView.swift:681`).

- [ ] **Step 2: Guard the template case.** "Template-backed" must be defined as *resolves via
  template* — i.e. `exercisesJSON` fails the non-empty-decode guard — **not** merely "`templateID`
  is non-empty," since a day can carry both and ad-hoc wins. A day that genuinely resolves via
  template has no `exercisesJSON` to edit. Two honest options — **materialize** the template into the day's own `exercisesJSON` (breaking the template link, which must be stated in the preview: "this will detach the day from its template"), or **decline** the fix for template-backed days. **Decline for v1** — silently severing a template link the user deliberately created is worse than not offering the fix. The preview explains why.

- [ ] **Step 3: Confirm the preview's before/after uses the same parameters** as the panel's own report (including `dayExclusions`/`dayIsRest`) — otherwise the delta is computed against a different baseline than the one on screen.

- [ ] **Step 4: `build-for-testing` → commit.**

## Task 4: Scores in the "My Splits" list

**Files:**
- Modify: `Features/Train/Programs/ProgramsView.swift:402-435`

- [ ] **Step 1:** Add the score to `mySplitRow`, computed via `SavedSplitScoring`.

- [ ] **Step 2: Performance guard.** This runs `TemplateQualityEngine.score` once per split per render. Scoring is cheap but not free, and `mySplitRow` is inside a `ForEach`. Compute all scores **once** in a single `let scores = ...` above the `ForEach`, not per row — the exact mistake `TemplateQualityEngine`'s own doc comment warns about ("provided callers compute it *once* per view body rather than per row"). If more than ~10 splits is plausible, cap the computation to visible rows.

- [ ] **Step 3: `build-for-testing` → commit.**

**Phase 1 ships here** — a complete, coherent improvement with no dependency on anything below.

---

# Phase 2 — Gyms and day variants

## Task 5: `GymRecord` + active gym + management UI

**Files:**
- Modify: `SwiftData/ElosSchema.swift` (add `GymRecord`)
- Modify: `ElosApp.swift:27-52` (register `GymRecord` in the explicit `Schema([...])` list — it
  lives here, **not** in `ElosSchema.swift`; omitting it fails at runtime, not compile time)
- Modify: `AppViewModel.swift` (`activeGymID`)
- Create: `Features/You/GymsView.swift`
- Test: `ElosTests/GymRecordTests.swift`

- [ ] **Step 1:** Add `GymRecord` (fields above; `ownerID: String`, never `UUID`). Register it in the `ModelContainer` schema — **check `ElosApp.swift`'s container construction and add the type there**; a model missing from the schema list fails at runtime, not compile time.

- [ ] **Step 2:** `AppViewModel.activeGymID: String` backed by UserDefaults `elos.activeGymID` with `didSet { save() }`, matching `volumeOverrides`' shape (`AppViewModel.swift:117-121`).

- [ ] **Step 3:** `GymsView` — list, add, rename, delete. Deleting a gym must **not** orphan variants: a variant whose `gymID` no longer resolves falls back to displaying its stored `name`. Test this.

- [ ] **Step 4:** Reachable from Settings/Me. **Do not** put gym management in the split view; it's a profile-level concept used by several screens.

- [ ] **Step 5: Harness/`build-for-testing` → commit.**

## Task 6: Make the split builder's save preserve day-local data

**Files:**
- Modify: `Features/Train/Programs/CreateSplitView.swift:670-687` (`saveSplit`'s edit branch)
- Test: `ElosTests/SplitEditPreservesDayDataTests.swift`

**This is a hard prerequisite for Task 7, not a nicety.** Adversarial review caught that the plan as
originally written was broken here.

`saveSplit`'s edit branch does `for day in editDays { modelContext.delete(day) }` then
`buildDays(...)` (`:676-677`), constructing brand-new `UserSplitDayRecord`s. The builder's
`onAppear` (`:143-157`) hydrates `@State` only from the wire fields — it never reads
`variantsJSON`. So the moment `variantsJSON` exists, **Edit → Save (even with zero changes)
silently destroys every non-active variant on every day**, and the Edit button lives on
`UserSplitDetailView` (`ProgramsView.swift:531`), the exact screen variants inhabit.

The plan's original mitigation — "grep for direct `exercisesJSON =` assignments" — would not have
caught it: the destructive steps are `modelContext.delete(day)` and an initializer label
`exercisesJSON:` (colon, not `=`). Both slip past that grep.

**Fix: update days in place instead of delete-and-rebuild.** This also removes a latent bug that
exists today — rebuilding regenerates every local day `id` on every save, orphaning anything that
ever keys off one. The day count is always exactly 7 (`buildDays` loops `dayLabels.enumerated()`),
so in-place update needs no insert/delete logic in the common path.

- [ ] **Step 1: Write the failing test**

```swift
@Test func editingASplitPreservesLocalOnlyDayFields() {
    // Set a sentinel on a day (variantsJSON stands in for any local-only column),
    // run the edit-save path, assert the sentinel survives.
    // Today this fails: the day row is deleted and rebuilt with the column's default.
}

@Test func editingASplitKeepsDayRowIdentityStable() {
    // Day ids must not change across an edit-save. Rebuilding regenerates them.
}
```

- [ ] **Step 2: Confirm both fail.**

- [ ] **Step 3: Implement.** Replace the delete-and-rebuild with an upsert keyed on `orderIndex`:

```swift
// Update in place rather than delete-and-rebuild. Rebuilding drops every local-only column
// on the day (variants, and anything added later) and regenerates the row's id — the builder's
// @State only ever carried the six wire fields, so anything it doesn't know about is lost.
func upsertDays(for splitID: String, existing: [UserSplitDayRecord]) {
    let byIndex = Dictionary(grouping: existing, by: \.orderIndex).compactMapValues(\.first)
    for (i, label) in dayLabels.enumerated() {
        let rest = isEffectivelyRest(i)
        let exJSON = rest ? "[]" : encodedExercises(i)
        if let day = byIndex[i] {
            day.dayLabel = label
            day.dayName = rest ? "Rest" : (dayNames[i].isEmpty ? label : dayNames[i])
            day.templateID = rest ? "" : dayTemplateIDs[i]
            day.isRest = rest
            day.exercisesJSON = exJSON
            day.excludedMuscles = rest ? [] : dayExcludedMuscles[i]
            // variantsJSON deliberately untouched — the builder doesn't own it.
        } else {
            // ... construct + insert, as buildDays does today
        }
    }
    // Delete any stray rows beyond index 6 (defensive; shouldn't exist).
    for day in existing where day.orderIndex >= dayLabels.count { modelContext.delete(day) }
}
```

Create mode keeps calling `buildDays` unchanged — there are no existing rows to preserve.

- [ ] **Step 4: Fix the lying comment.** Line `:671` says "Edit mode — update in place then push to
  server" while doing the opposite. After this change it's finally true.

- [ ] **Step 5: `build-for-testing` → commit.**

```bash
git commit -m "fix(train): editing a split now updates day rows in place

saveSplit's edit branch deleted every UserSplitDayRecord and rebuilt
them from @State, despite a comment claiming it updated in place. That
regenerates each row's id on every save and drops any column the
builder's @State doesn't carry — today that's harmless, but it makes
any future day-local data silently unsurvivable across an edit. Upsert
by orderIndex instead."
```

## Task 7: `DayVariant` + the projection invariant

**Files:**
- Modify: `SwiftData/ElosSchema.swift` (`UserSplitDayRecord.variantsJSON`)
- Create: `Features/Train/Programs/DayVariants.swift`
- Test: `ElosTests/DayVariantsTests.swift`

**This is the highest-risk task in the plan.** Everything downstream assumes the invariant holds.

- [ ] **Step 1: Write the failing tests first — these define the invariant.**

```swift
@Test func activeVariantIsMirroredIntoTheDaysWireFields() {
    // After setting a variant active, day.exercisesJSON and day.templateID must equal
    // that variant's contents. This is what keeps prepareExercises/sync/scoring working.
}

@Test func aDayWithNoVariantsIsUnchanged() {
    // variantsJSON == "" must behave byte-identically to today.
}

@Test func switchingVariantsPreservesTheOutgoingVariantsEdits() {
    // Edits made while variant A was active must be written back into A's slot before
    // B is projected — otherwise switching gyms silently discards work.
}

@Test func remoteEditWinsOverTheLocalVariantCache() {
    // The reconciliation rule. If exercisesJSON was changed by a server sync, the active
    // variant is updated to match it — never the reverse. A stale local cache must not
    // overwrite a real edit made elsewhere.
}

@Test func deletingTheActiveVariantPromotesAnotherAndReprojects() { }

@Test func aVariantWhoseGymWasDeletedStillRendersByStoredName() { }
```

- [ ] **Step 2: Confirm failure. Step 3: Implement.**

```swift
struct DayVariantSet: Codable, Equatable {
    var activeID: String
    var variants: [DayVariant]
}

enum DayVariants {
    static func set(for day: UserSplitDayRecord) -> DayVariantSet?
    /// Writes `variants` back and re-projects the active one into the day's wire fields.
    /// Every mutation goes through here — there is no path that writes variantsJSON without
    /// re-projecting, because a day whose wire fields disagree with its active variant is
    /// the one state that breaks prepareExercises, sync, and scoring simultaneously.
    static func apply(_ set: DayVariantSet, to day: UserSplitDayRecord)
    static func switchTo(variantID: String, day: UserSplitDayRecord)
    static func createVariant(named: String, gymID: String?, from day: UserSplitDayRecord) -> DayVariant
    /// Called after a server sync overwrote the wire fields. Wire wins.
    static func reconcileAfterRemoteUpdate(day: UserSplitDayRecord)
}
```

- [ ] **Step 4: Call `reconcileAfterRemoteUpdate` from `syncSplitsFromServer`** (`AppViewModel.swift:1324-1348`), right after the remote day's fields are written to the local row.

  Note the hook only ever fires when `exercisesJSON` actually changed — the sync's day-update is
  guarded by `localDay.exercisesJSON != remoteDay.exercises_json` (`:1327`), so a remote
  `templateID`-only change isn't applied locally at all today. That's a pre-existing gap, out of
  scope here; just don't assume the reconcile runs on every remote edit.

- [ ] **Step 5: Harness pass, `build-for-testing`, commit.**

## Task 8: Variant UI in the split detail view

**Files:**
- Modify: `Features/Train/Programs/ProgramsView.swift` (`UserSplitDetailView`)
- Create: `Features/Train/Programs/DayVariantSheet.swift`

- [ ] **Step 1:** Each non-rest day row shows its active variant's name as a chip when the day has >1 variant (nothing at all when it has 0 or 1 — no UI noise for the common case).

- [ ] **Step 2:** Tapping the chip opens `DayVariantSheet`: list variants, switch, rename, delete, and "Add version for <gym>".

- [ ] **Step 3: "Add version"** starts as a **copy of the current day**, then opens the builder to edit it. Starting from a copy rather than blank is the whole point — a Warminster leg day is a Fairless leg day with three machines swapped, not a new program.

- [ ] **Step 4:** Editing a day while a non-default variant is active must write into **that variant's** slot. Verify the builder's save path routes through `DayVariants.apply`, not directly to `exercisesJSON` — a direct write would be silently lost on the next switch.

- [ ] **Step 5: `build-for-testing` → commit.**

## Task 9: The gym switcher

**Files:**
- Modify: `Features/Train/Programs/ProgramsView.swift`
- Create: `Features/Train/Programs/GymSwitchPreview.swift`

- [ ] **Step 1:** A gym selector in the split detail view showing the active gym.

- [ ] **Step 2: Switching previews first.** Selecting a gym shows what will change — which days swap to a different version, and (honestly) which days have **no** version for that gym and will stay as they are. Confirm/Cancel, matching the auto-fix preview pattern rather than inventing a second one.

- [ ] **Step 3: Apply** — for each day with a variant matching the target `gymID`, `DayVariants.switchTo`. Then `split.syncPending = true`, save, push. Set `activeGymID` and the gym's `lastUsedAt`.

- [ ] **Step 4: Show the split's score before → after the switch** in the preview. The two versions genuinely can score differently, and that's worth seeing before committing.

- [ ] **Step 5: `build-for-testing` → commit.**

**Phase 2 ships here** — the full "two gyms" feature, working, without Phase 3.

---

# Phase 3 — Learned equipment (optional)

Nothing above depends on this. It makes suggestions gym-aware; it can be cut or deferred freely.

## Task 10: Tag sessions with the gym

**Files:**
- Modify: `SwiftData/ElosSchema.swift` (`WorkoutSessionRecord.gymID: String = ""`)
- Modify: `AppViewModel.swift` / `TrainingContext` session-start path

- [ ] **Step 1:** Add the defaulted field (lightweight migration, local-only, never synced — same as `draftJSON`).
- [ ] **Step 2:** Set it from `activeGymID` at session creation. Existing sessions keep `""` and are simply excluded from any gym's inventory.
- [ ] **Step 3: `build-for-testing` → commit.**

## Task 11: `GymEquipmentIndex` + picker bias

**Files:**
- Create: `Features/Train/Programs/Intelligence/GymEquipmentIndex.swift`
- Test: `ElosTests/Intelligence/GymEquipmentIndexTests.swift`

- [ ] **Step 1: Tests** — inventory contains only dedupe keys logged at that gym; a set with no equipment key contributes nothing; an untagged session contributes nothing; empty inventory is distinguishable from "gym has nothing" (it means *unknown*, and must never be used as a hard filter).

- [ ] **Step 2: Implement** as a pure function over `[ExerciseSetRecord]` + a session→gym map. No new storage.

- [ ] **Step 3: Use it in two places, both soft:**
  - Bias the exercise picker toward equipment logged at the active gym (a ranking nudge in `ExerciseRankingEngine`'s existing shape, **not** a filter — an empty/thin inventory must never hide exercises).
  - A quiet note in `DayVariantSheet` when a variant references equipment never logged at its gym.

- [ ] **Step 4: Harness pass, `build-for-testing`, commit.**

---

# Independent bug fix

## Task 12: Template id rewrite orphans split days

**Files:**
- Modify: `Features/Train/Templates/TemplatesView.swift:111-123`
- Test: `ElosTests/TemplateSyncTests.swift`

- [ ] **Step 1: Reproduce in a test** — a `UserSplitDayRecord` with `templateID == "local-id"`, a template whose id is rewritten to `"server-id"` on push; assert the day still resolves exercises afterward. It currently won't.

- [ ] **Step 2: Fix** — in the same `if oldID != response.id` block that already re-points `TemplateExerciseRecord.templateID`, fetch `UserSplitDayRecord`s with `templateID == oldID` and re-point them too. Also re-point any `DayVariant.templateID` (Phase 2), which is why this lands after Task 7 if both are being done — though it stands alone and can ship first.

- [ ] **Step 3: `build-for-testing` → commit.**

```bash
git commit -m "fix(train): re-point split days when a template's id is rewritten on sync

A template's local id is replaced by the server's on first push, and
its exercise rows are re-pointed — but split days referencing the old
local id never were. fetchTemplateExercises then returned [], and
prepareExercises dropped through its guard loading zero exercises with
no error shown: you'd tap Start and get an empty workout."
```

---

## Risks

- **Task 7's projection invariant is the whole feature's integrity.** Any code path that writes `exercisesJSON` — *or replaces the row entirely* — desyncs the day. Adversarial review already caught one such path (`saveSplit`'s delete-and-rebuild), which is why Task 6 exists as a prerequisite. Mitigation: Task 7 Step 1's tests, plus an audit that looks for **row replacement and initializer labels**, not just `exercisesJSON =` assignments — the original grep-only mitigation missed the real killer because it was spelled `modelContext.delete(day)` and `exercisesJSON:`.
- **Local-only persistence** means gyms and variants are lost on reinstall and absent on a second device. Stated as a known limitation, matching existing precedent; upgrading it is a deliberate backend decision, not a silent add-on.
- **`syncSplitsFromServer` can clobber a variant's projection.** Handled by the wire-wins reconciliation rule (Task 7, Step 4), which is tested — but it is the subtlest thing in this plan and deserves an adversarial pass before shipping Phase 2.
- **Scoring in list rows** is a per-render cost in a `ForEach`. Task 4 Step 2 addresses it; if split counts grow this needs revisiting.
- **Phase 3's inventory is "unknown," not "empty."** Using a thin inventory as a hard filter would hide exercises from the picker. Both uses are deliberately soft.

## Out of scope

- Auto-translating a day between gyms (explicitly declined — variants are hand-built).
- Any backend, migration, or `elos-shared` change.
- Syncing gyms/variants across devices.
- Per-gym progressive-overload separation — `equipmentDedupeKey` deliberately keeps machine-model history unified across locations, which is the desired behavior.
- GPS/location detection of the active gym.
