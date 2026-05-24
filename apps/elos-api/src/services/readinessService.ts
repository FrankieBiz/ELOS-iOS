import { Pool } from "pg";
import type { ReadinessCheckin, CreateReadinessBody } from "elos-shared";

export class ReadinessService {
  constructor(private readonly db: Pool) {}

  async logCheckin(userId: string, body: CreateReadinessBody): Promise<ReadinessCheckin> {
    const { log_date, sleep_quality, soreness, stress, motivation } = body;
    const overall_score = (sleep_quality + soreness + stress + motivation) / 4;

    const result = await this.db.query<ReadinessCheckin>(
      `INSERT INTO readiness_checkins
         (user_id, log_date, sleep_quality, soreness, stress, motivation, overall_score)
       VALUES ($1, $2, $3, $4, $5, $6, $7)
       ON CONFLICT (user_id, log_date) DO UPDATE SET
         sleep_quality = EXCLUDED.sleep_quality,
         soreness      = EXCLUDED.soreness,
         stress        = EXCLUDED.stress,
         motivation    = EXCLUDED.motivation,
         overall_score = EXCLUDED.overall_score
       RETURNING id, user_id, log_date::text, sleep_quality, soreness,
         stress, motivation, overall_score::float, created_at::text`,
      [userId, log_date, sleep_quality, soreness, stress, motivation, overall_score]
    );
    return result.rows[0];
  }

  async getHistory(userId: string, days = 30): Promise<ReadinessCheckin[]> {
    const result = await this.db.query<ReadinessCheckin>(
      `SELECT id, user_id, log_date::text, sleep_quality, soreness,
         stress, motivation, overall_score::float, created_at::text
       FROM readiness_checkins
       WHERE user_id = $1
         AND log_date >= CURRENT_DATE - ($2 || ' days')::interval
       ORDER BY log_date DESC`,
      [userId, days]
    );
    return result.rows;
  }

  async getTodayCheckin(userId: string): Promise<ReadinessCheckin | null> {
    const result = await this.db.query<ReadinessCheckin>(
      `SELECT id, user_id, log_date::text, sleep_quality, soreness,
         stress, motivation, overall_score::float, created_at::text
       FROM readiness_checkins
       WHERE user_id = $1 AND log_date = CURRENT_DATE`,
      [userId]
    );
    return result.rows[0] ?? null;
  }
}
