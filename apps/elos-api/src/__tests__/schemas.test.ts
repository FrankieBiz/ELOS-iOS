import { describe, it, expect } from "vitest";
import {
  createSetSchema,
  createReadinessSchema,
  createSessionSchema,
  upsertProfileSchema,
  searchExercisesQuerySchema,
  createTemplateSchema,
  createFeedPostSchema,
  reactSchema,
  friendRequestSchema,
  reportUserSchema,
  saveWorkoutSchema,
  blockUserSchema,
} from "../schemas";
import { FEED_REACTION_EMOJIS } from "elos-shared";

describe("zod schemas", () => {
  describe("createSetSchema", () => {
    it("accepts a valid set", () => {
      const result = createSetSchema.safeParse({
        exercise_name: "Bench Press",
        set_index: 0,
        weight_kg: 60,
        reps: 8,
        rpe: 7,
      });
      expect(result.success).toBe(true);
    });

    it("rejects negative weight", () => {
      const result = createSetSchema.safeParse({
        exercise_name: "Bench Press",
        set_index: 0,
        weight_kg: -5,
        reps: 8,
      });
      expect(result.success).toBe(false);
    });

    it("rejects RPE above 10", () => {
      const result = createSetSchema.safeParse({
        exercise_name: "Bench Press",
        set_index: 0,
        weight_kg: 60,
        reps: 8,
        rpe: 11,
      });
      expect(result.success).toBe(false);
    });

    it("rejects reps above 500", () => {
      const result = createSetSchema.safeParse({
        exercise_name: "Bench Press",
        set_index: 0,
        weight_kg: 60,
        reps: 600,
      });
      expect(result.success).toBe(false);
    });

    it("accepts machine/equipment fields", () => {
      const result = createSetSchema.safeParse({
        exercise_name: "Lat Pulldown",
        set_index: 0,
        weight_kg: 50,
        reps: 10,
        equipment_id: "eq_hammer_lat_pulldown",
        equipment_dedupe_key: "hammer-strength|lat-pulldown|iso",
        equipment_brand_name: "Hammer Strength",
      });
      expect(result.success).toBe(true);
    });

    it("still accepts a set with equipment fields omitted (backward compat)", () => {
      const result = createSetSchema.safeParse({
        exercise_name: "Lat Pulldown",
        set_index: 0,
        weight_kg: 50,
        reps: 10,
      });
      expect(result.success).toBe(true);
    });
  });

  describe("createReadinessSchema", () => {
    it("accepts a valid check-in", () => {
      const result = createReadinessSchema.safeParse({
        log_date: "2026-05-12",
        sleep_quality: 4,
        soreness: 3,
        stress: 2,
        motivation: 5,
      });
      expect(result.success).toBe(true);
    });

    it("rejects ratings outside 1-5", () => {
      const result = createReadinessSchema.safeParse({
        log_date: "2026-05-12",
        sleep_quality: 0,
        soreness: 3,
        stress: 2,
        motivation: 5,
      });
      expect(result.success).toBe(false);
    });
  });

  describe("createSessionSchema", () => {
    it("requires started_at", () => {
      const result = createSessionSchema.safeParse({});
      expect(result.success).toBe(false);
    });

    it("accepts minimal valid body", () => {
      const result = createSessionSchema.safeParse({
        started_at: "2026-05-12T10:00:00Z",
      });
      expect(result.success).toBe(true);
    });
  });

  describe("upsertProfileSchema", () => {
    it("rejects unreasonable age", () => {
      const result = upsertProfileSchema.safeParse({ age_years: 200 });
      expect(result.success).toBe(false);
    });

    it("rejects unreasonable weight", () => {
      const result = upsertProfileSchema.safeParse({ weight_kg: 9999 });
      expect(result.success).toBe(false);
    });

    it("accepts onboarding_complete flag alone", () => {
      const result = upsertProfileSchema.safeParse({ onboarding_complete: true });
      expect(result.success).toBe(true);
    });
  });

  describe("searchExercisesQuerySchema", () => {
    it("accepts empty filters", () => {
      const result = searchExercisesQuerySchema.safeParse({});
      expect(result.success).toBe(true);
    });

    it("coerces numeric query strings", () => {
      const result = searchExercisesQuerySchema.safeParse({ limit: "25", offset: "10" });
      expect(result.success).toBe(true);
      if (result.success) {
        expect(result.data.limit).toBe(25);
        expect(result.data.offset).toBe(10);
      }
    });

    it("rejects limit above 500", () => {
      const result = searchExercisesQuerySchema.safeParse({ limit: 1000 });
      expect(result.success).toBe(false);
    });

    it("coerces is_custom string to boolean", () => {
      const result = searchExercisesQuerySchema.safeParse({ is_custom: "true" });
      expect(result.success).toBe(true);
      if (result.success) expect(result.data.is_custom).toBe(true);
    });

    it("accepts a full filter combo", () => {
      const result = searchExercisesQuerySchema.safeParse({
        q: "bench",
        primary_muscle: "chest",
        equipment: "barbell",
        movement_pattern: "push",
        brand_slug: "hammer-strength",
        limit: 50,
      });
      expect(result.success).toBe(true);
    });
  });

  describe("createTemplateSchema (with exercise_id)", () => {
    it("accepts exercises with exercise_id", () => {
      const result = createTemplateSchema.safeParse({
        name: "Push Day",
        exercises: [
          {
            exercise_id: "123e4567-e89b-12d3-a456-426614174000",
            exercise_name: "Barbell Bench Press",
            order_index: 0,
            target_sets: 4,
            target_reps: "6-8",
            rest_seconds: 180,
          },
        ],
      });
      expect(result.success).toBe(true);
    });

    it("rejects non-UUID exercise_id", () => {
      const result = createTemplateSchema.safeParse({
        name: "Push Day",
        exercises: [
          {
            exercise_id: "not-a-uuid",
            exercise_name: "Bench",
            order_index: 0,
            target_sets: 3,
            target_reps: "8-10",
            rest_seconds: 90,
          },
        ],
      });
      expect(result.success).toBe(false);
    });

    it("still accepts exercises without exercise_id (legacy clients)", () => {
      const result = createTemplateSchema.safeParse({
        name: "Push Day",
        exercises: [
          {
            exercise_name: "Bench",
            order_index: 0,
            target_sets: 3,
            target_reps: "8-10",
            rest_seconds: 90,
          },
        ],
      });
      expect(result.success).toBe(true);
    });

    it("accepts exercises with notes and machine/equipment fields", () => {
      const result = createTemplateSchema.safeParse({
        name: "Pull Day",
        exercises: [
          {
            exercise_name: "Lat Pulldown",
            order_index: 0,
            target_sets: 3,
            target_reps: "8-12",
            rest_seconds: 90,
            notes: "wide grip",
            equipment_id: "eq_hammer_lat_pulldown",
            equipment_dedupe_key: "hammer-strength|lat-pulldown|iso",
            equipment_brand_name: "Hammer Strength",
          },
        ],
      });
      expect(result.success).toBe(true);
    });
  });

  describe("createFeedPostSchema", () => {
    it("accepts a valid workout post", () => {
      const result = createFeedPostSchema.safeParse({
        kind: "workout",
        payload: {
          date: "2026-06-06",
          duration_min: 62,
          volume_kg: 4200,
          total_sets: 18,
          unique_exercises: 6,
          top_lift: { name: "Bench Press", weight_kg: 100, reps: 5 },
          pr: "Bench Press",
        },
      });
      expect(result.success).toBe(true);
    });

    it("accepts a valid pr post", () => {
      const result = createFeedPostSchema.safeParse({
        kind: "pr",
        payload: { exercise_name: "Deadlift", weight_kg: 180, reps: 3, e1rm: 198 },
      });
      expect(result.success).toBe(true);
    });

    it("rejects split posts (server-built only)", () => {
      const result = createFeedPostSchema.safeParse({
        kind: "split",
        payload: { name: "PPL", days: [] },
      });
      expect(result.success).toBe(false);
    });

    it("rejects a workout payload missing required fields", () => {
      const result = createFeedPostSchema.safeParse({
        kind: "workout",
        payload: { date: "2026-06-06" },
      });
      expect(result.success).toBe(false);
    });

    it("rejects unknown keys in the payload (strict)", () => {
      const result = createFeedPostSchema.safeParse({
        kind: "pr",
        payload: {
          exercise_name: "Deadlift",
          weight_kg: 180,
          reps: 3,
          e1rm: 198,
          injected: "x".repeat(100000),
        },
      });
      expect(result.success).toBe(false);
    });
  });

  describe("friendRequestSchema", () => {
    it("accepts a valid UUID addressee", () => {
      expect(
        friendRequestSchema.safeParse({ addresseeId: "123e4567-e89b-12d3-a456-426614174000" }).success
      ).toBe(true);
    });
    it("rejects a non-UUID addressee", () => {
      expect(friendRequestSchema.safeParse({ addresseeId: "nope" }).success).toBe(false);
    });
    it("rejects a missing addressee", () => {
      expect(friendRequestSchema.safeParse({}).success).toBe(false);
    });
  });

  describe("reportUserSchema", () => {
    it("accepts a valid report", () => {
      expect(
        reportUserSchema.safeParse({
          reportedId: "123e4567-e89b-12d3-a456-426614174000",
          category: "spam",
          note: "bot account",
        }).success
      ).toBe(true);
    });
    it("rejects an unknown category", () => {
      expect(
        reportUserSchema.safeParse({
          reportedId: "123e4567-e89b-12d3-a456-426614174000",
          category: "slander",
        }).success
      ).toBe(false);
    });
    it("rejects a note over 1000 chars", () => {
      expect(
        reportUserSchema.safeParse({
          reportedId: "123e4567-e89b-12d3-a456-426614174000",
          category: "other",
          note: "x".repeat(1001),
        }).success
      ).toBe(false);
    });
  });

  describe("saveWorkoutSchema", () => {
    it("accepts a valid UUID workout id", () => {
      expect(
        saveWorkoutSchema.safeParse({ workoutId: "123e4567-e89b-12d3-a456-426614174000" }).success
      ).toBe(true);
    });
    it("rejects a non-UUID workout id", () => {
      expect(saveWorkoutSchema.safeParse({ workoutId: "42" }).success).toBe(false);
    });
  });

  describe("blockUserSchema", () => {
    it("accepts a valid UUID", () => {
      expect(
        blockUserSchema.safeParse({ blockedId: "123e4567-e89b-12d3-a456-426614174000" }).success
      ).toBe(true);
    });
    it("rejects a non-UUID / missing id", () => {
      expect(blockUserSchema.safeParse({ blockedId: "nope" }).success).toBe(false);
      expect(blockUserSchema.safeParse({}).success).toBe(false);
    });
  });

  describe("reactSchema", () => {
    it("accepts each allowed emoji", () => {
      for (const emoji of FEED_REACTION_EMOJIS) {
        expect(reactSchema.safeParse({ emoji }).success).toBe(true);
      }
    });

    it("rejects an empty emoji", () => {
      expect(reactSchema.safeParse({ emoji: "" }).success).toBe(false);
    });
  });
});
