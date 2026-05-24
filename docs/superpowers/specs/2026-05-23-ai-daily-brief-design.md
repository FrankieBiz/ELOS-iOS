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

```
iOS (TodayView)
  → AppViewModel.loadTodayBrief()
    → AiBriefService.fetchBrief(ownerID:)
      → check AiBriefRecord in SwiftData (logDate == today)
        → if exists: return cached record
        → if absent: GET /api/ai/brief
            → BriefService (Node) fetches user context from DB
            → builds prompt
            → calls DeepSeek Chat API
            → stores result in ai_briefs table
            → returns { brief, mood, generated_at }
          → save AiBriefRecord to SwiftData
```

### Caching strategy

- **Server-side:** One row in `ai_briefs` per (`user_id`, `date`). `GET /api/ai/brief` returns the cached row if it exists for today's date (UTC). A `force=true` query param bypasses the cache and regenerates.
- **Client-side:** `AiBriefRecord` in SwiftData keyed by `logDate` ("yyyy-MM-dd"). If a local record exists for today, no network call is made.
- Result: DeepSeek is called **at most once per user per day** (unless the user taps "Refresh").

---

## Backend

### New files

| Path | Responsibility |
|---|---|
| `src/routes/ai.ts` | `GET /api/ai/brief` — auth-gated endpoint |
| `src/services/aiService.ts` | Fetches user context, builds prompt, calls DeepSeek, persists result |
| `src/lib/deepseek.ts` | Thin wrapper: `POST https://api.deepseek.com/chat/completions`, reads `DEEPSEEK_API_KEY` from env |

### Migration

```sql
-- migrations/025_ai_briefs.sql
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

### `GET /api/ai/brief`

**Auth:** `requireAuth` middleware (same as all other routes)

**Query params:**
- `force=true` — regenerates even if a cached record exists today

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

**Error response (no DeepSeek key / API failure):**
```json
{ "error": "brief_unavailable" }
```
The iOS client handles this gracefully — the card simply doesn't render.

### `aiService.ts` — context assembly

The service fetches:
1. Profile (first name)
2. Today's readiness check-in (sleep quality, soreness, stress, motivation, overall score) — may be absent
3. Last night's sleep record (duration, quality)
4. Last 7 days of workout sessions (count, total volume, avg RPE)
5. Assignments due in next 48 hours (name, subject, is_urgent)
6. Exams in next 7 days (subject, title, date)
7. Active split + today's planned day name

### Prompt template

```
You are a concise performance coach for a student-athlete named {firstName}.

Today's data:
- Sleep last night: {sleepHours}h, quality {sleepQuality}/5
- Readiness check-in: {readinessScore}/5 ({readinessLabel}) — sleep {sleepQ}, soreness {sorenessQ}, stress {stressQ}, motivation {motivationQ}
  (or "No check-in logged yet")
- Today's planned workout: {splitDayName} (or "No active split")
- Training this week: {sessionCount} sessions, {totalVolumeKg}kg total volume, avg RPE {avgRPE}
- Upcoming deadlines (48h): {deadlineList}
- Upcoming exams (7 days): {examList}

Write exactly 2 sentences. Sentence 1: one direct observation about physical readiness and today's training. Sentence 2: one observation about the academic/schedule pressure today. Be practical and direct — no fluff, no exclamation points. End with the mood tag on a new line: MOOD: positive|cautious|alert
```

**Mood rules (parsed from response tail):**
- `positive` — readiness ≥ 4 AND no urgent deadlines in 24h
- `cautious` — readiness 2–3 OR deadline in 24h
- `alert` — readiness ≤ 1 OR exam in 24h

The model's `MOOD:` line is parsed out before storing `brief_text`.

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
  return data.choices[0].message.content as string;
}
```

### Rate-limiting

A dedicated `briefLimiter` on the `/api/ai/brief` route: 5 requests per user per hour. This protects against abuse of the "Refresh" button.

### `lib/env.ts` addition

`DEEPSEEK_API_KEY` added to the `assertRequiredEnv()` check list.

---

## iOS

### New files

| Path | Responsibility |
|---|---|
| `Features/Today/AiBriefRecord.swift` | SwiftData `@Model` — local cache |
| `Features/Today/AiBriefService.swift` | Fetch, decode, persist brief |
| `Features/Today/DailyBriefCard.swift` | SwiftUI card shown in TodayView |

### `AiBriefRecord` (SwiftData)

```swift
@Model
final class AiBriefRecord {
    var id: String
    var ownerID: String
    var logDate: String        // "yyyy-MM-dd"
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

Added to the SwiftData schema in `ElosApp.swift`.

### `AiBriefService`

Pure function called by `AppViewModel`:

```swift
struct AiBriefResponse: Decodable {
    let id: String
    let date: String
    let brief_text: String
    let mood: String
    let generated_at: String
}

func fetchBrief(ownerID: String, force: Bool = false) async throws -> AiBriefResponse {
    let url = force ? "/ai/brief?force=true" : "/ai/brief"
    return try await ApiClient.shared.get(url)
}
```

### `AppViewModel` additions

```swift
@Published var todayBrief: AiBriefRecord? = nil
@Published var briefLoading: Bool = false

func loadTodayBrief() {
    guard !currentUserID.isEmpty else { return }
    let uid = currentUserID
    let fmt = DateFormatter(); fmt.dateFormat = "yyyy-MM-dd"
    let today = fmt.string(from: Date())
    let desc = FetchDescriptor<AiBriefRecord>(
        predicate: #Predicate { $0.ownerID == uid }
    )
    let existing = (try? context.fetch(desc))?.first { $0.logDate == today }
    if let cached = existing { todayBrief = cached; return }
    briefLoading = true
    Task { @MainActor in
        defer { briefLoading = false }
        guard let resp = try? await AiBriefService.fetchBrief(ownerID: uid) else { return }
        let record = AiBriefRecord(
            id: resp.id, ownerID: uid, logDate: resp.date,
            briefText: resp.brief_text, mood: resp.mood
        )
        context.insert(record)
        try? context.save()
        todayBrief = record
    }
}

func refreshBrief() {
    guard !currentUserID.isEmpty else { return }
    let uid = currentUserID
    briefLoading = true
    Task { @MainActor in
        defer { briefLoading = false }
        guard let resp = try? await AiBriefService.fetchBrief(ownerID: uid, force: true) else { return }
        // Delete old record for today if present
        let fmt = DateFormatter(); fmt.dateFormat = "yyyy-MM-dd"
        let today = fmt.string(from: Date())
        let desc = FetchDescriptor<AiBriefRecord>(predicate: #Predicate { $0.ownerID == uid })
        let stale = (try? context.fetch(desc))?.filter { $0.logDate == today } ?? []
        stale.forEach { context.delete($0) }
        let record = AiBriefRecord(
            id: resp.id, ownerID: uid, logDate: resp.date,
            briefText: resp.brief_text, mood: resp.mood
        )
        context.insert(record)
        try? context.save()
        todayBrief = record
    }
}
```

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
                ShimmerView()
                    .frame(height: 40)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
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
                .offset(x: 0)
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
```

`ShimmerView` is a simple animated gradient placeholder (standard pattern).

### `TodayView` change

In `TodayView.body`, insert `DailyBriefCard()` between the date header and the habits row. Call `vm.loadTodayBrief()` in `.onAppear`.

---

## Error handling

- **API key missing:** `assertRequiredEnv` catches this at startup; app won't boot without it.
- **DeepSeek returns error:** `aiService` catches and rethrows; route returns `{ error: "brief_unavailable" }`; iOS ignores the error and hides the card (`todayBrief` stays `nil`).
- **No check-in data:** Prompt states "No check-in logged yet" — brief still generates but focuses on training load and schedule only.
- **First-time user (no data):** All context fields are empty/zero — prompt produces a sensible fallback ("Log your first workout to get personalized coaching").

---

## File Map

| File | Action |
|---|---|
| `apps/elos-api/src/lib/deepseek.ts` | **Create** |
| `apps/elos-api/src/services/aiService.ts` | **Create** |
| `apps/elos-api/src/routes/ai.ts` | **Create** |
| `apps/elos-api/src/index.ts` | **Modify** — register `aiRouter` |
| `apps/elos-api/src/lib/env.ts` | **Modify** — add `DEEPSEEK_API_KEY` |
| `apps/elos-api/migrations/025_ai_briefs.sql` | **Create** |
| `apps/elos-api/.env.example` | **Modify** — add `DEEPSEEK_API_KEY=` |
| `apps/elos-mobile/.../SwiftData/ElosSchema.swift` | **Modify** — add `AiBriefRecord` |
| `apps/elos-mobile/.../ElosApp.swift` | **Modify** — add to SwiftData schema |
| `apps/elos-mobile/.../Features/Today/AiBriefRecord.swift` | **Create** — `@Model` |
| `apps/elos-mobile/.../Features/Today/AiBriefService.swift` | **Create** |
| `apps/elos-mobile/.../Features/Today/DailyBriefCard.swift` | **Create** |
| `apps/elos-mobile/.../AppViewModel.swift` | **Modify** — `todayBrief`, `loadTodayBrief()`, `refreshBrief()` |
| `apps/elos-mobile/.../Views/TodayView.swift` | **Modify** — insert card, call `loadTodayBrief()` |
