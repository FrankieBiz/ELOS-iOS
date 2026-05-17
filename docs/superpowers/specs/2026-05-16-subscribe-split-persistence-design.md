# Subscribe to Split + Account Persistence — Design Spec

**Date:** 2026-05-16  
**Scope:** Programs tab (subscribe flow), splits backend sync, XP/rank persistence  
**Status:** Draft (rev 6)

---

## Context

The current Programs tab lets users browse library splits and manage their own splits locally. User splits (`UserSplitRecord`, `UserSplitDayRecord`) are SwiftData-only — they are never synced to the backend. If a user reinstalls the app or changes devices, all splits and active-split state are lost. Additionally, the library split detail view (`WorkoutSplitDetailView`) has a "Copy Full Split" CTA that creates a local copy, but there is no subscribe-to-activate flow or weekly muscle target integration.

XP and rank are computed locally from session/set counts that already sync to the backend — so XP and rank are already safe under the current architecture. No backend change is needed for XP/rank; only the recompute-on-load path needs to be confirmed.

---

## Goals

1. **Subscribe to library split** — one tap from `WorkoutSplitDetailView` creates the user's split and sets it active
2. **Weekly muscle targets** — the active split's exercise distribution informs a per-muscle target-sets panel shown in the Programs tab
3. **Splits sync to backend** — create, delete, and activate user splits are durable; survives reinstall/device change
4. **XP/rank on load** — confirmed safe via existing session sync; no backend change, just verify the recompute path is called on login

---

## Non-Goals

- Editing a subscribed split's day content after subscribing (use the existing Edit Split flow)
- Social split sharing or split discovery feeds
- Multi-device real-time sync (eventual consistency via fetch-on-login is sufficient)
- Progress tracking per split day (separate feature)

---

## Architecture

### Subscribe Flow

**Entry point:** `WorkoutSplitDetailView` — replaces "Copy Full Split" primary CTA with **Subscribe** (if the user hasn't subscribed) or **Already Added** (disabled, if a `UserSplitRecord` with matching `libraryKey` exists).

**AppViewModel injection:** `WorkoutSplitDetailView` must add `@EnvironmentObject var vm: AppViewModel`. The view is reached via a `NavigationLink(destination:)` at line 265 in `ProgramsView.swift`; update that call to:
```swift
NavigationLink(destination: WorkoutSplitDetailView(split: split).environmentObject(vm))
```

**Library data model field mapping** (from `WorkoutSplit` / `SplitWorkoutDay`):

| Library field | Maps to |
|---|---|
| `split.title: String` | `UserSplitRecord.name` |
| `split.id: String` | `UserSplitRecord.libraryKey` |
| `day.focus: String` | `UserSplitDayRecord.dayName` |
| `"Day \(orderIndex + 1)"` (synthesized) | `UserSplitDayRecord.dayLabel` |
| `false` (hardcoded) | `UserSplitDayRecord.isRest` (no rest days in library `workouts`) |
| `day.exercises: [SplitExercise]` | `UserSplitDayRecord.exercisesJSON` (see encoding below) |

**`exercisesJSON` encoding:** `SplitExercise` has no stable `id`; generate one at subscribe time:
```swift
// In SplitHelpers.swift (shared):
struct DayExercise: Codable, Identifiable { let id: String; let name: String }

// When subscribing:
DayExercise(id: UUID().uuidString, name: exercise.name)
// Discard prescription — display-only, not used downstream
```

**Subscribe action:**
1. Check SwiftData for existing `UserSplitRecord` where `libraryKey == split.id`
   - If found: alert "You've already added this split. Set it as active?" → "Set Active" deactivates others locally and calls `activateSplitOnServer(serverID:)` only if `record.serverID` is non-empty; "Cancel" dismisses
2. Deactivate all other `UserSplitRecord` locally (`isActive = false`)
3. Create `UserSplitRecord` with all fields including new ones: `libraryKey: split.id, isActive: true, serverID: "", syncPending: true`
4. For each `SplitWorkoutDay` in `split.workouts`, create `UserSplitDayRecord` per mapping above
5. `context.save()`
6. Background `Task`:
   a. Call `pushSplitToServer(record)` → on success write returned server `id` to `record.serverID`, set `syncPending = false`, call `context.save()`
   b. Only if `record.serverID` is now non-empty: call `activateSplitOnServer(serverID: record.serverID)`
   c. On failure: leave `syncPending = true`; login-time scan retries

### `UserSplitRecord` schema additions

```swift
var libraryKey: String = ""      // new
var serverID: String = ""        // new
var syncPending: Bool = false    // new
```

Full updated `init` — preserves all existing parameters:
```swift
init(id: String = UUID().uuidString,
     ownerID: String,
     name: String,
     isActive: Bool = false,
     createdAt: Date = Date(),
     activatedAt: Date? = nil,
     skippedDatesJSON: String = "[]",
     libraryKey: String = "",
     serverID: String = "",
     syncPending: Bool = false)
```

All existing call sites (e.g., `CreateSplitView.saveSplit()`, `setActiveSplit`) remain unaffected — every new parameter is defaulted.

SwiftData auto-migrates the three new defaulted fields (no `VersionedSchema` in use).

### Weekly Muscle Targets Panel

When an active split exists, the Programs tab's "Your Splits" section shows a **Weekly Targets** subsection using `MuscleGroupPanelWeekly`. The component requires three parallel arrays of length 7:

```swift
var dayTemplateIDs = Array(repeating: "", count: 7)
var dayIsRest = Array(repeating: false, count: 7)
var dayExerciseNames = Array(repeating: [String](), count: 7)

for day in activeDays.sorted(by: { $0.orderIndex < $1.orderIndex }) where day.orderIndex < 7 {
    dayTemplateIDs[day.orderIndex] = day.templateID
    dayIsRest[day.orderIndex] = day.isRest
    let exercises = (try? JSONDecoder().decode([DayExercise].self,
                     from: Data(day.exercisesJSON.utf8))) ?? []
    dayExerciseNames[day.orderIndex] = exercises.map { $0.name }
}

MuscleGroupPanelWeekly(
    dayTemplateIDs: dayTemplateIDs,
    dayIsRest: dayIsRest,
    dayExerciseNames: dayExerciseNames
)
```

`DayExercise` is promoted to `SplitHelpers.swift` (see below). The private `ExInfo: Codable` struct in `AppViewModel.prepareExercises(for:)` decodes the same `exercisesJSON` format — replace `ExInfo` with `DayExercise` when making this change so there is one canonical type.

---

## Data Model Changes

### `UserSplitRecord` (SwiftData)

```swift
var libraryKey: String = ""      // new
var serverID: String = ""        // new
var syncPending: Bool = false    // new
```

### `UserSplitDayRecord` (SwiftData)

No changes.

---

## Backend Changes

### New DB Tables

**Migration: `023_user_splits.sql`**

(Migration `022_template_exercise_notes.sql` is reserved by the template builder v2 spec.)

```sql
CREATE TABLE user_splits (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  name        TEXT NOT NULL,
  library_key TEXT NOT NULL DEFAULT '',
  is_active   BOOLEAN NOT NULL DEFAULT FALSE,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE user_split_days (
  id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  split_id       UUID NOT NULL REFERENCES user_splits(id) ON DELETE CASCADE,
  order_index    INTEGER NOT NULL,
  day_label      TEXT NOT NULL,
  day_name       TEXT NOT NULL,
  template_id    TEXT NOT NULL DEFAULT '',
  is_rest        BOOLEAN NOT NULL DEFAULT FALSE,
  exercises_json TEXT NOT NULL DEFAULT '[]'
);

CREATE INDEX ON user_splits(user_id);
CREATE INDEX ON user_split_days(split_id);

-- Prevent duplicate library splits per user
CREATE UNIQUE INDEX ON user_splits(user_id, library_key) WHERE library_key <> '';
```

On duplicate subscribe (same `library_key`, same user): PG raises `23505` → handler emits `409 { conflict: true, existing_id: "<uuid>" }`.

### New Routes: `apps/elos-api/src/routes/splits.ts`

```
POST   /splits                    Create split + days
GET    /splits                    List user's splits with days
DELETE /splits/:id                Delete split (cascade deletes days)
PATCH  /splits/:id/activate       Set split as active (deactivates others in transaction)
```

**`POST /splits`** body (`createSplitSchema`):
```typescript
z.object({
  name: z.string().min(1).max(200),
  library_key: z.string().max(100).optional(),
  days: z.array(z.object({
    order_index: z.number().int().min(0).max(6),
    day_label: z.string().max(30),
    day_name: z.string().max(200),
    template_id: z.string().max(100).optional(),
    is_rest: z.boolean(),
    exercises_json: z.string().max(2000),   // per-day cap keeps payload under 32 kb body-parser limit
  })).max(7),
})
```

Response (201): `UserSplit` object with `days` included.  
Response (409): `{ conflict: true, existing_id: string }` on unique-key violation.

**`GET /splits`** response (200): `UserSplit[]`

Two-query approach — guard against empty split list to avoid pg type-inference error on `ANY($1)`:
```typescript
const splits = await db.query(
  'SELECT * FROM user_splits WHERE user_id = $1 ORDER BY created_at DESC', [userId]);
if (splits.rows.length === 0) return [];
const days = await db.query(
  'SELECT * FROM user_split_days WHERE split_id = ANY($1) ORDER BY split_id, order_index',
  [splits.rows.map(s => s.id)]);
return splits.rows.map(s => ({ ...s, days: days.rows.filter(d => d.split_id === s.id) }));
```

**`DELETE /splits/:id`**: verifies `user_id` ownership, deletes, returns `204 No Content` (`res.status(204).send()`). iOS must call `deleteNoContent(path:)`, not `delete<R: Decodable>` (which requires a decodable body).

**`PATCH /splits/:id/activate`** — two-UPDATE transaction using a checked-out pg pool client (not two independent `db.query()` calls, which do not share a transaction):
```typescript
const client = await pool.connect();
try {
  await client.query('BEGIN');
  await client.query('UPDATE user_splits SET is_active = FALSE WHERE user_id = $1', [userId]);
  const { rows } = await client.query(
    'UPDATE user_splits SET is_active = TRUE WHERE id = $1 AND user_id = $2 RETURNING *',
    [splitId, userId]);
  await client.query('COMMIT');
  return rows[0] ?? null;  // null → handler emits 404
} catch (e) {
  await client.query('ROLLBACK');
  throw e;
} finally {
  client.release();
}
```
Response (200): full `UserSplit` object with `days` (second query to fetch days after commit). iOS `activateSplitOnServer` decodes this as `UserSplitResponse`. Returns 404 if `rows[0]` is undefined.

### Service: `apps/elos-api/src/services/splitService.ts`

- `createSplit(userId, payload)` — transaction: insert `user_splits` + `user_split_days`; on `23505`, return `{ conflict: true, existingId }` to handler
- `getUserSplits(userId)` — two-query approach with empty-list guard (see above)
- `deleteSplit(userId, splitId)` — verifies ownership, deletes, returns void
- `activateSplit(userId, splitId)` — two-UPDATE BEGIN/COMMIT transaction; returns updated `UserSplit` with days

### `packages/elos-shared/src/index.ts`

```typescript
export interface UserSplit {
  id: string;
  user_id: string;
  name: string;
  library_key: string;
  is_active: boolean;
  created_at: string;
  days: UserSplitDay[];
}

export interface UserSplitDay {
  id: string;
  split_id: string;
  order_index: number;
  day_label: string;
  day_name: string;
  template_id: string;
  is_rest: boolean;
  exercises_json: string;
}
```

---

## iOS Sync Layer

### New file: `SplitHelpers.swift`

```swift
// Internal (default access) — usable from ProgramsView, CreateSplitView, AppViewModel
struct DayExercise: Codable, Identifiable {
    let id: String
    let name: String
}
```

Remove the `private struct DayExercise` from `CreateSplitView.swift`. Replace `private struct ExInfo: Codable` in `AppViewModel.prepareExercises(for:)` with `DayExercise`.

### New file: `Networking/SplitModels.swift`

```swift
struct UserSplitResponse: Decodable {
    let id: String
    let name: String
    let library_key: String
    let is_active: Bool
    let created_at: String
    let days: [UserSplitDayResponse]
}

struct UserSplitDayResponse: Decodable {
    let id: String
    let split_id: String
    let order_index: Int
    let day_label: String
    let day_name: String
    let template_id: String
    let is_rest: Bool
    let exercises_json: String
}

struct SplitConflictResponse: Decodable {
    let conflict: Bool
    let existing_id: String   // snake_case matches JSON key exactly
}
```

### `ApiClient.swift` addition

```swift
func deleteNoContent(path: String) async throws {
    // Build the authenticated request via the existing makeRequest helper
    // (same pattern as delete<R: Decodable> — auth is injected by makeRequest, NOT a bare `token` variable)
    let request = try await makeRequest(method: "DELETE", path: path)
    let (_, response) = try await URLSession.shared.data(for: request)
    guard (response as? HTTPURLResponse)?.statusCode == 204 else {
        // Use an existing ApiError case — add `.unexpectedStatus` to the ApiError enum
        // if it doesn't exist, or reuse `.httpError(statusCode, "Expected 204")`
        throw ApiError.httpError((response as? HTTPURLResponse)?.statusCode ?? 0, "Expected 204 No Content")
    }
    // Returns Void — does NOT call perform<R: Decodable>
}
```

Key implementation notes:
- Call `makeRequest(method:path:)` (not a bare `URLRequest`) so auth headers are injected correctly — `ApiClient` retrieves the access token asynchronously from Supabase; there is no stored `token` property
- Do not call `perform<R: Decodable>` — it always decodes a response body and will throw on the empty 204 response
- `deleteSplitOnServer` must call `deleteNoContent`, not `delete<R: Decodable>`

### `AppViewModel` additions

```swift
func syncSplitsFromServer() async
func pushSplitToServer(_ record: UserSplitRecord) async
func deleteSplitOnServer(serverID: String) async
func activateSplitOnServer(serverID: String) async   // decodes UserSplitResponse
```

**Call site:** add `Task { await syncSplitsFromServer() }` at the end of `loadForUser(id:)`, after `loadActiveSplit()`.

All `@Published` property mutations inside `syncSplitsFromServer()` must be wrapped in `await MainActor.run { ... }`, matching the pattern in `syncCanvas`.

**`syncSplitsFromServer()` logic:**
1. `GET /splits` → `[UserSplitResponse]`
2. For each response split:
   a. Find matching local record: first by `serverID == response.id`, then by `libraryKey == response.library_key && !libraryKey.isEmpty`
   b. If found: update `name`, `isActive`, `serverID`, `syncPending = false`. For each day, compare existing `exercisesJSON` string — only delete + re-insert if the content differs, to avoid wiping user edits made via the Edit Split flow
   c. If not found: create `UserSplitRecord` + `UserSplitDayRecord`s from response
3. `context.save()`
4. On the main actor: call `loadActiveSplit()` so the UI immediately reflects the synced active split state (without this, `activeSplit`/`activeSplitDays` remain stale from the pre-sync `loadForUser` call)
5. Pending-push scan: find all `UserSplitRecord` where `syncPending == true && serverID.isEmpty` (the `serverID.isEmpty` guard prevents a race with an in-flight subscribe `Task` that already successfully pushed and set `serverID`). Push each via `pushSplitToServer(_:)` in sequence

**Offline-push deduplication:** if `pushSplitToServer` receives 409, decode `SplitConflictResponse`, write `existing_id` → `record.serverID`, set `syncPending = false`.

---

## XP / Rank Persistence (Confirmation)

XP = sessions × 50 + sets × 5 + PRs × 100. Sessions and sets already sync. PRs are derived from set records. Fully recoverable on any device.

**Verification task:** Confirm `AppViewModel` calls `recomputeXP()` after `syncSessionsFromServer()` completes. If not, add the call there.

---

## File Change Summary

| File | Change |
|------|--------|
| `ElosSchema.swift` | Add `libraryKey`, `serverID`, `syncPending` to `UserSplitRecord` with defaults; update full `init` signature |
| `WorkoutSplitDetailView.swift` | Add `@EnvironmentObject var vm: AppViewModel`; replace "Copy Full Split" with Subscribe / Already Added; duplicate guard alert; subscribe action |
| `ProgramsView.swift` | Chain `.environmentObject(vm)` on `WorkoutSplitDetailView` `NavigationLink`; add Weekly Targets panel using `MuscleGroupPanelWeekly` |
| `SplitHelpers.swift` (new) | `DayExercise: Codable, Identifiable` — shared internal struct |
| `CreateSplitView.swift` | Remove `private struct DayExercise` (moved to `SplitHelpers.swift`) |
| `AppViewModel.swift` | Replace `ExInfo` with `DayExercise`; add sync methods; call `syncSplitsFromServer()` in `loadForUser`; `@MainActor` dispatch for `@Published` mutations |
| `Networking/SplitModels.swift` (new) | `UserSplitResponse`, `UserSplitDayResponse`, `SplitConflictResponse` |
| `ApiClient.swift` | Add `deleteNoContent(path:)` for 204 responses |
| `apps/elos-api/src/routes/splits.ts` (new) | POST, GET, DELETE, PATCH activate |
| `apps/elos-api/src/services/splitService.ts` (new) | `createSplit`, `getUserSplits`, `deleteSplit`, `activateSplit` |
| `apps/elos-api/src/routes/index.ts` | Register `/splits` router |
| `apps/elos-api/migrations/023_user_splits.sql` (new) | `user_splits` + `user_split_days` tables + partial unique index |
| `packages/elos-shared/src/index.ts` | Add `UserSplit` (with `user_id`), `UserSplitDay` interfaces |
