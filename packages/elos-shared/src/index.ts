export interface ErrorResponse {
  error: string;
  code?: string;
}

export type ApiResult<T> = T | ErrorResponse;

export interface ListResponse<T> {
  items: T[];
  next_cursor?: string;
}

export interface WorkoutSession {
  id: string;
  user_id: string;
  started_at: string;
  finished_at: string | null;
  session_rpe: number | null;
  notes: string;
  template_id: string | null;
  total_volume: number;
  created_at: string;
}

export interface CreateSessionBody {
  started_at: string;
  finished_at?: string;
  session_rpe?: number;
  notes?: string;
  template_id?: string;
  total_volume?: number;
}

export interface UpdateSessionBody {
  finished_at?: string;
  session_rpe?: number;
  notes?: string;
  total_volume?: number;
}

export interface ExerciseSet {
  id: string;
  session_id: string;
  user_id: string;
  exercise_name: string;
  set_index: number;
  weight_kg: number;
  reps: number;
  rpe: number | null;
  rir: number | null;
  completed_at: string | null;
  created_at: string;
}

export interface CreateSetBody {
  exercise_name: string;
  set_index: number;
  weight_kg: number;
  reps: number;
  rpe?: number | null;
  rir?: number | null;
  completed_at?: string;
}

export interface ExerciseDefinition {
  id: string;
  owner_id: string | null;
  name: string;
  primary_muscle: string;
  secondary_muscles: string[];
  equipment: string;
  movement_pattern: string;
  is_custom: boolean;
  created_at: string;
}

export interface CreateExerciseBody {
  name: string;
  primary_muscle: string;
  secondary_muscles?: string[];
  equipment?: string;
  movement_pattern?: string;
}

export interface WorkoutTemplate {
  id: string;
  user_id: string;
  name: string;
  created_at: string;
  exercises: TemplateExercise[];
}

export interface TemplateExercise {
  id: string;
  template_id: string;
  exercise_id: string | null;
  exercise_name: string;
  order_index: number;
  target_sets: number;
  target_reps: string;
  target_rpe: number | null;
  rest_seconds: number;
}

export interface CreateTemplateBody {
  name: string;
  exercises?: Omit<TemplateExercise, "id" | "template_id">[];
}

export interface VolumeDataPoint {
  muscle: string;
  week: string;
  hard_sets: number;
  tonnage: number;
}

export interface E1RMDataPoint {
  day: string;
  e1rm: number;
}

export interface PersonalRecord {
  exercise_name: string;
  weight_kg: number;
  reps: number;
  e1rm: number;
  achieved_at: string;
}

export interface OverloadSuggestion {
  exercise_name: string;
  suggested_weight_kg: number;
  suggested_reps: string;
  reasoning: string;
}

export interface ReadinessCheckin {
  id: string;
  user_id: string;
  log_date: string;
  sleep_quality: number;
  soreness: number;
  stress: number;
  motivation: number;
  overall_score: number;
  created_at: string;
}

export interface CreateReadinessBody {
  log_date: string;
  sleep_quality: number;
  soreness: number;
  stress: number;
  motivation: number;
}

export * from "./auth";

// ─── Library / Discover ───────────────────────────────────────────────────────

export interface Creator {
  id: string;
  name: string;
  slug: string;
  bio: string;
  category: string;
  training_style: string;
  goals: string[];
  split_types: string[];
  difficulty: string;
  image_url: string;
  is_verified: boolean;
  source_urls: string[];
  review_status: string;
}

export interface CreatorWorkout {
  id: string;
  creator_id: string;
  creator_name?: string;
  creator_slug?: string;
  title: string;
  description: string;
  program_type: string;
  days_per_week: number;
  goal: string;
  difficulty: string;
  duration_weeks: number;
  est_session_mins: number;
  equipment: string[];
  muscle_groups: string[];
  tags: string[];
  source_url: string;
  attribution: string;
  disclaimer: string;
  confidence_level: string;
}

export interface WorkoutDay {
  id: string;
  workout_id: string;
  day_number: number;
  name: string;
  focus: string;
  notes: string;
  order_index: number;
  exercises: WorkoutDayExercise[];
}

export interface WorkoutDayExercise {
  id: string;
  workout_day_id: string;
  exercise_name: string;
  order_index: number;
  sets: number;
  reps: string;
  rest_seconds: number;
  tempo: string;
  rpe_guidance: string;
  notes: string;
  substitution_notes: string;
  is_superset: boolean;
  superset_group: number | null;
}

export interface Machine {
  id: string;
  name: string;
  slug: string;
  alternate_names: string[];
  category: string;
  sub_category: string;
  equipment_type: string;
  primary_muscles: string[];
  secondary_muscles: string[];
  movement_pattern: string;
  description: string;
  image_url: string;
  tags: string[];
}

export interface MachineDetail extends Machine {
  models: MachineModel[];
  exercises: MachineExercise[];
  substitutions: MachineSubstitution[];
}

export interface MachineModel {
  id: string;
  machine_id: string;
  brand_id: string;
  brand_name: string;
  model_name: string;
  setup_instructions: string;
  adjustment_notes: string;
  usage_steps: string[];
  form_cues: string[];
  common_mistakes: string[];
  safety_notes: string[];
  beginner_tips: string[];
  advanced_tips: string[];
  rep_range_rec: string;
  notes: string;
}

export interface MachineBrand {
  id: string;
  name: string;
  slug: string;
  website_url: string;
}

export interface MachineExercise {
  exercise_name: string;
  exercise_id: string;
  notes: string;
}

export interface MachineSubstitution {
  substitution_type: string;
  notes: string;
  substitute_machine_name: string;
  substitute_machine_slug: string;
  substitute_exercise_id: string;
}

// Social / Leaderboard types

export interface FriendProfile {
  friendship_id: string;
  user_id: string;
  username: string;
  first_name: string;
  last_name: string;
  avatar_color: string;
  status: "pending" | "accepted" | "blocked";
  is_requester: boolean;
}

export interface LeaderboardEntry {
  rank: number;
  user_id: string;
  username: string;
  first_name: string;
  last_name: string;
  avatar_color: string;
  value: number;
  is_self: boolean;
}

export interface WeeklyLeaderboard {
  metric: "volume" | "sessions" | "streak" | "prs";
  week_start: string;
  entries: LeaderboardEntry[];
  my_rank: number;
  my_value: number;
}

export interface MyStandings {
  week_start: string;
  total_friends: number;
  volume:   { rank: number; value: number };
  sessions: { rank: number; value: number };
  streak:   { rank: number; value: number };
  prs:      { rank: number; value: number };
}

export interface UserSearchResult {
  user_id: string;
  username: string;
  first_name: string;
  last_name: string;
  avatar_color: string;
  friendship_status: "none" | "pending_sent" | "pending_received" | "accepted";
}

export interface UserSplitDay {
  id: string;
  split_id: string;
  order_index: number;
  day_label: string;
  day_name: string;
  template_id: string;
  is_rest: boolean;
  exercises_json: string;
}

export interface UserSplit {
  id: string;
  user_id: string;
  name: string;
  library_key: string;
  is_active: boolean;
  created_at: string;
  days: UserSplitDay[];
}
