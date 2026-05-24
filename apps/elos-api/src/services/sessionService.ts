import { Pool } from "pg";
import type {
  WorkoutSession,
  CreateSessionBody,
  UpdateSessionBody,
  ExerciseSet,
  CreateSetBody,
} from "elos-shared";

export class SessionService {
  constructor(private readonly db: Pool) {}

  async createSession(userId: string, body: CreateSessionBody): Promise<WorkoutSession> {
    const {
      started_at,
      finished_at = null,
      session_rpe = null,
      notes = "",
      template_id = null,
      total_volume = 0,
    } = body;
    const result = await this.db.query<WorkoutSession>(
      `INSERT INTO workout_sessions
         (user_id, started_at, finished_at, session_rpe, notes, template_id, total_volume)
       VALUES ($1, $2, $3, $4, $5, $6, $7)
       RETURNING id, user_id,
         started_at::text, finished_at::text,
         session_rpe, notes, template_id::text, total_volume,
         created_at::text`,
      [userId, started_at, finished_at, session_rpe, notes, template_id, total_volume]
    );
    return result.rows[0];
  }

  async getSessionsForUser(userId: string, limit = 30): Promise<WorkoutSession[]> {
    const result = await this.db.query<WorkoutSession>(
      `SELECT id, user_id,
         started_at::text, finished_at::text,
         session_rpe, notes, template_id::text, total_volume,
         created_at::text
       FROM workout_sessions
       WHERE user_id = $1
       ORDER BY started_at DESC
       LIMIT $2`,
      [userId, limit]
    );
    return result.rows;
  }

  async getSession(sessionId: string, userId: string): Promise<WorkoutSession | null> {
    const result = await this.db.query<WorkoutSession>(
      `SELECT id, user_id,
         started_at::text, finished_at::text,
         session_rpe, notes, template_id::text, total_volume,
         created_at::text
       FROM workout_sessions
       WHERE id = $1 AND user_id = $2`,
      [sessionId, userId]
    );
    return result.rows[0] ?? null;
  }

  async updateSession(
    sessionId: string,
    userId: string,
    body: UpdateSessionBody
  ): Promise<WorkoutSession | null> {
    const fields: string[] = [];
    const values: unknown[] = [];
    let idx = 1;

    if (body.finished_at !== undefined) { fields.push(`finished_at = $${idx++}`); values.push(body.finished_at); }
    if (body.session_rpe !== undefined) { fields.push(`session_rpe = $${idx++}`); values.push(body.session_rpe); }
    if (body.notes !== undefined)       { fields.push(`notes = $${idx++}`);       values.push(body.notes); }
    if (body.total_volume !== undefined){ fields.push(`total_volume = $${idx++}`); values.push(body.total_volume); }

    if (fields.length === 0) return this.getSession(sessionId, userId);

    values.push(sessionId, userId);
    const result = await this.db.query<WorkoutSession>(
      `UPDATE workout_sessions
       SET ${fields.join(", ")}
       WHERE id = $${idx} AND user_id = $${idx + 1}
       RETURNING id, user_id,
         started_at::text, finished_at::text,
         session_rpe, notes, template_id::text, total_volume,
         created_at::text`,
      values
    );
    return result.rows[0] ?? null;
  }

  async deleteSession(sessionId: string, userId: string): Promise<boolean> {
    const result = await this.db.query(
      `DELETE FROM workout_sessions WHERE id = $1 AND user_id = $2`,
      [sessionId, userId]
    );
    return (result.rowCount ?? 0) > 0;
  }

  async addSet(sessionId: string, userId: string, body: CreateSetBody): Promise<ExerciseSet> {
    const {
      exercise_name,
      set_index,
      weight_kg,
      reps,
      rpe = null,
      rir = null,
      completed_at = null,
    } = body;
    const result = await this.db.query<ExerciseSet>(
      `INSERT INTO exercise_sets
         (session_id, user_id, exercise_name, set_index, weight_kg, reps, rpe, rir, completed_at)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
       RETURNING id, session_id, user_id, exercise_name, set_index,
         weight_kg, reps, rpe, rir,
         completed_at::text, created_at::text`,
      [sessionId, userId, exercise_name, set_index, weight_kg, reps, rpe, rir, completed_at]
    );
    return result.rows[0];
  }

  async getSessionSets(sessionId: string, userId: string): Promise<ExerciseSet[]> {
    const result = await this.db.query<ExerciseSet>(
      `SELECT id, session_id, user_id, exercise_name, set_index,
         weight_kg, reps, rpe, rir,
         completed_at::text, created_at::text
       FROM exercise_sets
       WHERE session_id = $1 AND user_id = $2
       ORDER BY exercise_name, set_index`,
      [sessionId, userId]
    );
    return result.rows;
  }
}
