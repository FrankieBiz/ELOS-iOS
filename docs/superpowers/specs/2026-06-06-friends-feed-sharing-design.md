# Friends Activity Feed & In-App Sharing — Design

**Date:** 2026-06-06
**Status:** Approved → in implementation

## Goal

Let users share three things to their friends, in-app: a finished **workout**, a
**PR**, and a **split** (which friends can import). Add a **friends activity feed**
as the home for these shares, with lightweight **reactions**. Friends can already
see each other's weekly stats (leaderboard + `getFriendStats`); this adds the
deliberate, per-item sharing layer on top.

## Locked decisions

- **In-app only.** Content stays inside Elos; no external image export in v1.
- **Manual, per-item share.** Nothing is shared by default. The user taps a
  "Share to Friends" action on a workout, PR, or split.
- **Splits post to the feed; any friend can import.** One unified feed, three post
  kinds. Split posts carry an Import action.
- **Reactions only.** A single reaction per user per post from a fixed emoji
  allowlist (🔥 💪 👏 🎯 👀). No free-text comments — keeps moderation surface small.
- **Snapshot architecture.** Each post stores a frozen JSON snapshot of what was
  shared, so posts are immutable and stable even if the source workout/split is
  later edited or deleted, and split-import is a trivial copy.

## Non-goals (YAGNI)

External/social image export, auto-posting, comments, per-user import-tracking
table, push notifications.

## Data model — `migrations/027_create_feed.sql`

```sql
CREATE TABLE feed_posts (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  author_id    UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  kind         TEXT NOT NULL CHECK (kind IN ('workout','pr','split')),
  payload_json TEXT NOT NULL,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX feed_posts_author_idx  ON feed_posts(author_id);
CREATE INDEX feed_posts_created_idx ON feed_posts(created_at DESC);

CREATE TABLE post_reactions (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  post_id    UUID NOT NULL REFERENCES feed_posts(id) ON DELETE CASCADE,
  user_id    UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  emoji      TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (post_id, user_id)
);
CREATE INDEX post_reactions_post_idx ON post_reactions(post_id);
```

`ON DELETE CASCADE` on `author_id`/`user_id` makes account-deletion cleanup
automatic (consistent with the existing split-cleanup behavior).

### Payload snapshots (`payload_json`)

- **workout**: `{ date, durationMin, volumeKg, totalSets, uniqueExercises, topLift?: {name, weightKg, reps}, pr?: string }`
- **pr**: `{ exerciseName, weightKg, reps, e1rm }`
- **split**: `{ name, days: UserSplitDay[] }` (full definition, minus ids/user)

## API — `routes/feed.ts` mounted at `/feed`, logic in `FeedService`

| Method | Route                  | Purpose |
|--------|------------------------|---------|
| GET    | `/feed?cursor=`        | Friends' + own posts, newest first, cursor-paginated (cursor = ISO `created_at` of last seen post). Each post carries author profile + reaction summary (counts by emoji, my reaction). |
| POST   | `/feed`                | Create a `workout`/`pr` post. Client supplies the snapshot (it already holds `SessionSummary`). Zod-validated per `kind`. |
| POST   | `/feed/split/:splitId` | Share a split. Server reads the **owned** split from `user_splits` and snapshots it (authoritative). 404 if not owned. |
| POST   | `/feed/:id/import`     | Split posts only — copy snapshot into caller's `user_splits` via `SplitService.createSplit` with `library_key=""` (no unique conflict, always a fresh copy). 400 for non-split posts. |
| PUT    | `/feed/:id/react`      | Upsert caller's reaction `{ emoji }` (allowlist-validated). Re-PUT with same emoji = no-op; different emoji replaces. |
| DELETE | `/feed/:id/react`      | Remove caller's reaction. |
| DELETE | `/feed/:id`            | Delete caller's own post (author-scoped). |

**Visibility:** a post is visible to caller `me` iff `author_id = me` OR
`author_id` is an `accepted` friend of `me`. Reuses the friendship join used by
`FriendService`. Pagination uses keyset on `created_at` (`< cursor`) `LIMIT 20`.

**Page size:** 20. **Reaction emoji allowlist** enforced server-side; invalid → 400.

Post reporting reuses the existing `/social/report` + `user_reports` flow.

## Shared types — `packages/elos-shared`

Add: `FeedPostKind`, `WorkoutPayload`, `PrPayload`, `SplitPayload`,
`FeedReactionSummary`, `FeedPost`, `FeedPage`. Keeps backend ↔ iOS in contract.

## iOS (SwiftUI / MVVM)

- **`CrewView`** segmented control becomes `Feed | Friends | Leaderboard`, Feed first.
- **`FeedViewModel`** (`@MainActor`, `ObservableObject`) — `load()`, `loadMore()`,
  `react(postId, emoji)`, `unreact(postId)`, `importSplit(postId)`,
  `shareWorkout(...)`, `sharePR(...)`, `shareSplit(serverId)`. All networking via
  `ApiClient`. Injected at app level next to `SocialViewModel`.
- **Cards** (`Features/Social/Feed/`): `WorkoutPostCard` (reuses `WorkoutShareCard`
  visual language), `PrPostCard`, `SplitPostCard` (Import button + imported state),
  shared `ReactionBar`, `FeedPostHeader` (avatar + name + relative time).
- **Share entry points:**
  - `PostSessionSummaryView`: "Share to Friends" button → `shareWorkout` (carries
    top PR if any). Each PR row in the PR card → "Share PR" → `sharePR`.
  - `ProgramsView`: split-row `contextMenu` gains "Share to Friends" → `shareSplit`.

## Error handling

- Import always creates a fresh split copy (`library_key=""`), so no 409.
- React/delete on a missing post → 404; client drops the post from the list.
- Sharing a split you don't own → 404.
- Empty feed → friendly empty state ("Add friends and share a workout to get started").

## Testing

- **Backend (`FeedService`)**: create post; feed visibility includes self + accepted
  friends and excludes non-friends/blocked; keyset pagination; reaction upsert
  (insert, replace, idempotent same-emoji) and delete; split import copies all days;
  import rejects non-split posts.
- **Routes**: auth required; zod validation on `POST /feed`; emoji allowlist on react.
- **iOS**: `FeedViewModel` decode + state transitions; manual smoke of the three
  share flows and import.
