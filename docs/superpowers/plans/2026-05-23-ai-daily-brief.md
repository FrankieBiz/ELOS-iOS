# AI Daily Brief Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a personalized AI-generated daily brief card to the Today tab, powered by DeepSeek and cached server-side once per user per day.

**Architecture:** iOS POSTs SwiftData-only context (sleep, assignments, exams) to `POST /ai/brief`; the backend merges this with DB data (readiness, sessions, split, profile), calls DeepSeek, stores the result in `ai_briefs`, and returns it. iOS caches the response in SwiftData as `AiBriefRecord` and serves from cache on subsequent tab visits.

**Tech Stack:** Node/TypeScript/Express/pg (backend), DeepSeek Chat API, SwiftUI/SwiftData/MVVM (iOS)

---

## File Map

| File | Action |
|---|---|
| `apps/elos-api/migrations/024_ai_briefs.sql` | Create — `ai_briefs` table |
| `apps/elos-api/src/lib/env.ts` | Modify — add `DEEPSEEK_API_KEY` to `REQUIRED_VARS` |
| `apps/elos-api/.env.example` | Modify — add `DEEPSEEK_API_KEY=` entry |
| `apps/elos-api/src/lib/deepseek.ts` | Create — `callDeepSeek()` wrapper |
| `apps/elos-api/src/lib/__tests__/deepseek.test.ts` | Create — unit tests for `parseMoodAndBrief` |
| `apps/elos-api/src/services/aiService.ts` | Create — context assembly, prompt, DeepSeek call, upsert |
| `apps/elos-api/src/routes/ai.ts` | Create — `POST /brief` with `requireAuth` + `briefLimiter` |
| `apps/elos-api/src/index.ts` | Modify — import `aiRouter`, register `app.use("/ai", aiRouter)` |
| `apps/elos-mobile/Elos/Elos/Features/Today/AiBriefRecord.swift` | Create — SwiftData `@Model` |
| `apps/elos-mobile/Elos/Elos/Features/Today/AiBriefService.swift` | Create — request/response types + static `fetchBrief` |
| `apps/elos-mobile/Elos/Elos/Features/Today/DailyBriefCard.swift` | Create — SwiftUI card |
| `apps/elos-mobile/Elos/Elos/ElosApp.swift` | Modify — add `AiBriefRecord.self` to `Schema([…])` |
| `apps/elos-mobile/Elos/Elos/AppViewModel.swift` | Modify — `todayBrief`, `briefLoading`, `loadTodayBrief()`, `refreshBrief()`, `buildBriefClientContext()`, clearData/wipeSwiftData updates, loadForUser wiring |
| `apps/elos-mobile/Elos/Elos/Views/TodayView.swift` | Modify — insert `DailyBriefCard()`, call `vm.loadTodayBrief()` in `.onAppear` |

---

## Task 1: DB migration + env wiring

**Files:**
- Create: `apps/elos-api/migrations/024_ai_briefs.sql`
- Modify: `apps/elos-api/src/lib/env.ts` (line 1–4)
- Modify: `apps/elos-api/.env.example`
- Modify: `apps/elos-api/src/index.ts` (lines 23 and 79)

- [ ] **Step 1: Create the migration file**

```sql
-- apps/elos-api/migrations/024_ai_briefs.sql
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

- [ ] **Step 2: Add `DEEPSEEK_API_KEY` to `REQUIRED_VARS` in `apps/elos-api/src/lib/env.ts`**

Replace the existing `REQUIRED_VARS` block (lines 1–4):
```typescript
const REQUIRED_VARS = [
  "SUPABASE_URL",
  "SUPABASE_SERVICE_ROLE_KEY",
  "DEEPSEEK_API_KEY",
] as const;
```

- [ ] **Step 3: Add `DEEPSEEK_API_KEY` to `.env.example`**

Append after the existing `LOG_LEVEL` line in `apps/elos-api/.env.example`:
```
# DeepSeek API key — required for AI daily brief generation
DEEPSEEK_API_KEY=your-deepseek-api-key-here
```

- [ ] **Step 4: Register the AI router in `apps/elos-api/src/index.ts`**

Add import alongside other router imports (after line 23, `import splitsRouter from "./routes/splits";`):
```typescript
import aiRouter from "./routes/ai";
```

Add route registration alongside other `app.use` calls (after line 79, `app.use("/splits", splitsRouter);`):
```typescript
app.use("/ai", aiRouter);
```

- [ ] **Step 5: Commit**

```bash
git add apps/elos-api/migrations/024_ai_briefs.sql \
        apps/elos-api/src/lib/env.ts \
        apps/elos-api/.env.example \
        apps/elos-api/src/index.ts
git commit -m "feat: add ai_briefs migration, env var, and router registration"
```

---

## Task 2: DeepSeek wrapper + unit test

**Files:**
- Create: `apps/elos-api/src/lib/deepseek.ts`
- Create: `apps/elos-api/src/lib/__tests__/deepseek.test.ts`

- [ ] **Step 1: Write the failing test**

Create `apps/elos-api/src/lib/__tests__/deepseek.test.ts`:

```typescript
import { describe, it, expect } from "vitest";
import { parseMoodAndBrief } from "../deepseek";

describe("parseMoodAndBrief", () => {
  it("extracts positive mood and strips tag", () => {
    const raw = "You're well-rested and ready for today's workout. No major deadlines ahead.\nMOOD: positive";
    const { briefText, mood } = parseMoodAndBrief(raw);
    expect(mood).toBe("positive");
    expect(briefText).toBe("You're well-rested and ready for today's workout. No major deadlines ahead.");
    expect(briefText).not.toContain("MOOD:");
  });

  it("extracts cautious mood (case-insensitive)", () => {
    const { mood } = parseMoodAndBrief("Some text.\nMOOD: Cautious");
    expect(mood).toBe("cautious");
  });

  it("extracts alert mood", () => {
    const { mood } = parseMoodAndBrief("Fatigue detected.\nMOOD: alert");
    expect(mood).toBe("alert");
  });

  it("defaults to cautious when MOOD tag is absent", () => {
    const { briefText, mood } = parseMoodAndBrief("Plain text, no tag.");
    expect(mood).toBe("cautious");
    expect(briefText).toBe("Plain text, no tag.");
  });

  it("handles extra whitespace around tag", () => {
    const { mood } = parseMoodAndBrief("Text here.\nMOOD:  positive  ");
    expect(mood).toBe("positive");
  });
});
```

- [ ] **Step 2: Run test — expect FAIL (module not found)**

```bash
pnpm --filter apps/elos-api test
```
Expected: FAIL with `Cannot find module '../deepseek'`

- [ ] **Step 3: Create `apps/elos-api/src/lib/deepseek.ts`**

```typescript
export function parseMoodAndBrief(raw: string): { briefText: string; mood: string } {
  const moodMatch = raw.match(/MOOD:\s*(positive|cautious|alert)/i);
  const mood = moodMatch ? moodMatch[1].toLowerCase() : "cautious";
  const briefText = raw.replace(/\n?MOOD:\s*(positive|cautious|alert)\s*$/i, "").trim();
  return { briefText, mood };
}

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

- [ ] **Step 4: Run tests — expect PASS**

```bash
pnpm --filter apps/elos-api test
```
Expected: all 5 `parseMoodAndBrief` tests PASS

- [ ] **Step 5: Commit**

```bash
git add apps/elos-api/src/lib/deepseek.ts \
        apps/elos-api/src/lib/__tests__/deepseek.test.ts
git commit -m "feat: add DeepSeek wrapper and parseMoodAndBrief with tests"
```

---

## Task 3: AI service

**Files:**
- Create: `apps/elos-api/src/services/aiService.ts`

The service takes a `Pool` in its constructor (same pattern as all other services). It uses `supabaseAdmin` to fetch the user profile (profiles table lives in Supabase) and raw pg `pool` for readiness, sessions, and splits (which live in direct-connected Postgres tables).

- [ ] **Step 1: Create `apps/elos-api/src/services/aiService.ts`**

```typescript
import { Pool } from "pg";
import { supabaseAdmin } from "../supabase";
import { callDeepSeek, parseMoodAndBrief } from "../lib/deepseek";

export interface ClientSleepContext {
  hours: number;
  quality: number;
}

export interface ClientAssignmentContext {
  name: string;
  subject: string;
  isUrgent: boolean;
  dueIn: string;
}

export interface ClientExamContext {
  subject: string;
  title: string;
  daysUntil: number;
}

export interface BriefClientContext {
  sleep?: ClientSleepContext;
  assignments?: ClientAssignmentContext[];
  exams?: ClientExamContext[];
}

export interface BriefRow {
  id: string;
  date: string;
  brief_text: string;
  mood: string;
  generated_at: string;
}

export class AiService {
  constructor(private readonly db: Pool) {}

  async getBrief(
    userId: string,
    clientCtx: BriefClientContext,
    force: boolean
  ): Promise<BriefRow> {
    // Serve cached row unless force regeneration
    if (!force) {
      const cached = await this.db.query<BriefRow>(
        `SELECT id, date::text, brief_text, mood, generated_at::text
         FROM ai_briefs WHERE user_id = $1 AND date = CURRENT_DATE`,
        [userId]
      );
      if (cached.rows[0]) return cached.rows[0];
    } else {
      await this.db.query(
        `DELETE FROM ai_briefs WHERE user_id = $1 AND date = CURRENT_DATE`,
        [userId]
      );
    }

    // --- Fetch server-side context ---

    // Profile: first name from Supabase profiles table
    const { data: profile } = await supabaseAdmin
      .from("profiles")
      .select("first_name")
      .eq("user_id", userId)
      .maybeSingle();
    const firstName: string = profile?.first_name ?? "Athlete";

    // Today's readiness check-in
    const readinessRes = await this.db.query<{
      sleep_quality: number;
      soreness: number;
      stress: number;
      motivation: number;
      overall_score: number;
    }>(
      `SELECT sleep_quality, soreness, stress, motivation, overall_score::float
       FROM readiness_checkins WHERE user_id = $1 AND log_date = CURRENT_DATE`,
      [userId]
    );
    const readiness = readinessRes.rows[0] ?? null;

    // Last 7 days of completed workout sessions
    const sessionsRes = await this.db.query<{
      count: string;
      total_volume: string;
      avg_rpe: string;
    }>(
      `SELECT COUNT(*)::text AS count,
              COALESCE(SUM(total_volume), 0)::text AS total_volume,
              COALESCE(AVG(session_rpe), 0)::float::text AS avg_rpe
       FROM workout_sessions
       WHERE user_id = $1
         AND started_at >= NOW() - INTERVAL '7 days'
         AND finished_at IS NOT NULL`,
      [userId]
    );
    const sessions = sessionsRes.rows[0];

    // Active split name
    const splitRes = await this.db.query<{ name: string }>(
      `SELECT name FROM user_splits WHERE user_id = $1 AND is_active = true LIMIT 1`,
      [userId]
    );
    const splitName = splitRes.rows[0]?.name ?? null;

    // --- Build prompt ---
    const prompt = buildPrompt({
      firstName,
      readiness,
      sessions: {
        count: parseInt(sessions.count, 10),
        totalVolume: parseFloat(sessions.total_volume),
        avgRpe: parseFloat(sessions.avg_rpe),
      },
      splitName,
      clientCtx,
    });

    // --- Call DeepSeek + parse ---
    const raw = await callDeepSeek(prompt);
    const { briefText, mood } = parseMoodAndBrief(raw);

    // --- Persist (upsert in case of race) ---
    const insertRes = await this.db.query<BriefRow>(
      `INSERT INTO ai_briefs (user_id, date, brief_text, mood)
       VALUES ($1, CURRENT_DATE, $2, $3)
       ON CONFLICT (user_id, date) DO UPDATE
         SET brief_text    = EXCLUDED.brief_text,
             mood          = EXCLUDED.mood,
             generated_at  = now()
       RETURNING id, date::text, brief_text, mood, generated_at::text`,
      [userId, briefText, mood]
    );
    return insertRes.rows[0];
  }
}

interface PromptContext {
  firstName: string;
  readiness: {
    sleep_quality: number;
    soreness: number;
    stress: number;
    motivation: number;
    overall_score: number;
  } | null;
  sessions: { count: number; totalVolume: number; avgRpe: number };
  splitName: string | null;
  clientCtx: BriefClientContext;
}

function buildPrompt(ctx: PromptContext): string {
  const { firstName, readiness, sessions, splitName, clientCtx } = ctx;

  const sleepLine = clientCtx.sleep
    ? `Sleep last night: ${clientCtx.sleep.hours}h, quality ${clientCtx.sleep.quality}/5`
    : "Sleep last night: no data";

  const readinessLine = readiness
    ? `Readiness check-in: ${readiness.overall_score.toFixed(1)}/5 — sleep ${readiness.sleep_quality}, soreness ${readiness.soreness}, stress ${readiness.stress}, motivation ${readiness.motivation}`
    : "Readiness check-in: No check-in logged yet";

  const splitLine = splitName
    ? `Today's planned workout: current split is "${splitName}"`
    : "Today's planned workout: No active split";

  const sessionLine = `Training this week: ${sessions.count} sessions, ${sessions.totalVolume.toFixed(0)}kg total volume, avg RPE ${sessions.avgRpe.toFixed(1)}`;

  const urgentAssignments = (clientCtx.assignments ?? []).filter((a) => a.isUrgent);
  const deadlineList =
    urgentAssignments.length > 0
      ? urgentAssignments.map((a) => `${a.name} (${a.subject}, due ${a.dueIn})`).join("; ")
      : "None";

  const examList =
    (clientCtx.exams ?? []).length > 0
      ? clientCtx.exams!.map((e) => `${e.title} – ${e.subject} in ${e.daysUntil} day(s)`).join("; ")
      : "None";

  return `You are a concise performance coach for a student-athlete named ${firstName}.

Today's data:
- ${sleepLine}
- ${readinessLine}
- ${splitLine}
- ${sessionLine}
- Upcoming deadlines (48h): ${deadlineList}
- Upcoming exams (7 days): ${examList}

Write exactly 2 sentences. Sentence 1: a direct observation about physical readiness and today's training. Sentence 2: a note about academic or schedule pressure today. Be practical and direct — no fluff, no exclamation points.
On a new final line write: MOOD: positive|cautious|alert`;
}
```

- [ ] **Step 2: Run existing tests to confirm nothing broken**

```bash
pnpm --filter apps/elos-api test
```
Expected: all existing tests PASS (no new tests for this task)

- [ ] **Step 3: Commit**

```bash
git add apps/elos-api/src/services/aiService.ts
git commit -m "feat: add AiService — context assembly, prompt building, DeepSeek call, upsert"
```

---

## Task 4: AI route

**Files:**
- Create: `apps/elos-api/src/routes/ai.ts`

Pattern is identical to existing route files — `import { requireAuth }`, create `Router`, instantiate service with `pool`, delegate to service, handle errors.

- [ ] **Step 1: Create `apps/elos-api/src/routes/ai.ts`**

```typescript
import { Router, Request, Response } from "express";
import rateLimit from "express-rate-limit";
import { requireAuth } from "../middleware/auth";
import { AiService } from "../services/aiService";
import { pool } from "../db";

const router = Router();
const service = new AiService(pool);

const briefLimiter = rateLimit({
  windowMs: 60 * 60 * 1000, // 1 hour
  limit: 5,
  keyGenerator: (req) => (req as any).user?.id ?? req.ip,
  standardHeaders: "draft-7",
  legacyHeaders: false,
});

router.post("/brief", requireAuth, briefLimiter, async (req: Request, res: Response) => {
  const clientCtx = req.body?.client_context ?? {};
  const force = req.body?.force === true;
  try {
    const brief = await service.getBrief(req.user!.id, clientCtx, force);
    res.json(brief);
  } catch {
    res.status(503).json({ error: "brief_unavailable" });
  }
});

export default router;
```

- [ ] **Step 2: Run existing tests — expect PASS**

```bash
pnpm --filter apps/elos-api test
```
Expected: all tests PASS

- [ ] **Step 3: Verify TypeScript compiles**

```bash
pnpm --filter apps/elos-api exec tsc --noEmit
```
Expected: no errors

- [ ] **Step 4: Commit**

```bash
git add apps/elos-api/src/routes/ai.ts
git commit -m "feat: add POST /ai/brief route with requireAuth and per-user briefLimiter"
```

---

## Task 5: iOS SwiftData model + ElosApp schema

**Files:**
- Create: `apps/elos-mobile/Elos/Elos/Features/Today/AiBriefRecord.swift`
- Modify: `apps/elos-mobile/Elos/Elos/ElosApp.swift` (line 37)

- [ ] **Step 1: Create `apps/elos-mobile/Elos/Elos/Features/Today/AiBriefRecord.swift`**

```swift
import SwiftData

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

- [ ] **Step 2: Add `AiBriefRecord.self` to schema in `apps/elos-mobile/Elos/Elos/ElosApp.swift`**

After line 37 (`CourseRecord.self,`), add:
```swift
AiBriefRecord.self,
```

The closing `])` stays on line 38. The schema block becomes:
```swift
let schema = Schema([
    HabitRecord.self,
    // ... (all existing entries unchanged) ...
    CourseRecord.self,
    AiBriefRecord.self,   // ← new
])
```

- [ ] **Step 3: Build the iOS project to confirm it compiles**

In Xcode: Product → Build (⌘B). Expected: Build Succeeded.

- [ ] **Step 4: Commit**

```bash
git -C apps/elos-mobile/Elos add Elos/Features/Today/AiBriefRecord.swift Elos/ElosApp.swift
git -C apps/elos-mobile/Elos commit -m "feat: add AiBriefRecord SwiftData model and register in schema"
```

---

## Task 6: iOS service types

**Files:**
- Create: `apps/elos-mobile/Elos/Elos/Features/Today/AiBriefService.swift`

This file holds all the Encodable request structs, the Decodable response struct, and the static `fetchBrief` method. No logic — just types and a single API call.

- [ ] **Step 1: Create `apps/elos-mobile/Elos/Elos/Features/Today/AiBriefService.swift`**

```swift
import Foundation

struct AiBriefResponse: Decodable {
    let id: String
    let date: String           // "yyyy-MM-dd" UTC — use as SwiftData logDate key
    let brief_text: String
    let mood: String
    let generated_at: String   // ISO8601 — converted to Date in AppViewModel
}

struct BriefSleepContext: Encodable {
    let hours: Double
    let quality: Int
}

struct BriefAssignmentContext: Encodable {
    let name: String
    let subject: String
    let isUrgent: Bool
    let dueIn: String          // forwarded from AssignmentRecord.dueString
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

- [ ] **Step 2: Build iOS (⌘B) — expect Build Succeeded**

- [ ] **Step 3: Commit**

```bash
git -C apps/elos-mobile/Elos add Elos/Features/Today/AiBriefService.swift
git -C apps/elos-mobile/Elos commit -m "feat: add AiBriefService with request/response types and fetchBrief"
```

---

## Task 7: iOS AppViewModel additions

**Files:**
- Modify: `apps/elos-mobile/Elos/Elos/AppViewModel.swift`

Four separate changes, applied in this order to avoid merge confusion:
1. Add `@Published` vars (after line 71 — the `todayReadiness` property)
2. Add `loadTodayBrief()` call in `loadForUser()` (after line 194)
3. Reset vars in `clearData()` (after line 214, before `wipeSwiftData()` call)
4. Add `context.delete(model: AiBriefRecord.self)` in `wipeSwiftData()` (after line 238, before `context.save()`)
5. Add the three new methods after the existing `loadTodayReadiness()` method (after line ~408)

- [ ] **Step 1: Add `@Published` vars after `todayReadiness` (line 71)**

After this line:
```swift
@Published var todayReadiness: ReadinessCheckInRecord? = nil
```

Add:
```swift
@Published var todayBrief: AiBriefRecord? = nil
@Published var briefLoading: Bool = false
```

- [ ] **Step 2: Insert `loadTodayBrief()` call in `loadForUser()` (after line 194)**

After this line:
```swift
loadTodayReadiness()
```

Add:
```swift
loadTodayBrief()
```

The tail of `loadForUser()` should now read:
```swift
loadTodayReadiness()
loadTodayBrief()
loadActiveSplit()
Task { await syncCanvasIfConfigured() }
Task { await syncSplitsFromServer() }
```

- [ ] **Step 3: Reset vars in `clearData()` (after `activeSplitDays = []` on line 214, before `wipeSwiftData()` call)**

After `activeSplitDays = []`, add:
```swift
todayBrief   = nil
briefLoading = false
```

- [ ] **Step 4: Add `AiBriefRecord` deletion in `wipeSwiftData()` (after `CourseRecord` deletion, before `context.save()`)**

After:
```swift
try? context.delete(model: CourseRecord.self)
```

Add:
```swift
try? context.delete(model: AiBriefRecord.self)
```

- [ ] **Step 5: Add the three new methods**

Find `loadTodayReadiness()` in `AppViewModel.swift` (around line 399). After that function's closing brace, add:

```swift
func loadTodayBrief() {
    guard !currentUserID.isEmpty else { return }
    let uid = currentUserID
    let fmt = DateFormatter(); fmt.dateFormat = "yyyy-MM-dd"
    let today = fmt.string(from: Date())
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

func refreshBrief() {
    guard !currentUserID.isEmpty, !briefLoading else { return }
    let uid = currentUserID
    briefLoading = true
    Task { @MainActor in
        defer { briefLoading = false }
        let clientCtx = buildBriefClientContext(uid: uid)
        guard let resp = try? await AiBriefService.fetchBrief(context: clientCtx, force: true) else { return }
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

private func buildBriefClientContext(uid: String) -> BriefClientContext {
    var sleepDesc = FetchDescriptor<SleepRecord>(
        predicate: #Predicate { $0.ownerID == uid },
        sortBy: [SortDescriptor(\.logDate, order: .reverse)]
    )
    sleepDesc.fetchLimit = 1
    let latestSleep = (try? context.fetch(sleepDesc))?.first
    let sleepCtx: BriefSleepContext? = latestSleep.map {
        BriefSleepContext(hours: $0.duration, quality: $0.quality)
    }

    let assignDesc = FetchDescriptor<AssignmentRecord>(
        predicate: #Predicate { $0.ownerID == uid && $0.isDone == false }
    )
    let assignments = (try? context.fetch(assignDesc)) ?? []
    let assignCtx = assignments.map { a in
        BriefAssignmentContext(name: a.name, subject: a.subject,
                               isUrgent: a.isUrgent, dueIn: a.dueString)
    }

    let examDesc = FetchDescriptor<ExamRecord>(
        predicate: #Predicate { $0.ownerID == uid && $0.daysAway >= 0 && $0.daysAway <= 7 }
    )
    let exams = (try? context.fetch(examDesc)) ?? []
    let examCtx = exams.map { e in
        BriefExamContext(subject: e.subject, title: e.title, daysUntil: e.daysAway)
    }

    return BriefClientContext(sleep: sleepCtx, assignments: assignCtx, exams: examCtx)
}
```

- [ ] **Step 6: Build iOS (⌘B) — expect Build Succeeded**

If you see errors, check:
- `AiBriefRecord` type not found → confirm `AiBriefRecord.swift` was added to the Xcode target
- `BriefSleepContext` not found → confirm `AiBriefService.swift` was added to the Xcode target
- `#Predicate` with `$0.isDone == false` is the correct negation form (not `!$0.isDone`)

- [ ] **Step 7: Commit**

```bash
git -C apps/elos-mobile/Elos add Elos/AppViewModel.swift
git -C apps/elos-mobile/Elos commit -m "feat: add loadTodayBrief, refreshBrief, buildBriefClientContext to AppViewModel"
```

---

## Task 8: iOS DailyBriefCard

**Files:**
- Create: `apps/elos-mobile/Elos/Elos/Features/Today/DailyBriefCard.swift`

The card uses `Color.good`, `Color.bad`, and `Color.warn` — these already exist in the app's color extension. Uses `.redacted(reason: .placeholder)` for loading state (no external shimmer library).

- [ ] **Step 1: Create `apps/elos-mobile/Elos/Elos/Features/Today/DailyBriefCard.swift`**

```swift
import SwiftUI

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

- [ ] **Step 2: Build iOS (⌘B) — expect Build Succeeded**

- [ ] **Step 3: Commit**

```bash
git -C apps/elos-mobile/Elos add Elos/Features/Today/DailyBriefCard.swift
git -C apps/elos-mobile/Elos commit -m "feat: add DailyBriefCard SwiftUI component"
```

---

## Task 9: iOS TodayView wiring

**Files:**
- Modify: `apps/elos-mobile/Elos/Elos/Views/TodayView.swift`

Insert `DailyBriefCard()` between `headerSection` and `habitsSection` in the VStack. Add `.onAppear` to call `vm.loadTodayBrief()`.

- [ ] **Step 1: Insert `DailyBriefCard()` in `TodayView.body`**

Find the VStack body (starting around line 21). Change:
```swift
VStack(alignment: .leading, spacing: 24) {
    headerSection
    habitsSection
    scheduleSection
    upcomingDueSection
    quickStatsGrid
}
```

To:
```swift
VStack(alignment: .leading, spacing: 24) {
    headerSection
    DailyBriefCard()
    habitsSection
    scheduleSection
    upcomingDueSection
    quickStatsGrid
}
```

- [ ] **Step 2: Add `.onAppear` to the `ScrollView`**

After the closing brace of the `VStack` modifiers block, add `.onAppear` to the `ScrollView`. Find:
```swift
.scrollIndicators(.hidden)
```

Add after it (chained modifier on the `ScrollView`):
```swift
.onAppear { vm.loadTodayBrief() }
```

- [ ] **Step 3: Build iOS (⌘B) — expect Build Succeeded**

- [ ] **Step 4: Smoke test**

Run the app in the simulator. Navigate to the Today tab. Verify:
- The DailyBriefCard appears between the date header and the habits row
- When `todayBrief` is nil and `briefLoading` is true, the redacted placeholder text appears
- When a brief loads (requires DEEPSEEK_API_KEY set on the backend), the text and mood color appear
- Tapping the refresh button triggers a new network call (briefLoading flips true momentarily)
- The card does NOT render content if no brief is available (no empty card, just no text)

- [ ] **Step 5: Commit**

```bash
git -C apps/elos-mobile/Elos add Elos/Views/TodayView.swift
git -C apps/elos-mobile/Elos commit -m "feat: wire DailyBriefCard into TodayView with onAppear trigger"
```
