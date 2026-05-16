# Template Builder v2 — Design Spec

**Date:** 2026-05-16  
**Scope:** iOS template builder (CreateTemplateView / TemplatesView) + split builder muscle panel + backend PATCH route  
**Status:** Approved (rev 3 — spec-review issues addressed)

---

## Context

The current template builder is a create-only modal form. After saving, templates cannot be edited — the only option is delete and recreate. There is no muscle coverage feedback during creation, no estimated duration, and no per-exercise notes. The template list row shows only the name and a flat exercise string. Navigation is limited to swipe-to-delete.

---

## Goals

1. Live muscle coverage panel while building — user sees which muscles are being hit as they add exercises
2. Full edit mode — templates can be modified after creation
3. Duplicate — copy an existing template as a starting point
4. Estimated session duration — shown live while building
5. Per-exercise notes — optional cue field per exercise
6. Template row polish — duration and muscle dots visible at a glance
7. Weekly muscle coverage in split builder — same panel, weekly totals
8. Easy navigation — clear entry/exit paths, context menus, no dead ends

---

## Non-Goals

- Supersets (separate feature, requires data model changes)
- Auto-progression / weight suggestions (separate feature)
- Template tags or categories
- `targetRPE` UI control in builder (field stored on `TemplateExerciseRecord` but remains hidden in v2)

---

## Architecture

### Renamed / Refactored Components

| Old | New | Change |
|-----|-----|--------|
| `CreateTemplateView` | `TemplateBuilderView` | Accepts optional `existingTemplate` for edit mode |
| `TemplateExerciseEntry` | `TemplateExerciseEntry` | Gains `notes: String = ""` |
| `TemplatesViewModel` | `TemplatesViewModel` | Gains `editTemplate()`, `duplicateTemplate()` |
| `TemplateRow` | `TemplateRow` | Gains duration, muscle dots, context menu |

### New Components

- **`MuscleGroupPanel`** — reusable SwiftUI view; takes `[TemplateExerciseEntry]`, renders live muscle chips
- **`MuscleGroupPanelWeekly`** — variant for split builder; takes `[[TemplateExerciseEntry]]` (one per day)

### Retiring the Flat Tuple onSave

`CreateTemplateView` currently calls `onSave` with a flat named-tuple per exercise. This is replaced:

- `TemplateBuilderView` calls `onSave: (String, [TemplateExerciseEntry]) -> Void`
- `TemplatesViewModel.createTemplate()` and `editTemplate()` both accept `(name: String, exercises: [TemplateExerciseEntry])`
- `TemplateExerciseRequest` (the `Encodable` sent to the backend) is updated to be built from `TemplateExerciseEntry` directly
- The old flat-tuple consumers in `TemplatesViewModel` are fully replaced — no backwards-compat shim

### Backend

- Existing route `PATCH /templates/:id` currently binds to `updateTemplateNameSchema` (name-only). This binding is **replaced** with the new `updateTemplateSchema` that accepts both name and exercises.
- The existing `updateTemplateName()` service method is superseded by `updateTemplate()`.
- Follows existing offline-first pattern: SwiftData updated immediately, backend synced in background.

---

## Feature Details

### 1. Muscle Group Panel

**Location:** Sticky section at the top of `TemplateBuilderView`, above the exercise list section, below the template name field.

**Rendering:**
- Horizontal `ScrollView` of chips: `"{Muscle} · {N} sets"`
- Color coding: `Color.yellow` (1–3 sets), `Color.good` (4+ sets) — `Color.good` already exists in the app's Color extension; `Color.yellow` is the system yellow
- Only muscles with ≥ 1 exercise shown; panel hidden entirely when exercise list is empty

**Canonical muscle group display names (10 groups):**

| Display label | Canonical keys from heuristic / DB |
|---|---|
| Chest | `chest`, `upper_chest`, `lower_chest` |
| Back | `back`, `lats`, `rhomboids`, `traps`, `lower_traps` |
| Shoulders | `shoulders`, `front_delts`, `side_delts`, `rear_delts` |
| Biceps | `biceps`, `brachialis` |
| Triceps | `triceps` |
| Quads | `quads` |
| Hamstrings | `hamstrings` |
| Glutes | `glutes`, `adductors`, `hip_abductors` |
| Core | `core`, `obliques`, `hip_flexors` |
| Calves | `calves` |

`MuscleGroupPanel` normalizes resolved muscle keys to these 10 display labels using a static mapping dictionary. Keys not found in the mapping are silently dropped (they will not appear as chips).

**Muscle resolution (priority order):**
1. Fetch `ExerciseDefinitionRecord` where `id == entry.exerciseID` using `@Environment(\.modelContext)` — `MuscleGroupPanel` receives the model context via the SwiftUI environment (same pattern as `MuscleGroupPanelWeekly`). If a matching record is found, use its `primaryMuscle` string (a canonical key from the table above).
2. `TrainViewModel.muscleGroup(for: exerciseName)` keyword heuristic as fallback (also returns canonical keys; the heuristic already uses simplified names like `"chest"`, `"lats"`, `"quads"`)

**Set counting:** Each `TemplateExerciseEntry` contributes `targetSets` to its resolved display group.

**Split builder variant (`MuscleGroupPanelWeekly`):**
- Placed below the split name field in `CreateSplitView`
- Label: "WEEKLY MUSCLE COVERAGE"
- Receives `@Environment(\.modelContext)` — `CreateSplitView` already has the model context; pass it via the environment so the panel can execute its own `FetchDescriptor<TemplateExerciseRecord>` queries
- For template-linked days: fetches `TemplateExerciseRecord`s from SwiftData filtered by `templateID`
- For direct-exercise days: uses exercise name heuristic on `DayExercise.name`
- Sums sets across all 7 days

---

### 2. Edit Mode

**Entry:**
- Long-press on a `TemplateRow` → context menu with **Edit**, **Duplicate**, **Delete**
- Swipe-to-delete remains as a fast path for deletion

**`TemplateBuilderView` API:**
```swift
TemplateBuilderView(
    existingTemplate: (WorkoutTemplateRecord, [TemplateExerciseRecord])?,
    onSave: (String, [TemplateExerciseEntry]) -> Void
)
```
When `existingTemplate` is non-nil, the view pre-populates `name` and `exercises` state (mapping `TemplateExerciseRecord` → `TemplateExerciseEntry`) and sets `navigationTitle` to the template name instead of "New Template".

**Save path (edit):**
1. Update `WorkoutTemplateRecord.name` in SwiftData
2. Delete all existing `TemplateExerciseRecord`s for this template
3. Insert new `TemplateExerciseRecord`s with updated `orderIndex`
4. Call `context.save()`
5. Background: `PATCH /templates/:id` with full exercise list replacement

**Offline race guard:** Before calling `PATCH /templates/:id`, check whether the template's `id` was ever confirmed by the server. If `WorkoutTemplateRecord` has a flag `serverConfirmed: Bool = false` (set to `true` after a successful POST), skip the PATCH — the template's next POST attempt will carry the full state. If `serverConfirmed` is already `true`, proceed with PATCH normally.

> Note: `serverConfirmed` is a new Bool field on `WorkoutTemplateRecord`. SwiftData auto-migrates defaulted Bool additions the same way it does String ones (relies on no `VersionedSchema` being active — see §Data Model Changes).

**`TemplatesViewModel.editTemplate(id:name:exercises:ownerID:)`** handles steps 1–5.

**`updateTemplate()` service contract (backend):**
- Executes name update + exercise replacement in a single database transaction
- If the template ID does not exist or does not belong to `req.user.id`, return `null` (handler emits 404)
- Return type: `WorkoutTemplate & { exercises: TemplateExercise[] } | null`
- Partial updates: if `name` is omitted, skip the UPDATE on `templates`; if `exercises` is omitted, skip the DELETE + INSERT on `template_exercises`

---

### 3. Duplicate

**Entry:** Context menu → "Duplicate"

**Chosen flow (simpler path):**
1. `TemplatesViewModel.duplicateTemplate(source:)` opens `TemplateBuilderView` pre-populated with source exercises and name `"Copy of {source name}"`
2. No SwiftData record is created until the user taps **Save**
3. On Save, the normal `createTemplate()` path runs — new UUID, new backend POST

This means Duplicate is identical to tapping + and pre-filling. No new record is created until confirmed.

---

### 4. Estimated Duration

**Location:** Footer text below the template name section header, or as a `Section` footer.

**Formula:**
```
estimatedMinutes = exercises.reduce(0) { acc, ex in
    acc + (ex.targetSets * (ex.restSeconds + 45))
} / 60
```
(45 seconds = average time to perform one set)

**Display:** `Estimated · ~{N} min` — updates live as exercises are added, sets changed, or rest times changed. Hidden when no exercises exist.

---

### 5. Per-exercise Notes

**`TemplateExerciseEntry` change:**
```swift
var notes: String = ""
```

**`TemplateExerciseRecord` change:**
```swift
var notes: String = ""
```
Auto-migration note: This relies on the app not using `VersionedSchema` / `SchemaMigrationPlan`. If versioning is added later, a lightweight migration must be written for this field. For v2, no migration plan file is needed.

**UI in `ExerciseEntryRow`:**
- Below the sets/reps/rest stepper row, a tappable `"+ Add note"` text button
- Tapping expands a single `TextField("e.g. Touch chest, keep elbows in…", text: $entry.notes)`
- If notes is non-empty, field shows expanded by default with a small `✕` to clear
- Collapsed state shows `"Note: {preview…}"` in caption style when notes exist

---

### 6. Template Row Polish

**`TemplateRow` additions:**
- **Duration chip:** `~{N} min` shown as a small secondary label next to the exercise count
- **Muscle dots:** Up to 3 colored dots (`Circle().fill(color)`, 6pt) representing the top 3 muscles by set count — computed from `exercises` array using the same heuristic + mapping
- **Context menu:** Long-press reveals Edit / Duplicate / Delete

**Row layout (updated):**
```
[Template Name]                        [Start ▶]
Bench Press, Incline DB, Cable Fly…
●chest ●triceps ●shoulders   3 exercises · ~38 min
```

---

### 7. Navigation & UX

**Principle:** Every action has a visible entry point. No dead ends. Fast paths for common operations.

**Changes:**
- **Template list toolbar:** `+` button stays. No additional clutter.
- **Template row interaction:**
  - Tap → nothing (subtle selection state)
  - Long-press → context menu: Edit / Duplicate / Delete
  - Swipe left → Delete (fast path)
  - Start button → starts session immediately (unchanged)
- **Builder navigation:**
  - Cancel → dismiss with no changes (unchanged for create)
  - Save → dismiss and return to list; **new** template inserted at top of list; **edited** template stays in its current position (sort is `createdAt DESC` — editing does not change `createdAt`)
  - Back swipe (interactive dismiss) disabled while editing to prevent accidental loss
- **Edit confirmation:** If user has made changes and taps Cancel, show a discard confirmation alert: "Discard changes?" with "Discard" (destructive) and "Keep Editing" (cancel). Change detection: compare current `name` and `exercises` against initial values captured on appear.
- **Empty state:** "Create Template" button centered, plus a contextual tip: "Templates let you save a set of exercises to start a workout in one tap."

---

## Data Model Changes

### `TemplateExerciseEntry` (in-memory)
```swift
var notes: String = ""       // new
```

### `TemplateExerciseRecord` (SwiftData)
```swift
var notes: String = ""       // new — auto-migrated (no VersionedSchema)
```

### `WorkoutTemplateRecord` (SwiftData)
```swift
var serverConfirmed: Bool = false  // new — set true after successful POST response; governs PATCH eligibility
```

### `TemplateExerciseResponse` (iOS Decodable — in TemplatesView.swift)
```swift
let notes: String?           // new — populated from backend on sync/load
```
Mapping: when converting `TemplateExerciseResponse` → `TemplateExerciseRecord` in the sync path, write `notes ?? ""`.

### Backend: `TemplateExerciseRequest` (Encodable)
```swift
let notes: String?           // new, optional
```

---

## Backend Changes

### Database Migration: `022_template_exercise_notes.sql`
```sql
ALTER TABLE template_exercises ADD COLUMN notes TEXT;
```

### `packages/elos-shared/src/index.ts`
Add `notes` to the `TemplateExercise` interface:
```typescript
export interface TemplateExercise {
  // ...existing fields...
  notes?: string;
}
```
Also add `notes?: string` to `CreateTemplateBody`'s exercise entry type if that type is defined in shared.

### `PATCH /templates/:id` (replaces existing name-only PATCH)

**Route:** Replace existing `router.patch("/:id", requireAuth, validateBody(updateTemplateNameSchema), handler)` with:
```
router.patch("/:id", requireAuth, validateBody(updateTemplateSchema), handler)
```

**Schema:**
```typescript
export const updateTemplateSchema = z.object({
  name: z.string().min(1).max(200).optional(),
  exercises: z.array(z.object({
    exercise_id: z.string().uuid().nullable().optional(),
    exercise_name: z.string().min(1).max(200),
    order_index: z.number().int().min(0).max(100),
    target_sets: z.number().int().min(1).max(50),
    target_reps: z.string().max(50),
    target_rpe: z.number().min(0).max(10).nullable().optional(),
    rest_seconds: z.number().int().min(0).max(3600),
    notes: z.string().max(500).optional(),
  })).optional(),
});
```

**Handler logic:**
1. Verify template belongs to `req.user.id` — return 404 if not found or not owned
2. Delegate to `updateTemplate(id, userId, { name?, exercises? })`
3. Return updated template with exercises

**`updateTemplate()` service:**
- Executes inside a single transaction
- If `name` provided: `UPDATE templates SET name = $1 WHERE id = $2 AND user_id = $3`
- If `exercises` provided: `DELETE FROM template_exercises WHERE template_id = $1`, then bulk INSERT with columns: `(id, template_id, exercise_id, exercise_name, order_index, target_sets, target_reps, target_rpe, rest_seconds, notes)` — same as `createTemplate()` INSERT plus the new `notes` column
- Returns `WorkoutTemplate & { exercises: TemplateExercise[] } | null`; handler returns 404 if null

---

## File Change Summary

| File | Change |
|------|--------|
| `CreateTemplateView.swift` | Rename → `TemplateBuilderView.swift`; add `existingTemplate` param; add muscle panel; add duration; add notes UI; add discard alert; change `onSave` to struct-based |
| `TemplatesView.swift` | Update to use `TemplateBuilderView`; add context menus; update `TemplateRow`; update `TemplateExerciseResponse` with `notes?`; update sync mapping |
| `TemplatesViewModel` (in TemplatesView.swift) | Add `editTemplate()`, `duplicateTemplate()`; update `createTemplate()` to accept `[TemplateExerciseEntry]`; add `serverConfirmed` write |
| `ElosSchema.swift` | Add `notes: String = ""` to `TemplateExerciseRecord`; add `serverConfirmed: Bool = false` to `WorkoutTemplateRecord` only |
| `CreateSplitView.swift` | Add `MuscleGroupPanelWeekly` below split name |
| `MuscleGroupPanel.swift` | New file — shared panel component + canonical muscle key mapping dict |
| `apps/elos-api/src/routes/templates.ts` | Replace `PATCH /:id` binding: `updateTemplateNameSchema` → `updateTemplateSchema`; replace handler call |
| `apps/elos-api/src/services/templateService.ts` | Add `updateTemplate()` (transactional); supersedes `updateTemplateName()` |
| `apps/elos-api/src/schemas.ts` | Add `updateTemplateSchema`; keep `updateTemplateNameSchema` for reference or delete |
| `apps/elos-api/migrations/022_template_exercise_notes.sql` | New migration: `ALTER TABLE template_exercises ADD COLUMN notes TEXT` |
| `packages/elos-shared/src/index.ts` | Add `notes?: string` to `TemplateExercise` interface and `CreateTemplateBody` exercise type |
