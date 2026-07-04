# Exercise How-To Layer Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a brand-agnostic "how-to" layer (step-by-step instructions + one demo photo) to Elos exercises, surfaced via the existing ⓘ affordance in the active session and exercise picker, sourced from the public-domain `free-exercise-db`.

**Architecture:** How-to content attaches to the generic `exercise_definitions` row (one level above the brand-machine layer), so every brand variant inherits it for free. Content is produced offline by a `ts-node` import script that matches the source dataset to the existing catalog (conservative: exact-normalized + alias only) and emits a seed migration + a match report. iOS reads the new fields through the existing `/exercises` → SwiftData sync and renders them in a new how-to sheet; demo photos are bundled in an asset catalog. No runtime dependency on the external dataset.

**Tech Stack:** Node/TypeScript + Express + raw `pg` (backend), Vitest (backend tests), PostgreSQL migrations (`ts-node src/migrate.ts`), Swift/SwiftUI + SwiftData (iOS), Swift Testing (iOS tests).

**Spec:** `docs/superpowers/specs/2026-07-03-exercise-how-to-layer-design.md`

---

## Prerequisites & conventions

- Backend tests run with: `pnpm --filter elos-api test` (→ `vitest run`). Backend tests live in `__tests__/` dirs beside the code, named `<subject>.test.ts`, and stub the `pg` `Pool` (never hit a real DB).
- Migrations: add a numbered `.sql` to `apps/elos-api/migrations/`, then `pnpm migrate` from repo root (requires `pnpm db:up` first). The runner (`apps/elos-api/src/migrate.ts`) tracks applied files in `schema_migrations` and wraps each in a transaction. **Next free number is `036`** (highest is `035`; `022`/`029` are gaps — do not reuse them).
- Typecheck backend: `pnpm typecheck` (→ `tsc --noEmit`).
- iOS tests run with (from `apps/elos-mobile/Elos/`):
  `xcodebuild test -scheme Elos -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:ElosTests`
  New `.swift` files under `Elos/` and `ElosTests/` auto-join their targets (Xcode 16 `PBXFileSystemSynchronizedRootGroup`) — no `project.pbxproj` edits. SourceKit may show spurious "No such module 'Testing'" on freshly added files; `xcodebuild` is authoritative.
- The mobile app does **not** consume `elos-shared`; Swift models are hand-maintained mirrors. Updating the shared package does not auto-propagate — iOS field additions are manual (Group 3).
- Commit after every task. Keep commits small.

## File structure (created / modified)

**Backend + shared:**
- Create: `apps/elos-api/migrations/036_add_exercise_howto_columns.sql` — adds `instructions`, `image_key` columns.
- Create: `apps/elos-api/migrations/037_seed_exercise_howto.sql` — **generated** by the import script (enrich + gap-fill + movement_pattern backfill).
- Modify: `packages/elos-shared/src/index.ts:72-82` — add fields to `ExerciseDefinition`.
- Modify: `apps/elos-api/src/services/exerciseService.ts` — extend the shared column projection.
- Create: `apps/elos-api/src/services/__tests__/exerciseService.test.ts` — assert projection includes new columns.

**Import script (new module, `ts-node`):**
- Create: `apps/elos-api/src/scripts/howto/matcher.ts` — pure matcher (normalize, alias, taxonomy, movement-pattern derivation).
- Create: `apps/elos-api/src/scripts/howto/aliases.ts` — gym-slang → source-name alias map + machine gap-fill allowlist.
- Create: `apps/elos-api/src/scripts/howto/__tests__/matcher.test.ts` — Vitest tests for the pure matcher.
- Create: `apps/elos-api/src/scripts/howto/generate.ts` — I/O wrapper: reads source + catalog, runs matcher, writes migration `037` + report CSV + downloads/writes demo images.
- Modify: `apps/elos-api/package.json` — add `"howto:generate": "ts-node src/scripts/howto/generate.ts"`.
- Create: `data/free-exercise-db.exercises.json` — vendored public-domain source (Unlicense).
- Create: `data/free-exercise-db.NOTICE` — license/provenance note.
- Create: `docs/superpowers/artifacts/2026-07-03-howto-match-report.csv` — generated spot-check report (committed for the record).

**iOS:**
- Modify: `apps/elos-mobile/Elos/Elos/SwiftData/ElosSchema.swift:244-273` — add `instructionsJSON`, `imageKey` to `ExerciseDefinitionRecord`.
- Modify: `apps/elos-mobile/Elos/Elos/Features/Train/ExercisePicker/ExercisePickerViewModel.swift` — extend `ExerciseResponse` + `syncExercises` upsert.
- Create: `apps/elos-mobile/Elos/Elos/Features/Train/HowTo/ExerciseHowTo.swift` — value type + `from(record:)` + lookup.
- Create: `apps/elos-mobile/Elos/Elos/Features/Train/HowTo/ExerciseHowToSheet.swift` — the how-to sheet view.
- Modify: `apps/elos-mobile/Elos/Elos/Features/ActiveWorkout/SetRowView.swift` — wire ⓘ to the sheet.
- Modify: `apps/elos-mobile/Elos/Elos/Features/Train/ExercisePicker/ExercisePickerView.swift` — add ⓘ to `rowView`, extend `Row`.
- Create: `apps/elos-mobile/Elos/ElosTests/HowTo/ExerciseHowToTests.swift` — Swift Testing for `from(record:)`.
- Create: `apps/elos-mobile/Elos/Elos/Resources/ExerciseHowTo.xcassets/` — bundled demo photos (generated imagesets).

---

# Group 1 — Backend: schema + contract + service (fields flow end-to-end, empty)

Goal of this group: `GET /exercises` returns `instructions: []` and `image_key: null` for every row, verified by a service test. No content yet.

### Task 1.1: Add the columns (migration 036)

**Files:**
- Create: `apps/elos-api/migrations/036_add_exercise_howto_columns.sql`

- [ ] **Step 1: Write the migration**

```sql
-- Add how-to content to exercise_definitions.
-- instructions: ordered step strings (English), '{}' when none.
-- image_key: reference to a bundled demo photo in the iOS asset catalog; NULL when none.
-- Content attaches to the GENERIC exercise, so every brand-machine variant inherits it.
ALTER TABLE exercise_definitions
  ADD COLUMN IF NOT EXISTS instructions TEXT[] NOT NULL DEFAULT '{}',
  ADD COLUMN IF NOT EXISTS image_key    TEXT;
```

- [ ] **Step 2: Apply it**

Run: `pnpm db:up && pnpm migrate`
Expected: `Applying migration: 036_add_exercise_howto_columns.sql` … `Applied` … `Migrations complete.`

- [ ] **Step 3: Verify columns exist**

Run: `pnpm --filter elos-api exec node -e "const{pool}=require('./dist/db');" 2>/dev/null || psql "$DATABASE_URL" -c "\d exercise_definitions"` (or inspect via your DB tool).
Expected: `instructions text[]` and `image_key text` present.

- [ ] **Step 4: Commit**

```bash
git add apps/elos-api/migrations/036_add_exercise_howto_columns.sql
git commit -m "feat(api): add instructions + image_key columns to exercise_definitions"
```

### Task 1.2: Extend the shared contract

**Files:**
- Modify: `packages/elos-shared/src/index.ts:72-82`

- [ ] **Step 1: Add the two fields to `ExerciseDefinition`**

Change the interface to:

```ts
export interface ExerciseDefinition {
  id: string;
  owner_id: string | null;
  name: string;
  primary_muscle: string;
  secondary_muscles: string[];
  equipment: string;
  movement_pattern: string;
  instructions: string[];
  image_key: string | null;
  is_custom: boolean;
  created_at: string;
}
```

Leave `CreateExerciseBody` unchanged — user-created exercises do not author how-to content (a non-goal).

- [ ] **Step 2: Typecheck**

Run: `pnpm typecheck`
Expected: PASS (the service still compiles because its SELECT is updated in 1.3; do 1.2 and 1.3 in the same commit if typecheck complains about missing fields on returned rows — see note in 1.3).

- [ ] **Step 3: Commit**

```bash
git add packages/elos-shared/src/index.ts
git commit -m "feat(shared): add instructions + image_key to ExerciseDefinition contract"
```

### Task 1.3: Extend the service projection (DRY across all read/return paths)

**Files:**
- Modify: `apps/elos-api/src/services/exerciseService.ts`
- Test: `apps/elos-api/src/services/__tests__/exerciseService.test.ts`

Context: four methods project exercise columns — `searchExercises`, `getRecentExercises`, `getFavorites` (SELECT), and `createCustomExercise` (RETURNING). Extract one shared column list so the projection can't drift.

- [ ] **Step 1: Write the failing test**

Create `apps/elos-api/src/services/__tests__/exerciseService.test.ts`:

```ts
import { describe, it, expect, vi } from "vitest";
import type { Pool } from "pg";
import { ExerciseService } from "../exerciseService";

function stubPool(rows: unknown[] = []) {
  const query = vi.fn().mockResolvedValue({ rows, rowCount: rows.length });
  return { pool: { query } as unknown as Pool, query };
}

const USER = "11111111-1111-1111-1111-111111111111";

describe("ExerciseService projection", () => {
  it("searchExercises selects instructions and image_key", async () => {
    const { pool, query } = stubPool([]);
    await new ExerciseService(pool).searchExercises(USER, {});
    const sql = query.mock.calls[0][0] as string;
    expect(sql).toContain("instructions");
    expect(sql).toContain("image_key");
  });

  it("createCustomExercise returns instructions and image_key", async () => {
    const { pool, query } = stubPool([{ id: "x" }]);
    await new ExerciseService(pool).createCustomExercise(USER, {
      name: "Test",
      primary_muscle: "chest",
    });
    const sql = query.mock.calls[0][0] as string;
    expect(sql).toContain("instructions");
    expect(sql).toContain("image_key");
  });
});
```

- [ ] **Step 2: Run it, verify it fails**

Run: `pnpm --filter elos-api test`
Expected: FAIL — both assertions fail (columns not yet in the SQL).

- [ ] **Step 3: Add the shared projection constant and use it everywhere**

Near the top of `exerciseService.ts` (after imports), add:

```ts
// Single source of truth for the exercise column projection. Any query that
// returns an ExerciseDefinition must select exactly these, in this order.
const EXERCISE_COLUMNS = `id, owner_id::text, name, primary_muscle,
       secondary_muscles, equipment, movement_pattern,
       instructions, image_key, is_custom, created_at::text`;
```

In `searchExercises`, replace the inline SELECT column list with the constant:

```ts
    const result = await this.db.query<ExerciseDefinition>(
      `SELECT ${EXERCISE_COLUMNS}
       FROM exercise_definitions ed
       WHERE ${where.join(" AND ")}
       ORDER BY ed.is_custom ASC, ed.name ASC
       LIMIT $${limitIdx} OFFSET $${offsetIdx}`,
      params
    );
```

In `getRecentExercises` and `getFavorites`, replace their SELECT column lists with `${EXERCISE_COLUMNS}` as well (read the two methods, ~lines 97-136; their projection currently matches the 9-column list — swap it for the constant; if their columns are `ed.`-prefixed, the unaliased constant still resolves against the single `exercise_definitions ed` table).

In `createCustomExercise`, replace the `RETURNING` list with the constant (leave the INSERT column list unchanged — new custom exercises get the column defaults `'{}'` / `NULL`):

```ts
      `INSERT INTO exercise_definitions
         (owner_id, name, primary_muscle, secondary_muscles, equipment, movement_pattern, is_custom)
       VALUES ($1, $2, $3, $4, $5, $6, true)
       RETURNING ${EXERCISE_COLUMNS}`,
```

- [ ] **Step 4: Run tests + typecheck**

Run: `pnpm --filter elos-api test && pnpm typecheck`
Expected: PASS (both new tests green; `tsc` clean now that returned rows carry the new fields the contract requires).

- [ ] **Step 5: Commit**

```bash
git add apps/elos-api/src/services/exerciseService.ts apps/elos-api/src/services/__tests__/exerciseService.test.ts
git commit -m "feat(api): project instructions + image_key in exercise queries"
```

---

# Group 2 — Import script: matcher + generated seed migration

Goal: an offline `ts-node` script that matches the source dataset to the live catalog (conservatively), and emits `037_seed_exercise_howto.sql` (UPDATE enrich + INSERT gap-fill + movement_pattern backfill) plus a spot-check CSV. Demo-image download is added in Group 5.

### Task 2.1: Vendor the public-domain source data

**Files:**
- Create: `data/free-exercise-db.exercises.json`
- Create: `data/free-exercise-db.NOTICE`

- [ ] **Step 1: Download the source**

Run:
```bash
curl -sL https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/dist/exercises.json \
  -o data/free-exercise-db.exercises.json
```
Verify: `jq 'length' data/free-exercise-db.exercises.json` → `873` (± as upstream evolves). Confirm one record has `name`, `instructions[]`, `images[]`, `mechanic`, `force`, `primaryMuscles[]`, `secondaryMuscles[]`, `equipment`, `category`, `id`.

- [ ] **Step 2: Write the NOTICE**

Create `data/free-exercise-db.NOTICE`:

```
Source: https://github.com/yuhonas/free-exercise-db
License: The Unlicense (public domain). Free to use, copy, modify, and redistribute.
Vendored 2026-07-03 for offline, reproducible generation of exercise how-to content.
Only a matched subset of instructions and one demo image per matched exercise is
imported into Elos; see docs/superpowers/plans/2026-07-03-exercise-how-to-layer.md.
```

- [ ] **Step 3: Commit**

```bash
git add data/free-exercise-db.exercises.json data/free-exercise-db.NOTICE
git commit -m "chore(data): vendor public-domain free-exercise-db source"
```

### Task 2.2: Alias map + gap-fill allowlist + taxonomy map

**Files:**
- Create: `apps/elos-api/src/scripts/howto/aliases.ts`

- [ ] **Step 1: Write the maps**

```ts
// Gym-slang / Elos catalog name (normalized) -> source dataset name (normalized).
// Normalized = lowercase, punctuation stripped, whitespace collapsed (see matcher.normalize).
// Extend this as the match report surfaces confident-but-non-exact pairs.
export const NAME_ALIASES: Record<string, string> = {
  "pec deck": "butterfly",
  "pec deck fly": "butterfly",
  "machine chest fly": "butterfly",
  "reverse pec deck": "reverse machine flyes",
  "seated leg curl": "seated leg curl",
  "lying leg curl": "lying leg curls",
  "leg extension": "leg extensions",
  "lat pulldown": "wide grip lat pulldown",
  "seated cable row": "seated cable rows",
  "hip abduction machine": "thigh abductor",
  "hip adduction machine": "thigh adductor",
  // ... expand during the review pass in Task 2.6
};

// Source exercises to ADD as new generic exercises (machine gaps with no Elos match).
// Each is curated from the match report's unmatched machine/cable entries.
export interface GapFill {
  sourceName: string;   // exact source `name`
  elosName: string;     // name to insert into the catalog
  primaryMuscle: string;// Elos taxonomy value
  secondaryMuscles: string[];
  equipment: string;    // Elos equipment string
  movementPattern: string;
}
export const MACHINE_GAP_FILLS: GapFill[] = [
  { sourceName: "Butterfly", elosName: "Pec Deck", primaryMuscle: "chest", secondaryMuscles: ["front_delts"], equipment: "machine", movementPattern: "isolation" },
  { sourceName: "Reverse Machine Flyes", elosName: "Reverse Pec Deck", primaryMuscle: "rear_delts", secondaryMuscles: ["traps"], equipment: "machine", movementPattern: "isolation" },
  { sourceName: "Thigh Abductor", elosName: "Hip Abduction Machine", primaryMuscle: "glutes", secondaryMuscles: [], equipment: "machine", movementPattern: "isolation" },
  { sourceName: "Thigh Adductor", elosName: "Hip Adduction Machine", primaryMuscle: "adductors", secondaryMuscles: [], equipment: "machine", movementPattern: "isolation" },
  // ... expand during the review pass in Task 2.6
];

// Source `primaryMuscles`/`secondaryMuscles` vocabulary (17 values) -> Elos taxonomy.
export const MUSCLE_MAP: Record<string, string> = {
  abdominals: "core",
  abductors: "glutes",
  adductors: "adductors",
  biceps: "biceps",
  calves: "calves",
  chest: "chest",
  forearms: "forearms",
  glutes: "glutes",
  hamstrings: "hamstrings",
  lats: "lats",
  "lower back": "lower_back",
  "middle back": "back",
  neck: "neck",
  quadriceps: "quads",
  shoulders: "front_delts",
  traps: "traps",
  triceps: "triceps",
};
```

- [ ] **Step 2: Commit**

```bash
git add apps/elos-api/src/scripts/howto/aliases.ts
git commit -m "feat(howto): alias map, machine gap-fill allowlist, muscle taxonomy map"
```

### Task 2.3: Pure matcher (TDD)

**Files:**
- Create: `apps/elos-api/src/scripts/howto/matcher.ts`
- Test: `apps/elos-api/src/scripts/howto/__tests__/matcher.test.ts`

- [ ] **Step 1: Write the failing tests**

```ts
import { describe, it, expect } from "vitest";
import { normalize, deriveMovementPattern, matchCatalog } from "../matcher";
import type { SourceExercise, CatalogExercise } from "../matcher";

describe("normalize", () => {
  it("lowercases, strips punctuation, collapses whitespace", () => {
    expect(normalize("3/4 Sit-Up")).toBe("3 4 sit up");
    expect(normalize("Leg  Extensions")).toBe("leg extensions");
  });
});

describe("deriveMovementPattern", () => {
  it("maps push/pull force, squat/hinge/isolation heuristics", () => {
    expect(deriveMovementPattern({ force: "push", mechanic: "compound", name: "Bench Press" } as SourceExercise)).toBe("push");
    expect(deriveMovementPattern({ force: "pull", mechanic: "compound", name: "Barbell Row" } as SourceExercise)).toBe("pull");
    expect(deriveMovementPattern({ force: "push", mechanic: "compound", name: "Barbell Squat" } as SourceExercise)).toBe("squat");
    expect(deriveMovementPattern({ force: "pull", mechanic: "compound", name: "Romanian Deadlift" } as SourceExercise)).toBe("hinge");
    expect(deriveMovementPattern({ force: "pull", mechanic: "isolation", name: "Bicep Curl" } as SourceExercise)).toBe("isolation");
  });
});

describe("matchCatalog", () => {
  const source: SourceExercise[] = [
    { id: "Leg_Extensions", name: "Leg Extensions", instructions: ["a", "b"], images: ["Leg_Extensions/0.jpg"], primaryMuscles: ["quadriceps"], secondaryMuscles: [], equipment: "machine", force: "push", mechanic: "isolation", category: "strength" },
    { id: "Butterfly", name: "Butterfly", instructions: ["x"], images: ["Butterfly/0.jpg"], primaryMuscles: ["chest"], secondaryMuscles: ["shoulders"], equipment: "machine", force: "push", mechanic: "isolation", category: "strength" },
  ];

  it("matches by exact normalized name", () => {
    const catalog: CatalogExercise[] = [{ name: "Leg Extension", movement_pattern: "" }];
    const { enriched, unmatched } = matchCatalog(catalog, source, {}, {});
    // "leg extension" != "leg extensions" -> not exact; unmatched unless aliased
    expect(unmatched).toContain("Leg Extension");
    expect(enriched).toHaveLength(0);
  });

  it("matches via alias map", () => {
    const catalog: CatalogExercise[] = [{ name: "Pec Deck", movement_pattern: "" }];
    const { enriched } = matchCatalog(catalog, source, { "pec deck": "butterfly" }, {});
    expect(enriched).toHaveLength(1);
    expect(enriched[0].instructions).toEqual(["x"]);
    expect(enriched[0].imageKey).toBe("Butterfly");
  });

  it("leaves ambiguous names unmatched (never guesses)", () => {
    const catalog: CatalogExercise[] = [{ name: "Some Novel Lift", movement_pattern: "" }];
    const { enriched, unmatched } = matchCatalog(catalog, source, {}, {});
    expect(enriched).toHaveLength(0);
    expect(unmatched).toContain("Some Novel Lift");
  });
});
```

- [ ] **Step 2: Run tests, verify they fail**

Run: `pnpm --filter elos-api test`
Expected: FAIL — module `../matcher` not found.

- [ ] **Step 3: Implement `matcher.ts`**

```ts
export interface SourceExercise {
  id: string;
  name: string;
  instructions: string[];
  images: string[];
  primaryMuscles: string[];
  secondaryMuscles: string[];
  equipment: string | null;
  force: string | null;
  mechanic: string | null;
  category: string;
}

export interface CatalogExercise {
  name: string;
  movement_pattern: string;
}

export interface Enriched {
  elosName: string;
  sourceName: string;
  instructions: string[];
  imageKey: string;          // = source id (filesystem-safe)
  imagePath: string;         // = source images[0], for download
  derivedMovementPattern: string;
}

/** lowercase, replace non-alphanumeric with space, collapse whitespace. */
export function normalize(s: string): string {
  return s
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, " ")
    .trim()
    .replace(/\s+/g, " ");
}

/** Derive an Elos movement_pattern from the source's force/mechanic/name. */
export function deriveMovementPattern(ex: SourceExercise): string {
  const n = normalize(ex.name);
  if (/\bsquat\b/.test(n)) return "squat";
  if (/\b(deadlift|romanian|rdl|hip thrust|good morning|hyperextension)\b/.test(n)) return "hinge";
  if (ex.mechanic === "isolation") return "isolation";
  if (ex.force === "push") return "push";
  if (ex.force === "pull") return "pull";
  return "isolation";
}

/**
 * Conservative match: exact-normalized name OR alias-map hit only. No fuzzy matching.
 * A wrong how-to is worse than none.
 */
export function matchCatalog(
  catalog: CatalogExercise[],
  source: SourceExercise[],
  aliases: Record<string, string>,
  _muscleMap: Record<string, string>
): { enriched: Enriched[]; unmatched: string[] } {
  const byNorm = new Map<string, SourceExercise>();
  for (const s of source) {
    const key = normalize(s.name);
    if (!byNorm.has(key)) byNorm.set(key, s); // first wins; source has near-dupes
  }

  const enriched: Enriched[] = [];
  const unmatched: string[] = [];

  for (const c of catalog) {
    const cn = normalize(c.name);
    const target = aliases[cn] ?? cn;
    const src = byNorm.get(target);
    if (!src || src.instructions.length === 0) {
      unmatched.push(c.name);
      continue;
    }
    enriched.push({
      elosName: c.name,
      sourceName: src.name,
      instructions: src.instructions,
      imageKey: src.id,
      imagePath: src.images[0] ?? "",
      derivedMovementPattern: deriveMovementPattern(src),
    });
  }
  return { enriched, unmatched };
}
```

- [ ] **Step 4: Run tests, verify they pass**

Run: `pnpm --filter elos-api test`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add apps/elos-api/src/scripts/howto/matcher.ts apps/elos-api/src/scripts/howto/__tests__/matcher.test.ts
git commit -m "feat(howto): conservative pure matcher with movement-pattern derivation"
```

### Task 2.4: Generator — emit migration 037 + report

**Files:**
- Create: `apps/elos-api/src/scripts/howto/generate.ts`
- Modify: `apps/elos-api/package.json` (add script)

Note: this reads the live dev catalog via the existing `pool` (same as `migrate.ts`). Requires `pnpm db:up && pnpm migrate` first so the 206 global exercises are present.

- [ ] **Step 1: Add the package.json script**

In `apps/elos-api/package.json` `scripts`, add:

```json
    "howto:generate": "ts-node src/scripts/howto/generate.ts",
```

- [ ] **Step 2: Implement `generate.ts`** (image download stubbed until Group 5)

```ts
import { readFileSync, writeFileSync, mkdirSync } from "fs";
import { join, dirname } from "path";
import { pool } from "../../db";
import { matchCatalog, type SourceExercise, type CatalogExercise } from "./matcher";
import { NAME_ALIASES, MUSCLE_MAP, MACHINE_GAP_FILLS } from "./aliases";

const REPO_ROOT = join(__dirname, "..", "..", "..", "..", "..");
const SOURCE = join(REPO_ROOT, "data", "free-exercise-db.exercises.json");
const MIGRATION_OUT = join(__dirname, "..", "..", "..", "migrations", "037_seed_exercise_howto.sql");
const REPORT_OUT = join(REPO_ROOT, "docs", "superpowers", "artifacts", "2026-07-03-howto-match-report.csv");

// Postgres literal helpers.
const sq = (s: string) => `'${s.replace(/'/g, "''")}'`;
const pgTextArray = (arr: string[]) =>
  `ARRAY[${arr.map((s) => sq(s)).join(", ")}]::text[]`;

async function main() {
  const source: SourceExercise[] = JSON.parse(readFileSync(SOURCE, "utf8"));
  const { rows } = await pool.query<CatalogExercise>(
    "SELECT name, movement_pattern FROM exercise_definitions WHERE owner_id IS NULL"
  );

  const { enriched, unmatched } = matchCatalog(rows, source, NAME_ALIASES, MUSCLE_MAP);

  const lines: string[] = [
    "-- GENERATED by src/scripts/howto/generate.ts. Do not hand-edit; re-run howto:generate.",
    "-- Enriches matched exercises with how-to content and backfills movement_pattern;",
    "-- inserts curated machine gap-fill exercises. Re-runnable (guarded).",
    "",
  ];

  // Pass A: enrich matched rows.
  for (const e of enriched) {
    lines.push(
      `UPDATE exercise_definitions SET instructions = ${pgTextArray(e.instructions)}, image_key = ${sq(e.imageKey)} ` +
        `WHERE lower(name) = lower(${sq(e.elosName)}) AND owner_id IS NULL;`
    );
    // Backfill movement_pattern only when empty.
    lines.push(
      `UPDATE exercise_definitions SET movement_pattern = ${sq(e.derivedMovementPattern)} ` +
        `WHERE lower(name) = lower(${sq(e.elosName)}) AND owner_id IS NULL AND movement_pattern = '';`
    );
  }
  lines.push("");

  // Pass B: insert curated machine gap-fills (guarded so re-runs don't duplicate).
  const srcByName = new Map(source.map((s) => [s.name, s]));
  for (const g of MACHINE_GAP_FILLS) {
    const src = srcByName.get(g.sourceName);
    if (!src) {
      console.warn(`gap-fill source not found: ${g.sourceName}`);
      continue;
    }
    lines.push(
      `INSERT INTO exercise_definitions (name, primary_muscle, secondary_muscles, equipment, movement_pattern, instructions, image_key) ` +
        `SELECT ${sq(g.elosName)}, ${sq(g.primaryMuscle)}, ${pgTextArray(g.secondaryMuscles)}, ${sq(g.equipment)}, ${sq(g.movementPattern)}, ${pgTextArray(src.instructions)}, ${sq(src.id)} ` +
        `WHERE NOT EXISTS (SELECT 1 FROM exercise_definitions WHERE lower(name) = lower(${sq(g.elosName)}) AND owner_id IS NULL);`
    );
  }

  writeFileSync(MIGRATION_OUT, lines.join("\n") + "\n");

  // Spot-check report. (writeFileSync does not create parent dirs.)
  mkdirSync(dirname(REPORT_OUT), { recursive: true });
  const csv = ["elos_name,source_name,image_key,status"];
  for (const e of enriched) csv.push(`${sq(e.elosName)},${sq(e.sourceName)},${e.imageKey},matched`);
  for (const u of unmatched) csv.push(`${sq(u)},,,unmatched`);
  writeFileSync(REPORT_OUT, csv.join("\n") + "\n");

  console.log(`Enriched: ${enriched.length}  Unmatched: ${unmatched.length}  Gap-fills: ${MACHINE_GAP_FILLS.length}`);
  console.log(`Wrote ${MIGRATION_OUT}`);
  console.log(`Wrote ${REPORT_OUT}`);
  await pool.end();
}

main().catch((err) => { console.error(err); process.exit(1); });
```

- [ ] **Step 3: Verify the generator paths resolve (dry compile)**

Run: `pnpm typecheck`
Expected: PASS. (Adjust the `REPO_ROOT` `..` depth if `__dirname` resolution differs — the file is at `apps/elos-api/src/scripts/howto/`, so repo root is five levels up.)

- [ ] **Step 4: Commit**

```bash
git add apps/elos-api/src/scripts/howto/generate.ts apps/elos-api/package.json
git commit -m "feat(howto): generator emits seed migration 037 + match report"
```

### Task 2.5: Run generation, spot-check, apply

**Files:**
- Create (generated): `apps/elos-api/migrations/037_seed_exercise_howto.sql`, `docs/superpowers/artifacts/2026-07-03-howto-match-report.csv`

- [ ] **Step 1: Ensure DB is seeded, then generate**

Run: `pnpm db:up && pnpm migrate && pnpm --filter elos-api howto:generate`
Expected: prints `Enriched: N  Unmatched: M  Gap-fills: K` and writes both files.

- [ ] **Step 2: Spot-check the report**

Open `docs/superpowers/artifacts/2026-07-03-howto-match-report.csv`. Scan the `matched` rows for obviously wrong pairings (a bad match is worse than none). Scan `unmatched` machine/cable-type names — add high-value ones to `NAME_ALIASES` (if the source has them under a different name) or `MACHINE_GAP_FILLS` (if they need inserting). Re-run Step 1 after edits until the matched set looks clean. **Log the final counts** in the commit message so coverage isn't silently truncated.

- [ ] **Step 3: Apply the generated migration**

Run: `pnpm migrate`
Expected: `Applying migration: 037_seed_exercise_howto.sql` … `Migrations complete.`

- [ ] **Step 4: Sanity-check content in the API**

Query one enriched row (e.g. via a REST call or psql):
`SELECT name, array_length(instructions,1), image_key FROM exercise_definitions WHERE lower(name)=lower('Pec Deck');`
Expected: non-null instruction count and an `image_key`.

- [ ] **Step 5: Commit**

```bash
git add apps/elos-api/migrations/037_seed_exercise_howto.sql docs/superpowers/artifacts/2026-07-03-howto-match-report.csv apps/elos-api/src/scripts/howto/aliases.ts
git commit -m "feat(howto): seed exercise how-to content (enriched N, gap-filled K)"
```

---

# Group 3 — iOS: model + sync (content reaches SwiftData)

### Task 3.1: Add fields to `ExerciseDefinitionRecord`

**Files:**
- Modify: `apps/elos-mobile/Elos/Elos/SwiftData/ElosSchema.swift:244-273`

- [ ] **Step 1: Add the stored fields, computed accessor, and init params**

Add two stored properties (defaulted → lightweight migration, no store reset), a computed `instructions` mirroring the existing `secondaryMuscles` pattern, and extend the initializer with defaulted params:

```swift
    var instructionsJSON: String = ""
    var imageKey: String = ""

    var instructions: [String] {
        (try? JSONDecoder().decode([String].self, from: Data(instructionsJSON.utf8))) ?? []
    }
```

In the initializer, add parameters `instructionsJSON: String = ""` and `imageKey: String = ""` and assign them (keep them last so existing call sites compile unchanged).

- [ ] **Step 2: Build**

Run (from `apps/elos-mobile/Elos/`): `xcodebuild build -scheme Elos -destination 'platform=iOS Simulator,name=iPhone 17'`
Expected: BUILD SUCCEEDED.

- [ ] **Step 3: Commit**

```bash
git add apps/elos-mobile/Elos/Elos/SwiftData/ElosSchema.swift
git commit -m "feat(ios): add instructions + imageKey to ExerciseDefinitionRecord"
```

### Task 3.2: Decode + upsert the new fields in sync

**Files:**
- Modify: `apps/elos-mobile/Elos/Elos/Features/Train/ExercisePicker/ExercisePickerViewModel.swift`

- [ ] **Step 1: Extend `ExerciseResponse`**

Add to the struct (lines 7-16), tolerating older servers by making them optional:

```swift
        let instructions: [String]?
        let image_key: String?
```

- [ ] **Step 2: Populate on upsert (both branches)**

In `syncExercises` (lines 96-118), compute the instructions JSON and set it in both the update and insert branches:

```swift
        for ex in incoming {
            let secondaryJSON = (try? String(data: JSONEncoder().encode(ex.secondary_muscles), encoding: .utf8)) ?? "[]"
            let instructionsJSON = (try? String(data: JSONEncoder().encode(ex.instructions ?? []), encoding: .utf8)) ?? "[]"
            if let record = existingByID[ex.id] {
                record.name = ex.name
                record.equipment = ex.equipment
                record.primaryMuscle = ex.primary_muscle
                record.secondaryMusclesJSON = secondaryJSON
                record.movementPattern = ex.movement_pattern
                record.instructionsJSON = instructionsJSON
                record.imageKey = ex.image_key ?? ""
            } else {
                let record = ExerciseDefinitionRecord(
                    id: ex.id,
                    ownerID: ex.owner_id ?? "",
                    name: ex.name,
                    primaryMuscle: ex.primary_muscle,
                    secondaryMusclesJSON: secondaryJSON,
                    equipment: ex.equipment,
                    movementPattern: ex.movement_pattern,
                    isCustom: ex.is_custom,
                    instructionsJSON: instructionsJSON,
                    imageKey: ex.image_key ?? ""
                )
                context.insert(record)
            }
        }
```

- [ ] **Step 3: Build**

Run: `xcodebuild build -scheme Elos -destination 'platform=iOS Simulator,name=iPhone 17'`
Expected: BUILD SUCCEEDED.

- [ ] **Step 4: Commit**

```bash
git add apps/elos-mobile/Elos/Elos/Features/Train/ExercisePicker/ExercisePickerViewModel.swift
git commit -m "feat(ios): sync instructions + imageKey into the local exercise catalog"
```

---

# Group 4 — iOS: how-to sheet + ⓘ wiring (text renders end-to-end)

After this group, tapping ⓘ on an enriched exercise shows the how-to steps. Images come in Group 5 (the sheet renders text-only until then).

### Task 4.1: `ExerciseHowTo` value type + `from(record:)` (TDD)

**Files:**
- Create: `apps/elos-mobile/Elos/Elos/Features/Train/HowTo/ExerciseHowTo.swift`
- Test: `apps/elos-mobile/Elos/ElosTests/HowTo/ExerciseHowToTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
import Testing
@testable import Elos

struct ExerciseHowToTests {
    @Test func returnsNilWhenNoInstructions() {
        let r = ExerciseDefinitionRecord(
            id: "1", ownerID: "", name: "Pec Deck", primaryMuscle: "chest",
            secondaryMusclesJSON: "[]", equipment: "machine", movementPattern: "isolation",
            isCustom: false, instructionsJSON: "[]", imageKey: ""
        )
        #expect(ExerciseHowTo.from(record: r) == nil)
    }

    @Test func buildsFromRecordWithSteps() {
        let r = ExerciseDefinitionRecord(
            id: "1", ownerID: "", name: "Pec Deck", primaryMuscle: "chest",
            secondaryMusclesJSON: "[]", equipment: "machine", movementPattern: "isolation",
            isCustom: false, instructionsJSON: "[\"Sit down.\",\"Squeeze.\"]", imageKey: "Butterfly"
        )
        let howTo = ExerciseHowTo.from(record: r)
        #expect(howTo?.steps == ["Sit down.", "Squeeze."])
        #expect(howTo?.imageKey == "Butterfly")
    }
}
```

- [ ] **Step 2: Run, verify it fails**

Run: `xcodebuild test -scheme Elos -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:ElosTests/ExerciseHowToTests`
Expected: FAIL — `ExerciseHowTo` undefined.

- [ ] **Step 3: Implement `ExerciseHowTo.swift`**

```swift
import Foundation
import SwiftData

/// Reference how-to content for a generic exercise. Keyed on the generic exercise,
/// so every brand-machine variant inherits it. Pure value type.
struct ExerciseHowTo: Equatable {
    let name: String
    let steps: [String]
    let imageKey: String?   // nil / "" -> no bundled photo

    /// Returns nil when the record has no instructions (ⓘ then falls back to the muscle caption).
    static func from(record: ExerciseDefinitionRecord) -> ExerciseHowTo? {
        let steps = record.instructions
        guard !steps.isEmpty else { return nil }
        let key = record.imageKey.isEmpty ? nil : record.imageKey
        return ExerciseHowTo(name: record.name, steps: steps, imageKey: key)
    }
}

/// Looks up how-to content for an exercise by its (catalog) name.
enum ExerciseHowToLookup {
    static func find(name: String, in context: ModelContext) -> ExerciseHowTo? {
        var descriptor = FetchDescriptor<ExerciseDefinitionRecord>(
            predicate: #Predicate { $0.name == name }
        )
        descriptor.fetchLimit = 5
        let matches = (try? context.fetch(descriptor)) ?? []
        // Prefer a global catalog row (empty ownerID) over a custom one.
        let record = matches.first(where: { $0.ownerID.isEmpty }) ?? matches.first
        return record.flatMap(ExerciseHowTo.from(record:))
    }
}
```

- [ ] **Step 4: Run, verify it passes**

Run: `xcodebuild test -scheme Elos -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:ElosTests/ExerciseHowToTests`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add apps/elos-mobile/Elos/Elos/Features/Train/HowTo/ExerciseHowTo.swift apps/elos-mobile/Elos/ElosTests/HowTo/ExerciseHowToTests.swift
git commit -m "feat(ios): ExerciseHowTo value type + catalog lookup"
```

### Task 4.2: The how-to sheet view

**Files:**
- Create: `apps/elos-mobile/Elos/Elos/Features/Train/HowTo/ExerciseHowToSheet.swift`

- [ ] **Step 1: Implement the sheet** (text-only for now; image slot wired in Group 5)

Mirror `MachineSelectionSheet`/`LogSleepSheet` conventions (NavigationView, drag handle, `.presentationDetents`):

```swift
import SwiftUI

struct ExerciseHowToSheet: View {
    let howTo: ExerciseHowTo
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Image slot — filled in Group 5.
                    ExerciseHowToImage(imageKey: howTo.imageKey)

                    VStack(alignment: .leading, spacing: 14) {
                        ForEach(Array(howTo.steps.enumerated()), id: \.offset) { idx, step in
                            HStack(alignment: .top, spacing: 10) {
                                Text("\(idx + 1)")
                                    .font(.subheadline.weight(.semibold))
                                    .frame(width: 24, height: 24)
                                    .background(Circle().fill(Color.accentColor.opacity(0.15)))
                                Text(step)
                                    .font(.body)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }
                }
                .padding(20)
            }
            .navigationTitle(howTo.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

/// Placeholder until Group 5 adds the bundled asset catalog. Renders nothing when
/// the key is absent or the asset isn't bundled yet.
struct ExerciseHowToImage: View {
    let imageKey: String?
    var body: some View {
        if let key = imageKey, UIImage(named: key) != nil {
            Image(key)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}
```

- [ ] **Step 2: Build**

Run: `xcodebuild build -scheme Elos -destination 'platform=iOS Simulator,name=iPhone 17'`
Expected: BUILD SUCCEEDED.

- [ ] **Step 3: Commit**

```bash
git add apps/elos-mobile/Elos/Elos/Features/Train/HowTo/ExerciseHowToSheet.swift
git commit -m "feat(ios): exercise how-to sheet (text steps + image slot)"
```

### Task 4.3: Wire the active-session ⓘ

**Files:**
- Modify: `apps/elos-mobile/Elos/Elos/Features/ActiveWorkout/SetRowView.swift`

Context: `SessionExerciseCard` already has `@State private var showInfo` (line 23), an ⓘ button (lines 94-97) toggling it, and `if showInfo { muscleCaption }` (line 40). We resolve how-to on appear; if present, ⓘ opens the sheet, else it keeps today's caption behavior.

- [ ] **Step 1: Add state + environment**

Near the existing `@State` declarations in `SessionExerciseCard`, add:

```swift
    @Environment(\.modelContext) private var modelContext
    @State private var howTo: ExerciseHowTo?
    @State private var showHowTo = false
```

- [ ] **Step 2: Resolve on appear**

Add an `.onAppear` (or extend an existing one) on the card body:

```swift
        .onAppear {
            if howTo == nil {
                howTo = ExerciseHowToLookup.find(name: exercise.name, in: modelContext)
            }
        }
        .sheet(isPresented: $showHowTo) {
            if let howTo { ExerciseHowToSheet(howTo: howTo) }
        }
```

- [ ] **Step 3: Change the ⓘ action** (lines 94-97)

```swift
        Button {
            if howTo != nil {
                HapticManager.impact(.light)
                showHowTo = true
            } else {
                withAnimation { showInfo.toggle() }
            }
        } label: {
            Image(systemName: "info.circle").font(.caption).foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
```

(The `showInfo` / `muscleCaption` fallback path is unchanged and still serves exercises with no how-to.)

- [ ] **Step 4: Build + manual smoke**

Run: `xcodebuild build -scheme Elos -destination 'platform=iOS Simulator,name=iPhone 17'`
Then run the app, start a workout, add an enriched exercise (e.g. Pec Deck / Bench Press), tap ⓘ → the how-to sheet appears with steps. Add a non-enriched/custom exercise → ⓘ still shows the muscle caption.

- [ ] **Step 5: Commit**

```bash
git add apps/elos-mobile/Elos/Elos/Features/ActiveWorkout/SetRowView.swift
git commit -m "feat(ios): active-session ⓘ opens the how-to sheet when content exists"
```

### Task 4.4: Wire the picker ⓘ

**Files:**
- Modify: `apps/elos-mobile/Elos/Elos/Features/Train/ExercisePicker/ExercisePickerView.swift`

Context: the picker has full catalog data in its `@Query`, so it can carry how-to inline on its `Row` (no per-row fetch).

- [ ] **Step 1: Extend the `Row` struct** (lines 395-402)

Add the fields **with defaults** so the synthesized memberwise initializer stays valid at every `Row(...)` call site:

```swift
        let instructions: [String] = []
        let imageKey: String = ""
```

- [ ] **Step 2: Populate at ALL THREE `Row(...)` construction sites**

`Row` is built in three places — do not miss any, or the build fails with "missing arguments":

1. `allRows` (line ~406), from `dbExercises` (`ExerciseDefinitionRecord`):

```swift
        dbExercises.map {
            Row(id: $0.id, name: $0.name, primaryMuscle: $0.primaryMuscle,
                equipment: $0.equipment, movementPattern: $0.movementPattern,
                isCustom: $0.isCustom,
                instructions: $0.instructions, imageKey: $0.imageKey)
        }
```

2. The `.recent` case in `rowsForCurrentTab` (line ~418) and 3. the `.favorites` case (line ~424), both built from `[ExerciseResponse]`. `ExerciseResponse` gained `instructions`/`image_key` in Task 3.2, so append to each `Row(...)`:

```swift
                instructions: $0.instructions ?? [], imageKey: $0.image_key ?? ""
```

(The defaults from Step 1 make this a safety net, but wire the real values so ⓘ works on the Recent and Favorites tabs too.)

- [ ] **Step 3: Add sheet state + the ⓘ button**

Add `@State private var howToRow: ExerciseHowTo?` to the view. In `rowView(_:)`, insert an ⓘ button just before the trailing `Spacer()`/star (~line 675), shown only when content exists:

```swift
            if !row.instructions.isEmpty {
                Button {
                    HapticManager.impact(.light)
                    howToRow = ExerciseHowTo(
                        name: row.name,
                        steps: row.instructions,
                        imageKey: row.imageKey.isEmpty ? nil : row.imageKey
                    )
                } label: {
                    Image(systemName: "info.circle").foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
```

Attach a sheet at the list/view level:

```swift
        .sheet(item: $howToRow) { ExerciseHowToSheet(howTo: $0) }
```

For `.sheet(item:)`, make `ExerciseHowTo` conform to `Identifiable` — add `var id: String { name }` in `ExerciseHowTo.swift` (and `Hashable` if the compiler asks).

- [ ] **Step 4: Build + manual smoke**

Run: `xcodebuild build -scheme Elos -destination 'platform=iOS Simulator,name=iPhone 17'`
Open the picker, confirm ⓘ appears on enriched rows and opens the same sheet; tapping the row still selects as before (ⓘ must not trigger selection — it's a nested `.plain` button, same pattern as the star).

- [ ] **Step 5: Commit**

```bash
git add apps/elos-mobile/Elos/Elos/Features/Train/HowTo/ExerciseHowTo.swift apps/elos-mobile/Elos/Elos/Features/Train/ExercisePicker/ExercisePickerView.swift
git commit -m "feat(ios): exercise picker ⓘ opens the how-to sheet"
```

---

# Group 5 — iOS: bundled demo photos

Goal: fill the image slot with bundled public-domain photos. De-risk asset-catalog bundling with one image before bulk-generating.

### Task 5.1: Create the asset catalog + de-risk with one image

**Files:**
- Create: `apps/elos-mobile/Elos/Elos/Resources/ExerciseHowTo.xcassets/Contents.json`
- Create: `.../ExerciseHowTo.xcassets/Butterfly.imageset/{Contents.json, Butterfly.jpg}`

- [ ] **Step 1: Create the catalog root**

`ExerciseHowTo.xcassets/Contents.json`:
```json
{ "info" : { "author" : "xcode", "version" : 1 } }
```

- [ ] **Step 2: Add one imageset manually**

Download one image and create its imageset:
```bash
mkdir -p apps/elos-mobile/Elos/Elos/Resources/ExerciseHowTo.xcassets/Butterfly.imageset
curl -sL https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Butterfly/0.jpg \
  -o apps/elos-mobile/Elos/Elos/Resources/ExerciseHowTo.xcassets/Butterfly.imageset/Butterfly.jpg
```
`Butterfly.imageset/Contents.json`:
```json
{
  "images" : [ { "filename" : "Butterfly.jpg", "idiom" : "universal" } ],
  "info" : { "author" : "xcode", "version" : 1 }
}
```

- [ ] **Step 3: Build + verify the asset resolves at runtime**

Run: `xcodebuild build -scheme Elos -destination 'platform=iOS Simulator,name=iPhone 17'`
Then run the app and open the Pec Deck how-to (image_key `Butterfly`) → the photo renders. This confirms a synchronized-group `.xcassets` is compiled and `UIImage(named:)` resolves it. **If it does not render**, fall back to hosting (see spec §6 alternative) before bulk-importing — stop and flag.

- [ ] **Step 4: Commit**

```bash
git add apps/elos-mobile/Elos/Elos/Resources/ExerciseHowTo.xcassets
git commit -m "feat(ios): exercise how-to asset catalog + first demo photo"
```

### Task 5.2: Extend the generator to emit imagesets

**Files:**
- Modify: `apps/elos-api/src/scripts/howto/generate.ts`

- [ ] **Step 1: Add image download + imageset emission**

Add to `generate.ts` (after computing `enriched`, before `pool.end()`), downloading `images[0]` for each enriched + gap-fill exercise into `ExerciseHowTo.xcassets/<imageKey>.imageset/`:

```ts
import { mkdirSync } from "fs";
const ASSETS = join(REPO_ROOT, "apps", "elos-mobile", "Elos", "Elos", "Resources", "ExerciseHowTo.xcassets");
const RAW_BASE = "https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/";

async function writeImageset(imageKey: string, imagePath: string) {
  if (!imagePath) return;
  const dir = join(ASSETS, `${imageKey}.imageset`);
  mkdirSync(dir, { recursive: true });
  const res = await fetch(RAW_BASE + imagePath);
  if (!res.ok) { console.warn(`image miss: ${imagePath}`); return; }
  const buf = Buffer.from(await res.arrayBuffer());
  writeFileSync(join(dir, `${imageKey}.jpg`), buf);
  writeFileSync(join(dir, "Contents.json"), JSON.stringify({
    images: [{ filename: `${imageKey}.jpg`, idiom: "universal" }],
    info: { author: "xcode", version: 1 },
  }, null, 2) + "\n");
}
```

Call it for each enriched exercise (`writeImageset(e.imageKey, e.imagePath)`) and each gap-fill (`writeImageset(src.id, src.images[0] ?? "")`). Run these sequentially or with a small concurrency cap to be polite to the CDN.

- [ ] **Step 2: Typecheck**

Run: `pnpm typecheck`
Expected: PASS. (`fetch`/`Buffer` are available in the Node version this repo targets; if `fetch` is undefined, use `node-fetch` already present or bump the ts-node lib — verify Node ≥18.)

- [ ] **Step 3: Commit**

```bash
git add apps/elos-api/src/scripts/howto/generate.ts
git commit -m "feat(howto): generator downloads + bundles demo photos as imagesets"
```

### Task 5.3: Generate all images, verify, commit

- [ ] **Step 1: Re-run generation**

Run: `pnpm --filter elos-api howto:generate`
Expected: `ExerciseHowTo.xcassets` populated with one imageset per matched/gap-fill exercise.

- [ ] **Step 2: Build + spot-check several how-tos**

Run: `xcodebuild build -scheme Elos -destination 'platform=iOS Simulator,name=iPhone 17'`
Open 4-5 different enriched exercises in-app → each shows its photo + steps. Note the app binary size delta (spec §9 open question); if it exceeds a comfortable budget, revisit hosting.

- [ ] **Step 3: Run the full iOS test suite**

Run: `xcodebuild test -scheme Elos -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:ElosTests`
Expected: PASS.

- [ ] **Step 4: Commit**

```bash
git add apps/elos-mobile/Elos/Elos/Resources/ExerciseHowTo.xcassets
git commit -m "feat(ios): bundle demo photos for all enriched exercises"
```

---

# Wrap-up

- [ ] **Full backend suite:** `pnpm --filter elos-api test && pnpm typecheck` → PASS.
- [ ] **Full iOS suite:** `xcodebuild test -scheme Elos -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:ElosTests` → PASS.
- [ ] **Deploy ordering note:** migrations `036` and `037` MUST be applied before the new server code is deployed (the service now selects `instructions`/`image_key`). Same constraint as prior column-adding migrations.
- [ ] **Update memory:** add a `reference`/`project` memory noting the how-to layer (content on generic `exercise_definitions`, `image_key` → bundled asset catalog, import via `pnpm --filter elos-api howto:generate`, Phase 2 = licensed GIFs into the same slot). Link `[[equipment-machine-tracking]]` and `[[exercise-sort-intelligence-layer]]`.
- [ ] **Open the PR** against `main` from `feat/core-functionality-hardening` (or a dedicated branch), summarizing the three-layer change and the deploy-ordering constraint.

## Notes on deferred / Phase-2 items (do NOT build now)

- **Animated GIFs** via a licensed source (ExerciseDB.io) drop into the existing `image_key` slot — separate spec, pending budget/legal.
- **Multilingual instructions** — out of scope; English only.
- **`definitionID` on in-session `Exercise`** — the name-based lookup in `ExerciseHowToLookup` is sufficient for v1; add exact-id lookup only if name collisions ever appear.
