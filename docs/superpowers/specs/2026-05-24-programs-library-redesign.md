# Programs Library Redesign — Design Spec

**Date:** 2026-05-24
**Status:** Approved

---

## Overview

Redesign `ProgramsView` from a flat filterable list into a curated, browseable split library with category sections, favorites, and custom split creation from templates. The splits already exist in `WorkoutSplitData.swift` but are not surfaced effectively. This redesign makes the library the centerpiece of the Programs tab.

---

## Goals

- Surface the full curated split library (Creator-Inspired, Olympia/Bodybuilding, Sports, Foundation, Home/Minimal, Specialization) as browseable horizontal category rows
- Let users favorite splits so they sort to the top
- Let users create custom splits from a library split as a starting point
- Keep the active split card visible at the top for users who are already on a program

---

## Screen Layout

`ProgramsView` is a single vertical `ScrollView` with these sections top-to-bottom:

1. **Active Split Card** — compact progress card (existing), shown only if user has an active split
2. **Favorites** — horizontal scroll of favorited splits; hidden if no favorites exist
3. **Creator-Inspired** — horizontal scroll (Jeff Nippard, CBUM, Meadows, Arnold, Layne Norton, RP)
4. **Olympia/Bodybuilding** — horizontal scroll (Ronnie Coleman, Dorian Yates, Lee Haney, Arnold Classic, Phil Heath)
5. **Sport Performance** — horizontal scroll (Football, Basketball, Soccer, Baseball, Combat Sports, Track)
6. **Foundation** — horizontal scroll (3-Day Full Body, 5x5 Strength, 4-Day Upper/Lower, Starting Strength)
7. **Home/Minimal** — horizontal scroll (existing splits in this category)
8. **Specialization** — horizontal scroll (existing splits in this category)
9. **My Splits** — vertical list of user-created/subscribed splits with an in-section `+ Create` button

The existing toolbar `+` button that currently presents `CreateSplitView` is **removed**. The `+ Create` button in the My Splits section is the sole entry point for split creation. The Split Finder wand button stays in the toolbar.

Category section labels match `SplitCategory.rawValue` exactly:
- `"Creator-Inspired"`, `"Olympia/Bodybuilding"`, `"Sport Performance"`, `"Foundation"`, `"Home/Minimal"`, `"Specialization"`

---

## Split Library Cards

Each library split is represented by a `SplitLibraryCard` — a fixed-width card shown in horizontal rows:

**Card contents:**
- Split name (e.g., "Jeff Nippard PPL")
- Source label (`split.category.rawValue`)
- Day count badge (e.g., "6 days")
- Up to 3 goal tags from `split.goals`
- Heart button (top-right) — toggles favorite state

**Interaction:**
- Tap card → pushes `WorkoutSplitDetailView(split: split)` via `NavigationLink`
- Tap heart → toggles favorite, updates Favorites section immediately

---

## Split Detail View

Reuse the existing `WorkoutSplitDetailView` — no new file needed. Add a **"Customize & Subscribe"** button alongside the existing "Subscribe" CTA in `WorkoutSplitDetailView`:

- **Subscribe / Already Added** — existing behavior unchanged: shows "Subscribe" when not subscribed, "Already Added" (disabled) when subscribed.
- **Customize & Subscribe** — always visible regardless of `isSubscribed` state (user may want a personalized copy). Presented via `@State private var showCustomize = false` with `.sheet(isPresented: $showCustomize) { CreateSplitView(template: split) { showCustomize = false } }`. The `onSave` closure dismisses the sheet. Not a NavigationLink push — `WorkoutSplitDetailView` is already inside a NavigationStack and `CreateSplitView` has its own inner NavigationStack; a push would nest them.

---

## Favorites

- Persisted in `UserDefaults` under key `"elos.favoriteSplitKeys"` as `[String]` (array of `WorkoutSplit.id` values)
- In memory, `AppViewModel` exposes `favoriteSplitKeys: Set<String>` (decoded from stored `[String]`)
- `favoriteSplitKeys` is initialized in `AppViewModel.init` (or `loadForUser`) by reading `UserDefaults.standard.stringArray(forKey: "elos.favoriteSplitKeys") ?? []` and converting to `Set<String>`. This ensures the set is populated on cold launch, not only after a toggle.
- Favorites are **not cleared on sign-out** (`clearData()` does not remove this key). Favorites reference global library split IDs, not user-scoped data, so they are device-local preferences that should persist across sign-in/sign-out.
- `toggleFavorite(_ id: String)` on `AppViewModel` — flips membership in the set, re-encodes as `[String]` and saves to `UserDefaults`, publishes change via `@Published`
- Favorites section appears at top of library (below active split card) only when at least one split is favorited
- Favorited splits appear in BOTH the Favorites row AND their original category row (heart icon filled)

---

## Custom Split Creation

The `+ Create` button in My Splits presents `CreateSplitView()` directly (start from scratch). No `.confirmationDialog` needed — the "use a library split as base" path is already served by the "Customize & Subscribe" button on each split's detail view.

`CreateSplitView` gains an optional `template: WorkoutSplit?` parameter (default `nil`). When non-nil:

- Pre-populate `splitName` from `split.title`
- For each index `i` in `0..<workouts.count`: set `dayNames[i] = workouts[i].focus`, set `dayIsRest[i] = false`, pre-fill `dayExercises[i]` by converting each `SplitExercise` → `DayExercise(id: UUID().uuidString, name: ex.name)`
- For indices `workouts.count..<7`: leave in default state (empty name, `isRest = false`, no exercises) — user can fill or mark rest as desired

---

## WorkoutSplitData Expansion

Expand `WorkoutSplitData.swift` to ensure all categories are well-populated:

**Creator-Inspired** (target: 6+ splits)
- Jeff Nippard PPL (existing)
- CBUM Bro Split
- John Meadows Mountain Dog
- Arnold Golden Six
- Layne Norton PHAT
- Renaissance Periodization (RP Hypertrophy)

**Olympia / Bodybuilding** (target: 5+ splits)
- Ronnie Coleman (existing)
- Dorian Yates Blood & Guts (existing)
- Lee Haney (existing)
- Arnold Classic Split
- Phil Heath Chest-dominant Split

**Sport Performance** (target: 6+ splits)
- Football Strength & Power
- Basketball Explosiveness
- Soccer Endurance + Legs
- Baseball Rotational Power
- Combat Sports (BJJ/MMA) Conditioning
- Track & Field Speed Focus

**Foundation** (target: 4+ splits, expand if fewer exist)
- 3-Day Full Body (existing)
- 5x5 Strength (existing)
- 4-Day Upper/Lower
- Starting Strength

**Home/Minimal** and **Specialization** — keep existing splits as-is; show in their own rows.

---

## File Map

| File | Action |
|------|--------|
| `ProgramsView.swift` | Full rewrite — sectioned layout, remove toolbar `+` button |
| `WorkoutSplitData.swift` | Expand Creator, Olympia, Sport Performance categories |
| `Features/Train/Programs/SplitLibraryCard.swift` | New — horizontal card component |
| `WorkoutSplitDetailView.swift` | Add "Customize & Subscribe" button (always visible, sheet presentation) |
| `CreateSplitView.swift` | Add optional `template: WorkoutSplit?` param with day/exercise pre-fill |
| `AppViewModel.swift` | Add `favoriteSplitKeys: Set<String>` + `toggleFavorite(_ id: String)` |

---

## Out of Scope

- Search/filter within the library (can be added later)
- User-submitted or community splits
- Split ratings or reviews
- Syncing favorites to the server
