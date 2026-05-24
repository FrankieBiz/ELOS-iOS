import { z } from "zod";

const isoDate = z.string().min(1);

export const createSessionSchema = z.object({
  started_at: isoDate,
  finished_at: isoDate.optional(),
  session_rpe: z.number().min(0).max(10).optional(),
  notes: z.string().max(2000).optional(),
  template_id: z.string().uuid().optional(),
  total_volume: z.number().min(0).max(1_000_000).optional(),
});

export const updateSessionSchema = z.object({
  finished_at: isoDate.optional(),
  session_rpe: z.number().min(0).max(10).optional(),
  notes: z.string().max(2000).optional(),
  total_volume: z.number().min(0).max(1_000_000).optional(),
});

export const createSetSchema = z.object({
  exercise_name: z.string().min(1).max(200),
  set_index: z.number().int().min(0).max(100),
  weight_kg: z.number().min(0).max(1000),
  reps: z.number().int().min(0).max(500),
  rpe: z.number().min(0).max(10).nullable().optional(),
  rir: z.number().int().min(0).max(20).nullable().optional(),
  completed_at: isoDate.optional(),
});

export const createExerciseSchema = z.object({
  name: z.string().min(1).max(200),
  primary_muscle: z.string().min(1).max(100),
  secondary_muscles: z.array(z.string().max(100)).max(20).optional(),
  equipment: z.string().max(100).optional(),
  movement_pattern: z.string().max(100).optional(),
});

const optionalIntString = z
  .union([z.string(), z.number()])
  .transform((v) => (typeof v === "string" ? Number.parseInt(v, 10) : v))
  .pipe(z.number().int());

export const searchExercisesQuerySchema = z.object({
  q: z.string().max(200).optional(),
  primary_muscle: z.string().max(100).optional(),
  equipment: z.string().max(100).optional(),
  movement_pattern: z.string().max(100).optional(),
  brand_slug: z.string().max(100).optional(),
  is_custom: z
    .union([z.string(), z.boolean()])
    .transform((v) => (typeof v === "string" ? v === "true" : v))
    .optional(),
  limit: optionalIntString.refine((n) => n >= 1 && n <= 500, "1-500").optional(),
  offset: optionalIntString.refine((n) => n >= 0, "non-negative").optional(),
});

export const createTemplateSchema = z.object({
  name: z.string().min(1).max(200),
  exercises: z
    .array(
      z.object({
        exercise_id: z.string().uuid().optional(),
        exercise_name: z.string().min(1).max(200),
        order_index: z.number().int().min(0).max(100),
        target_sets: z.number().int().min(1).max(50),
        target_reps: z.string().max(50),
        target_rpe: z.number().min(0).max(10).nullable().optional(),
        rest_seconds: z.number().int().min(0).max(3600),
      })
    )
    .max(50)
    .optional(),
});

export const updateTemplateNameSchema = z.object({
  name: z.string().min(1).max(200),
});

export const createReadinessSchema = z.object({
  log_date: z.string().min(1).max(20),
  sleep_quality: z.number().int().min(1).max(5),
  soreness: z.number().int().min(1).max(5),
  stress: z.number().int().min(1).max(5),
  motivation: z.number().int().min(1).max(5),
});

export const upsertProfileSchema = z.object({
  first_name: z.string().max(100).nullable().optional(),
  last_name: z.string().max(100).nullable().optional(),
  height_cm: z.number().min(50).max(300).nullable().optional(),
  weight_kg: z.number().min(20).max(500).nullable().optional(),
  age_years: z.number().int().min(13).max(120).nullable().optional(),
  training_experience: z.string().max(100).nullable().optional(),
  training_goal: z.string().max(100).nullable().optional(),
  school_name: z.string().max(200).nullable().optional(),
  school_year: z.string().max(50).nullable().optional(),
  cal_goal: z.number().int().min(500).max(10000).nullable().optional(),
  protein_goal: z.number().int().min(0).max(1000).nullable().optional(),
  carb_goal: z.number().int().min(0).max(2000).nullable().optional(),
  fat_goal: z.number().int().min(0).max(500).nullable().optional(),
  onboarding_complete: z.boolean().optional(),
});

export const createSplitSchema = z.object({
  name: z.string().min(1).max(200),
  library_key: z.string().max(100).optional(),
  days: z.array(z.object({
    order_index: z.number().int().min(0).max(6),
    day_label: z.string().max(30),
    day_name: z.string().max(200),
    template_id: z.string().max(100).optional(),
    is_rest: z.boolean(),
    exercises_json: z.string().max(2000),
  })).max(7),
});
