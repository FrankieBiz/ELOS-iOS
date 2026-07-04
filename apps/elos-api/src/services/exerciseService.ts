import { Pool } from "pg";
import type { ExerciseDefinition, CreateExerciseBody } from "elos-shared";

// Single source of truth for the exercise column projection. Any query that
// returns an ExerciseDefinition must select exactly these, in this order.
// Optionally alias-qualified so it works in both single-table SELECTs/RETURNING
// and joined queries where a bare column (id, created_at) would be ambiguous.
const exerciseColumns = (alias = ""): string => {
  const p = alias ? `${alias}.` : "";
  return `${p}id, ${p}owner_id::text, ${p}name, ${p}primary_muscle,
       ${p}secondary_muscles, ${p}equipment, ${p}movement_pattern,
       ${p}instructions, ${p}image_key, ${p}is_custom, ${p}created_at::text`;
};

export interface ExerciseSearchFilters {
  q?: string;
  primary_muscle?: string;
  equipment?: string;
  movement_pattern?: string;
  brand_slug?: string;
  is_custom?: boolean;
  limit?: number;
  offset?: number;
}

export class ExerciseService {
  constructor(private readonly db: Pool) {}

  async searchExercises(userId: string, filters: ExerciseSearchFilters = {}): Promise<ExerciseDefinition[]> {
    const where: string[] = ["(ed.owner_id IS NULL OR ed.owner_id = $1)"];
    const params: unknown[] = [userId];

    if (filters.q && filters.q.trim().length > 0) {
      params.push(filters.q.trim());
      where.push(`ed.search_vector @@ plainto_tsquery('english', $${params.length})`);
    }
    if (filters.primary_muscle) {
      params.push(filters.primary_muscle);
      where.push(`ed.primary_muscle = $${params.length}`);
    }
    if (filters.equipment) {
      params.push(filters.equipment);
      where.push(`ed.equipment = $${params.length}`);
    }
    if (filters.movement_pattern) {
      params.push(filters.movement_pattern);
      where.push(`ed.movement_pattern = $${params.length}`);
    }
    if (filters.is_custom !== undefined) {
      params.push(filters.is_custom);
      where.push(`ed.is_custom = $${params.length}`);
    }
    if (filters.brand_slug) {
      params.push(filters.brand_slug);
      where.push(`EXISTS (
        SELECT 1
        FROM machine_exercises me
        JOIN machines m       ON m.id = me.machine_id
        JOIN machine_models mm ON mm.machine_id = m.id
        JOIN machine_brands mb ON mb.id = mm.brand_id
        WHERE lower(me.exercise_name) = lower(ed.name)
          AND mb.slug = $${params.length}
      )`);
    }

    const limit = Math.min(Math.max(filters.limit ?? 50, 1), 500);
    const offset = Math.max(filters.offset ?? 0, 0);
    params.push(limit, offset);
    const limitIdx = params.length - 1;
    const offsetIdx = params.length;

    const result = await this.db.query<ExerciseDefinition>(
      `SELECT ${exerciseColumns("ed")}
       FROM exercise_definitions ed
       WHERE ${where.join(" AND ")}
       ORDER BY ed.is_custom ASC, ed.name ASC
       LIMIT $${limitIdx} OFFSET $${offsetIdx}`,
      params
    );
    return result.rows;
  }

  async createCustomExercise(
    userId: string,
    body: CreateExerciseBody
  ): Promise<ExerciseDefinition> {
    const {
      name,
      primary_muscle,
      secondary_muscles = [],
      equipment = "",
      movement_pattern = "",
    } = body;
    const result = await this.db.query<ExerciseDefinition>(
      `INSERT INTO exercise_definitions
         (owner_id, name, primary_muscle, secondary_muscles, equipment, movement_pattern, is_custom)
       VALUES ($1, $2, $3, $4, $5, $6, true)
       RETURNING ${exerciseColumns()}`,
      [userId, name, primary_muscle, secondary_muscles, equipment, movement_pattern]
    );
    return result.rows[0];
  }

  async getRecentExercises(userId: string, limit = 10): Promise<ExerciseDefinition[]> {
    const clamped = Math.min(Math.max(limit, 1), 50);
    // Compute each definition's last-used time once in a CTE, then order by it —
    // avoids the per-row correlated subquery the previous query used.
    const result = await this.db.query<ExerciseDefinition>(
      `WITH last_used AS (
         SELECT ed2.id AS def_id, MAX(es.completed_at) AS last_at
         FROM exercise_sets es
         JOIN exercise_definitions ed2 ON lower(ed2.name) = lower(es.exercise_name)
           AND (ed2.owner_id IS NULL OR ed2.owner_id = $1)
         WHERE es.user_id = $1
           AND es.completed_at IS NOT NULL
         GROUP BY ed2.id
       )
       SELECT ${exerciseColumns("ed")}
       FROM exercise_definitions ed
       JOIN last_used lu ON lu.def_id = ed.id
       ORDER BY lu.last_at DESC NULLS LAST
       LIMIT $2`,
      [userId, clamped]
    );
    return result.rows;
  }

  async getFavorites(userId: string): Promise<ExerciseDefinition[]> {
    const result = await this.db.query<ExerciseDefinition>(
      `SELECT ${exerciseColumns("ed")}
       FROM user_favorite_exercises ufe
       JOIN exercise_definitions ed ON ed.id = ufe.exercise_id
       WHERE ufe.user_id = $1
         AND (ed.owner_id IS NULL OR ed.owner_id = $1)
       ORDER BY ufe.created_at DESC`,
      [userId]
    );
    return result.rows;
  }

  async favoriteExercise(userId: string, exerciseId: string): Promise<void> {
    await this.db.query(
      `INSERT INTO user_favorite_exercises (user_id, exercise_id)
       VALUES ($1, $2)
       ON CONFLICT DO NOTHING`,
      [userId, exerciseId]
    );
  }

  async unfavoriteExercise(userId: string, exerciseId: string): Promise<void> {
    await this.db.query(
      `DELETE FROM user_favorite_exercises
       WHERE user_id = $1 AND exercise_id = $2`,
      [userId, exerciseId]
    );
  }
}
