# Wearable API Integrations (Garmin + Fitbit) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Cronometer-style direct cloud integrations — users connect their Garmin and/or Fitbit accounts inside ELOS; the backend ingests their daily health data from the vendor APIs, normalizes it into one canonical store, and the iOS app merges it with HealthKit (wearable wins) for readiness and training intelligence.

**Architecture:** Server-side OAuth in `elos-api` (mobile opens the vendor consent page via `ASWebAuthenticationSession`; the backend holds encrypted tokens and handles callbacks/webhooks). Provider payloads are normalized at the boundary into a `wearable_daily_metrics` table (single source of truth), with verbatim vendor payloads retained separately in `wearable_raw_payloads` for reprocessing. A pure merge layer resolves per-metric source priority (Garmin > Fitbit on the server; wearable > HealthKit on the phone), and every served value carries its source. Ingestion is webhook-driven in production with a pull-based backfill/sync path that also works in local dev (no public URL needed).

**Tech Stack:** Express 5 + raw `pg` + zod + vitest (elos-api) · Node built-in `fetch` and `crypto` (AES-256-GCM token encryption) · SwiftUI + `ASWebAuthenticationSession` + Swift Testing (elos-mobile) · Fitbit Web API (OAuth 2.0 + PKCE, Subscriptions API) · Garmin Connect Developer Program Health API (OAuth 2.0 + PKCE, push/ping + backfill).

**Spec:** `docs/superpowers/specs/2026-07-11-wearable-api-integrations-spec.md`

---

## Context you need before starting

### Repo conventions (do not deviate)

**elos-api** (`apps/elos-api`):
- Routes are thin `Router()` modules in `src/routes/`, default-exported, mounted in `src/index.ts` after middleware and before `notFoundHandler`/`errorHandler`.
- Business logic lives in `src/services/*Service.ts` modules (`import * as fooService`).
- Auth: `requireAuth` middleware (`src/middleware/auth.ts`) verifies the Supabase bearer token and sets `req.user!.id` / `req.user!.email`.
- Validation: zod schemas in `src/schemas.ts`, applied with `validateBody(schema)` / `validateQuery(schema)` from `src/middleware/validate.ts`.
- Errors: throw `badRequest()/unauthorized()/forbidden()/notFound()/conflict()` from `src/lib/httpError.ts`; the error handler renders `{ error, code? }` (`ErrorResponse` from `elos-shared`).
- DB: raw `pool.query<T>()` from `src/db.ts` with parameterized SQL; transactions via `pool.connect()` + BEGIN/COMMIT/ROLLBACK.
- Migrations: `migrations/NNN_snake_case.sql`, next number is **040** (check `ls migrations/ | sort | tail -1` first). They run automatically at boot; apply manually with `npm run migrate`.
- Env: required vars asserted in `src/lib/env.ts`; document new vars in `.env.example`.
- Tests: vitest, colocated in `__tests__/` dirs. Run: `npm test` (from `apps/elos-api`). Typecheck: `npx tsc --noEmit`.

**elos-mobile** (`apps/elos-mobile/Elos/Elos`):
- Thin singleton services (`Services/HealthKitService.swift` is the template) with pure logic extracted to testable value types (`Features/Train/Programs/Intelligence/HealthMetrics.swift` is the template).
- Networking through `ApiClient.shared` (`Networking/ApiClient.swift`) — generic `get/post/patch/delete`, Supabase bearer token added automatically. Production base URL `https://elos.onrender.com`.
- App state in `AppViewModel` (`@MainActor ObservableObject`), injected via `.environmentObject`. Small prefs mirrored to `UserDefaults`.
- SwiftData models live in `SwiftData/ElosSchema.swift`. **This feature does not need new SwiftData models** — wearable metrics are served by the backend and cached in memory; do not add `@Model` types.
- Tests: Swift Testing (`import Testing`, `@Test`, `#expect`) in `ElosTests/`. Run tests from a real terminal (the sandbox pty limit breaks test execution) with `-parallel-testing-enabled NO`.
- Settings sections live in `Features/You/SettingsView.swift`; the Apple Health section (~lines 138–167) is the pattern to copy. The new section goes right after it.
- Readiness sheet: `Features/Train/Readiness/ReadinessCheckInView.swift` renders `vm.healthSnapshot` in `healthMetricsCard`.

### Vendor API facts (verified July 2026)

**Fitbit Web API** (registration is free at dev.fitbit.com; choose app type **Server**):
- OAuth 2.0 authorization-code + PKCE. Authorize: `https://www.fitbit.com/oauth2/authorize`. Token: `https://api.fitbit.com/oauth2/token` (client credentials as HTTP Basic `client_id:client_secret`).
- Access tokens last **8 hours**; refresh tokens are **single-use** (each refresh returns a new refresh token — always persist the new pair atomically).
- Scopes we request: `activity heartrate sleep respiratory_rate cardio_fitness weight`.
- Rate limit: **150 requests/hour per user**. Use range (time-series) endpoints for backfill, not per-day calls.
- Data endpoints (user path `-` = token owner):
  - Steps: `GET /1/user/-/activities/steps/date/{start}/{end}.json` → `{"activities-steps":[{"dateTime":"2026-07-10","value":"8123"}]}`
  - Resting HR: `GET /1/user/-/activities/heart/date/{start}/{end}.json` → per-day `value.restingHeartRate`
  - Sleep: `GET /1.2/user/-/sleep/date/{start}/{end}.json` (max 100 days) → `sleep[]` with `duration` (ms), `isMainSleep`, `levels.summary.{deep,rem,light}.minutes`
  - HRV: `GET /1/user/-/hrv/date/{start}/{end}.json` (max 30 days) → `hrv[].value.dailyRmssd`
  - Calories (activity): part of steps-style time series `activities/calories`.
- Subscriptions API (webhooks): register a **Subscriber endpoint** in the app settings; Fitbit verifies it with two GETs (`?verify=<code>` → respond **204** if the code matches your configured verification code, **404** otherwise). Notifications arrive as `POST` with JSON array `[{collectionType, date, ownerId, subscriptionId}]` — respond 204 fast, then fetch the changed data. Verify `X-Fitbit-Signature` (HMAC-SHA1 of the raw body with key `client_secret&`, base64). Create per-user subscriptions with `POST /1/user/-/{collection}/apiSubscriptions/{subscription-id}.json` for `activities` and `sleep`.
- Note: despite the Google acquisition, the **Fitbit Web API remains the third-party server integration path in 2026**. Google Health Connect is Android on-device only — irrelevant to ELOS iOS. (The user-facing wording "Fitbit uses a Google health API" refers to consumer app changes, not the developer API.)

**Garmin Connect Developer Program — Health API** (apply at developer.garmin.com; **evaluation tier is free** with full API access; production approval costs a one-time fee and is a *launch* gate, not a build gate):
- OAuth 2.0 + PKCE (OAuth 1.0a is retired). Authorize: `https://connect.garmin.com/oauth2Confirm`. Token: `https://diauth.garmin.com/di-oauth2-service/oauth/token`. Refresh tokens are long-lived (~3 months); access tokens short-lived — treat both as opaque and refresh on expiry.
- API base: `https://apis.garmin.com/wellness-api/rest`. Get the stable user id from `GET /user/id` after connecting (notifications identify users by this, not by token).
- Delivery model: **push/ping notifications** — you register callback URLs per summary type in the developer portal; Garmin POSTs either the data itself (push) or a callback URL to pull (ping). Summary types we consume: `dailies` (steps `steps`, `restingHeartRateInBeatsPerMinute`, `activeKilocalories`, `calendarDate`), `sleeps` (`durationInSeconds`, `deepSleepDurationInSeconds`, `remSleepInSeconds`, `lightSleepDurationInSeconds`, `calendarDate`), `hrv` (`lastNightAvg` rmssd).
- Pull endpoints exist for the same types with `uploadStartTimeInSeconds`/`uploadEndTimeInSeconds` params (max 24h window per request): `GET /wellness-api/rest/{dailies|sleeps|hrv}`.
- Backfill: `GET /wellness-api/rest/backfill/{summaryType}?summaryStartTimeInSeconds=&summaryEndTimeInSeconds=` — async; results arrive via the notification endpoints. **Caveat:** the backfill permission is a toggle on Garmin's consent screen and is OFF by default; the UI copy must tell users to enable it.
- ⚠️ Exact field names / endpoint paths above match the public Health API docs, but the authoritative spec is the versioned PDF in the partner portal you get with evaluation access. **Task 7 isolates every Garmin URL and field name in one config/normalizer pair** so corrections after portal access touch exactly two files.

### Design decisions (locked)

1. **Server-side OAuth, app opens browser.** `ASWebAuthenticationSession` can't attach our bearer token, so: authenticated `POST /integrations/:provider/start` returns the vendor authorize URL (state + PKCE verifier persisted server-side, bound to the user); the session opens it; the vendor redirects to the **public** `GET /integrations/:provider/callback`; the server exchanges the code, stores encrypted tokens, triggers backfill, and 302s to `elos://wearables?provider=X&status=connected`, which the session intercepts (scheme `elos`).
2. **Canonical store:** `wearable_daily_metrics` PK `(user_id, provider, day)` with nullable metric columns. Provider shapes are converted at the boundary by pure normalizers. Raw retention is a separate `wearable_raw_payloads` log of verbatim pull responses and webhook bodies — deliberately independent of normalization, so if a normalizer's field names are wrong (the Garmin risk) the original data survives and can be re-normalized after the fix.
3. **Source priority:** server merges across providers (`garmin` > `fitbit`, newer `updated_at` breaks ties within a metric); phone merges backend result with HealthKit (`wearable` > `healthKit`). Every metric served/displayed carries its source. HealthKit ingestion of watch-synced duplicates is avoided because the merged value simply prefers the wearable source — no double counting.
4. **Tokens encrypted at rest** with AES-256-GCM (`WEARABLE_TOKEN_KEY`, 32-byte base64, generated per environment).
5. **No cron infra exists — don't build one.** Freshness comes from: (a) webhooks in production, (b) on-demand refresh — `GET /wearables/daily` triggers a lazy sync if a connection is stale > 30 min (fire-and-forget), (c) explicit `POST /integrations/:provider/sync` from the app on foreground. Token refresh happens lazily on use.
6. **Feature flag:** `FeatureFlags.wearableIntegrations` (new file, mobile). Ship dark until Garmin production approval; Fitbit can launch first if desired.

### File map

**Create (elos-api):**
- `migrations/040_create_wearable_integrations.sql`
- `src/lib/tokenCrypto.ts` (+ `src/lib/__tests__/tokenCrypto.test.ts`)
- `src/services/wearables/types.ts` — canonical `DailyMetrics`, provider ids
- `src/services/wearables/normalize.ts` (+ `__tests__/normalize.test.ts`) — pure provider→canonical converters
- `src/services/wearables/merge.ts` (+ `__tests__/merge.test.ts`) — pure cross-provider merge with sources
- `src/services/wearables/fitbitClient.ts` — OAuth + data fetch, all Fitbit URLs/shapes
- `src/services/wearables/garminClient.ts` — OAuth + data fetch, all Garmin URLs/shapes
- `src/services/wearableService.ts` — connections CRUD, sync, token refresh, metric upserts/reads
- `src/routes/integrations.ts` — start/callback/list/disconnect/sync
- `src/routes/wearableWebhooks.ts` — Fitbit verify+notify, Garmin push
- `src/routes/wearables.ts` — `GET /wearables/daily`

**Modify (elos-api):** `src/index.ts` (mounts), `src/schemas.ts` (zod), `src/lib/env.ts` (+ vars), `.env.example`
**Modify (elos-shared):** `packages/elos-shared/src/index.ts` (contract types)

**Create (elos-mobile, under `Elos/Elos/`):**
- `Utils/FeatureFlags.swift`
- `Features/You/Wearables/WearableModels.swift` — pure types + HealthKit merge (+ `ElosTests/WearableModelsTests.swift`)
- `Services/WearableService.swift` — thin API wrapper + `ASWebAuthenticationSession` connect flow
- `Features/You/Wearables/ConnectedDevicesView.swift`

**Modify (elos-mobile):** `AppViewModel.swift` (state + refresh), `Features/You/SettingsView.swift` (nav row), `Features/Train/Readiness/ReadinessCheckInView.swift` (merged card with sources)

---

## Phase 0 — Accounts & configuration (human prerequisites)

### Task 1: Register vendor apps and configure env

Manual steps (Frank). Nothing downstream compiles against real credentials, so development can proceed in parallel using the placeholder env values — but callbacks/webhooks can't be exercised end-to-end until this lands.

- [ ] **Step 1: Fitbit.** Create an app at https://dev.fitbit.com/apps → type **Server**. Redirect URL: `https://elos.onrender.com/integrations/fitbit/callback` (add `http://localhost:3000/integrations/fitbit/callback` in a second dev app for local testing). Note client id + secret. In app settings, add Subscriber endpoint `https://elos.onrender.com/webhooks/fitbit` with a chosen **verification code** — do this *after* Task 11 deploys (Fitbit pings the URL immediately); it can wait.
- [ ] **Step 2: Garmin.** Apply for the Connect Developer Program (evaluation) at https://developer.garmin.com/gc-developer-program/ → business use case: consumer fitness app readiness features. On approval, create the app, note client id + secret, set OAuth redirect `https://elos.onrender.com/integrations/garmin/callback`, and register notification callback URLs for `dailies`, `sleeps`, `hrv` → `https://elos.onrender.com/webhooks/garmin`. Download the Health API spec PDF and **diff its endpoint paths/field names against `garminClient.ts` + `normalize.ts`** (Task 7 flags the exact spots).
- [ ] **Step 3: Generate token key:** `openssl rand -base64 32` → `WEARABLE_TOKEN_KEY`.
- [ ] **Step 4: Set env on Render and in local `.env`:**

```
WEARABLE_TOKEN_KEY=<base64 32 bytes>
FITBIT_CLIENT_ID=...
FITBIT_CLIENT_SECRET=...
FITBIT_VERIFICATION_CODE=...           # from the Fitbit subscriber settings
GARMIN_CLIENT_ID=...
GARMIN_CLIENT_SECRET=...
API_PUBLIC_URL=https://elos.onrender.com   # http://localhost:3000 locally
```

---

## Phase 1 — Backend (elos-api). All commands run from `apps/elos-api`.

### Task 2: Migration — connections, oauth states, daily metrics

**Files:**
- Create: `migrations/040_create_wearable_integrations.sql`

- [ ] **Step 1: Confirm next migration number:** `ls migrations/ | sort | tail -1` → expect `039_...`. If not, renumber accordingly.
- [ ] **Step 2: Write the migration**

```sql
-- Wearable vendor integrations (Garmin / Fitbit): OAuth connections,
-- in-flight OAuth state, and the canonical normalized daily-metrics store.

CREATE TABLE wearable_connections (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL,
  provider TEXT NOT NULL CHECK (provider IN ('garmin', 'fitbit')),
  -- Vendor's stable user id (Garmin notifications identify users by this).
  provider_user_id TEXT NOT NULL DEFAULT '',
  access_token_enc TEXT NOT NULL,
  refresh_token_enc TEXT NOT NULL,
  access_token_expires_at TIMESTAMPTZ NOT NULL,
  scopes TEXT NOT NULL DEFAULT '',
  status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'error')),
  last_synced_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (user_id, provider)
);
CREATE INDEX idx_wearable_conn_provider_user
  ON wearable_connections (provider, provider_user_id);

-- One row per in-flight OAuth attempt; state is the CSRF token AND the lookup key.
CREATE TABLE wearable_oauth_states (
  state TEXT PRIMARY KEY,
  user_id UUID NOT NULL,
  provider TEXT NOT NULL CHECK (provider IN ('garmin', 'fitbit')),
  code_verifier TEXT NOT NULL,
  expires_at TIMESTAMPTZ NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE wearable_daily_metrics (
  user_id UUID NOT NULL,
  provider TEXT NOT NULL CHECK (provider IN ('garmin', 'fitbit')),
  day DATE NOT NULL,
  steps INTEGER,
  resting_heart_rate REAL,
  hrv_ms REAL,
  sleep_seconds INTEGER,
  sleep_deep_seconds INTEGER,
  sleep_rem_seconds INTEGER,
  sleep_light_seconds INTEGER,
  active_kcal REAL,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, provider, day)
);
CREATE INDEX idx_wearable_daily_user_day ON wearable_daily_metrics (user_id, day);

-- Verbatim vendor payloads (pull responses and webhook bodies), retained so data
-- can be re-normalized after field-name corrections. Independent of normalization
-- success on purpose. Prune periodically (90 days is plenty).
CREATE TABLE wearable_raw_payloads (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  user_id UUID NOT NULL,
  provider TEXT NOT NULL CHECK (provider IN ('garmin', 'fitbit')),
  kind TEXT NOT NULL CHECK (kind IN ('pull', 'push')),
  payload JSONB NOT NULL,
  received_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_wearable_raw_user ON wearable_raw_payloads (user_id, provider, received_at);
```

- [ ] **Step 3: Apply and verify:** `npm run migrate` → expect `Applying migration: 040_create_wearable_integrations.sql … Migrations complete.`
- [ ] **Step 4: Commit:** `git add migrations/040_create_wearable_integrations.sql && git commit -m "feat(api): wearable integration tables"`

### Task 3: Token encryption helper (TDD)

**Files:**
- Create: `src/lib/tokenCrypto.ts`
- Test: `src/lib/__tests__/tokenCrypto.test.ts`

- [ ] **Step 1: Write the failing test**

```typescript
import { describe, it, expect, beforeAll } from "vitest";
import { randomBytes } from "crypto";
import { encryptToken, decryptToken } from "../tokenCrypto";

beforeAll(() => {
  process.env.WEARABLE_TOKEN_KEY = randomBytes(32).toString("base64");
});

describe("tokenCrypto", () => {
  it("round-trips a token", () => {
    const enc = encryptToken("secret-access-token");
    expect(enc).not.toContain("secret-access-token");
    expect(decryptToken(enc)).toBe("secret-access-token");
  });

  it("produces distinct ciphertexts for the same plaintext (fresh IV)", () => {
    expect(encryptToken("same")).not.toBe(encryptToken("same"));
  });

  it("rejects tampered ciphertext", () => {
    const enc = encryptToken("secret");
    const parts = enc.split(":");
    parts[2] = Buffer.from("tampered!").toString("base64");
    expect(() => decryptToken(parts.join(":"))).toThrow();
  });
});
```

- [ ] **Step 2: Run to verify failure:** `npm test -- tokenCrypto` → FAIL (module not found).
- [ ] **Step 3: Implement**

```typescript
import { createCipheriv, createDecipheriv, randomBytes } from "crypto";

/**
 * AES-256-GCM for OAuth tokens at rest. Format: "iv:authTag:ciphertext" (base64 fields).
 * Key: WEARABLE_TOKEN_KEY, 32 bytes base64 (openssl rand -base64 32).
 */
function key(): Buffer {
  const raw = process.env.WEARABLE_TOKEN_KEY;
  if (!raw) throw new Error("WEARABLE_TOKEN_KEY is not set");
  const buf = Buffer.from(raw, "base64");
  if (buf.length !== 32) throw new Error("WEARABLE_TOKEN_KEY must be 32 bytes base64");
  return buf;
}

export function encryptToken(plaintext: string): string {
  const iv = randomBytes(12);
  const cipher = createCipheriv("aes-256-gcm", key(), iv);
  const enc = Buffer.concat([cipher.update(plaintext, "utf8"), cipher.final()]);
  return [iv.toString("base64"), cipher.getAuthTag().toString("base64"), enc.toString("base64")].join(":");
}

export function decryptToken(encoded: string): string {
  const [ivB64, tagB64, dataB64] = encoded.split(":");
  if (!ivB64 || !tagB64 || !dataB64) throw new Error("malformed encrypted token");
  const decipher = createDecipheriv("aes-256-gcm", key(), Buffer.from(ivB64, "base64"));
  decipher.setAuthTag(Buffer.from(tagB64, "base64"));
  return Buffer.concat([decipher.update(Buffer.from(dataB64, "base64")), decipher.final()]).toString("utf8");
}
```

- [ ] **Step 4: Run:** `npm test -- tokenCrypto` → PASS.
- [ ] **Step 5: Commit:** `git add src/lib/tokenCrypto.ts src/lib/__tests__/tokenCrypto.test.ts && git commit -m "feat(api): AES-256-GCM token encryption for wearable oauth"`

### Task 4: Canonical types, shared contracts, zod schemas

**Files:**
- Create: `src/services/wearables/types.ts`
- Modify: `packages/elos-shared/src/index.ts` (append)
- Modify: `src/schemas.ts` (append)

- [ ] **Step 1: Create `src/services/wearables/types.ts`**

```typescript
export type WearableProvider = "garmin" | "fitbit";
export const WEARABLE_PROVIDERS: WearableProvider[] = ["garmin", "fitbit"];

/** Canonical per-day metrics; provider payloads are converted to this at the boundary. */
export interface DailyMetrics {
  day: string; // YYYY-MM-DD (user-local calendar date as reported by the vendor)
  steps?: number;
  restingHeartRate?: number;
  hrvMs?: number; // rmssd, ms
  sleepSeconds?: number;
  sleepDeepSeconds?: number;
  sleepRemSeconds?: number;
  sleepLightSeconds?: number;
  activeKcal?: number;
}

```

- [ ] **Step 2: Append contracts to `packages/elos-shared/src/index.ts`** (client-facing shapes; snake_case matches the rest of the API surface)

```typescript
// ---- Wearable integrations ----
export type WearableProvider = "garmin" | "fitbit";

export interface WearableConnectionInfo {
  provider: WearableProvider;
  status: "active" | "error";
  connected_at: string;
  last_synced_at: string | null;
}

export interface WearableConnectStart {
  authorize_url: string;
}

/** One merged day; each present metric names the provider that supplied it. */
export interface WearableDailyMetrics {
  day: string;
  steps?: number;
  resting_heart_rate?: number;
  hrv_ms?: number;
  sleep_seconds?: number;
  sleep_deep_seconds?: number;
  sleep_rem_seconds?: number;
  sleep_light_seconds?: number;
  active_kcal?: number;
  sources: Record<string, WearableProvider>;
}
```

- [ ] **Step 3: Append to `src/schemas.ts`**

```typescript
export const wearableProviderSchema = z.enum(["garmin", "fitbit"]);

export const wearableDailyQuerySchema = z.object({
  start: z.string().regex(/^\d{4}-\d{2}-\d{2}$/),
  end: z.string().regex(/^\d{4}-\d{2}-\d{2}$/),
});

export const wearableSyncSchema = z.object({
  days: z.number().int().min(1).max(30).optional(),
});
```

- [ ] **Step 4: Typecheck both packages:** `npx tsc --noEmit` in `apps/elos-api` and `packages/elos-shared`.
- [ ] **Step 5: Commit:** `git add -A && git commit -m "feat(api,shared): wearable canonical types, contracts, schemas"`

### Task 5: Pure normalizers (TDD)

**Files:**
- Create: `src/services/wearables/normalize.ts`
- Test: `src/services/wearables/__tests__/normalize.test.ts`

- [ ] **Step 1: Write the failing tests** (fixtures are trimmed real response shapes — keep them verbatim; they document the vendor contract)

```typescript
import { describe, it, expect } from "vitest";
import {
  normalizeFitbitSteps, normalizeFitbitHeart, normalizeFitbitSleep, normalizeFitbitHrv,
  normalizeGarminDaily, normalizeGarminSleep, normalizeGarminHrv, mergeDayFragments,
} from "../normalize";

describe("fitbit normalizers", () => {
  it("steps time series → {day, steps}", () => {
    const json = { "activities-steps": [{ dateTime: "2026-07-10", value: "8123" }] };
    expect(normalizeFitbitSteps(json)).toEqual([{ day: "2026-07-10", steps: 8123 }]);
  });

  it("heart series → resting HR, skipping days without one", () => {
    const json = { "activities-heart": [
      { dateTime: "2026-07-10", value: { restingHeartRate: 52 } },
      { dateTime: "2026-07-09", value: {} },
    ]};
    expect(normalizeFitbitHeart(json)).toEqual([{ day: "2026-07-10", restingHeartRate: 52 }]);
  });

  it("sleep log → main-sleep duration and stages in seconds", () => {
    const json = { sleep: [{
      dateOfSleep: "2026-07-10", isMainSleep: true, duration: 27000000, // ms
      levels: { summary: { deep: { minutes: 90 }, rem: { minutes: 100 }, light: { minutes: 250 } } },
    }, { dateOfSleep: "2026-07-10", isMainSleep: false, duration: 1200000, levels: {} }]};
    expect(normalizeFitbitSleep(json)).toEqual([{
      day: "2026-07-10", sleepSeconds: 27000, sleepDeepSeconds: 5400,
      sleepRemSeconds: 6000, sleepLightSeconds: 15000,
    }]);
  });

  it("hrv → dailyRmssd", () => {
    const json = { hrv: [{ dateTime: "2026-07-10", value: { dailyRmssd: 62.5 } }] };
    expect(normalizeFitbitHrv(json)).toEqual([{ day: "2026-07-10", hrvMs: 62.5 }]);
  });
});

describe("garmin normalizers", () => {
  it("dailies → steps, resting HR, active kcal", () => {
    const summaries = [{ calendarDate: "2026-07-10", steps: 9042,
      restingHeartRateInBeatsPerMinute: 49, activeKilocalories: 512 }];
    expect(normalizeGarminDaily(summaries)).toEqual([{
      day: "2026-07-10", steps: 9042, restingHeartRate: 49, activeKcal: 512,
    }]);
  });

  it("sleeps → duration + stages", () => {
    const summaries = [{ calendarDate: "2026-07-10", durationInSeconds: 26100,
      deepSleepDurationInSeconds: 5000, remSleepInSeconds: 6100, lightSleepDurationInSeconds: 15000 }];
    expect(normalizeGarminSleep(summaries)).toEqual([{
      day: "2026-07-10", sleepSeconds: 26100, sleepDeepSeconds: 5000,
      sleepRemSeconds: 6100, sleepLightSeconds: 15000,
    }]);
  });

  it("hrv → lastNightAvg", () => {
    const summaries = [{ calendarDate: "2026-07-10", lastNightAvg: 58 }];
    expect(normalizeGarminHrv(summaries)).toEqual([{ day: "2026-07-10", hrvMs: 58 }]);
  });
});

describe("mergeDayFragments", () => {
  it("combines fragments for the same day into one DailyMetrics", () => {
    const merged = mergeDayFragments([
      { day: "2026-07-10", steps: 8123 },
      { day: "2026-07-10", restingHeartRate: 52 },
      { day: "2026-07-09", steps: 100 },
    ]);
    expect(merged).toEqual([
      { day: "2026-07-09", steps: 100 },
      { day: "2026-07-10", steps: 8123, restingHeartRate: 52 },
    ]);
  });
});
```

- [ ] **Step 2: Run:** `npm test -- normalize` → FAIL.
- [ ] **Step 3: Implement `normalize.ts`** — pure functions, no IO. Defensive on missing fields (return partial objects, drop days with no data). `mergeDayFragments` groups by `day`, `Object.assign`s fragments, returns sorted by day.

```typescript
import { DailyMetrics } from "./types";

const min2sec = (m: number | undefined) => (m == null ? undefined : Math.round(m * 60));

export function normalizeFitbitSteps(json: any): DailyMetrics[] {
  return (json?.["activities-steps"] ?? [])
    .filter((r: any) => r?.dateTime && r?.value != null)
    .map((r: any) => ({ day: r.dateTime, steps: parseInt(r.value, 10) }));
}

export function normalizeFitbitHeart(json: any): DailyMetrics[] {
  return (json?.["activities-heart"] ?? [])
    .filter((r: any) => r?.dateTime && r?.value?.restingHeartRate != null)
    .map((r: any) => ({ day: r.dateTime, restingHeartRate: r.value.restingHeartRate }));
}

export function normalizeFitbitSleep(json: any): DailyMetrics[] {
  const mains = (json?.sleep ?? []).filter((s: any) => s?.isMainSleep && s?.dateOfSleep);
  return mains.map((s: any) => {
    const sum = s.levels?.summary ?? {};
    const out: DailyMetrics = { day: s.dateOfSleep, sleepSeconds: Math.round((s.duration ?? 0) / 1000) };
    if (sum.deep?.minutes != null) out.sleepDeepSeconds = min2sec(sum.deep.minutes);
    if (sum.rem?.minutes != null) out.sleepRemSeconds = min2sec(sum.rem.minutes);
    if (sum.light?.minutes != null) out.sleepLightSeconds = min2sec(sum.light.minutes);
    return out;
  });
}

export function normalizeFitbitHrv(json: any): DailyMetrics[] {
  return (json?.hrv ?? [])
    .filter((r: any) => r?.dateTime && r?.value?.dailyRmssd != null)
    .map((r: any) => ({ day: r.dateTime, hrvMs: r.value.dailyRmssd }));
}

// Garmin summaries arrive as arrays (both from pull endpoints and push payloads).
export function normalizeGarminDaily(summaries: any[]): DailyMetrics[] {
  return (summaries ?? [])
    .filter((s) => s?.calendarDate)
    .map((s) => {
      const out: DailyMetrics = { day: s.calendarDate };
      if (s.steps != null) out.steps = s.steps;
      if (s.restingHeartRateInBeatsPerMinute != null) out.restingHeartRate = s.restingHeartRateInBeatsPerMinute;
      if (s.activeKilocalories != null) out.activeKcal = s.activeKilocalories;
      return out;
    });
}

export function normalizeGarminSleep(summaries: any[]): DailyMetrics[] {
  return (summaries ?? [])
    .filter((s) => s?.calendarDate && s?.durationInSeconds != null)
    .map((s) => {
      const out: DailyMetrics = { day: s.calendarDate, sleepSeconds: s.durationInSeconds };
      if (s.deepSleepDurationInSeconds != null) out.sleepDeepSeconds = s.deepSleepDurationInSeconds;
      if (s.remSleepInSeconds != null) out.sleepRemSeconds = s.remSleepInSeconds;
      if (s.lightSleepDurationInSeconds != null) out.sleepLightSeconds = s.lightSleepDurationInSeconds;
      return out;
    });
}

export function normalizeGarminHrv(summaries: any[]): DailyMetrics[] {
  return (summaries ?? [])
    .filter((s) => s?.calendarDate && s?.lastNightAvg != null)
    .map((s) => ({ day: s.calendarDate, hrvMs: s.lastNightAvg }));
}

/** Combine per-metric fragments for the same day into single DailyMetrics rows. */
export function mergeDayFragments(fragments: DailyMetrics[]): DailyMetrics[] {
  const byDay = new Map<string, DailyMetrics>();
  for (const f of fragments) {
    byDay.set(f.day, { ...(byDay.get(f.day) ?? { day: f.day }), ...f });
  }
  return [...byDay.values()].sort((a, b) => a.day.localeCompare(b.day));
}
```

- [ ] **Step 4: Run:** `npm test -- normalize` → PASS.
- [ ] **Step 5: Commit:** `git commit -am "feat(api): pure wearable payload normalizers"`

### Task 6: Cross-provider merge with source attribution (TDD)

**Files:**
- Create: `src/services/wearables/merge.ts`
- Test: `src/services/wearables/__tests__/merge.test.ts`

- [ ] **Step 1: Write the failing tests**

```typescript
import { describe, it, expect } from "vitest";
import { mergeAcrossProviders, MetricRow } from "../merge";
import { WearableProvider } from "../types";

/** Build a MetricRow (the snake_case shape SQL returns) with all metrics null unless overridden. */
function row(provider: WearableProvider, day: string, m: Partial<MetricRow> = {}): MetricRow {
  return {
    provider, day,
    steps: null, resting_heart_rate: null, hrv_ms: null, sleep_seconds: null,
    sleep_deep_seconds: null, sleep_rem_seconds: null, sleep_light_seconds: null,
    active_kcal: null, ...m,
  };
}

describe("mergeAcrossProviders", () => {
  it("prefers garmin when both report the same metric", () => {
    const out = mergeAcrossProviders([
      row("garmin", "2026-07-10", { steps: 9000 }),
      row("fitbit", "2026-07-10", { steps: 8000 }),
    ]);
    expect(out[0].steps).toBe(9000);
    expect(out[0].sources.steps).toBe("garmin");
  });

  it("fills gaps from the lower-priority provider per metric", () => {
    const out = mergeAcrossProviders([
      row("garmin", "2026-07-10", { steps: 9000 }),
      row("fitbit", "2026-07-10", { resting_heart_rate: 55 }),
    ]);
    expect(out[0].steps).toBe(9000);
    expect(out[0].resting_heart_rate).toBe(55);
    expect(out[0].sources).toEqual({ steps: "garmin", resting_heart_rate: "fitbit" });
  });

  it("returns one row per day, sorted ascending", () => {
    const out = mergeAcrossProviders([
      row("garmin", "2026-07-10", { steps: 1 }),
      row("garmin", "2026-07-09", { steps: 2 }),
    ]);
    expect(out.map((d) => d.day)).toEqual(["2026-07-09", "2026-07-10"]);
  });
});
```

The merge input is the **snake_case stored row shape** (`MetricRow`, defined in Step 3) — the service reads SQL rows and serves `WearableDailyMetrics` directly, so merge operates on rows.

- [ ] **Step 2: Run:** `npm test -- merge` → FAIL.
- [ ] **Step 3: Implement `merge.ts`**

```typescript
import { WearableDailyMetrics, WearableProvider } from "elos-shared";

/** Row shape as read from wearable_daily_metrics (snake_case, per provider). */
export interface MetricRow {
  provider: WearableProvider;
  day: string;
  steps: number | null;
  resting_heart_rate: number | null;
  hrv_ms: number | null;
  sleep_seconds: number | null;
  sleep_deep_seconds: number | null;
  sleep_rem_seconds: number | null;
  sleep_light_seconds: number | null;
  active_kcal: number | null;
  updatedAt?: string;
}

const METRIC_KEYS = [
  "steps", "resting_heart_rate", "hrv_ms", "sleep_seconds", "sleep_deep_seconds",
  "sleep_rem_seconds", "sleep_light_seconds", "active_kcal",
] as const;

/** Connected-wearable priority. Garmin over Fitbit (spec R4). */
const PRIORITY: WearableProvider[] = ["garmin", "fitbit"];

export function mergeAcrossProviders(rows: MetricRow[]): WearableDailyMetrics[] {
  const byDay = new Map<string, MetricRow[]>();
  for (const row of rows) {
    byDay.set(row.day, [...(byDay.get(row.day) ?? []), row]);
  }
  const out: WearableDailyMetrics[] = [];
  for (const [day, dayRows] of byDay) {
    const ranked = [...dayRows].sort(
      (a, b) => PRIORITY.indexOf(a.provider) - PRIORITY.indexOf(b.provider)
    );
    const merged: WearableDailyMetrics = { day, sources: {} };
    for (const key of METRIC_KEYS) {
      for (const row of ranked) {
        const value = row[key];
        if (value != null) {
          (merged as any)[key] = value;
          merged.sources[key] = row.provider;
          break;
        }
      }
    }
    out.push(merged);
  }
  return out.sort((a, b) => a.day.localeCompare(b.day));
}
```

- [ ] **Step 4: Run:** `npm test -- merge` → PASS.
- [ ] **Step 5: Commit:** `git commit -am "feat(api): cross-provider daily-metric merge with source attribution"`

### Task 7: Provider clients (Fitbit + Garmin)

**Files:**
- Create: `src/services/wearables/fitbitClient.ts`
- Create: `src/services/wearables/garminClient.ts`
- Test: `src/services/wearables/__tests__/clients.test.ts` (URL builders + parsing only — network functions stay thin and untested per house style)

Both clients expose the same interface so `wearableService` is provider-generic:

```typescript
export interface TokenSet {
  accessToken: string;
  refreshToken: string;
  expiresAt: Date;       // now + expires_in
  scopes: string;
  providerUserId?: string;
}
export interface FetchDailyResult {
  metrics: DailyMetrics[];
  /** Verbatim vendor responses keyed by metric group — logged to wearable_raw_payloads. */
  raw: Record<string, unknown>;
}
export interface ProviderClient {
  authorizeUrl(state: string, codeChallenge: string): string;
  exchangeCode(code: string, codeVerifier: string): Promise<TokenSet>;
  refresh(refreshToken: string): Promise<TokenSet>;
  /** Pull all supported metrics for [startDay, endDay] (YYYY-MM-DD, inclusive): normalized + raw. */
  fetchDaily(accessToken: string, startDay: string, endDay: string): Promise<FetchDailyResult>;
  /** Best-effort vendor-side revocation / subscription cleanup on disconnect. */
  revoke(accessToken: string): Promise<void>;
  /** Post-connect hook: fetch provider user id, create webhook subscriptions, request backfill. */
  afterConnect(accessToken: string, userIdForSubscription: string): Promise<{ providerUserId: string }>;
}
```

- [ ] **Step 1: Implement `fitbitClient.ts`**

```typescript
import { DailyMetrics } from "./types";
import {
  normalizeFitbitSteps, normalizeFitbitHeart, normalizeFitbitSleep,
  normalizeFitbitHrv, mergeDayFragments,
} from "./normalize";

const AUTHORIZE_URL = "https://www.fitbit.com/oauth2/authorize";
const TOKEN_URL = "https://api.fitbit.com/oauth2/token";
const API = "https://api.fitbit.com";
export const FITBIT_SCOPES = "activity heartrate sleep respiratory_rate cardio_fitness weight";

const env = () => ({
  id: process.env.FITBIT_CLIENT_ID!,
  secret: process.env.FITBIT_CLIENT_SECRET!,
  redirect: `${process.env.API_PUBLIC_URL}/integrations/fitbit/callback`,
});

const basicAuth = () =>
  "Basic " + Buffer.from(`${env().id}:${env().secret}`).toString("base64");

export function authorizeUrl(state: string, codeChallenge: string): string {
  const q = new URLSearchParams({
    response_type: "code", client_id: env().id, redirect_uri: env().redirect,
    scope: FITBIT_SCOPES, state, code_challenge: codeChallenge, code_challenge_method: "S256",
  });
  return `${AUTHORIZE_URL}?${q}`;
}

async function tokenRequest(params: Record<string, string>) {
  const res = await fetch(TOKEN_URL, {
    method: "POST",
    headers: { Authorization: basicAuth(), "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams(params),
  });
  if (!res.ok) throw new Error(`fitbit token endpoint ${res.status}: ${await res.text()}`);
  const j: any = await res.json();
  return {
    accessToken: j.access_token, refreshToken: j.refresh_token,
    expiresAt: new Date(Date.now() + j.expires_in * 1000),
    scopes: j.scope ?? "", providerUserId: j.user_id,
  };
}

export const exchangeCode = (code: string, codeVerifier: string) =>
  tokenRequest({ grant_type: "authorization_code", code, code_verifier: codeVerifier, redirect_uri: env().redirect, client_id: env().id });

export const refresh = (refreshToken: string) =>
  tokenRequest({ grant_type: "refresh_token", refresh_token: refreshToken });

async function apiGet(accessToken: string, path: string): Promise<any> {
  const res = await fetch(`${API}${path}`, { headers: { Authorization: `Bearer ${accessToken}` } });
  if (res.status === 429) throw new Error("fitbit rate limited");
  if (!res.ok) throw new Error(`fitbit ${path} ${res.status}`);
  return res.json();
}

/** Range endpoints keep backfill within the 150 req/hr/user budget (4 calls per sync). */
export async function fetchDaily(accessToken: string, startDay: string, endDay: string) {
  const [steps, heart, sleep, hrv] = await Promise.all([
    apiGet(accessToken, `/1/user/-/activities/steps/date/${startDay}/${endDay}.json`),
    apiGet(accessToken, `/1/user/-/activities/heart/date/${startDay}/${endDay}.json`),
    apiGet(accessToken, `/1.2/user/-/sleep/date/${startDay}/${endDay}.json`),
    apiGet(accessToken, `/1/user/-/hrv/date/${startDay}/${endDay}.json`).catch(() => ({ hrv: [] })), // scope may be denied
  ]);
  return {
    metrics: mergeDayFragments([
      ...normalizeFitbitSteps(steps), ...normalizeFitbitHeart(heart),
      ...normalizeFitbitSleep(sleep), ...normalizeFitbitHrv(hrv),
    ]),
    raw: { steps, heart, sleep, hrv },
  };
}

export async function revoke(accessToken: string): Promise<void> {
  await fetch(`${API}/oauth2/revoke`, {
    method: "POST",
    headers: { Authorization: basicAuth(), "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({ token: accessToken }),
  }).catch(() => undefined);
}

/** Subscribe to activities + sleep notifications; subscription id = our user id. */
export async function afterConnect(accessToken: string, userId: string) {
  for (const collection of ["activities", "sleep"]) {
    await fetch(`${API}/1/user/-/${collection}/apiSubscriptions/${userId}.json`, {
      method: "POST", headers: { Authorization: `Bearer ${accessToken}` },
    }).catch(() => undefined); // webhook subscription is best-effort; pull path still works
  }
  const profile = await apiGet(accessToken, "/1/user/-/profile.json");
  return { providerUserId: profile?.user?.encodedId ?? "" };
}
```

- [ ] **Step 2: Implement `garminClient.ts`** — same interface. **Every URL and the consent caveat live in the `GARMIN` config object below — this is the single place to correct after the partner-portal spec PDF is available (Task 1 Step 2).**

```typescript
import { DailyMetrics } from "./types";
import { normalizeGarminDaily, normalizeGarminSleep, normalizeGarminHrv, mergeDayFragments } from "./normalize";

/** ⚠️ Verify against the partner-portal Health API spec PDF once evaluation access is granted. */
const GARMIN = {
  authorizeUrl: "https://connect.garmin.com/oauth2Confirm",
  tokenUrl: "https://diauth.garmin.com/di-oauth2-service/oauth/token",
  api: "https://apis.garmin.com/wellness-api/rest",
  pull: { dailies: "/dailies", sleeps: "/sleeps", hrv: "/hrv" },
  backfill: ["dailies", "sleeps", "hrv"],
  maxPullWindowSec: 24 * 3600, // pull endpoints accept at most 24h upload windows
};

const env = () => ({
  id: process.env.GARMIN_CLIENT_ID!,
  secret: process.env.GARMIN_CLIENT_SECRET!,
  redirect: `${process.env.API_PUBLIC_URL}/integrations/garmin/callback`,
});

export function authorizeUrl(state: string, codeChallenge: string): string {
  const q = new URLSearchParams({
    response_type: "code", client_id: env().id, redirect_uri: env().redirect,
    state, code_challenge: codeChallenge, code_challenge_method: "S256",
  });
  return `${GARMIN.authorizeUrl}?${q}`;
}

async function tokenRequest(params: Record<string, string>) {
  const res = await fetch(GARMIN.tokenUrl, {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({ client_id: env().id, client_secret: env().secret, ...params }),
  });
  if (!res.ok) throw new Error(`garmin token endpoint ${res.status}: ${await res.text()}`);
  const j: any = await res.json();
  return {
    accessToken: j.access_token, refreshToken: j.refresh_token,
    expiresAt: new Date(Date.now() + j.expires_in * 1000), scopes: j.scope ?? "",
  };
}

export const exchangeCode = (code: string, codeVerifier: string) =>
  tokenRequest({ grant_type: "authorization_code", code, code_verifier: codeVerifier, redirect_uri: env().redirect });

export const refresh = (refreshToken: string) =>
  tokenRequest({ grant_type: "refresh_token", refresh_token: refreshToken });

async function apiGet(accessToken: string, path: string, params: Record<string, string>): Promise<any> {
  const res = await fetch(`${GARMIN.api}${path}?${new URLSearchParams(params)}`, {
    headers: { Authorization: `Bearer ${accessToken}` },
  });
  if (!res.ok) throw new Error(`garmin ${path} ${res.status}`);
  return res.json();
}

/** Pull in 24h upload-window slices (Garmin's max), then normalize + merge.
 *  Raw summaries are accumulated verbatim so re-normalization survives field-name fixes. */
export async function fetchDaily(accessToken: string, startDay: string, endDay: string) {
  const startSec = Math.floor(Date.parse(`${startDay}T00:00:00Z`) / 1000);
  const endSec = Math.floor(Date.parse(`${endDay}T23:59:59Z`) / 1000);
  const fragments: DailyMetrics[] = [];
  const rawAll = { dailies: [] as unknown[], sleeps: [] as unknown[], hrv: [] as unknown[] };
  for (let t = startSec; t < endSec; t += GARMIN.maxPullWindowSec) {
    const win = {
      uploadStartTimeInSeconds: String(t),
      uploadEndTimeInSeconds: String(Math.min(t + GARMIN.maxPullWindowSec, endSec)),
    };
    const [dailies, sleeps, hrv] = await Promise.all([
      apiGet(accessToken, GARMIN.pull.dailies, win).catch(() => []),
      apiGet(accessToken, GARMIN.pull.sleeps, win).catch(() => []),
      apiGet(accessToken, GARMIN.pull.hrv, win).catch(() => []),
    ]);
    // Push the verbatim window responses — no shape assumptions, so raw survives
    // even if the normalizers' expectations turn out wrong.
    rawAll.dailies.push(dailies);
    rawAll.sleeps.push(sleeps);
    rawAll.hrv.push(hrv);
    fragments.push(...normalizeGarminDaily(dailies), ...normalizeGarminSleep(sleeps), ...normalizeGarminHrv(hrv));
  }
  return { metrics: mergeDayFragments(fragments), raw: rawAll };
}

export async function revoke(accessToken: string): Promise<void> {
  // Garmin: user deregistration endpoint per spec; best-effort.
  await fetch(`${GARMIN.api}/user/registration`, {
    method: "DELETE", headers: { Authorization: `Bearer ${accessToken}` },
  }).catch(() => undefined);
}

export async function afterConnect(accessToken: string, _userId: string) {
  const idResp: any = await apiGet(accessToken, "/user/id", {}).catch(() => ({}));
  // Kick async backfill for the last 30 days; results arrive via webhooks in prod.
  const end = Math.floor(Date.now() / 1000);
  const start = end - 30 * 86400;
  for (const type of GARMIN.backfill) {
    await fetch(`${GARMIN.api}/backfill/${type}?summaryStartTimeInSeconds=${start}&summaryEndTimeInSeconds=${end}`, {
      headers: { Authorization: `Bearer ${accessToken}` },
    }).catch(() => undefined);
  }
  return { providerUserId: idResp?.userId ?? "" };
}
```

- [ ] **Step 3: Write `__tests__/clients.test.ts`** asserting: `authorizeUrl` for each provider contains `response_type=code`, the right host, `state`, `code_challenge_method=S256`; Fitbit URL contains the scope string. (Set the env vars in `beforeAll`.) Run: `npm test -- clients` → PASS.
- [ ] **Step 4: Typecheck:** `npx tsc --noEmit`.
- [ ] **Step 5: Commit:** `git add src/services/wearables && git commit -m "feat(api): fitbit + garmin provider clients (oauth, pull, webhook hooks)"`

### Task 8: wearableService

**Files:**
- Create: `src/services/wearableService.ts`
- Test: `src/services/__tests__/wearableService.test.ts`

The service is the only layer that touches the DB and the clients. Full implementation:

```typescript
import { randomBytes, createHash } from "crypto";
import { pool } from "../db";
import { badRequest, notFound } from "../lib/httpError";
import { logger } from "../lib/logger";
import { encryptToken, decryptToken } from "../lib/tokenCrypto";
import { WearableProvider, DailyMetrics } from "./wearables/types";
import { mergeAcrossProviders, MetricRow } from "./wearables/merge";
import * as fitbit from "./wearables/fitbitClient";
import * as garmin from "./wearables/garminClient";
import type { WearableConnectionInfo, WearableDailyMetrics } from "elos-shared";

const clients = { fitbit, garmin } as const;
const STATE_TTL_MIN = 10;
const STALE_SYNC_MIN = 30;

// ---- OAuth flow ----

export async function startConnect(userId: string, provider: WearableProvider): Promise<string> {
  const state = randomBytes(24).toString("base64url");
  const verifier = randomBytes(48).toString("base64url");
  const challenge = createHash("sha256").update(verifier).digest("base64url");
  await pool.query(
    `INSERT INTO wearable_oauth_states (state, user_id, provider, code_verifier, expires_at)
     VALUES ($1, $2, $3, $4, now() + interval '${STATE_TTL_MIN} minutes')`,
    [state, userId, provider, verifier]
  );
  return clients[provider].authorizeUrl(state, challenge);
}

export async function handleCallback(provider: WearableProvider, code: string, state: string): Promise<void> {
  const res = await pool.query<{ user_id: string; code_verifier: string }>(
    `DELETE FROM wearable_oauth_states
     WHERE state = $1 AND provider = $2 AND expires_at > now()
     RETURNING user_id, code_verifier`,
    [state, provider]
  );
  const row = res.rows[0];
  if (!row) throw badRequest("Invalid or expired OAuth state", "OAUTH_STATE");

  const tokens = await clients[provider].exchangeCode(code, row.code_verifier);
  const hook = await clients[provider].afterConnect(tokens.accessToken, row.user_id)
    .catch((err) => { logger.warn({ err, provider }, "afterConnect hook failed"); return { providerUserId: tokens.providerUserId ?? "" }; });

  await pool.query(
    `INSERT INTO wearable_connections
       (user_id, provider, provider_user_id, access_token_enc, refresh_token_enc,
        access_token_expires_at, scopes, status)
     VALUES ($1, $2, $3, $4, $5, $6, $7, 'active')
     ON CONFLICT (user_id, provider) DO UPDATE SET
       provider_user_id = EXCLUDED.provider_user_id,
       access_token_enc = EXCLUDED.access_token_enc,
       refresh_token_enc = EXCLUDED.refresh_token_enc,
       access_token_expires_at = EXCLUDED.access_token_expires_at,
       scopes = EXCLUDED.scopes, status = 'active', updated_at = now()`,
    [row.user_id, provider, hook.providerUserId ?? "", encryptToken(tokens.accessToken),
     encryptToken(tokens.refreshToken), tokens.expiresAt, tokens.scopes]
  );

  // Immediate pull so the app has data the moment the user returns to it.
  // Garmin only needs a few days here — afterConnect already kicked a 30-day
  // async backfill whose results arrive via webhooks; Fitbit has no async
  // backfill, so pull the full window.
  syncProvider(row.user_id, provider, provider === "garmin" ? 7 : 30).catch((err) =>
    logger.warn({ err, provider }, "initial wearable sync failed"));
}

// ---- Connections ----

export async function listConnections(userId: string): Promise<WearableConnectionInfo[]> {
  // Strict ISO8601 (UTC "Z") so ISO8601DateFormatter on iOS parses it directly —
  // plain ::text yields Postgres "YYYY-MM-DD HH:MM:SS+00", which it will not parse.
  const iso = (col: string) =>
    `to_char(${col} AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"')`;
  const res = await pool.query(
    `SELECT provider, status, ${iso("created_at")} AS connected_at,
            ${iso("last_synced_at")} AS last_synced_at
     FROM wearable_connections WHERE user_id = $1 ORDER BY provider`,
    [userId]
  );
  return res.rows.map((r) => ({
    provider: r.provider, status: r.status,
    connected_at: r.connected_at, last_synced_at: r.last_synced_at,
  }));
}

export async function disconnect(userId: string, provider: WearableProvider): Promise<void> {
  const conn = await getConnection(userId, provider);
  if (!conn) throw notFound("No such connection", "NOT_CONNECTED");
  await clients[provider].revoke(decryptToken(conn.access_token_enc)).catch(() => undefined);
  // All three tables: the app's disconnect dialog promises synced data is deleted.
  await pool.query(`DELETE FROM wearable_connections WHERE user_id = $1 AND provider = $2`, [userId, provider]);
  await pool.query(`DELETE FROM wearable_daily_metrics WHERE user_id = $1 AND provider = $2`, [userId, provider]);
  await pool.query(`DELETE FROM wearable_raw_payloads WHERE user_id = $1 AND provider = $2`, [userId, provider]);
}

interface ConnRow {
  user_id: string; provider: WearableProvider; access_token_enc: string;
  refresh_token_enc: string; access_token_expires_at: Date; status: string;
}

async function getConnection(userId: string, provider: WearableProvider): Promise<ConnRow | null> {
  const res = await pool.query<ConnRow>(
    `SELECT user_id, provider, access_token_enc, refresh_token_enc, access_token_expires_at, status
     FROM wearable_connections WHERE user_id = $1 AND provider = $2`,
    [userId, provider]
  );
  return res.rows[0] ?? null;
}

/** Lazy refresh: returns a live access token, refreshing (and persisting the new pair) if expired. */
async function liveAccessToken(conn: ConnRow): Promise<string> {
  if (conn.access_token_expires_at.getTime() > Date.now() + 60_000) {
    return decryptToken(conn.access_token_enc);
  }
  const fresh = await clients[conn.provider].refresh(decryptToken(conn.refresh_token_enc));
  // Persist atomically — Fitbit refresh tokens are single-use; losing the new one strands the user.
  await pool.query(
    `UPDATE wearable_connections
     SET access_token_enc = $1, refresh_token_enc = $2, access_token_expires_at = $3,
         status = 'active', updated_at = now()
     WHERE user_id = $4 AND provider = $5`,
    [encryptToken(fresh.accessToken), encryptToken(fresh.refreshToken), fresh.expiresAt,
     conn.user_id, conn.provider]
  );
  return fresh.accessToken;
}

// ---- Sync & serve ----

/** Verbatim vendor payload log (spec R3): re-normalization source of truth. */
export async function logRawPayload(
  userId: string, provider: WearableProvider, kind: "pull" | "push", payload: unknown
): Promise<void> {
  await pool.query(
    `INSERT INTO wearable_raw_payloads (user_id, provider, kind, payload) VALUES ($1, $2, $3, $4)`,
    [userId, provider, kind, JSON.stringify(payload)]
  );
  // Piggybacked pruning (no cron infra): 90 days of raw history is plenty for reprocessing.
  await pool.query(
    `DELETE FROM wearable_raw_payloads
     WHERE user_id = $1 AND provider = $2 AND received_at < now() - interval '90 days'`,
    [userId, provider]
  ).catch(() => undefined);
}

export async function upsertDailyMetrics(
  userId: string, provider: WearableProvider, metrics: DailyMetrics[]
): Promise<void> {
  for (const m of metrics) {
    await pool.query(
      `INSERT INTO wearable_daily_metrics
         (user_id, provider, day, steps, resting_heart_rate, hrv_ms, sleep_seconds,
          sleep_deep_seconds, sleep_rem_seconds, sleep_light_seconds, active_kcal, updated_at)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11, now())
       ON CONFLICT (user_id, provider, day) DO UPDATE SET
         steps               = COALESCE(EXCLUDED.steps, wearable_daily_metrics.steps),
         resting_heart_rate  = COALESCE(EXCLUDED.resting_heart_rate, wearable_daily_metrics.resting_heart_rate),
         hrv_ms              = COALESCE(EXCLUDED.hrv_ms, wearable_daily_metrics.hrv_ms),
         sleep_seconds       = COALESCE(EXCLUDED.sleep_seconds, wearable_daily_metrics.sleep_seconds),
         sleep_deep_seconds  = COALESCE(EXCLUDED.sleep_deep_seconds, wearable_daily_metrics.sleep_deep_seconds),
         sleep_rem_seconds   = COALESCE(EXCLUDED.sleep_rem_seconds, wearable_daily_metrics.sleep_rem_seconds),
         sleep_light_seconds = COALESCE(EXCLUDED.sleep_light_seconds, wearable_daily_metrics.sleep_light_seconds),
         active_kcal         = COALESCE(EXCLUDED.active_kcal, wearable_daily_metrics.active_kcal),
         updated_at = now()`,
      [userId, provider, m.day, m.steps ?? null, m.restingHeartRate ?? null, m.hrvMs ?? null,
       m.sleepSeconds ?? null, m.sleepDeepSeconds ?? null, m.sleepRemSeconds ?? null,
       m.sleepLightSeconds ?? null, m.activeKcal ?? null]
    );
  }
}

export async function syncProvider(userId: string, provider: WearableProvider, days: number): Promise<number> {
  const conn = await getConnection(userId, provider);
  if (!conn) throw notFound("No such connection", "NOT_CONNECTED");
  try {
    const token = await liveAccessToken(conn);
    const end = new Date().toISOString().slice(0, 10);
    const start = new Date(Date.now() - (days - 1) * 86400_000).toISOString().slice(0, 10);
    const { metrics, raw } = await clients[provider].fetchDaily(token, start, end);
    await logRawPayload(userId, provider, "pull", raw);
    await upsertDailyMetrics(userId, provider, metrics);
    await pool.query(
      `UPDATE wearable_connections SET last_synced_at = now(), status = 'active', updated_at = now()
       WHERE user_id = $1 AND provider = $2`, [userId, provider]);
    return metrics.length;
  } catch (err) {
    await pool.query(
      `UPDATE wearable_connections SET status = 'error', updated_at = now()
       WHERE user_id = $1 AND provider = $2`, [userId, provider]);
    throw err;
  }
}

export async function getDailyMerged(userId: string, start: string, end: string): Promise<WearableDailyMetrics[]> {
  // Freshness valve: opportunistically kick a background sync for stale active connections.
  pool.query<{ provider: WearableProvider }>(
    `SELECT provider FROM wearable_connections
     WHERE user_id = $1 AND status = 'active'
       AND (last_synced_at IS NULL OR last_synced_at < now() - interval '${STALE_SYNC_MIN} minutes')`,
    [userId]
  ).then(({ rows }) => rows.forEach((r) =>
    syncProvider(userId, r.provider, 3).catch((err) => logger.warn({ err }, "lazy wearable sync failed"))
  )).catch(() => undefined);

  const res = await pool.query<MetricRow>(
    `SELECT provider, day::text, steps, resting_heart_rate, hrv_ms, sleep_seconds,
            sleep_deep_seconds, sleep_rem_seconds, sleep_light_seconds, active_kcal
     FROM wearable_daily_metrics
     WHERE user_id = $1 AND day BETWEEN $2 AND $3`,
    [userId, start, end]
  );
  return mergeAcrossProviders(res.rows);
}

// ---- Webhook entry points ----

/** Map a vendor's user id back to our user (Garmin push / Fitbit ownerId). */
export async function userForProviderUser(provider: WearableProvider, providerUserId: string): Promise<string | null> {
  const res = await pool.query<{ user_id: string }>(
    `SELECT user_id FROM wearable_connections WHERE provider = $1 AND provider_user_id = $2 AND status = 'active'`,
    [provider, providerUserId]
  );
  return res.rows[0]?.user_id ?? null;
}
```

- [ ] **Step 1: Write tests first** (`src/services/__tests__/wearableService.test.ts`): mock `../db` (`vi.mock` with a `pool.query` spy), mock both clients. Cover: `startConnect` inserts a state row and returns the client's URL; `handleCallback` with an unknown state throws `OAUTH_STATE`; `handleCallback` happy path calls `exchangeCode` with the stored verifier and upserts encrypted tokens (assert stored value ≠ raw token); `liveAccessToken` refresh path persists the new pair (drive via `syncProvider` with an expired `access_token_expires_at`); `syncProvider` inserts the client's `raw` into `wearable_raw_payloads` and upserts the normalized metrics; `syncProvider` marks status `error` when the client throws. Follow the mocking style of `src/middleware/__tests__/auth.test.ts`.
- [ ] **Step 2: Run:** `npm test -- wearableService` → FAIL, then implement (code above), then PASS.
- [ ] **Step 3: Typecheck + full suite:** `npx tsc --noEmit && npm test`.
- [ ] **Step 4: Commit:** `git add -A && git commit -m "feat(api): wearableService — oauth lifecycle, sync, merged reads"`

### Task 9: Integration routes (start / callback / list / disconnect / sync)

**Files:**
- Create: `src/routes/integrations.ts`
- Modify: `src/index.ts`

- [ ] **Step 1: Implement the router**

```typescript
import { Router, Request, Response } from "express";
import * as wearableService from "../services/wearableService";
import { requireAuth } from "../middleware/auth";
import { validateBody } from "../middleware/validate";
import { wearableProviderSchema, wearableSyncSchema } from "../schemas";
import { badRequest } from "../lib/httpError";
import { qs } from "../lib/query";

const router = Router();

function parseProvider(raw: string) {
  const parsed = wearableProviderSchema.safeParse(raw);
  if (!parsed.success) throw badRequest("Unknown provider", "PROVIDER");
  return parsed.data;
}

router.post("/:provider/start", requireAuth, async (req: Request, res: Response) => {
  const provider = parseProvider(req.params.provider);
  const authorize_url = await wearableService.startConnect(req.user!.id, provider);
  res.json({ authorize_url });
});

// Public: the browser lands here from the vendor. State (created by an authed call,
// single-use, 10-min TTL) is what binds this request to a user — no bearer token exists here.
router.get("/:provider/callback", async (req: Request, res: Response) => {
  const provider = parseProvider(req.params.provider);
  const code = qs(req.query.code);
  const state = qs(req.query.state);
  const fail = () => res.redirect(`elos://wearables?provider=${provider}&status=error`);
  if (!code || !state) return fail();
  try {
    await wearableService.handleCallback(provider, code, state);
    res.redirect(`elos://wearables?provider=${provider}&status=connected`);
  } catch {
    fail();
  }
});

router.get("/", requireAuth, async (req: Request, res: Response) => {
  res.json(await wearableService.listConnections(req.user!.id));
});

router.delete("/:provider", requireAuth, async (req: Request, res: Response) => {
  await wearableService.disconnect(req.user!.id, parseProvider(req.params.provider));
  res.status(204).end();
});

router.post("/:provider/sync", requireAuth, validateBody(wearableSyncSchema), async (req: Request, res: Response) => {
  const days = (req.body as { days?: number }).days ?? 3;
  const upserted = await wearableService.syncProvider(req.user!.id, parseProvider(req.params.provider), days);
  res.json({ upserted });
});

export default router;
```

- [ ] **Step 2: Mount in `src/index.ts`** next to the other mounts: `app.use("/integrations", integrationsRouter);`
- [ ] **Step 3: Typecheck + boot smoke test:** `npx tsc --noEmit && npm run dev` → hit `curl -s localhost:3000/integrations` → expect 401 JSON (auth required), `curl -s "localhost:3000/integrations/fitbit/callback"` → 302 to `elos://wearables?provider=fitbit&status=error`.
- [ ] **Step 4: Commit:** `git add -A && git commit -m "feat(api): wearable integration routes (oauth start/callback, list, disconnect, sync)"`

### Task 10: Webhook routes (Fitbit verify + notify, Garmin push)

**Files:**
- Create: `src/routes/wearableWebhooks.ts`
- Modify: `src/index.ts`

Webhooks are vendor-authenticated (signature / verification code), never `requireAuth`. Fitbit signature needs the **raw body**, so this router mounts its own `express.raw` parser — mount the router **before** the global `express.json`.

- [ ] **Step 1: Implement**

```typescript
import { Router, Request, Response, raw } from "express";
import { createHmac } from "crypto";
import * as wearableService from "../services/wearableService";
import { normalizeGarminDaily, normalizeGarminSleep, normalizeGarminHrv } from "../services/wearables/normalize";
import { logger } from "../lib/logger";

const router = Router();

// --- Fitbit subscriber verification (two GETs at registration time) ---
router.get("/fitbit", (req: Request, res: Response) => {
  const ok = req.query.verify === process.env.FITBIT_VERIFICATION_CODE;
  res.status(ok ? 204 : 404).end();
});

// --- Fitbit notifications: ack fast, fetch changed days in the background ---
router.post("/fitbit", raw({ type: "*/*", limit: "1mb" }), async (req: Request, res: Response) => {
  const body: Buffer = req.body;
  const expected = createHmac("sha1", `${process.env.FITBIT_CLIENT_SECRET}&`).update(body).digest("base64");
  if (req.header("X-Fitbit-Signature") !== expected) {
    res.status(404).end(); // per Fitbit guidance: don't confirm the endpoint to strangers
    return;
  }
  res.status(204).end();

  try {
    const notifications: Array<{ collectionType: string; date: string; ownerId: string }> =
      JSON.parse(body.toString("utf8"));
    const owners = new Set(notifications.map((n) => n.ownerId));
    for (const ownerId of owners) {
      const userId = await wearableService.userForProviderUser("fitbit", ownerId);
      if (userId) {
        await wearableService.syncProvider(userId, "fitbit", 3)
          .catch((err) => logger.warn({ err }, "fitbit webhook sync failed"));
      }
    }
  } catch (err) {
    logger.warn({ err }, "fitbit webhook processing failed");
  }
});

// --- Garmin push: body is { dailies?: [...], sleeps?: [...], hrv?: [...] },
// each summary carrying userId. Ack immediately; upsert asynchronously. ---
router.post("/garmin", raw({ type: "*/*", limit: "5mb" }), async (req: Request, res: Response) => {
  res.status(200).end();
  try {
    const payload = JSON.parse((req.body as Buffer).toString("utf8"));
    const groups: Array<[any[], (s: any[]) => any[]]> = [
      [payload.dailies ?? [], normalizeGarminDaily],
      [payload.sleeps ?? [], normalizeGarminSleep],
      [payload.hrv ?? [], normalizeGarminHrv],
    ];
    for (const [summaries, normalize] of groups) {
      // Group by Garmin user id; each summary carries `userId`.
      const byUser = new Map<string, any[]>();
      for (const s of summaries) {
        if (!s?.userId) continue;
        byUser.set(s.userId, [...(byUser.get(s.userId) ?? []), s]);
      }
      for (const [garminUserId, userSummaries] of byUser) {
        const userId = await wearableService.userForProviderUser("garmin", garminUserId);
        if (!userId) continue;
        // Raw first: retention must not depend on normalization succeeding.
        await wearableService.logRawPayload(userId, "garmin", "push", userSummaries)
          .catch((err) => logger.warn({ err }, "garmin raw log failed"));
        await wearableService.upsertDailyMetrics(userId, "garmin", normalize(userSummaries))
          .catch((err) => logger.warn({ err }, "garmin push upsert failed"));
      }
    }
  } catch (err) {
    logger.warn({ err }, "garmin webhook processing failed");
  }
});

export default router;
```

- [ ] **Step 2: Mount in `src/index.ts` BEFORE `app.use(express.json(...))`:** `app.use("/webhooks", wearableWebhooksRouter);` (add a comment saying why the order matters).
- [ ] **Step 3: Smoke test:** with `FITBIT_VERIFICATION_CODE=abc npm run dev`: `curl -si "localhost:3000/webhooks/fitbit?verify=abc"` → 204; `?verify=wrong` → 404; `curl -si -XPOST localhost:3000/webhooks/fitbit -d '[]'` → 404 (bad signature).
- [ ] **Step 4: Add env vars to `src/lib/env.ts`** — extend `REQUIRED_VARS` only with `WEARABLE_TOKEN_KEY` (provider creds are optional until launch; the clients throw descriptively if used unset). Add all new vars to `.env.example` with comments.
- [ ] **Step 5: Full suite + typecheck:** `npm test && npx tsc --noEmit`.
- [ ] **Step 6: Commit:** `git add -A && git commit -m "feat(api): fitbit + garmin webhook endpoints"`

### Task 11: Serve merged daily metrics

**Files:**
- Create: `src/routes/wearables.ts`
- Modify: `src/index.ts`

- [ ] **Step 1: Implement**

```typescript
import { Router, Request, Response } from "express";
import * as wearableService from "../services/wearableService";
import { requireAuth } from "../middleware/auth";
import { validateQuery } from "../middleware/validate";
import { wearableDailyQuerySchema } from "../schemas";

const router = Router();

router.get("/daily", requireAuth, validateQuery(wearableDailyQuerySchema), async (req: Request, res: Response) => {
  const { start, end } = req.validatedQuery as { start: string; end: string };
  res.json(await wearableService.getDailyMerged(req.user!.id, start, end));
});

export default router;
```

- [ ] **Step 2: Mount:** `app.use("/wearables", wearablesRouter);`
- [ ] **Step 3: Verify** `npm test && npx tsc --noEmit`; boot and `curl -s "localhost:3000/wearables/daily?start=2026-07-01&end=2026-07-11"` → 401 (no token) — correct.
- [ ] **Step 4: Commit, then deploy checkpoint:** `git add -A && git commit -m "feat(api): merged wearable daily metrics endpoint"`. Push to `main` → Render deploys → complete Task 1 Steps 1–2 vendor-side URLs (callback + webhook registration) against the live host.

---

## Phase 2 — Mobile (elos-mobile). Paths relative to `apps/elos-mobile/Elos/Elos/`.

### Task 12: FeatureFlags + pure wearable models & merge (TDD)

**Files:**
- Create: `Utils/FeatureFlags.swift`
- Create: `Features/You/Wearables/WearableModels.swift`
- Test: `../ElosTests/WearableModelsTests.swift`

- [ ] **Step 1: `FeatureFlags.swift`**

```swift
/// Compile-time gates for unfinished features. Flip to ship.
enum FeatureFlags {
    /// Garmin/Fitbit direct integrations. Gate until Garmin production access is approved.
    static let wearableIntegrations = true // DEBUG-visible; set false before App Store build if not approved
}
```

- [ ] **Step 2: Write failing tests** (Swift Testing, mirror `HealthMetricsTests.swift` style)

```swift
import Testing
@testable import Elos

struct WearableModelsTests {
    @Test func mergePrefersWearableOverHealthKit() {
        let wearable = WearableDailyMetrics(
            day: "2026-07-10", steps: 9042, restingHeartRate: 49, hrvMs: 58,
            sleepSeconds: 26100, sleepDeepSeconds: nil, sleepRemSeconds: nil,
            sleepLightSeconds: nil, activeKcal: nil, sources: ["steps": "garmin", "resting_heart_rate": "garmin"]
        )
        let health = HealthSnapshot(bodyWeightKg: 80, restingHeartRate: 55, restingHRBaseline: 50, steps: 8000)
        let merged = MergedHealthMetrics.merge(wearable: wearable, health: health)
        #expect(merged.steps?.value == 9042)
        #expect(merged.steps?.source == .wearable("garmin"))
        #expect(merged.restingHeartRate?.value == 49)
    }

    @Test func mergeFallsBackToHealthKit() {
        let health = HealthSnapshot(bodyWeightKg: nil, restingHeartRate: 55, restingHRBaseline: 50, steps: 8000)
        let merged = MergedHealthMetrics.merge(wearable: nil, health: health)
        #expect(merged.steps?.value == 8000)
        #expect(merged.steps?.source == .healthKit)
        #expect(merged.sleepSeconds == nil)
    }

    @Test func recoveryHintUsesMergedRestingHR() {
        let wearable = WearableDailyMetrics(
            day: "2026-07-10", steps: nil, restingHeartRate: 60, hrvMs: nil,
            sleepSeconds: nil, sleepDeepSeconds: nil, sleepRemSeconds: nil,
            sleepLightSeconds: nil, activeKcal: nil, sources: [:]
        )
        let health = HealthSnapshot(bodyWeightKg: nil, restingHeartRate: nil, restingHRBaseline: 50, steps: nil)
        let merged = MergedHealthMetrics.merge(wearable: wearable, health: health)
        #expect(merged.recoveryHint != nil)  // 60 > 50 * 1.10
    }
}
```

- [ ] **Step 3: Implement `WearableModels.swift`**

```swift
import Foundation

/// Wearable vendors ELOS can connect directly (server-side OAuth).
enum WearableProvider: String, CaseIterable, Codable, Identifiable {
    case garmin, fitbit
    var id: String { rawValue }
    var label: String { self == .garmin ? "Garmin" : "Fitbit" }
    var icon: String { self == .garmin ? "applewatch" : "figure.walk.circle" } // SF Symbols stand-ins
}

/// GET /integrations row.
struct WearableConnectionInfo: Decodable, Identifiable {
    let provider: WearableProvider
    let status: String
    let connectedAt: String
    let lastSyncedAt: String?
    var id: String { provider.rawValue }

    enum CodingKeys: String, CodingKey {
        case provider, status
        case connectedAt = "connected_at"
        case lastSyncedAt = "last_synced_at"
    }
}

/// One merged day from GET /wearables/daily. `sources` maps snake_case metric → provider.
struct WearableDailyMetrics: Decodable, Equatable {
    let day: String
    let steps: Int?
    let restingHeartRate: Double?
    let hrvMs: Double?
    let sleepSeconds: Int?
    let sleepDeepSeconds: Int?
    let sleepRemSeconds: Int?
    let sleepLightSeconds: Int?
    let activeKcal: Double?
    let sources: [String: String]

    enum CodingKeys: String, CodingKey {
        case day, steps, sources
        case restingHeartRate = "resting_heart_rate"
        case hrvMs = "hrv_ms"
        case sleepSeconds = "sleep_seconds"
        case sleepDeepSeconds = "sleep_deep_seconds"
        case sleepRemSeconds = "sleep_rem_seconds"
        case sleepLightSeconds = "sleep_light_seconds"
        case activeKcal = "active_kcal"
    }
}

/// Where a displayed metric came from — every value the UI shows carries this.
enum MetricSource: Equatable {
    case wearable(String)   // provider raw value, e.g. "garmin"
    case healthKit

    var label: String {
        switch self {
        case .wearable(let p): return p.capitalized
        case .healthKit:       return "Apple Health"
        }
    }
}

struct SourcedMetric<V: Equatable>: Equatable {
    let value: V
    let source: MetricSource
}

/// The phone-side merge: connected wearable beats HealthKit, HealthKit fills gaps.
/// Pure and unit-tested; AppViewModel publishes the result.
struct MergedHealthMetrics: Equatable {
    var steps: SourcedMetric<Int>?
    var restingHeartRate: SourcedMetric<Double>?
    var hrvMs: SourcedMetric<Double>?
    var sleepSeconds: SourcedMetric<Int>?
    var activeKcal: SourcedMetric<Double>?
    var bodyWeightKg: Double?          // HealthKit-only today
    var restingHRBaseline: Double?     // HealthKit-only today

    var recoveryHint: String? {
        RecoveryHint.evaluate(restingHR: restingHeartRate?.value, baseline: restingHRBaseline)
    }

    var hasAnyMetric: Bool {
        steps != nil || restingHeartRate != nil || sleepSeconds != nil || hrvMs != nil || bodyWeightKg != nil
    }

    static func merge(wearable: WearableDailyMetrics?, health: HealthSnapshot) -> MergedHealthMetrics {
        var out = MergedHealthMetrics()
        func pick<V: Equatable>(_ wearableValue: V?, sourceKey: String, _ healthValue: V?) -> SourcedMetric<V>? {
            if let v = wearableValue {
                return SourcedMetric(value: v, source: .wearable(wearable?.sources[sourceKey] ?? "wearable"))
            }
            if let h = healthValue { return SourcedMetric(value: h, source: .healthKit) }
            return nil
        }
        out.steps            = pick(wearable?.steps, sourceKey: "steps", health.steps)
        out.restingHeartRate = pick(wearable?.restingHeartRate, sourceKey: "resting_heart_rate", health.restingHeartRate)
        out.hrvMs            = pick(wearable?.hrvMs, sourceKey: "hrv_ms", nil)
        out.sleepSeconds     = pick(wearable?.sleepSeconds, sourceKey: "sleep_seconds", nil)
        out.activeKcal       = pick(wearable?.activeKcal, sourceKey: "active_kcal", nil)
        out.bodyWeightKg = health.bodyWeightKg
        out.restingHRBaseline = health.restingHRBaseline
        return out
    }

    static let empty = MergedHealthMetrics()
}
```

- [ ] **Step 4: Run tests from a real terminal** (sandbox pty limit): `xcodebuild test -project Elos.xcodeproj -scheme Elos -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:ElosTests/WearableModelsTests -parallel-testing-enabled NO` → PASS.
- [ ] **Step 5: Commit:** `git add -A && git commit -m "feat(ios): wearable models + healthkit merge with source attribution"`

### Task 13: WearableService (API + connect flow)

**Files:**
- Create: `Services/WearableService.swift`

- [ ] **Step 1: Implement** — thin singleton over `ApiClient`, plus the `ASWebAuthenticationSession` dance. No Info.plist change needed: the session intercepts the `elos` scheme itself.

```swift
import Foundation
import UIKit
import AuthenticationServices

/// Boundary over the backend's wearable-integration endpoints plus the OAuth browser flow.
/// Mirrors HealthKitService: best-effort, never a hard dependency.
@MainActor
final class WearableService: NSObject {
    static let shared = WearableService()

    private struct StartResponse: Decodable { let authorize_url: String }
    private struct SyncBody: Encodable { let days: Int }
    private struct SyncResponse: Decodable { let upserted: Int }

    func connections() async -> [WearableConnectionInfo] {
        (try? await ApiClient.shared.get("/integrations") as [WearableConnectionInfo]) ?? []
    }

    func disconnect(_ provider: WearableProvider) async throws {
        try await ApiClient.shared.deleteNoContent("/integrations/\(provider.rawValue)")
    }

    func sync(_ provider: WearableProvider, days: Int = 3) async {
        _ = try? await ApiClient.shared.post("/integrations/\(provider.rawValue)/sync",
                                             body: SyncBody(days: days)) as SyncResponse
    }

    func daily(start: String, end: String) async -> [WearableDailyMetrics] {
        (try? await ApiClient.shared.get("/wearables/daily?start=\(start)&end=\(end)") as [WearableDailyMetrics]) ?? []
    }

    /// Full connect flow: ask the backend for the vendor authorize URL, run it in an
    /// ASWebAuthenticationSession, and treat `elos://wearables?...status=connected` as success.
    func connect(_ provider: WearableProvider) async throws -> Bool {
        struct Empty: Encodable {}
        let start: StartResponse = try await ApiClient.shared.post(
            "/integrations/\(provider.rawValue)/start", body: Empty())
        guard let url = URL(string: start.authorize_url) else { throw ApiError.invalidURL }

        let callback: URL = try await withCheckedThrowingContinuation { cont in
            let session = ASWebAuthenticationSession(url: url, callbackURLScheme: "elos") { url, error in
                if let url { cont.resume(returning: url) }
                else { cont.resume(throwing: error ?? ApiError.invalidURL) }
            }
            session.presentationContextProvider = self
            session.prefersEphemeralWebBrowserSession = false // keep vendor login cookies
            session.start()
        }
        let status = URLComponents(url: callback, resolvingAgainstBaseURL: false)?
            .queryItems?.first(where: { $0.name == "status" })?.value
        return status == "connected"
    }
}

extension WearableService: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.keyWindow }
            .first ?? ASPresentationAnchor()
    }
}
```

- [ ] **Step 2: Build:** `xcodebuild build -project Elos.xcodeproj -scheme Elos -destination 'platform=iOS Simulator,name=iPhone 16'` → succeeds.
- [ ] **Step 3: Commit:** `git add -A && git commit -m "feat(ios): WearableService — api wrapper + ASWebAuthenticationSession connect"`

### Task 14: AppViewModel wiring

**Files:**
- Modify: `AppViewModel.swift` (extend the existing `// MARK: - Apple Health` region)

- [ ] **Step 1: Add published state + methods**

```swift
// MARK: - Wearables (Garmin / Fitbit direct integrations)
@Published var wearableConnections: [WearableConnectionInfo] = []
@Published var wearableToday: WearableDailyMetrics?
/// Wearable-over-HealthKit merged view; what readiness & intelligence consume.
@Published var mergedHealth: MergedHealthMetrics = .empty

var hasWearableConnected: Bool { !wearableConnections.isEmpty }

func refreshWearables() async {
    guard FeatureFlags.wearableIntegrations else { return }
    wearableConnections = await WearableService.shared.connections()
    if hasWearableConnected {
        let today = Formatters.isoDay.string(from: Date())
        wearableToday = await WearableService.shared.daily(start: today, end: today).last
    } else {
        wearableToday = nil
    }
    recomputeMergedHealth()
}

func connectWearable(_ provider: WearableProvider) async {
    do {
        if try await WearableService.shared.connect(provider) {
            await refreshWearables()
        } else {
            showError("Couldn't connect \(provider.label). Please try again.")
        }
    } catch {
        // User cancelling the browser sheet also lands here — stay quiet for ASWebAuth cancel.
        if (error as? ASWebAuthenticationSessionError)?.code != .canceledLogin {
            showError("Couldn't connect \(provider.label). Please try again.")
        }
    }
}

func disconnectWearable(_ provider: WearableProvider) async {
    try? await WearableService.shared.disconnect(provider)
    await refreshWearables()
}

private func recomputeMergedHealth() {
    mergedHealth = MergedHealthMetrics.merge(wearable: wearableToday, health: healthSnapshot)
}
```

Add `import AuthenticationServices` at the top of the file for `ASWebAuthenticationSessionError`.

- [ ] **Step 2: Keep the merge current:** at the end of the existing `refreshHealthMetrics()`, call `recomputeMergedHealth()`. Find where the app refreshes health on foreground/launch (callers of `refreshHealthMetrics`) and add `await refreshWearables()` alongside.
- [ ] **Step 3: Build** (same command) → succeeds.
- [ ] **Step 4: Commit:** `git add -A && git commit -m "feat(ios): wearable state + merged health metrics in AppViewModel"`

### Task 15: Connected Devices UI

**Files:**
- Create: `Features/You/Wearables/ConnectedDevicesView.swift`
- Modify: `Features/You/SettingsView.swift`

- [ ] **Step 1: Implement the screen**

```swift
import SwiftUI

/// Settings → Connected Devices: connect/disconnect Garmin & Fitbit, see sync state.
struct ConnectedDevicesView: View {
    @EnvironmentObject var vm: AppViewModel
    @State private var busyProvider: WearableProvider?
    @State private var confirmDisconnect: WearableProvider?

    var body: some View {
        List {
            Section {
                ForEach(WearableProvider.allCases) { provider in
                    providerRow(provider)
                }
            } footer: {
                Text("Data syncs from your device's vendor account. Garmin users: enable "
                     + "\"backfill\" on Garmin's consent screen to import history. "
                     + "Wearable data takes priority over Apple Health when both report the same metric.")
            }
        }
        .navigationTitle("Connected Devices")
        .task { await vm.refreshWearables() }
        .refreshable { await vm.refreshWearables() }
        .confirmationDialog("Disconnect?", isPresented: .init(
            get: { confirmDisconnect != nil }, set: { if !$0 { confirmDisconnect = nil } })
        ) {
            Button("Disconnect \(confirmDisconnect?.label ?? "")", role: .destructive) {
                if let p = confirmDisconnect { Task { await vm.disconnectWearable(p) } }
            }
        } message: {
            Text("ELOS will stop receiving data and delete already-synced metrics from this device.")
        }
    }

    @ViewBuilder private func providerRow(_ provider: WearableProvider) -> some View {
        let connection = vm.wearableConnections.first { $0.provider == provider }
        HStack {
            Label(provider.label, systemImage: provider.icon)
            Spacer()
            if busyProvider == provider {
                ProgressView()
            } else if let connection {
                VStack(alignment: .trailing, spacing: 2) {
                    Text(connection.status == "active" ? "Connected" : "Needs attention")
                        .font(.caption).foregroundStyle(connection.status == "active" ? Color.good : Color.warn)
                    if let last = connection.lastSyncedAt {
                        Text("Synced \(relative(last))").font(.caption2).foregroundStyle(.secondary)
                    }
                }
            } else {
                Button("Connect") {
                    Task {
                        busyProvider = provider
                        await vm.connectWearable(provider)
                        busyProvider = nil
                    }
                }
                .buttonStyle(.borderedProminent).controlSize(.small)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { if connection != nil { confirmDisconnect = provider } }
    }

    private func relative(_ iso: String) -> String {
        guard let date = ISO8601DateFormatter().date(from: iso) else { return "recently" }
        return RelativeDateTimeFormatter().localizedString(for: date, relativeTo: Date())
    }
}
```

(Server timestamps are strict ISO8601 UTC — `listConnections` formats them with `to_char` for exactly this reason — so `ISO8601DateFormatter` parses them directly.)

- [ ] **Step 2: Add the Settings entry** in `SettingsView.swift`, immediately after the Apple Health section:

```swift
if FeatureFlags.wearableIntegrations {
    Section {
        NavigationLink {
            ConnectedDevicesView()
        } label: {
            Label("Connected Devices", systemImage: "applewatch.radiowaves.left.and.right")
        }
        if vm.hasWearableConnected {
            ForEach(vm.wearableConnections) { c in
                healthRow(c.provider.label, value: c.status == "active" ? "Connected" : "Error")
            }
        }
    } header: {
        Text("Wearables")
    } footer: {
        Text("Connect Garmin or Fitbit to sync steps, sleep, heart rate, and HRV directly — no Apple Health bridge needed.")
    }
}
```

- [ ] **Step 3: Build, then run in the simulator** and eyeball the section renders (connect will fail without vendor creds — expected; verify the error path shows the alert, not a crash).
- [ ] **Step 4: Commit:** `git add -A && git commit -m "feat(ios): Connected Devices settings screen"`

### Task 16: Readiness & intelligence consume merged metrics

**Files:**
- Modify: `Features/Train/Readiness/ReadinessCheckInView.swift`

- [ ] **Step 1: Switch the check-in card to merged data with source labels.** Replace the `healthMetricsCard` gate and body:

```swift
// was: if vm.healthKitEnabled, vm.healthSnapshot.hasAnyMetric { healthMetricsCard }
if vm.mergedHealth.hasAnyMetric {
    healthMetricsCard
}
```

```swift
@ViewBuilder private var healthMetricsCard: some View {
    let m = vm.mergedHealth
    VStack(spacing: 8) {
        HStack(spacing: 12) {
            if let rhr = m.restingHeartRate {
                metricStat("Resting HR", "\(Int(rhr.value)) bpm", source: rhr.source)
            }
            if let sleep = m.sleepSeconds {
                metricStat("Sleep", sleepText(sleep.value), source: sleep.source)
            }
            if let hrv = m.hrvMs {
                metricStat("HRV", "\(Int(hrv.value)) ms", source: hrv.source)
            }
            if let steps = m.steps {
                metricStat("Steps", "\(steps.value)", source: steps.source)
            }
        }
        if let hint = m.recoveryHint {
            Text(hint)
                .font(.caption2).foregroundStyle(Color.warn)
                .multilineTextAlignment(.center)
        }
    }
    .padding(12)
    .frame(maxWidth: .infinity)
    .background(Color(.secondarySystemBackground))
    .clipShape(RoundedRectangle(cornerRadius: 12))
    .padding(.horizontal, 20)
}

private func metricStat(_ label: String, _ value: String, source: MetricSource) -> some View {
    VStack(spacing: 2) {
        Text(value).font(.system(size: 16, weight: .bold, design: .rounded))
        Text(label).font(.caption2).foregroundStyle(.secondary)
        Text(source.label).font(.system(size: 8)).foregroundStyle(.tertiary)
    }
    .frame(maxWidth: .infinity)
}

private func sleepText(_ seconds: Int) -> String {
    let h = seconds / 3600, m = (seconds % 3600) / 60
    return "\(h)h \(m)m"
}
```

Cap the HStack at the three most valuable metrics if four feel cramped at runtime — priority: Resting HR, Sleep, HRV, then Steps.

- [ ] **Step 2: Pre-fill sleep quality from wearable sleep** (small, honest default — data assists, never overrides the user): in the view's `.task`/`onAppear`, if `vm.mergedHealth.sleepSeconds?.value` exists, set the initial `sleepQuality` slider: ≥ 8h → 5, ≥ 7h → 4, ≥ 6h → 3, ≥ 5h → 2, else 1. The user can still move the slider; nothing else about scoring changes.
- [ ] **Step 3: Build + run readiness sheet in simulator** — card renders with source captions; with no wearable connected it shows HealthKit-only values exactly as before.
- [ ] **Step 4: Run the full iOS test suite** from a real terminal: `xcodebuild test ... -parallel-testing-enabled NO` → green.
- [ ] **Step 5: Commit:** `git add -A && git commit -m "feat(ios): readiness consumes merged wearable+health metrics with sources"`

---

## Phase 3 — Verification & launch gates

### Task 17: End-to-end verification

- [ ] **Step 1: Backend gate:** `cd apps/elos-api && npx tsc --noEmit && npm test` → all green.
- [ ] **Step 2: Local E2E (Fitbit, pull path — no webhook needed):** run the API locally with the dev Fitbit app creds (`API_PUBLIC_URL=http://localhost:3000`), launch the iOS app with `-use-local-api`, Settings → Connected Devices → Connect Fitbit → real Fitbit login → expect redirect back, row shows "Connected", and `SELECT provider, day, steps, resting_heart_rate, sleep_seconds FROM wearable_daily_metrics` shows ~30 days of rows. Then open readiness → metrics show with "Fitbit" captions.
- [ ] **Step 3: Prod webhook path:** after deploy, register the Fitbit subscriber URL (Task 1) → Verify button turns green; sync a Fitbit device → within minutes `wearable_daily_metrics.updated_at` moves without any app call (check Render logs for the webhook POST).
- [ ] **Step 4: Garmin (once evaluation access exists):** repeat Step 2 with Garmin; **before first connect, diff `garminClient.ts`/`normalize.ts` field names against the portal spec PDF** and correct. Verify the acceptance criterion from the spec: steps/RHR/sleep in ELOS match the Garmin Connect app for the same day.
- [ ] **Step 5: Conflict/no-double-count check:** with Garmin connected *and* Garmin→Apple Health sync on the phone, confirm readiness shows the Garmin value once, sourced "Garmin" (priority beats HealthKit; nothing sums the two).
- [ ] **Step 6: Disconnect check:** disconnect in Settings → row returns to "Connect"; DB rows for that provider are gone from **all three tables** (`wearable_connections`, `wearable_daily_metrics`, `wearable_raw_payloads`); readiness falls back to HealthKit values.
- [ ] **Step 7: Ship gate:** run `/ship` (typecheck + tests + format across both stacks). Launch flag: keep `FeatureFlags.wearableIntegrations` true for TestFlight; App Store release waits on Garmin production approval **or** ships Fitbit-only (hide the Garmin row with a sub-flag if approval lags).

---

## Risks & watch-outs

- **Garmin endpoint drift:** everything Garmin-specific is confined to `garminClient.ts` + three normalizers; reconcile with the partner spec PDF before first real connect (Tasks 1/7/17). If field names were wrong anyway, the verbatim payloads in `wearable_raw_payloads` let you fix the normalizers and re-normalize without re-fetching.
- **Fitbit single-use refresh tokens:** the refresh path persists the new pair in one UPDATE before returning; never call `refresh()` outside `liveAccessToken`. Concurrent refreshes are tolerated by Fitbit's 2-minute identical-request window.
- **Rate limits:** backfill = 4 Fitbit calls; lazy sync = 4 calls per 30 min max. Far under 150/hr/user. Don't add per-day loops.
- **Webhook body parsing:** `/webhooks` must be mounted before `express.json` or the Fitbit signature check breaks. There's a comment in `index.ts`; don't "clean it up".
- **Timezones:** vendor `calendarDate`/`dateTime` are user-local calendar days — store as-is, never convert through UTC `Date`.
- **Sandbox/pty:** iOS *test execution* must run from a real terminal; builds are fine anywhere.
