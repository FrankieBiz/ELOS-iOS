# Database schema authority

This project has **two** schema sources. Know which one owns what before editing.

## 1. `supabase/schema.sql` (repo root) — auth-linked tables
Run **once** in the Supabase SQL editor. It owns tables that hang off Supabase Auth:

- `public.profiles` — `user_id` references **`auth.users(id)`**, has Row-Level Security
  policies, and an `on_auth_user_created` trigger that auto-creates a profile row on
  signup. This is the authoritative definition of `profiles` in production.

## 2. `apps/elos-api/migrations/*.sql` — backend-owned tables
Run by `pnpm --filter apps/elos-api migrate` (`src/migrate.ts`) against `DATABASE_URL`.
These own the workout/social/library tables (`workout_sessions`, `exercise_sets`,
`user_splits`, `feed_posts`, `friendships`, …). They key off the Supabase auth user id
but deliberately store it as a bare `UUID` (no FK to `auth.users`, which lives in a
schema the migration runner can't reference).

## Known legacy / cleanup
- `002_create_users.sql` creates a standalone `public.users` table with `password_hash`.
  It is a **leftover from an abandoned custom-auth design** — the app now authenticates
  entirely through Supabase. Nothing in `src/` reads or writes it. Migrations `003`,
  `023`, `024`, `027` declare `REFERENCES users(id)`, but in a Supabase deployment the
  authoritative `profiles` (from `supabase/schema.sql`) references `auth.users` instead,
  so the legacy table is effectively unused.
- **Do not** add new tables that reference `users(id)`. Use a bare `UUID user_id` like the
  newer migrations, or reference `auth.users(id)` in `supabase/schema.sql`.
- A future migration may drop `public.users` once it's confirmed no environment still
  depends on it. Left in place for now to avoid breaking any dev DB built purely from
  these migrations.
