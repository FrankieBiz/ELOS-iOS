# Spec: Direct Wearable API Integrations (Garmin + Fitbit)

**Date:** 2026-07-11
**Status:** Approved for planning

## Problem

ELOS currently reads health data only from Apple HealthKit on-device. Two problems:

1. **Data mismatch.** The user wears a Garmin. Steps/HR that reach ELOS via
   Garmin Connect → Apple Health → HealthKit often disagree with what Garmin
   Connect itself shows (sync lag, partial type coverage, Apple Health merging
   multiple sources). The numbers in ELOS don't match the numbers on the watch.
2. **Coverage gap.** Fitbit does not sync to Apple Health at all on iOS, so
   Fitbit users get nothing without a third-party bridge app.

## Goal

Cronometer-style **direct cloud integrations**: the user connects their Garmin
and/or Fitbit account once inside ELOS; the ELOS backend receives their data
from the vendor cloud APIs from then on; the app displays wearable metrics that
match the vendor's own app and feeds them into readiness/training intelligence.

## Requirements

### Backend (elos-api)
- R1. Users can connect and disconnect a Garmin account (Garmin Connect
  Developer Program / Health API, OAuth) and a Fitbit account (Fitbit Web API,
  OAuth 2.0 + PKCE). Tokens stored server-side, encrypted at rest.
- R2. Ingestion is webhook-driven (Garmin push/ping notifications, Fitbit
  Subscriptions API) with an on-connect backfill of recent history.
- R3. All provider data is normalized into one canonical daily-metrics store
  (single source of truth; provider-specific shapes converted at the boundary):
  steps, resting HR, HRV, sleep duration + stages, active energy, plus a
  connection registry. Raw provider payloads retained for reprocessing.
- R4. A per-metric **source priority** rule resolves conflicts: connected
  wearable > HealthKit > manual. Every served value carries its source. No
  double counting when multiple sources report the same day.
- R5. API endpoints for the mobile app: start OAuth, list connection status,
  disconnect, fetch daily metrics (range query).

### Mobile (elos-mobile)
- R6. Settings gains a "Connected Devices" screen: per-provider row with
  status + last sync, connect via `ASWebAuthenticationSession` against the
  backend OAuth start URL, disconnect with confirmation.
- R7. Daily metrics from the backend merge with HealthKit locally using the R4
  priority order; readiness check-in and the training-intelligence health
  metrics consume the merged values and show which source supplied them.
- R8. Feature is gated behind a `FeatureFlags` flag until Garmin production
  access is granted.

## Non-goals

- Aggregator services (Terra/Rook/Spike) — revisit at scale.
- Android / Google Health Connect (Health Connect is Android on-device only;
  irrelevant for the iOS app — Fitbit's server path is the Fitbit Web API).
- Nutrition or body-composition sync.
- Committing to Garmin's production fee up front — build against the free
  evaluation tier; production approval is a launch gate, not a build gate.

## Success criteria

- Steps / resting HR / sleep shown in ELOS for a Garmin-connected user match
  Garmin Connect for the same day.
- A Fitbit-connected user sees daily metrics with no HealthKit involvement.
- Readiness check-in pre-fills from wearable data with source attribution.
