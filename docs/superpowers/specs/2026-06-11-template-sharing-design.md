# Template Sharing Design

**Date:** 2026-06-11  
**Status:** Approved  

## Problem

Users want to share workout templates with friends via text message. The recipient should be able to tap a link, preview the template, and copy it into their own library.

## Scope

- Share a template from the templates list via a swipe action
- Generate a short deep link suitable for iMessage/SMS
- Recipient opens link → sees import sheet → copies template into their library
- Recipient must already have Elos installed

Out of scope: web preview for non-app users, link expiry, share analytics, feed posting of templates.

---

## Backend

### Database Migration

New table `template_shares`:

```sql
CREATE TABLE template_shares (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  template_id  UUID NOT NULL REFERENCES workout_templates(id) ON DELETE CASCADE,
  owner_id     UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  share_code   TEXT NOT NULL UNIQUE,
  payload_json JSONB NOT NULL,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (template_id, owner_id)
);
```

`UNIQUE` constraints create indexes automatically — no extra `CREATE INDEX` needed.

`payload_json` snapshots the template and exercises at first-share time. If the owner edits or deletes their template afterward, the shared link still resolves to the original snapshot. **Re-sharing an edited template is not supported** — the same share code is returned on every subsequent call. Users wanting to share an updated version must delete and recreate the template.

### New Endpoints

#### `POST /templates/:id/share` (auth required)

- Validates the template belongs to the authenticated user
- Generates an 8-char alphanumeric `share_code` via `crypto.randomBytes`; retries once on the rare unique-constraint collision
- Performs a single atomic CTE upsert (no race condition):

```sql
WITH ins AS (
  INSERT INTO template_shares (template_id, owner_id, share_code, payload_json)
  VALUES ($1, $2, $3, $4)
  ON CONFLICT (template_id, owner_id) DO NOTHING
  RETURNING share_code
)
SELECT share_code FROM ins
UNION ALL
SELECT share_code FROM template_shares WHERE template_id = $1 AND owner_id = $2
LIMIT 1;
```

- Response: `{ shareCode: string }`

#### `GET /templates/shared/:code` (no auth)

- **Must be registered before any `/:id` wildcard route** in `templates.ts` to avoid Express matching the literal string "shared" as an id
- JOINs `users` to resolve `first_name || ' ' || last_name` as `owner_name`
- Returns `SharedTemplate` payload
- 404 if code not found (record is removed by `ON DELETE CASCADE` when template is deleted)

### Service: `templateService.ts`

Two new methods:

```typescript
shareTemplate(templateId: string, userId: string): Promise<{ shareCode: string }>
getSharedTemplate(shareCode: string): Promise<SharedTemplate>
```

### Schema fix: `schemas.ts`

`exercise_id` in the `CreateTemplateBody` Zod schema currently uses `.optional()` which rejects `null`. The shared TypeScript type already declares `exercise_id: string | null`, so this is a pre-existing mismatch. Fix:

```typescript
// before
exercise_id: z.string().uuid().optional(),
// after
exercise_id: z.string().uuid().nullish(),
```

---

## Shared Types (`packages/elos-shared`)

All field names use `snake_case` matching the existing convention in this package.

```typescript
export interface SharedTemplateExercise {
  exercise_name: string;
  exercise_id: string | null;
  order_index: number;
  target_sets: number;
  target_reps: string;          // e.g. "8-10"
  target_rpe: number | null;
  rest_seconds: number;
  notes: string | null;
  equipment_id: string | null;
  equipment_dedupe_key: string | null;
  equipment_brand_name: string | null;
}

export interface SharedTemplate {
  share_code: string;
  owner_name: string;           // first_name || ' ' || last_name from users table
  template_name: string;
  exercises: SharedTemplateExercise[];
}

export interface ShareTemplateResponse {
  shareCode: string;
}
```

`SharedTemplateExercise` mirrors `Omit<TemplateExercise, "id" | "template_id">` so iOS can pass `template.exercises` directly to `CreateTemplateBody.exercises`.

---

## iOS

### Swipe Action on Template Row

In `TemplatesView.swift`, add a trailing swipe action on each template row:

- Label: "Share", system image: `square.and.arrow.up`
- Tapping calls `viewModel.shareTemplate(id:)` which:
  1. POSTs to `/templates/:id/share`
  2. Constructs `"elos://template?code=\(shareCode)"`
  3. Presents `UIActivityViewController` with the URL and subject `"Check out my workout on Elos"`
- Spinner during the network call; `.alert` on error

### Deep Link Handler (`ElosApp.swift`)

The existing `onOpenURL` handler uses a `guard` that returns early unless `url.host == "add-friend"`. Refactor to a `switch` on `url.host` so both link types are handled in the single `.onOpenURL` modifier:

```swift
.onOpenURL { url in
    guard url.scheme == "elos",
          let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
    else { return }

    switch url.host {
    case "add-friend":
        if let userId = components.queryItems?.first(where: { $0.name == "userId" })?.value,
           !userId.isEmpty {
            viewModel.pendingFriendInviteUserId = userId
        }
    case "template":
        if let code = components.queryItems?.first(where: { $0.name == "code" })?.value,
           !code.isEmpty {
            viewModel.pendingTemplateShareCode = code
        }
    default:
        break
    }
}
```

### `AppViewModel` Changes

Add `pendingTemplateShareCode: String?` alongside the existing `pendingFriendInviteUserId`.

### `TemplateShareTarget` Wrapper

`String` is not `Identifiable`. Use a stable wrapper — identity is the `shareCode` itself, not a newly generated UUID (which would cause sheet flicker on re-renders):

```swift
struct TemplateShareTarget: Identifiable {
    let shareCode: String
    var id: String { shareCode }
}
```

Sheet binding (matches existing `FriendInviteSheet` pattern):

```swift
.sheet(item: Binding(
    get: { viewModel.pendingTemplateShareCode.map { TemplateShareTarget(shareCode: $0) } },
    set: { if $0 == nil { viewModel.pendingTemplateShareCode = nil } }
)) { target in
    TemplateImportSheet(shareCode: target.shareCode)
}
```

### `TemplateImportViewModel`

All network logic lives here per MVVM rules.

State machine — single `ImportState` enum (no separate `isLoading` flag):

```swift
enum ImportState {
    case fetchingTemplate
    case idle(SharedTemplateResponse)
    case importing
    case success
    case error(String)
}
```

Methods:
- `fetchTemplate(shareCode: String)` — sets state to `.fetchingTemplate`, GETs `/templates/shared/:code`, transitions to `.idle(template)` or `.error`
- `importTemplate()` — sets state to `.importing`, POSTs `/templates` with `CreateTemplateBody` built from snapshot exercises, transitions to `.success` or `.error`

### `TemplateImportSheet`

Pure view driven entirely by `TemplateImportViewModel`.

States:
- `.fetchingTemplate` → skeleton placeholder rows
- `.idle(template)` → owner name header, template name (large title), scrollable exercise list (name + sets×reps + RPE if set), "Copy to My Templates" button, "Dismiss" button
- `.importing` → "Copy to My Templates" shows spinner, disabled
- `.success` → dismisses sheet (clears `pendingTemplateShareCode`)
- `.error` → inline message; if the error is a 404, show "This template is no longer available"; otherwise show a generic retry prompt

---

## Data Flow

```
[User] swipe "Share" on template row
    → POST /templates/:id/share
    ← { shareCode: "a1b2c3d4" }
    → iOS share sheet: "elos://template?code=a1b2c3d4"
    → user sends via iMessage

[Friend] taps link
    → iOS opens Elos via elos:// scheme
    → onOpenURL sets pendingTemplateShareCode = "a1b2c3d4"
    → TemplateImportSheet appears
    → GET /templates/shared/a1b2c3d4 (no auth)
    ← SharedTemplate
    → friend taps "Copy to My Templates"
    → POST /templates with CreateTemplateBody from snapshot
    → template added to friend's library
```

---

## Files Changed

| File | Change |
|------|--------|
| `migrations/035_create_template_shares.sql` | New `template_shares` table |
| `apps/elos-api/src/schemas.ts` | `exercise_id: z.string().uuid().nullish()` |
| `apps/elos-api/src/services/templateService.ts` | `shareTemplate()`, `getSharedTemplate()` |
| `apps/elos-api/src/routes/templates.ts` | `POST /:id/share`, `GET /shared/:code` (before `/:id`) |
| `packages/elos-shared/src/index.ts` | `SharedTemplateExercise`, `SharedTemplate`, `ShareTemplateResponse` |
| `TemplatesView.swift` | Trailing swipe action + `UIActivityViewController` |
| `TemplateImportSheet.swift` | New view |
| `TemplateImportViewModel.swift` | New view model |
| `AppViewModel.swift` | `pendingTemplateShareCode: String?` |
| `ElosApp.swift` | `onOpenURL` refactored to `switch url.host`; `TemplateShareTarget` wrapper; `.sheet(item:)` binding |
