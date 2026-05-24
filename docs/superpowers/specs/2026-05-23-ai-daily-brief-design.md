# AI Daily Brief — Design Spec

**Date:** 2026-05-23
**Status:** Approved

---

## Goal

Add a personalized, AI-generated 2–3 sentence daily brief to the top of the Today tab. The brief synthesizes sleep quality, readiness, training load, and academic deadlines into an actionable morning summary — making Elos feel like it actually knows the user's day.

---

## Problem

The Today tab already surfaces all the right data (sleep, habits, schedule, assignments, readiness) but each piece is siloed. Users have to mentally connect "I slept 5 hours + I have an exam tomorrow + leg day is scheduled" themselves. The brief does that work for them.

---

## Architecture

### Overview

Sleep records, assignments, and exams are SwiftData-only (no server tables — they're Canvas-synced on-device). The server owns readiness check-ins, workout sessions, active split, and the user profile. The endpoint is therefore a `POST` that receives the client-side context in the request body and merges it with the server-side context before calling DeepSeek.

```
iOS (TodayView)
  → AppViewModel.loadTodayBrief()
    → check AiBriefRecord in SwiftData (ownerID == uid && logDate == today)
      → if exists: publish cached record
      → if absent:
          → build BriefClientContext from SwiftData (sleep, assignments, exams)
          → POST /ai/brief  { client_context: { ... } }
              → BriefService (Node) fetches server context from DB
                  (readiness, sessions, active split, profile)
              → merges with client_context
              → builds prompt, calls DeepSeek Chat API
              → parses MOOD tag, strips from brief_text
              → stores result in ai_briefs table (UNIQUE user_id, date)
              → returns { id, date, brief_text, mood, generated_at }
            → save AiBriefRecord to SwiftData (logDate = resp.date)
            → publish record
```

### Caching strategy

- **Server-side:** One row in `ai_briefs` per (`user_id`, `date`). `POST /ai/brief` returns the cached row if one exists for today's UTC date. `force=true` query param bypasses the cache and regenerates.
- **Client-side:** `AiBriefRecord` in SwiftData. `logDate` is taken from the server response's `date` field (not computed locally) to avoid UTC/timezone mismatch.
- Result: DeepSeek is called **at most once per user per day** unless the user taps "Refresh".

---

## Backend

### New files

| Path | Responsibility |
|---|---|
| `src/routes/ai.ts` | `POST /ai/brief` — auth-gated endpoint |
| `src/services/aiService.ts` | Merges client context with DB context, builds prompt, calls DeepSeek, persists result |
| `src/lib/deepseek.ts` | Thin wrapper around DeepSeek Chat Completions API |

### Migration

```sql
-- migrations/024_ai_briefs.sql
CREATE TABLE IF NOT EXISTS ai_briefs (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  date        DATE NOT NULL,
  brief_text  TEXT NOT NULL,
  mood        TEXT NOT NULL CHECK (mood IN ('positive', 'cautious', 'alert')),
  generated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (user_id, date)
);
```

### `POST /ai/brief`

**Auth:** `requireAuth` middleware (same as all other routes)

**Request body:**
```json
{
  "client_context": {
    "sleep": { "hours": 6.5, "quality": 3 },
    "assignments": [{ "name": "Problem Set 3", "subject": "Chem", "isUrgent": true, "dueIn": "18h" }],
    "exams": [{ "subject": "Chemistry", "title": "Midterm 2", "daysUntil": 1 }]
  },
  "force": false
}
```
All `client_context` fields are optional. `force` replaces the old query param.

**Query params:**
- ~~`force=true`~~ — use `force: true` in the request body instead

**Response:**
```json
{
  "id": "uuid",
  "date": "2026-05-23",
  "brief_text": "You slept 5.5 hrs and rated energy 2/5 — keep today's chest session but trim one set per exercise. Chem exam in 18 hours: protect tonight and skip any late training.",
  "mood": "cautious",
  "generated_at": "2026-05-23T07:14:22Z"
}
```

**Error response (API failure):**
```json
{ "error": "brief_unavailable" }
```
The iOS client handles this gracefully — the card simply doesn't render.

### `aiService.ts` — context assembly

The service receives `client_context` (sleep, assignments, exams) from the iOS POST body and fetches the rest from the database:

**From DB (server owns):**
1. Profile (first name)
2. Today's readiness check-in (sleep quality, soreness, stress, motivation, overall score) — may be absent
3. Last 7 days of workout sessions (count, total volume, avg RPE)
4. Active split + today's planned day name

**From `client_context` POST body (SwiftData-only, no server tables):**
5. Last night's sleep record (duration, quality) — `client_context.sleep`
6. Assignments due in next 48 hours — `client_context.assignments`
7. Exams in next 7 days — `client_context.exams`

**MOOD parsing** (done server-side before storing):

```typescript
function parseMoodAndBrief(raw: string): { briefText: string; mood: string } {
  const moodMatch = raw.match(/MOOD:\s*(positive|cautious|alert)/i);
  const mood = moodMatch ? moodMatch[1].toLowerCase() : "cautious";
  const briefText = raw.replace(/\n?MOOD:\s*(positive|cautious|alert)\s*$/i, "").trim();
  return { briefText, mood };
}
```

The tag is stripped from `brief_text` before storage. If the model omits the tag (truncated output, format drift), mood defaults to `"cautious"`.

### Prompt template

```
You are a concise performance coach for a student-athlete named {firstName}.

Today's data:
- Sleep last night: {sleepHours}h, quality {sleepQuality}/5
- Readiness check-in: {readinessScore}/5 — sleep {sleepQ}, soreness {sorenessQ}, stress {stressQ}, motivation {motivationQ}
  (or "No check-in logged yet")
- Today's planned workout: {splitDayName} (or "No active split")
- Training this week: {sessionCount} sessions, {totalVolumeKg}kg total volume, avg RPE {avgRPE}
- Upcoming deadlines (48h): {deadlineList or "None"}
- Upcoming exams (7 days): {examList or "None"}

Write exactly 2 sentences. Sentence 1: a direct observation about physical readiness and today's training. Sentence 2: a note about academic or schedule pressure today. Be practical and direct — no fluff, no exclamation points.
On a new final line write: MOOD: positive|cautious|alert
```

**Mood rules** (advisory — model output is authoritative):
- `positive` — readiness ≥ 4 AND no urgent deadlines in 24h
- `cautious` — readiness 2–3 OR deadline in 24h
- `alert` — readiness ≤ 1 OR exam in 24h

### `deepseek.ts`

```typescript
export async function callDeepSeek(prompt: string): Promise<string> {
  const res = await fetch("https://api.deepseek.com/chat/completions", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${process.env.DEEPSEEK_API_KEY}`,
    },
    body: JSON.stringify({
      model: "deepseek-chat",
      messages: [{ role: "user", content: prompt }],
      max_tokens: 150,
      temperature: 0.5,
    }),
  });
  if (!res.ok) throw new Error(`DeepSeek API error: ${res.status}`);
  const data = await res.json();
  const content = data.choices?.[0]?.message?.content;
  if (!content) throw new Error("DeepSeek returned no choices");
  return content as string;
}
```

### Rate-limiting

A dedicated `briefLimiter` defined and applied inside `routes/ai.ts`, keyed per user (not per IP). It runs **after** `requireAuth` on the same route so `req.user.id` is populated when `keyGenerator` fires. See `### routes/ai.ts — auth and rate-limit pattern` below for the exact code.

### `lib/env.ts` — exact change

```typescript
const REQUIRED_VARS = [
  "SUPABASE_URL",
  "SUPABASE_SERVICE_ROLE_KEY",
  "DEEPSEEK_API_KEY",          // ← add this line
] as const;
```

### `index.ts` additions (exact changes)

`rateLimit` is already imported via `import rateLimit from "express-rate-limit"` — do **not** add a second import. `requireAuth` is **not** imported in `index.ts` (the established pattern is to import it per-route inside each route file). The `briefLimiter` and `requireAuth` are both applied inside `routes/ai.ts` — see that section.

```typescript
// 1. Add alongside other route imports:
import aiRouter from "./routes/ai";

// 2. Register route alongside other app.use registrations (no extra middleware here):
app.use("/ai", aiRouter);
```

### `routes/ai.ts` — auth and rate-limit pattern

`briefLimiter` is defined locally in `routes/ai.ts` and applied **after** `requireAuth` on the route so `keyGenerator` can read `req.user.id`. This follows the same per-route middleware pattern used in all other route files.

```typescript
import rateLimit from "express-rate-limit";
import { requireAuth } from "../middleware/auth";

const briefLimiter = rateLimit({
  windowMs: 60 * 60 * 1000, // 1 hour
  limit: 5,
  keyGenerator: (req) => (req as any).user?.id ?? req.ip,
  standardHeaders: "draft-7",
  legacyHeaders: false,
});

router.post("/brief", requireAuth, briefLimiter, async (req, res) => {
  // handler body — see aiService.ts section
});
```

---

## iOS

### New files

| Path | Responsibility |
|---|---|
| `Features/Today/AiBriefRecord.swift` | SwiftData `@Model` — local cache. Lives alongside its feature code (not in `ElosSchema.swift`) |
| `Features/Today/AiBriefService.swift` | `struct` with static fetch method + response type |
| `Features/Today/DailyBriefCard.swift` | SwiftUI card shown in TodayView |

> `AiBriefRecord` is defined in its own file rather than in `ElosSchema.swift` because it belongs to the Today feature module. It still must be added to the `Schema([…])` array in `ElosApp.swift` like every other `@Model`.

### `AiBriefRecord` (SwiftData)

```swift
@Model
final class AiBriefRecord {
    var id: String
    var ownerID: String
    var logDate: String        // "yyyy-MM-dd" — taken from server response, not computed locally
    var briefText: String
    var mood: String           // "positive" | "cautious" | "alert"
    var generatedAt: Date

    init(id: String = UUID().uuidString, ownerID: String,
         logDate: String, briefText: String, mood: String,
         generatedAt: Date = Date()) {
        self.id          = id
        self.ownerID     = ownerID
        self.logDate     = logDate
        self.briefText   = briefText
        self.mood        = mood
        self.generatedAt = generatedAt
    }
}
```

**`ElosApp.swift` schema array** — add `AiBriefRecord.self` to the `Schema([...])` call:

```swift
let schema = Schema([
    // ... existing models ...
    AiBriefRecord.self,   // ← add this line
])
```

### `AiBriefService`

```swift
struct AiBriefResponse: Decodable {
    let id: String
    let date: String           // "yyyy-MM-dd" UTC — use as SwiftData logDate key
    let brief_text: String
    let mood: String
    let generated_at: String   // ISO8601 string — converted to Date via ISO8601DateFormatter in AppViewModel
}

// Encodable structs for the POST body — built from SwiftData in AppViewModel before calling fetchBrief
struct BriefSleepContext: Encodable {
    let hours: Double
    let quality: Int           // 1–5
}

struct BriefAssignmentContext: Encodable {
    let name: String
    let subject: String
    let isUrgent: Bool
    let dueIn: String          // forwarded from AssignmentRecord.dueString (Canvas-formatted, e.g. "Tomorrow 11:59 PM")
}

struct BriefExamContext: Encodable {
    let subject: String
    let title: String
    let daysUntil: Int
}

struct BriefClientContext: Encodable {
    let sleep: BriefSleepContext?
    let assignments: [BriefAssignmentContext]
    let exams: [BriefExamContext]
}

struct BriefRequest: Encodable {
    let client_context: BriefClientContext
    let force: Bool
}

struct AiBriefService {
    static func fetchBrief(context: BriefClientContext, force: Bool = false) async throws -> AiBriefResponse {
        let body = BriefRequest(client_context: context, force: force)
        return try await ApiClient.shared.post("/ai/brief", body: body)
    }
}
```

`ownerID` is not passed as a parameter — the backend resolves the user from the auth token. `AppViewModel` builds `BriefClientContext` from SwiftData (fetching today's sleep record, assignments due in 48h, and exams in 7 days) before calling `AiBriefService.fetchBrief`.

### `AppViewModel` additions

```swift
@Published var todayBrief: AiBriefRecord? = nil
@Published var briefLoading: Bool = false

func loadTodayBrief() {
    guard !currentUserID.isEmpty else { return }
    let uid = currentUserID
    let fmt = DateFormatter(); fmt.dateFormat = "yyyy-MM-dd"
    let today = fmt.string(from: Date())
    // Predicate includes date to avoid full-table scan accumulation over time
    let desc = FetchDescriptor<AiBriefRecord>(
        predicate: #Predicate { $0.ownerID == uid && $0.logDate == today }
    )
    if let cached = (try? context.fetch(desc))?.first {
        todayBrief = cached
        return
    }
    briefLoading = true
    Task { @MainActor in
        defer { briefLoading = false }
        let clientCtx = buildBriefClientContext(uid: uid)
        guard let resp = try? await AiBriefService.fetchBrief(context: clientCtx) else { return }
        // Use server's date field as logDate key (avoids UTC/timezone mismatch)
        let iso = ISO8601DateFormatter()
        let generatedAt = iso.date(from: resp.generated_at) ?? Date()
        let record = AiBriefRecord(
            id: resp.id, ownerID: uid, logDate: resp.date,
            briefText: resp.brief_text, mood: resp.mood,
            generatedAt: generatedAt
        )
        context.insert(record)
        try? context.save()
        todayBrief = record
    }
}

// Builds BriefClientContext from SwiftData — called before every POST /ai/brief.
// Uses exact ElosSchema.swift property names:
//   SleepRecord: ownerID, duration (Double), quality (Int)
//   AssignmentRecord: ownerID, isDone (Bool), isUrgent (Bool), name, subject, dueString (String)
//   ExamRecord: ownerID, daysAway (Int), subject, title
private func buildBriefClientContext(uid: String) -> BriefClientContext {
    // Sleep: most recent record — SleepRecord.logDate is Date, sort descending
    var sleepDesc = FetchDescriptor<SleepRecord>(
        predicate: #Predicate { $0.ownerID == uid },
        sortBy: [SortDescriptor(\.logDate, order: .reverse)]
    )
    sleepDesc.fetchLimit = 1
    let latestSleep = (try? context.fetch(sleepDesc))?.first
    let sleepCtx: BriefSleepContext? = latestSleep.map {
        BriefSleepContext(hours: $0.duration, quality: $0.quality)
    }

    // Assignments: all non-done; isUrgent is Canvas-computed and serves as the "due soon" signal
    let assignDesc = FetchDescriptor<AssignmentRecord>(
        predicate: #Predicate { $0.ownerID == uid && $0.isDone == false }
    )
    let assignments = (try? context.fetch(assignDesc)) ?? []
    let assignCtx = assignments.map { a in
        BriefAssignmentContext(name: a.name, subject: a.subject,
                               isUrgent: a.isUrgent, dueIn: a.dueString)
    }

    // Exams: daysAway is pre-computed by Canvas sync; 0–7 captures this week
    let examDesc = FetchDescriptor<ExamRecord>(
        predicate: #Predicate { $0.ownerID == uid && $0.daysAway >= 0 && $0.daysAway <= 7 }
    )
    let exams = (try? context.fetch(examDesc)) ?? []
    let examCtx = exams.map { e in
        BriefExamContext(subject: e.subject, title: e.title, daysUntil: e.daysAway)
    }

    return BriefClientContext(sleep: sleepCtx, assignments: assignCtx, exams: examCtx)
}

func refreshBrief() {
    guard !currentUserID.isEmpty, !briefLoading else { return }  // guard double-tap
    let uid = currentUserID
    briefLoading = true
    Task { @MainActor in
        defer { briefLoading = false }
        let clientCtx = buildBriefClientContext(uid: uid)
        guard let resp = try? await AiBriefService.fetchBrief(context: clientCtx, force: true) else { return }
        // Delete ALL existing briefs for this user before inserting the refreshed one.
        // Keying by resp.date would miss a prior-day record if the user crosses midnight
        // without relaunching — deleting by ownerID prevents stale accumulation.
        let staleDesc = FetchDescriptor<AiBriefRecord>(
            predicate: #Predicate { $0.ownerID == uid }
        )
        (try? context.fetch(staleDesc))?.forEach { context.delete($0) }
        let iso = ISO8601DateFormatter()
        let generatedAt = iso.date(from: resp.generated_at) ?? Date()
        let record = AiBriefRecord(
            id: resp.id, ownerID: uid, logDate: resp.date,
            briefText: resp.brief_text, mood: resp.mood,
            generatedAt: generatedAt
        )
        context.insert(record)
        try? context.save()
        todayBrief = record
    }
}
```

`loadTodayBrief()` is called inside `loadForUser()` (handles login / app start) **and** in `TodayView.onAppear` (handles tab revisits after the app is already running). Both calls are intentional: `loadForUser()` covers cold start; `onAppear` refreshes when the user returns to the tab mid-session. Because the function checks SwiftData for a cached record first, the `onAppear` call is cheap when a brief already exists for today.

**Exact insertion point in `loadForUser()`:** add `loadTodayBrief()` immediately after `loadTodayReadiness()`, before `loadActiveSplit()`:

```swift
loadTodayReadiness()
loadTodayBrief()         // ← insert here
loadActiveSplit()
Task { await syncCanvasIfConfigured() }
Task { await syncSplitsFromServer() }
```

`clearData()` and `wipeSwiftData()` must also cover `AiBriefRecord`:

```swift
// In clearData(), add alongside other @Published resets (before the wipeSwiftData() call):
todayBrief    = nil
briefLoading  = false   // guard against permanent spinner if sign-out interrupts a fetch

// In wipeSwiftData(), add alongside the other context.delete(model:) calls:
try? context.delete(model: AiBriefRecord.self)
```

`clearData()` resets `@Published` properties; `wipeSwiftData()` wipes SwiftData stores — keep the two concerns separate, matching the existing pattern.

### `DailyBriefCard`

```swift
struct DailyBriefCard: View {
    @EnvironmentObject var vm: AppViewModel

    private var moodColor: Color {
        switch vm.todayBrief?.mood {
        case "positive": return .good
        case "alert":    return .bad
        default:         return .warn
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Daily Brief", systemImage: "sparkles")
                    .font(.caption).fontWeight(.semibold)
                    .foregroundStyle(moodColor)
                Spacer()
                Button { vm.refreshBrief() } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .disabled(vm.briefLoading)
            }

            if vm.briefLoading {
                // Skeleton placeholder — no external ShimmerView needed
                Text("Loading your brief…")
                    .font(.subheadline)
                    .redacted(reason: .placeholder)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else if let brief = vm.todayBrief {
                Text(brief.briefText)
                    .font(.subheadline)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: 2)
                .fill(moodColor)
                .frame(width: 3)
                .padding(.vertical, 8)
        }
    }
}
```

Loading state uses `.redacted(reason: .placeholder)` on a static string — no `ShimmerView` needed.

### `TodayView` change

In `TodayView.body`, insert `DailyBriefCard()` between the date header and the habits row. Call `vm.loadTodayBrief()` in `.onAppear`.

---

## Error handling

- **API key missing at startup:** `assertRequiredEnv()` now includes `"DEEPSEEK_API_KEY"` in `REQUIRED_VARS` — server exits with a clear error message.
- **DeepSeek API down or returns no choices:** `callDeepSeek` throws; `aiService` catches and rethrows; route returns `{ error: "brief_unavailable" }`; iOS `guard let resp = try? …` silently returns — `todayBrief` stays `nil` and the card doesn't render.
- **Model omits MOOD tag:** `parseMoodAndBrief` defaults to `"cautious"`.
- **No check-in data:** Prompt states "No check-in logged yet" — brief focuses on training load and schedule only.
- **First-time user (no data):** All context fields empty — model produces: "Log your first workout to get personalized coaching."

---

## File Map

| File | Action |
|---|---|
| `apps/elos-api/src/lib/deepseek.ts` | **Create** |
| `apps/elos-api/src/services/aiService.ts` | **Create** |
| `apps/elos-api/src/routes/ai.ts` | **Create** — defines `briefLimiter`, imports `requireAuth`, registers `router.post("/brief", requireAuth, briefLimiter, handler)` |
| `apps/elos-api/src/index.ts` | **Modify** — import `aiRouter`, register `app.use("/ai", aiRouter)` |
| `apps/elos-api/src/lib/env.ts` | **Modify** — add `"DEEPSEEK_API_KEY"` to `REQUIRED_VARS` array |
| `apps/elos-api/migrations/024_ai_briefs.sql` | **Create** |
| `apps/elos-api/.env.example` | **Modify** — add `DEEPSEEK_API_KEY=` |
| `apps/elos-mobile/.../ElosApp.swift` | **Modify** — add `AiBriefRecord.self` to `Schema([…])` array |
| `apps/elos-mobile/.../Features/Today/AiBriefRecord.swift` | **Create** — `@Model` |
| `apps/elos-mobile/.../Features/Today/AiBriefService.swift` | **Create** — `struct AiBriefService` with `static func fetchBrief` |
| `apps/elos-mobile/.../Features/Today/DailyBriefCard.swift` | **Create** |
| `apps/elos-mobile/.../AppViewModel.swift` | **Modify** — add `todayBrief`, `briefLoading`, `loadTodayBrief()`, `refreshBrief()`, `buildBriefClientContext()`; update `clearData()` (reset both new `@Published` vars) and `wipeSwiftData()` (add `context.delete(model: AiBriefRecord.self)`) |
| `apps/elos-mobile/.../Views/TodayView.swift` | **Modify** — insert `DailyBriefCard()`, call `vm.loadTodayBrief()` in `.onAppear` |
