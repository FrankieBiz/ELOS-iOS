import { supabaseAdmin } from "../supabase";

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
