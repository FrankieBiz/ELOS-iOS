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

**State additions inside `ActiveSessionView`:**

```swift
@State private var plateCalcTarget: PlateCalcTarget? = nil   // Identifiable; nil = sheet closed
@State private var showDeleteConfirm: DeleteConfirm? = nil   // Identifiable; nil = no alert
@State private var hasFiredRestEndAlert = false              // dedupes the haptic+sound on the 1→0 tick
```

`PlateCalcTarget` and `DeleteConfirm` are small `Identifiable` wrappers so the sheet/alert APIs can use the `item:` overload (avoids two booleans per state).

## Feature 1 — Copy Previous Set

### UX

In the existing set-row layout in `SessionExerciseCard`:

```
[#]  [↺]  [Weight ____]  [Reps __]  [RPE __]  [✓]
```

A new `↺` (SF Symbol `arrow.uturn.down`) icon button sits between the row number and the weight field, sized ~22pt. Tap fills `exercise.sets[i].weight` and `exercise.sets[i].reps` from the corresponding `previousSets[i]` (kg → lb conversion). RPE is intentionally **not** copied — lifters rate fresh each session.

When no previous set exists at index `i`, the icon is hidden (not just disabled) to keep the row clean for new exercises.

A second affordance — **"Copy all from last session"** — is added to the exercise card footer alongside `+ Add set` and `Swap`. Tapping it fills every set in that exercise's previous-session record in one tap. If a set already has user-entered values, those are preserved (don't overwrite manual input).

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
- Plate breakdown display: large numeric weight at top, "per side" subtitle, then a vertical list of plate rows like `2 × 45 lb`, `1 × 25 lb`, `1 × 2.5 lb`
- Footer status:
  - Green checkmark + "Exact" when the target is achievable
  - Orange warning + "Closest: 222.5 lb (target 225)" when not achievable
- Bar-weight selection persists to `UserDefaults.standard.set(_, forKey: "elos.plateCalculator.barWeightLb")`

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

Greedy descent: `remaining = (target - bar) / 2`, take largest plate ≤ remaining, repeat until `remaining < smallest plate`. The `achievedWeightLb` reflects what the algorithm produced (may be < target if no exact match). Pure function, deterministic, no dependencies.

### Error handling

- `targetLb < barLb`: show "Below bar weight" inline; no plates displayed.
- `targetLb == barLb`: show "Just the bar" message; empty plate list.
- Unachievable target (e.g., 226 lb with standard plates): show closest achievable + a "Δ 1 lb" indicator.
- Custom bar weight ≤ 0 or non-numeric: validate the input field, disable the picker until valid.

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
            ├─ context.delete(each), context.save()
            └─ (best-effort) DELETE /sessions/:id/sets for each — backend route already exists per spec, otherwise log to logger and rely on next session sync

Move Up / Move Down
  └─> vm.exercises.swapAt(index, index ± 1)
```

`deleteExerciseFromSession` is a new method on `TrainViewModel` that mirrors the existing `unlogCompletedSet` pattern but works in bulk for a named exercise.

### Error handling

- Move at boundary: menu items disabled, no-op.
- Delete on already-finished session: should not be reachable (context menu only shown while `vm.showingSession` is true), but guard with `currentSession != nil`.
- API delete failure: log silently; local state is the source of truth in the session.

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

No XCTest suite exists for this app today; a small one is added for `PlateMath` only (pure function, easy to unit-test) and everything else is manual.

### Unit tests — `PlateMathTests.swift` (new)

- `breakdown(targetLb: 225, barLb: 45)` → 1×45, 1×45 per side; exact = true
- `breakdown(targetLb: 135, barLb: 45)` → 1×45 per side; exact = true
- `breakdown(targetLb: 45, barLb: 45)` → empty plates; exact = true (just the bar)
- `breakdown(targetLb: 40, barLb: 45)` → empty plates; achieved = 45; exact = false (below bar)
- `breakdown(targetLb: 226, barLb: 45)` → 1×45 + 1×35 + 1×10 per side = 225; exact = false (closest)
- `breakdown(targetLb: 137.5, barLb: 45)` → 1×45 + 1×1.25... actually no, 2.5 is smallest, so 1×45 + 1×2.5 per side = 95 + 45 = 140 — verify algorithm picks 1×45 + smallest fit; document expected result in test
- `breakdown(targetLb: 100, barLb: 20)` (kg-style bar) → 1×35 + 1×5 per side = 90 + 20 = 110; verify achieved = 110

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
