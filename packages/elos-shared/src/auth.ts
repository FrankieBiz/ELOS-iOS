export interface User {
  user_id: string;
  email: string;
  onboarding_complete: boolean;
}

export interface LoginRequest {
  email: string;
  password: string;
}

export interface LoginResponse {
  token: string;
  user_id: string;
  onboarding_complete: boolean;
}

export interface RegisterRequest {
  email: string;
  password: string;
}

export interface RegisterResponse {
  token: string;
  user_id: string;
}

export interface Profile {
  user_id: string;
  first_name: string | null;
  last_name: string | null;
  height_cm: number | null;
  weight_kg: number | null;
  age_years: number | null;
  training_experience: "beginner" | "intermediate" | "advanced" | null;
  training_goal: "strength" | "hypertrophy" | "endurance" | "weight_loss" | null;
  school_name: string | null;
  school_year: "freshman" | "sophomore" | "junior" | "senior" | null;
  cal_goal: number | null;
  protein_goal: number | null;
  carb_goal: number | null;
  fat_goal: number | null;
  onboarding_complete: boolean;
  updated_at: string;
}

export interface ProfileUpdate {
  first_name?: string;
  last_name?: string;
  height_cm?: number;
  weight_kg?: number;
  age_years?: number;
  training_experience?: string;
  training_goal?: string;
  school_name?: string;
  school_year?: string;
  cal_goal?: number;
  protein_goal?: number;
  carb_goal?: number;
  fat_goal?: number;
  onboarding_complete?: boolean;
}
