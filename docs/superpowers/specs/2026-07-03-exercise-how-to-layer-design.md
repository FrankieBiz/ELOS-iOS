# Exercise How-To Layer ("brand-agnostic ⓘ") — Design

**Date:** 2026-07-03
**Status:** Draft (design); pending review
**Scope tier:** A + targeted B — enrich existing exercises with how-to content, plus fill machine gaps
**Source dataset:** [`yuhonas/free-exercise-db`](https://github.com/yuhonas/free-exercise-db) — 873 exercises, `Unlicense` (public domain), bundled photos + step instructions

## 1. Problem

Elos exercises are purely taxonomic — `exercise_definitions` carries `name`, `primary_muscle`, `secondary_muscles`, `equipment`, `movement_pattern`, and nothing else (206 seeded global rows across migrations `006` and `016`). There is **no "how do I do this movement" content** anywhere in the app. This matters most on machines: a user selects a specific brand machine (e.g. a Hammer Strength Pec Deck) from the 1,697-record equipment DB and gets zero guidance on how to use it.

Two facts make this cheap to fix:

1. **Brand variants already dedupe to a generic exercise.** The equipment DB's brand machines map up to a generic exercise via `dedupeKey` / the `machine_exercises` junction and `EquipmentDatabase.variants(forExercise:)`. So one "Pec Deck" how-to, attached to the *generic* exercise, is inherited by every brand — "all pec decks no matter brand" — with no per-brand content.
2. **The UI affordance already exists.** `SetRowView.swift:94–97` has an `info.circle` button wired to a `showInfo` toggle that today only reveals a one-line muscle caption (`SetRowView.swift:105–109`). We upgrade *what it reveals*.

A public-domain dataset (`free-exercise-db`, `Unlicense`) supplies the content: clean step-by-step `instructions` arrays, 2 demo photos per exercise, a 17-value muscle vocabulary that maps trivially to Elos's taxonomy, and `mechanic`/`force` fields that can backfill Elos's frequently-empty `movement_pattern`. Its 873 exercises cover the common commercial machines (Leg Extension/Curl/Press, Machine/Leverage Chest & Shoulder Press, Lat Pulldown, Seated Row, Thigh Abductor/Adductor, Ab Crunch, Dip, Calf machines) — the flagship "Pec Deck" appears as `Butterfly` / `Reverse Machine Flyes`, which is why matching needs an alias layer, not exact string equality.

## 2. Goals

1. Add a **how-to layer** — step instructions + one demo photo — to the exercises users actually do.
2. Content is authored **once per generic exercise** and inherited by every brand machine variant. No per-brand content.
3. Surface it via the existing ⓘ affordance in the active session, and in the exercise picker before adding.
4. Work **offline** (gym signal is unreliable) and introduce no runtime dependency on the external dataset.
5. Leave the curated 206-exercise catalog and all logged history untouched; only *enrich* existing rows and *add* new generic exercises where a machine has no exercise to hang content on.
6. Opportunistically backfill `movement_pattern` on matched rows (a free win for the existing Smart Sort / compound-first Intelligence layer).

## 3. Non-goals

- **No catalog replacement.** Existing exercises stay authoritative; logged `ExerciseSetRecord` / template rows are never touched.
- **No multilingual content.** English instructions only (the source's other languages are out of scope).
- **No bulk import.** We do not pull all 873 rows; the ~200+ cable/stretching/plyometrics/cardio/strongman entries are not brought in as new catalog exercises.
- **No change to the machine/equipment DB** (`EquipmentDatabase.swift`, `machines`/`machine_models`/`machine_brands`, `MachineSelectionSheet` flow).
- **No animated GIFs in this phase.** Static photos only; animated GIFs are a licensed Phase 2 (see §9).
- **No runtime API/network calls to the dataset.** Import is a one-time, build-time step baked into a seed migration.

## 4. Architecture

### 4.1 Content lives on the generic exercise, looked up at display time

How-to content attaches to the **generic `ExerciseDefinitionRecord`** (the catalog row), one level *above* the brand layer. Because every brand machine dedupes up to a generic exercise, content written once is inherited by all brands automatically.

Crucially, the how-to sheet **looks content up by exercise name at display time** rather than threading it through the `PickedExercise → Exercise` pipeline. The exercise catalog is already synced into SwiftData for offline use (`ExercisePickerViewModel.syncExercises` pulls `GET /exercises?limit=500` and upserts `ExerciseDefinitionRecord`), so the sheet can fetch the matching record locally. This deliberately sidesteps the existing data-flow gap where `PickedExercise → Exercise` (`ActiveSessionView.swift:102–114`) does not even populate `primaryMuscle`/`secondaryMuscles` — we do not want to widen that pipeline with reference data.

Lookup key: case-insensitive `name` match against `ExerciseDefinitionRecord`. (Optional hardening — carry the catalog `definitionID` on the in-session `Exercise` for exact lookup — is noted in §9 but not required for v1, since catalog names are unique.)

### 4.2 Data model changes

Add two fields to the exercise definition, in all three layers:

**Backend** (`exercise_definitions`, new migration):
- `instructions TEXT[] DEFAULT '{}'` — ordered step strings.
- `image_key TEXT` (nullable) — stable reference to a bundled demo photo; `NULL` when no how-to exists.

**Shared contract** (`packages/elos-shared/src/index.ts`, `ExerciseDefinition`):
- `instructions: string[]`
- `image_key: string | null`
- (`CreateExerciseBody` unchanged — user-created exercises do not author how-to content.)

**iOS** (`ExerciseDefinitionRecord`, `ElosSchema.swift:244–273`, lightweight migration — new optional/defaulted properties auto-migrate):
- `instructionsJSON: String = ""` with a computed `instructions: [String]` (mirrors the existing `secondaryMusclesJSON`/`secondaryMuscles` pattern).
- `imageKey: String = ""` (empty = none).

`movement_pattern` gets **backfilled in place** on matched rows (no new column) using the source's `mechanic` (compound/isolation) + `force` (push/pull) + name heuristics, only where Elos's value is currently empty.

### 4.3 Import pipeline — one-time, conservative auto-match, seed migration

A build-time script (not shipped, not called at runtime) produces the seed content:

1. **Normalize** names on both sides (lowercase, strip punctuation/qualifiers).
2. **Match** each Elos exercise to a source exercise via normalized-name equality + an **alias map** that extends the app's existing `gymAliases` (this is what resolves "pec deck" → `Butterfly`/`Reverse Machine Flyes", "leg extension" ↔ "Leg Extensions", etc.). Matching is **conservative**: only high-confidence matches are applied; anything ambiguous is left blank so the ⓘ falls back to the muscle caption. A *wrong* how-to is worse than none.
3. **Enrich (pass A):** for matched existing exercises, populate `instructions` + `image_key` (+ backfill `movement_pattern` if empty).
4. **Fill machine gaps (pass B):** for machines in the equipment DB whose generic exercise does not exist in the catalog, insert the source's exercise as a **new global generic exercise**, mapping its muscle vocabulary through the 17-value → Elos taxonomy table and deriving `movement_pattern` from `mechanic`/`force`. Scope pass B to machine-type gaps, not the whole dataset.
5. **Emit a match report** (CSV: Elos exercise → matched source name → confidence / unmatched) so the "spot-check" is a list scan, not an in-app hunt.
6. Approved content bakes into a **seed migration** (backend); iOS receives it through the normal `/exercises` sync → SwiftData upsert. No per-user work, no runtime dependency.

### 4.4 Images — bundled, resolved by `image_key`

Demo photos are **bundled in the iOS app asset catalog**, resolved at render time by `image_key`. Rationale: gyms have unreliable signal, so offline is guaranteed; the enriched set is bounded (~one photo per enriched exercise); and it avoids introducing the app's *first* remote-image-loading pattern (there is zero `AsyncImage` usage today — `imageURL` fields on `CreatorRecord`/`MachineRecord`/`LibraryWorkoutRecord` exist but are never rendered) for a secondary feature.

- The source ships 2 photos per exercise (start/end position); we bundle **one representative photo** per enriched exercise to keep binary growth bounded.
- `image_key` is a stable slug derived from the matched source id; the app maps it to a bundled asset. `NULL`/empty ⇒ the sheet renders text-only.
- Source images are public domain (`Unlicense`), so bundling/redistribution is unrestricted.
- **Phase 2** (animated GIFs) reuses this same `image_key` slot with a licensed media set (see §9).

### 4.5 iOS UX

**How-to sheet** — a new lightweight view mirroring `MachineSelectionSheet` / `LogSleepSheet` conventions (`NavigationView`, drag handle, `.presentationDetents`): title = exercise name, the demo photo (when present), then numbered instruction steps. It fetches the `ExerciseDefinitionRecord` for the row's exercise name and renders `instructions` + `imageKey`.

**Active session** (`SetRowView.swift`): repurpose the existing `showInfo` toggle. When how-to content exists for the exercise, ⓘ presents the how-to sheet; when it does not, ⓘ falls back to today's one-line muscle caption. No new button — the affordance is already there.

**Exercise picker** (`ExercisePickerView.swift` `rowView`, ~line 675): add a matching ⓘ button before the trailing `Spacer()` (alongside the existing star button), presenting the same sheet, so users can read the how-to *before* adding. Shown only when content exists.

## 5. Data flow

1. Build-time script matches source → catalog, emits report, and produces a seed migration populating `instructions` / `image_key` (and backfilling `movement_pattern`). Demo photos are added to the iOS asset catalog.
2. Backend serves the new fields via `GET /exercises`; `ExercisePickerViewModel.syncExercises` upserts them into `ExerciseDefinitionRecord` (offline cache).
3. In the active session, tapping ⓘ on a row: if a matching `ExerciseDefinitionRecord` has non-empty `instructions`, present the how-to sheet (photo resolved from `imageKey` in the bundle); else show the muscle caption.
4. In the picker, ⓘ presents the same sheet for the row's exercise.
5. Because content is keyed on the generic exercise, any brand machine variant the user selected shows the same how-to with no extra wiring.

## 6. Error handling & edge cases

- **No match / low confidence** → `image_key` NULL and empty `instructions`; ⓘ falls back to the muscle caption. Never a wrong how-to.
- **Custom user exercises** → no catalog how-to content; fall back to muscle caption.
- **Missing bundled image but present instructions** → render text-only (image optional).
- **Offline** → fully functional; content is in SwiftData and photos are bundled.
- **Name lookup miss** (e.g. exercise renamed) → fall back to muscle caption; no crash.
- **Lightweight migration**: new iOS properties are defaulted (`""`), so existing on-disk stores migrate without a destructive reset.
- **`movement_pattern` backfill** only writes where the current value is empty — never overwrites curated data.

## 7. Testing

- **Import script** (offline, Node): given fixture source rows + Elos catalog, conservative matcher produces expected pairings; ambiguous names stay unmatched; muscle-vocabulary mapping table covers all 17 source values; `movement_pattern` derivation from `mechanic`/`force` yields expected patterns; report CSV shape.
- **Backend**: `GET /exercises` returns `instructions` / `image_key`; migration applies cleanly and is idempotent-safe; zod schema accepts the new fields.
- **iOS**: `ExerciseDefinitionRecord.instructions` decodes from `instructionsJSON`; how-to sheet renders steps + image when present and falls back when absent; ⓘ visibility gated on content existence; lookup-by-name is case-insensitive. Light smoke coverage on the sheet view.

## 8. Phasing

1. **Phase 1 (this spec):** schema fields, conservative import + seed migration (enrich + machine-gap fill), bundled demo photos, how-to sheet, ⓘ wired in session + picker, `movement_pattern` backfill.
2. **Phase 2 (separate spec):** animated GIFs via a licensed source (ExerciseDB.io one-time commercial dataset license — pending budget/legal sign-off), dropped into the existing `image_key` slot.
3. **Phase 3 (optional, later):** multilingual instructions if the app localizes.

## 9. Open questions (resolve during planning, non-blocking)

- Confidence threshold for the conservative matcher, and the exact alias-map entries (seeded from the machine list, expanded during the review pass).
- One representative photo vs both start/end photos per exercise (proposed: one, to bound binary size).
- Whether to carry `definitionID` on the in-session `Exercise` for exact content lookup vs relying on case-insensitive name match (proposed: name match for v1).
- Estimated app binary growth from bundled photos (measure during implementation; revisit hosting only if it exceeds an acceptable budget).
- Exact `machine_exercises` / `dedupeKey` traversal used to decide which machines have "no generic exercise" for pass B.
