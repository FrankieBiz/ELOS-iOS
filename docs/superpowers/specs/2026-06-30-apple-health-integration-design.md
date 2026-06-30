# Apple Health (HealthKit) Integration — Design

**Date:** 2026-06-30
**Branch:** `feat/core-functionality-hardening`
**Status:** Approved (execute)

## Goal

Connect Elos to Apple Health: **write** completed workouts so they appear in Apple Fitness /
contribute to Activity, and **read** body weight + resting heart rate + step count to keep the
profile current and enrich readiness/recovery. Opt-in, user-controlled, and non-fatal everywhere
(Health is enrichment, never a hard dependency).

## Decisions (locked)

- **Scope:** write workouts; read body weight, resting HR, steps.
- **Connect UX:** opt-in **Settings → Apple Health** toggle (mirrors the existing Canvas section);
  authorization requested on connect; once connected, workouts export automatically. A one-time
  "Connect Apple Health" offer also appears on the post-session summary.
- **Read metrics:** **display + gentle hint** — body weight updates the profile (BMI/calorie targets
  recompute as they already do); resting HR + steps shown on Today/readiness; a non-intrusive
  "recovery may be down" hint when resting HR is meaningfully above the user's baseline. The
  readiness *score* is NOT silently changed.
- **Backfill:** on connect, export finished sessions from the last ~90 days (dedup), then every new one.

## Architecture (thin service + pure helpers)

- **`Services/HealthKitService.swift`** — `@MainActor`, wraps `HKHealthStore`. Single boundary for all
  HealthKit access. API:
  - `isAvailable` → `HKHealthStore.isHealthDataAvailable()`
  - `requestAuthorization() async -> Bool` — share: `workoutType`, `activeEnergyBurned`; read:
    `bodyMass`, `restingHeartRate`, `stepCount`
  - `export(session:bodyWeightKg:) async -> Bool` — saves `HKWorkout(.traditionalStrengthTraining)`
    (start/end/duration + estimated active energy)
  - `backfillRecent(sessions:bodyWeightKg:) async` — finished sessions in last 90 days where
    `!exportedToHealth`, marking each
  - `latestBodyWeightKg()`, `todaySteps()`, `restingHeartRate()`, `restingHRBaseline(days:)` —
    each `async -> ...?`, returning nil on unavailable/denied/empty
- **Pure engines (Swift Testing, under `Intelligence/`):**
  - `HealthEnergy.estimateKcal(durationSec:bodyWeightKg:)` — MET-based (~5 MET strength training)
  - `RecoveryHint.evaluate(restingHR:baseline:)` → a hint only when resting HR is meaningfully
    (~>10%) above baseline
- **Persistence:** add `exportedToHealth: Bool = false` to `WorkoutSessionRecord` (additive
  lightweight migration; dedup flag). `healthKitEnabled` preference in `UserDefaults`.
- **`AppViewModel`** gains `@Published var healthSnapshot: HealthSnapshot?` (weight, restingHR,
  baseline, steps, recoveryHint, updatedAt), refreshed on connect and on foreground.

## Data flow

- **Connect:** Settings toggle → `requestAuthorization()`; on success set the pref, run
  `backfillRecent`, refresh the snapshot, and pull latest body weight → update
  `UserProfileRecord.weightKg`.
- **Write:** `TrainViewModel.finishSession` (when enabled) exports the just-finished session, sets
  `exportedToHealth = true`. Failed export leaves the flag false to retry on next finish/foreground.
- **Read:** on connect/foreground, refresh weight (→ profile), steps, resting HR + baseline; compute
  the recovery hint. Today + the readiness check-in render these; rows hide when a value is nil.

## Error handling

All calls gated on `isHealthDataAvailable()` + authorization status. Reads degrade to nil (UI hides
the row). Nothing throws to the UI. Disabling the toggle stops writes/reads (data already in Health
is left as-is).

## Capability / Info.plist (the awkward part)

Requires the **HealthKit capability** (entitlement `com.apple.developer.healthkit`) and Info.plist
usage strings `NSHealthShareUsageDescription` / `NSHealthUpdateUsageDescription` (or the equivalent
`INFOPLIST_KEY_*` build settings). These need entitlements/`project.pbxproj` edits (not auto-joined
like source files). The pure logic and build are verifiable here; full runtime Health reads need a
device with Health data.

## Testing

Swift Testing for `HealthEnergy` and `RecoveryHint`. Build verification for the service + UI wiring.
The `HKHealthStore` layer stays deliberately thin so the untestable surface is minimal.

## Out of scope (YAGNI)

Background delivery / `HKObserverQuery` live updates, writing body weight from Elos (no weight-entry
UI yet), heart-rate-during-workout capture, auto-changing the readiness score from HR/steps.
