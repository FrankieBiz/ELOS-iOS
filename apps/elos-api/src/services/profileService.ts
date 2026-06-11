import { supabaseAdmin } from "../supabase";
import { pool } from "../db";
import { conflict } from "../lib/httpError";

export interface ProfileFields {
  first_name?: string | null;
  last_name?: string | null;
  username?: string | null;
  height_cm?: number | null;
  weight_kg?: number | null;
  age_years?: number | null;
  training_experience?: string | null;
  training_goal?: string | null;
  school_name?: string | null;
  school_year?: string | null;
  cal_goal?: number | null;
  protein_goal?: number | null;
  carb_goal?: number | null;
  fat_goal?: number | null;
  onboarding_complete?: boolean;
  use_imperial?: boolean | null;
}

export async function getProfile(userID: string) {
  const { data, error } = await supabaseAdmin
    .from("profiles")
    .select("*")
    .eq("user_id", userID)
    .maybeSingle();
  if (error) throw error;
  return data;
}

export async function upsertProfile(userID: string, fields: ProfileFields) {
  const payload = Object.fromEntries(
    Object.entries(fields).filter(([, v]) => v !== undefined)
  ) as Record<string, unknown>;

  const { data, error } = await supabaseAdmin
    .from("profiles")
    .upsert(
      { user_id: userID, ...payload, updated_at: new Date().toISOString() },
      { onConflict: "user_id" }
    )
    .select()
    .single();
  if (error) {
    // Postgres unique-violation on the username index → surface as a 409 the
    // client can show as "username taken" rather than a generic 500.
    if (isUsernameConflict(error)) {
      throw conflict("That username is taken", "USERNAME_TAKEN");
    }
    throw error;
  }
  return data;
}

/** True when a Supabase/Postgres error is the unique violation on profiles.username. */
function isUsernameConflict(error: { code?: string; message?: string } | null): boolean {
  if (!error) return false;
  if (error.code === "23505") return true;
  return /username/i.test(error.message ?? "");
}

/**
 * Is `username` free (case-insensitive), ignoring the caller's own row so a user
 * re-saving their existing handle doesn't see a false "taken".
 */
export async function usernameAvailable(username: string, forUserId: string): Promise<boolean> {
  const result = await pool.query(
    `SELECT 1 FROM profiles WHERE lower(username) = lower($1) AND user_id <> $2 LIMIT 1`,
    [username, forUserId]
  );
  return result.rows.length === 0;
}

/**
 * Guarantee a user is findable: if they have no username, derive one from their
 * first name (fallback "athlete") plus random digits, retrying on collision.
 */
export async function ensureUsername(userID: string): Promise<void> {
  const existing = await pool.query<{ first_name: string | null; username: string | null }>(
    `SELECT first_name, username FROM profiles WHERE user_id = $1`,
    [userID]
  );
  const row = existing.rows[0];
  if (!row || (row.username && row.username.trim() !== "")) return;

  const base =
    (row.first_name ?? "")
      .toLowerCase()
      .replace(/[^a-z0-9]/g, "")
      .slice(0, 12) || "athlete";
  // Ensure it starts with a letter (the base could be empty/numeric after stripping).
  const safeBase = /^[a-z]/.test(base) ? base : `a${base}`;

  for (let attempt = 0; attempt < 6; attempt++) {
    const candidate = `${safeBase}${Math.floor(100 + Math.random() * 9900)}`;
    try {
      const res = await pool.query(
        `UPDATE profiles SET username = $1, updated_at = now()
         WHERE user_id = $2 AND (username IS NULL OR username = '')`,
        [candidate, userID]
      );
      if ((res.rowCount ?? 0) > 0) return; // assigned (or another writer already set one)
      return; // username got set concurrently — nothing to do
    } catch (err: unknown) {
      const code = (err as { code?: string }).code;
      if (code === "23505") continue; // candidate taken — retry with new digits
      throw err;
    }
  }
}

export async function completeOnboarding(userID: string) {
  const profile = await upsertProfile(userID, { onboarding_complete: true });
  // Safety net so users who somehow finished without a username stay findable.
  await ensureUsername(userID);
  return profile;
}

/**
 * Permanently delete a user and all data they own. App-data deletes run in a
 * single transaction (all-or-nothing); the Supabase auth identity is removed
 * only after that commit succeeds. Child rows (exercise_sets, template_exercises,
 * user_split_days, post_reactions on the user's posts) are removed via ON DELETE
 * CASCADE, but we also delete the user's reactions on OTHER users' posts.
 */
export async function deleteAccount(userID: string): Promise<void> {
  const client = await pool.connect();
  try {
    await client.query("BEGIN");
    // Reactions the user left on other people's posts (own-post reactions cascade).
    await client.query(`DELETE FROM post_reactions WHERE user_id = $1`, [userID]);
    await client.query(`DELETE FROM feed_posts WHERE author_id = $1`, [userID]);
    await client.query(`DELETE FROM user_favorite_exercises WHERE user_id = $1`, [userID]);
    await client.query(`DELETE FROM saved_library_workouts WHERE user_id = $1`, [userID]);
    await client.query(
      `DELETE FROM friendships WHERE requester_id = $1 OR addressee_id = $1`,
      [userID],
    );
    await client.query(`DELETE FROM user_reports WHERE reporter_id = $1`, [userID]);
    await client.query(`DELETE FROM readiness_checkins WHERE user_id = $1`, [userID]);
    await client.query(`DELETE FROM exercise_sets WHERE user_id = $1`, [userID]);
    await client.query(`DELETE FROM workout_sessions WHERE user_id = $1`, [userID]);
    await client.query(`DELETE FROM workout_templates WHERE user_id = $1`, [userID]);
    await client.query(`DELETE FROM exercise_definitions WHERE owner_id = $1`, [userID]);
    await client.query(
      `DELETE FROM user_split_days WHERE split_id IN (SELECT id FROM user_splits WHERE user_id = $1)`,
      [userID],
    );
    await client.query(`DELETE FROM user_splits WHERE user_id = $1`, [userID]);
    await client.query(`DELETE FROM ai_briefs WHERE user_id = $1`, [userID]);
    await client.query(`DELETE FROM workouts WHERE user_id = $1`, [userID]);
    await client.query(`DELETE FROM profiles WHERE user_id = $1`, [userID]);
    await client.query("COMMIT");
  } catch (err) {
    await client.query("ROLLBACK");
    throw err;
  } finally {
    client.release();
  }

  const { error } = await supabaseAdmin.auth.admin.deleteUser(userID);
  if (error) throw error;
}
