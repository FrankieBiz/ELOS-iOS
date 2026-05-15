# Gym Usability Polish — Quick Wins

**Date:** 2026-05-15
**Status:** Design approved, ready for implementation plan
**Scope:** Four high-leverage UX improvements to make `ActiveSessionView` usable in a real gym setting

## Problem

After the 2026-05-15 bug-fix sweep (template formatting, local-first template save, mid-session exercise adds, dynamic nav title), the app is functional in a gym but still has friction in four areas that interrupt training flow:

1. **Set logging speed** — entering weight + reps via the soft keyboard every set is slow and breaks concentration between heavy lifts.
2. **Weight/plate math** — lifters do plate math in their head between sets.
3. **Mid-session control** — exercises can't be deleted or reordered once the session starts (only swapped).
4. **Rest timer flow** — no haptic/sound alert at timer end, and the screen sleeps based on the user's auto-lock setting, forcing them to unlock between every set.

This spec covers one quick-win fix per area. Anything beyond that (Apple Watch, voice input, superset grouping, drop sets, etc.) is explicitly out of scope.

## Goals

- Cut typing per set by ≥80% for users with prior history on the same exercise.
- Eliminate in-head plate math for barbell movements.
- Allow mid-session exercise reorder + delete without leaving the workout.
- Surface rest-timer completion through haptic + sound, and prevent the screen from sleeping during an active session.

## Non-goals

- No drag-to-reorder gesture (long-press context menu is sufficient).
- No persistent plate calculator screen (modal sheet only).
- No per-exercise rest sound customization (one global default).
- No backend changes, shared-package changes, or new SwiftData models.
- No Apple Watch / iCloud / share-extension integration.

## Architecture

All four features are UI-layer additions confined to the iOS app. No new SwiftData models, no API contracts, no shared-package types.

**Files affected:**

- `apps/elos-mobile/Elos/Elos/Views/ActiveSessionView.swift` — all four features hook into this view
- `apps/elos-mobile/Elos/Elos/Features/Train/TrainViewModel.swift` — one new method (`deleteExerciseFromSession`) for cascading set deletes
- **New:** `apps/elos-mobile/Elos/Elos/Features/Train/PlateCalculator/PlateCalculatorSheet.swift` — sheet view + computation
- **New:** `apps/elos-mobile/Elos/Elos/Features/Train/PlateCalculator/PlateMath.swift` — pure plate-breakdown algorithm (separately testable)
- **New:** `apps/elos-mobile/Elos/ElosTests/PlateMathTests.swift` — unit tests added to existing `ElosTests` target

**State additions inside `ActiveSessionView`:**

```swift
@State private var plateCalcTarget: PlateCalcTarget? = nil   // Identifiable; nil = sheet closed
@State private var showDeleteConfirm: DeleteConfirm? = nil   // Identifiable; nil = no alert
```

`PlateCalcTarget` and `DeleteConfirm` are small `Identifiable` wrappers so the sheet/alert APIs can use the `item:` overload (avoids two booleans per state).

The rest-end alert is self-deduped: the `if restSeconds == 0` block flips `restActive = false` in the same tick, so subsequent ticks short-circuit before re-entering the alert path. No dedupe flag needed.

## Feature 1 — Copy Previous Set

### UX

In the existing set-row layout in `SessionExerciseCard`:

```
[#]  [↺]  [Weight ____]  [Reps __]  [RPE __]  [✓]
```

A new `↺` (SF Symbol `arrow.uturn.down`) icon button sits between the row number and the weight field, sized ~22pt. Tap fills `exercise.sets[i].weight` and `exercise.sets[i].reps` from the corresponding `previousSets[i]` (kg → lb conversion). RPE is intentionally **not** copied — lifters rate fresh each session.

When no previous set exists at index `i`, the icon is hidden (not just disabled) to keep the row clean for new exercises.

A second affordance — **"Copy all from last session"** — is added to the exercise card footer alongside `+ Add set` and `Swap`. Tapping it fills every set in that exercise's previous-session record in one tap. If a set already has user-entered values, those are preserved (don't overwrite manual input). The button is **hidden** (not just disabled) when `previousSets.isEmpty`, mirroring the `↺` icon rule.

### Data flow

```
previousSets (from TrainViewModel.previousSets, already a stored value used for placeholder hints)
  └─> tap ↺ on row i
       └─> exercise.sets[i].weight = String(format: "%.0f", prev.weightKg / 0.453592)
       └─> exercise.sets[i].reps   = "\(prev.reps)"
```

The previous-set lookup is already memoized via the `previousSets(for:ownerID:)` call inside the card; no additional fetch.

### Error handling

- No previous data: icon hidden.
- "Copy all" with fewer previous sets than current sets: only fills the leading N rows; remaining rows untouched.
- "Copy all" preserves already-filled values: skip any set where `weight` or `reps` is non-empty.

## Feature 2 — Plate Calculator

### UX

A small `scalemass` SF Symbol icon button is added to the exercise card header row, between the existing `0/3 sets` chip and the chevron. Tapping opens `PlateCalculatorSheet` as a `.sheet` with `.presentationDetents([.medium])`.

**Sheet contents:**

- Header: "Plate Calculator"
- Target weight `TextField` (decimal pad, lb), prefilled with the most recent non-empty `weight` value from that exercise's sets, or empty if none
- Bar weight segmented picker: 45 / 35 / 20 / 15 / Custom (Custom reveals a number field)
- Plate breakdown display: large numeric weight at top, "per side" subtitle, then a vertical list of plate rows. **Plates are grouped by denomination** in descending order: e.g., `4 × 45 lb`, `1 × 25 lb`, `1 × 2.5 lb` — never expanded as four separate `1 × 45 lb` rows.
- Footer status:
  - Green checkmark + "Exact" when `achievedWeightLb == targetLb`
  - Orange warning + "Best fit: 225 lb (target 226 — short by 1 lb)" when the greedy fit rounds down
- Bar-weight selection persists to `UserDefaults.standard.set(_, forKey: "elos.plateCalculator.barWeightLb")`

**Plate supply assumption:** unlimited supply of each denomination. The algorithm does not model a finite plate set (real-world counterexamples — e.g., racks running out of 45s — are out of scope).

**Input validation:**

- Empty target field: display is blank ("Enter a target weight" placeholder), no plates, no status chrome.
- Non-numeric target (e.g., user pastes "abc"): treated as empty per above. `Double(target) ?? nil` drives the empty-state path.
- Negative target or `0`: same empty-state.
- `target > 0 && target < barLb`: show "Below bar weight (bar is X lb)" inline; no plates.
- `target == barLb`: show "Just the bar" message; empty plate list; status = Exact.
- Custom bar weight ≤ 0, empty, or non-numeric: validate inline; the segmented picker remains on the previously valid selection until the custom value is fixed.

### Algorithm (`PlateMath.swift`)

```swift
struct PlateBreakdown {
    let totalWeightLb: Double         // requested target
    let barWeightLb: Double
    let achievedWeightLb: Double      // best the algorithm got
    let platesPerSide: [(plate: Double, count: Int)]  // sorted desc by plate
    var isExact: Bool { abs(achievedWeightLb - totalWeightLb) < 0.01 }
}

enum PlateMath {
    static let standardPlatesLb: [Double] = [45, 35, 25, 10, 5, 2.5]

    static func breakdown(targetLb: Double, barLb: Double, plates: [Double] = standardPlatesLb) -> PlateBreakdown
}
```

**Greedy fit (rounds down).** Algorithm:

1. `remainingPerSide = (target - bar) / 2`
2. For each plate denomination in descending order, while `plate ≤ remainingPerSide`: emit one plate, subtract from `remainingPerSide`.
3. Stop when no remaining plate fits. `achievedWeightLb = target - 2 × remainingPerSide`.

This is **not** a closest-fit search — it only produces values ≤ target. With the standard set `[45, 35, 25, 10, 5, 2.5]`, the smallest non-zero increment per side is 2.5 lb (so 5 lb total), and any target that's a 5-lb multiple ≥ bar is achievable exactly. For non-5-lb targets the achieved weight is the largest 5-lb multiple ≤ target. Documented limitation; users who want odd weights can use micro-plates not modeled here.

Pure function, deterministic, no dependencies.

### Error handling

All input edge cases are enumerated in the **Input validation** subsection above. There are no runtime exceptions to handle — `PlateMath.breakdown` is total over `Double` inputs and clamps via the validation rules at the view layer.

For targets that don't land on a 5-lb boundary, the sheet shows the greedy fit (≤ target) and the "short by X lb" footer described above. There is no second-pass closest-search — that's an explicit non-goal.

## Feature 3 — Delete + Reorder Mid-Session

### UX

Each `SessionExerciseCard` gets a `.contextMenu { ... }` on its header tap target. Long-press surfaces three actions:

- **Move Up** (`arrow.up`) — disabled when index 0
- **Move Down** (`arrow.down`) — disabled when at last index
- **Delete Exercise** (`trash`, role `.destructive`) — see below

The context menu is chosen over `List` + `.onMove` because the current `VStack`-of-cards layout doesn't translate cleanly to `List` row styling, and over a custom edit mode because it ships in fewer LOC and is more discoverable through standard iOS gestures. With typical session sizes of 4–6 exercises, drag-to-reorder is over-engineered.

### Delete confirmation

When the exercise has any logged sets (`exercise.sets.contains { $0.done }`), tapping Delete triggers an `.alert`:

> "Delete *{exercise name}*? This will remove all logged sets for this exercise from the current workout. This can't be undone."

Buttons: **Delete** (destructive) / **Cancel**.

If no sets are logged, delete immediately with no confirmation.

### Data flow

```
Delete tapped
  └─> if any logged sets: alert; otherwise proceed
       └─> vm.exercises.remove(at: index)
       └─> trainVM.deleteExerciseFromSession(name: exerciseName, ownerID: vm.currentUserID)
            ├─ fetch ExerciseSetRecord predicate(sessionID == currentSession.id, exerciseName == name)
            ├─ subtract their volume from currentSession.totalVolume
            └─ context.delete(each), context.save()

Move Up / Move Down
  └─> vm.exercises.swapAt(index, index ± 1)
```

`deleteExerciseFromSession` is a new method on `TrainViewModel` that mirrors the existing `unlogCompletedSet` pattern but works in bulk for a named exercise. **No backend call is made** — there is no `DELETE /sessions/:id/sets` route today (`apps/elos-api/src/routes/sessions.ts` exposes only POST/GET on that path). Local SwiftData is treated as the source of truth for the in-progress session, matching how `unlogCompletedSet` already behaves. Adding a server-side delete would expand backend scope and is deferred.

### Error handling

- Move at boundary: menu items disabled, no-op.
- Delete on already-finished session: should not be reachable (context menu only shown while `vm.showingSession` is true), but guard with `currentSession != nil`.
- SwiftData save failure: surface via existing `vm.showError(_:)` banner so the user knows the delete didn't fully persist; in-memory `vm.exercises` is already mutated and reflects the user's intent for the rest of the session.

## Feature 4 — Rest Timer Alerts + Keep Screen On

### Haptic + sound

In the existing `.onReceive(sessionTimer)` block:

```swift
.onReceive(sessionTimer) { _ in
    elapsed += 1
    if restActive && !restPaused {
        if restSeconds > 0 {
            restSeconds -= 1
            if restSeconds == 0 {
                fireRestEndAlert()       // new helper
                restActive = false
            }
        }
    }
}
```

`fireRestEndAlert()`:

```swift
private func fireRestEndAlert() {
    if UserDefaults.standard.object(forKey: "elos.rest.haptic") as? Bool ?? true {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
    if UserDefaults.standard.object(forKey: "elos.rest.sound") as? Bool ?? true {
        AudioServicesPlaySystemSound(1057)   // "Tweet Sent" — brief, non-jarring chime
    }
}
```

Both default to enabled. The settings keys (`elos.rest.haptic`, `elos.rest.sound`) are reserved now so a future SettingsView toggle can flip them without a migration. **No settings UI in v1** — defaults are correct for the common case.

**Skip button does not fire the alert.** The existing Skip handler sets `restActive = false; restSeconds = 0; restPaused = false` directly. Because the alert fires from inside the timer-tick branch (only when `restActive && !restPaused` and the countdown reaches 0 via decrement), manually setting `restSeconds = 0` from outside that branch never executes `fireRestEndAlert()`. This is the desired behavior — Skip means "I'm ready, don't bother me."

### Keep screen on

```swift
.onAppear {
    activeExerciseId = vm.exercises.first?.id
    trainVM.startSession(ownerID: vm.currentUserID)
    UIApplication.shared.isIdleTimerDisabled = true
}
.onDisappear {
    UIApplication.shared.isIdleTimerDisabled = false
}
```

`isIdleTimerDisabled` is restored on disappear so other screens (Today, Plan, etc.) honor the user's normal auto-lock.

### Error handling

- Device without haptic engine (older simulator): API is a no-op; no exception.
- Audio session not configured: `AudioServicesPlaySystemSound` works without explicit setup; if the device is in silent mode, the system suppresses it (acceptable).
- App backgrounded mid-rest: timer is driven by `Timer.publish` which pauses when the app suspends; on foreground return, the rest timer resumes from wherever it was. The 1→0 transition will still trigger the alert when it happens. This matches current behavior; no change.

## Testing

An `ElosTests` XCTest target already exists at `apps/elos-mobile/Elos/ElosTests/` (referenced in `project.pbxproj` via `BUNDLE_LOADER = "$(TEST_HOST)"`). The new test file `PlateMathTests.swift` is added to that existing target — no new target setup needed. All other features are validated manually per the plan below.

### Unit tests — `apps/elos-mobile/Elos/ElosTests/PlateMathTests.swift` (new)

All expected values below are computed against the greedy-fit algorithm with the standard plate set `[45, 35, 25, 10, 5, 2.5]`. "PS" = per side.

- `breakdown(targetLb: 225, barLb: 45)` → 2×45 PS; achieved = 225; isExact = true
- `breakdown(targetLb: 135, barLb: 45)` → 1×45 PS; achieved = 135; isExact = true
- `breakdown(targetLb: 45, barLb: 45)` → empty plates; achieved = 45; isExact = true (just the bar)
- `breakdown(targetLb: 40, barLb: 45)` → empty plates; achieved = 45; isExact = false (caller renders "below bar")
- `breakdown(targetLb: 226, barLb: 45)` → 2×45 PS; achieved = 225; isExact = false (short by 1). Greedy: remaining/side = 90.5 → take 45 (45.5 left) → take 45 (0.5 left) → 0.5 < 2.5 so stop.
- `breakdown(targetLb: 185, barLb: 45)` → 1×45 + 1×25 PS; achieved = 185; isExact = true. Verifies the algorithm correctly emits mixed denominations: remaining/side = 70 → take 45 (25 left) → 35 > 25 skip → take 25 (0 left) → done.
- `breakdown(targetLb: 137.5, barLb: 45)` → 1×45 PS; achieved = 135; isExact = false (short by 2.5). Greedy: remaining/side = 46.25 → take 45 (1.25 left) → 1.25 < 2.5 so stop.
- `breakdown(targetLb: 100, barLb: 20)` → 1×35 + 1×5 PS; achieved = 100; isExact = true. Greedy: remaining/side = 40 → take 35 (5 left) → take 5 (0 left) → done.
- `breakdown(targetLb: 405, barLb: 45)` → 4×45 PS (grouped display: `4 × 45 lb`); achieved = 405; isExact = true. Verifies the algorithm emits multiple plates of the same denomination and that the grouped count is correct.

### Manual test plan

1. **Copy previous:** Log a full session (e.g., bench press 3 sets at 135×8). Start a new session, add bench press. Verify ↺ icons appear, tap one → fills 135 lb / 8 reps. Tap "Copy all from last session" → fills all 3 rows. Verify already-filled rows are not overwritten.
2. **Plate calculator:** Tap the scale icon on an exercise card. Enter 225 lb, bar = 45. Verify display shows 2×45 per side, exact = true. Change to 226 lb → shows closest with delta indicator. Change bar to 35 → verify recomputes.
3. **Delete with logged sets:** Log 2 sets on an exercise. Long-press the card, tap Delete. Verify confirmation alert. Confirm → exercise removed from session, sets removed from `WorkoutHistoryView` for that session.
4. **Delete without logged sets:** Add a fresh exercise, long-press, Delete. Verify no alert, immediate removal.
5. **Reorder:** Long-press first card, tap Move Down. Verify it moves to second position. Verify Move Up is disabled on the first card.
6. **Rest timer haptic + sound:** Log a set to start rest timer. Let it tick to 0. Verify haptic buzz + sound on a physical device.
7. **Keep screen on:** Open active session, leave phone idle for >30s (or whatever the user's auto-lock is). Verify screen does not dim/sleep. Exit session, leave phone idle again. Verify screen sleeps normally.

## Implementation order

Recommended sequence for incremental shipping (each item is a self-contained PR-sized change):

1. Feature 4 — Idle timer + haptic/sound (smallest, no UI risk, immediate user value)
2. Feature 1 — Copy previous (1 button, well-isolated, leverages existing data flow)
3. Feature 3 — Delete + reorder (context menu, needs new VM method)
4. Feature 2 — Plate calculator (largest; new files, algorithm tests, sheet)

## Open questions

None. All UX decisions confirmed during brainstorming on 2026-05-15.

## Out of scope (deferred)

- Drag-to-reorder gesture (use context menu for v1)
- Per-exercise rest defaults (one global 90s default stays for v1)
- Custom plate denominations (standard set hardcoded for v1)
- kg/lb global unit toggle (lb-only for v1; matches existing app)
- Notification banner when rest ends if app is backgrounded
- Apple Watch companion / live activity
