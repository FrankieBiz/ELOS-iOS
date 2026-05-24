import { Pool } from "pg";
import type {
  VolumeDataPoint,
  E1RMDataPoint,
  PersonalRecord,
  OverloadSuggestion,
} from "elos-shared";

export class AnalyticsService {
  constructor(private readonly db: Pool) {}

  async getWeeklyVolume(userId: string, weeks = 8): Promise<VolumeDataPoint[]> {
    const result = await this.db.query<VolumeDataPoint>(
      `SELECT
         ed.primary_muscle AS muscle,
         date_trunc('week', es.completed_at)::date::text AS week,
         COUNT(*)::int AS hard_sets,
         COALESCE(SUM(es.weight_kg * es.reps), 0)::float AS tonnage
       FROM exercise_sets es
       JOIN exercise_definitions ed ON lower(es.exercise_name) = lower(ed.name)
       WHERE es.user_id = $1
         AND es.completed_at >= NOW() - ($2 || ' weeks')::interval
         AND es.reps > 0
       GROUP BY ed.primary_muscle, date_trunc('week', es.completed_at)
       ORDER BY week DESC, hard_sets DESC`,
      [userId, weeks]
    );
    return result.rows;
  }

  async getE1RMHistory(userId: string, exerciseName: string, weeks = 12): Promise<E1RMDataPoint[]> {
    const result = await this.db.query<E1RMDataPoint>(
      `SELECT
         date_trunc('day', completed_at)::date::text AS day,
         MAX(weight_kg * (1 + reps::float / 30))::float AS e1rm
       FROM exercise_sets
       WHERE user_id = $1
         AND lower(exercise_name) = lower($2)
         AND reps > 0 AND reps <= 30
         AND completed_at IS NOT NULL
         AND completed_at >= NOW() - ($3 || ' weeks')::interval
       GROUP BY date_trunc('day', completed_at)
       ORDER BY day ASC`,
      [userId, exerciseName, weeks]
    );
    return result.rows;
  }

  async getPersonalRecords(userId: string): Promise<PersonalRecord[]> {
    const result = await this.db.query<PersonalRecord>(
      `SELECT
         exercise_name,
         weight_kg::float,
         reps,
         (weight_kg * (1 + reps::float / 30))::float AS e1rm,
         completed_at::text AS achieved_at
       FROM (
         SELECT DISTINCT ON (exercise_name)
           exercise_name, weight_kg, reps, completed_at,
           weight_kg * (1 + reps::float / 30) AS e1rm_val
         FROM exercise_sets
         WHERE user_id = $1 AND reps > 0 AND reps <= 30
         ORDER BY exercise_name, e1rm_val DESC
       ) sub
       ORDER BY e1rm DESC`,
      [userId]
    );
    return result.rows;
  }

  async getOverloadSuggestion(
    userId: string,
    exerciseName: string
  ): Promise<OverloadSuggestion> {
    // Fetch last 3 sessions that included this exercise
    const result = await this.db.query<{
      weight_kg: number;
      reps: number;
      rpe: number | null;
      target_reps: string | null;
    }>(
      `SELECT es.weight_kg::float, es.reps, es.rpe::float,
         te.target_reps
       FROM exercise_sets es
       LEFT JOIN workout_sessions ws ON es.session_id = ws.id
       LEFT JOIN template_exercises te
         ON ws.template_id = te.template_id
         AND lower(te.exercise_name) = lower(es.exercise_name)
       WHERE es.user_id = $1
         AND lower(es.exercise_name) = lower($2)
         AND es.completed_at IS NOT NULL
       ORDER BY es.completed_at DESC
       LIMIT 6`,
      [userId, exerciseName]
    );

    const sets = result.rows;
    if (sets.length === 0) {
      return {
        exercise_name: exerciseName,
        suggested_weight_kg: 0,
        suggested_reps: "8-10",
        reasoning: "No history found — start with a comfortable weight.",
      };
    }

    const lastWeight = sets[0].weight_kg;
    const avgReps = sets.slice(0, 3).reduce((s, r) => s + r.reps, 0) / Math.min(sets.length, 3);
    const avgRPE = sets.slice(0, 3).filter((r) => r.rpe).reduce((s, r) => s + (r.rpe ?? 0), 0) /
      (sets.slice(0, 3).filter((r) => r.rpe).length || 1);

    // Parse target from template if available
    const targetReps = sets[0].target_reps ?? "8-10";
    const [minReps] = targetReps.split("-").map(Number);
    const targetMin = isNaN(minReps) ? 8 : minReps;

    const lowerName = exerciseName.toLowerCase();
    const isLower = ["squat", "deadlift", "leg", "hip"].some((k) => lowerName.includes(k));
    const weightIncrement = isLower ? 5 : 2.5;

    let suggestedWeight = lastWeight;
    let reasoning: string;

    if (avgRPE > 0 && avgRPE >= 9.5) {
      suggestedWeight = Math.max(0, lastWeight - weightIncrement);
      reasoning = `RPE averaged ${avgRPE.toFixed(1)} — reduce load to manage fatigue.`;
    } else if (avgReps >= targetMin && (avgRPE === 0 || avgRPE <= 8.0)) {
      suggestedWeight = lastWeight + weightIncrement;
      reasoning = `Hit target reps at RPE ≤ 8 — increase load by ${weightIncrement} kg.`;
    } else if (avgReps < targetMin) {
      reasoning = `Missed target reps last session — keep same weight, aim for ${targetMin}+ reps.`;
    } else {
      reasoning = `Good progress — maintain weight, add 1–2 reps before increasing load.`;
    }

    return {
      exercise_name: exerciseName,
      suggested_weight_kg: suggestedWeight,
      suggested_reps: targetReps,
      reasoning,
    };
  }
}
