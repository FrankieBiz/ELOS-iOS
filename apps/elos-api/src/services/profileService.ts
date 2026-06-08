import { supabaseAdmin } from "../supabase";
import { pool } from "../db";

export interface ProfileFields {
  first_name?: string | null;
  last_name?: string | null;
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
  if (error) throw error;
  return data;
}

export async function completeOnboarding(userID: string) {
  return upsertProfile(userID, { onboarding_complete: true });
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
