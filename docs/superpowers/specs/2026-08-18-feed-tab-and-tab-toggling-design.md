# Feed tab + tab toggling

**Date:** 2026-08-18 · **Branch:** `feat/muscle-coverage-coach`

## What this actually was

The request was "add a Strava-like feed as a new tab, and let tabs be toggled on and off."
Exploration changed the shape of the work twice:

1. **The feed already existed, fully built.** Backend (`routes/feed.ts` + `FeedService`) and iOS
   (`FeedView`, `FeedViewModel`, `FeedPostCard`) with three post kinds (workout / PR / split),
   a five-emoji reaction bar, cursor pagination, report/block, and empty/error states. It was
   buried as the first segment of `CrewView`, a modal sheet reachable only from a button on Train
   and Me — the same way Discover went unnoticed.
2. **Tab toggling already existed too.** `LayoutStore.TabLayout` shipped in the previous commit
   with order, hidden set, launch tab, JSON persistence, and a full editor in `CustomizeView` —
   hide, reorder, choose the launch tab.

So almost none of this was new construction. It was **wiring an existing feature into the
navigation, adding one tab to a system that already supported toggling, and fixing the reason
feeds stay empty.**

## Decisions

| Decision | Choice | Why |
| --- | --- | --- |
| Feed scope | Promote + make it feel alive | The feed worked; nothing posted to it. |
| Tab customization | Me pinned, rest toggleable, no new reorder work | The editor already reorders. Pinning Me avoids a soft-lock, since Settings is the only route back to the editor. |
| Default bar | Today · Train · **Feed** · Stats · Me | Feed gets discovered instead of repeating the burial problem. |
| Plan | Hidden by default, never deleted | It's a student course planner left over from another app. Its SwiftData records survive; one toggle restores it. |
| Auto-share | Ask once, then automatic | Strava's model. Defaulting on publishes someone's training off the back of a release note; defaulting off leaves feeds empty. |
| Social layout | Feed tab is pure feed | Friends/Leaderboard moved to a toolbar button. A segmented control makes the feed one mode of three. |

## The forcing function

Six tabs do not fit. The existing code already documents five as the ceiling — at large Dynamic
Type "TRAIN" and "STATS" collided with no gap. So `TabLayout.maxVisible = 5` is a real invariant,
and adding Feed *requires* something to come off. That is why Plan ships hidden rather than as a
style preference.

## Architecture

The rules moved onto `TabLayout` as pure, testable code; `LayoutStore` only persists what it
decides.

- `resolvedOrder` — every tab once (deduped), catalog additions appended.
- `resolvedVisible` — non-empty, capped at five, always contains the launch tab, trims from the end.
- `migrated(_:)` — versioned, one-shot reconciliation of a stored arrangement with shipped defaults.

`LayoutStore` gained `canShowTab(_:)`. The previous `setTabHidden` allowed the *show* path
unconditionally, which with six tabs would have overflowed the bar.

### Migration

Every existing install has five tabs, nothing hidden, no version field. On load:

1. Insert `.feed` after `.train` — appending would put it past Me.
2. Hide `.plan` **only if** the bar would overflow **and** Plan isn't the launch tab. A lifter who
   already curated down to four keeps Plan; someone who launches into Plan is never stranded.
3. Stamp the version, and persist — `config`'s `didSet` does not fire from an initialiser, so
   without an explicit write this would re-migrate every launch.

### Auto-share

`FeedAutoShare` is three states, not a `Bool`: `unasked` is what makes a one-time prompt possible.

- **One post per workout, never one per PR.** `FeedPRSummary.label` renders "Bench Press +2 more";
  the card uses `lineLimit(1)`, so a joined list of three exercise names would truncate mid-word.
- **Quiet failure.** An automatic post that fails shows an inline row with Retry, not the global
  error banner — nobody pressed anything, and the workout itself is saved either way.
- **Undo** deletes the post without touching the preference. Undoing one post is not a standing
  objection to auto-sharing.

## Known gap (not fixed)

`DashboardWidgets` has nine `vm.selectedTab = .train/.stats/.me` links. If a lifter hides one of
those tabs themselves, following such a link renders the screen with nothing highlighted in the
bar. This is pre-existing — tabs were already hideable — and is *not* reachable by default, so it
was left alone. The one link this change did break, Today's "View all assignments" pointing at the
now-hidden Plan, opens `PlanView` as a sheet instead.

## Verification

- `xcodebuild build-for-testing` green, zero warnings in touched files.
- 37 assertions on `TabLayout` + `FeedPRSummary` + `FeedAutoShare`, run natively via the swiftc
  harness against source extracted verbatim from the real files (`xcodebuild test` cannot run in
  this sandbox — pty is blocked, EXIT=133).
- Simulator: default bar, migration on a pre-existing install, Feed tab, `CrewView` without its
  Feed segment, the tab editor's "Hidden · bar is full", and the Settings toggle.
- **The `ElosTests` suite has not been executed.** It compiles; running it needs a non-sandboxed run.
