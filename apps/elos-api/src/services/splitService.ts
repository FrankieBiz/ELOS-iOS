import { Pool } from "pg";
import type { UserSplit, UserSplitDay } from "elos-shared";

type CreateSplitDayBody = {
  order_index: number;
  day_label: string;
  day_name: string;
  template_id?: string;
  is_rest: boolean;
  exercises_json: string;
};

type CreateSplitBody = {
  name: string;
  library_key?: string;
  days: CreateSplitDayBody[];
};

type CreateResult =
  | { conflict: false; split: UserSplit }
  | { conflict: true; existingId: string };

export class SplitService {
  constructor(private readonly pool: Pool) {}

  async createSplit(userId: string, body: CreateSplitBody): Promise<CreateResult> {
    const client = await this.pool.connect();
    try {
      await client.query("BEGIN");

      const splitResult = await client.query<Omit<UserSplit, "days">>(
        `INSERT INTO user_splits (user_id, name, library_key, is_active)
         VALUES ($1, $2, $3, TRUE)
         RETURNING id, user_id, name, library_key, is_active, created_at::text`,
        [userId, body.name, body.library_key ?? ""]
      );
      const split = splitResult.rows[0];

      // Deactivate all other splits for this user
      await client.query(
        `UPDATE user_splits SET is_active = FALSE WHERE user_id = $1 AND id <> $2`,
        [userId, split.id]
      );

      const days: UserSplitDay[] = [];
      for (const day of body.days ?? []) {
        const dayResult = await client.query<UserSplitDay>(
          `INSERT INTO user_split_days
             (split_id, order_index, day_label, day_name, template_id, is_rest, exercises_json)
           VALUES ($1, $2, $3, $4, $5, $6, $7)
           RETURNING *`,
          [
            split.id,
            day.order_index,
            day.day_label,
            day.day_name,
            day.template_id ?? "",
            day.is_rest,
            day.exercises_json,
          ]
        );
        days.push(dayResult.rows[0]);
      }

      await client.query("COMMIT");
      return { conflict: false, split: { ...split, days } };
    } catch (err: any) {
      await client.query("ROLLBACK");
      if (err.code === "23505") {
        const existing = await this.pool.query<{ id: string }>(
          `SELECT id FROM user_splits WHERE user_id = $1 AND library_key = $2`,
          [userId, body.library_key ?? ""]
        );
        return { conflict: true, existingId: existing.rows[0]?.id ?? "" };
      }
      throw err;
    } finally {
      client.release();
    }
  }

  async getUserSplits(userId: string): Promise<UserSplit[]> {
    const splits = await this.pool.query<Omit<UserSplit, "days">>(
      `SELECT id, user_id, name, library_key, is_active, created_at::text
       FROM user_splits WHERE user_id = $1 ORDER BY created_at DESC`,
      [userId]
    );
    if (splits.rows.length === 0) return [];

    const days = await this.pool.query<UserSplitDay>(
      `SELECT * FROM user_split_days
       WHERE split_id = ANY($1) ORDER BY split_id, order_index`,
      [splits.rows.map((s) => s.id)]
    );

    return splits.rows.map((s) => ({
      ...s,
      days: days.rows.filter((d) => d.split_id === s.id),
    }));
  }

  async deleteSplit(userId: string, splitId: string): Promise<boolean> {
    const result = await this.pool.query(
      `DELETE FROM user_splits WHERE id = $1 AND user_id = $2`,
      [splitId, userId]
    );
    return (result.rowCount ?? 0) > 0;
  }

  async activateSplit(userId: string, splitId: string): Promise<UserSplit | null> {
    const client = await this.pool.connect();
    try {
      await client.query("BEGIN");
      await client.query(
        `UPDATE user_splits SET is_active = FALSE WHERE user_id = $1`,
        [userId]
      );
      const result = await client.query<Omit<UserSplit, "days">>(
        `UPDATE user_splits SET is_active = TRUE
         WHERE id = $1 AND user_id = $2
         RETURNING id, user_id, name, library_key, is_active, created_at::text`,
        [splitId, userId]
      );
      await client.query("COMMIT");

      if (!result.rows[0]) return null;
      const split = result.rows[0];

      const days = await this.pool.query<UserSplitDay>(
        `SELECT * FROM user_split_days WHERE split_id = $1 ORDER BY order_index`,
        [split.id]
      );
      return { ...split, days: days.rows };
    } catch (err) {
      await client.query("ROLLBACK");
      throw err;
    } finally {
      client.release();
    }
  }
}
