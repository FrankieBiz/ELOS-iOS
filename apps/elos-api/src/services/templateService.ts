import crypto from "crypto";
import { Pool } from "pg";
import type { WorkoutTemplate, TemplateExercise, CreateTemplateBody, SharedTemplate, SharedTemplateExercise } from "elos-shared";

export class TemplateService {
  constructor(private readonly db: Pool) {}

  async getTemplatesForUser(userId: string): Promise<WorkoutTemplate[]> {
    const templatesResult = await this.db.query<Omit<WorkoutTemplate, "exercises">>(
      `SELECT id, user_id, name, created_at::text
       FROM workout_templates
       WHERE user_id = $1
       ORDER BY created_at DESC`,
      [userId]
    );
    if (templatesResult.rows.length === 0) return [];

    const templateIds = templatesResult.rows.map((t) => t.id);
    const exResult = await this.db.query<TemplateExercise>(
      `SELECT id, template_id, exercise_id::text, exercise_name, order_index,
         target_sets, target_reps, target_rpe, rest_seconds, notes,
         equipment_id, equipment_dedupe_key, equipment_brand_name
       FROM template_exercises
       WHERE template_id = ANY($1)
       ORDER BY template_id, order_index`,
      [templateIds]
    );

    const byTemplate = new Map<string, TemplateExercise[]>();
    for (const ex of exResult.rows) {
      const list = byTemplate.get(ex.template_id) ?? [];
      list.push(ex);
      byTemplate.set(ex.template_id, list);
    }

    return templatesResult.rows.map((t) => ({
      ...t,
      exercises: byTemplate.get(t.id) ?? [],
    }));
  }

  async createTemplate(userId: string, body: CreateTemplateBody): Promise<WorkoutTemplate> {
    const client = await this.db.connect();
    try {
      await client.query("BEGIN");
      const tResult = await client.query<Omit<WorkoutTemplate, "exercises">>(
        `INSERT INTO workout_templates (user_id, name)
         VALUES ($1, $2)
         RETURNING id, user_id, name, created_at::text`,
        [userId, body.name]
      );
      const template = tResult.rows[0];
      const exercises: TemplateExercise[] = [];

      for (const ex of body.exercises ?? []) {
        const eResult = await client.query<TemplateExercise>(
          `INSERT INTO template_exercises
             (template_id, user_id, exercise_id, exercise_name, order_index,
              target_sets, target_reps, target_rpe, rest_seconds, notes,
              equipment_id, equipment_dedupe_key, equipment_brand_name)
           VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13)
           RETURNING id, template_id, exercise_id::text, exercise_name, order_index,
             target_sets, target_reps, target_rpe, rest_seconds, notes,
             equipment_id, equipment_dedupe_key, equipment_brand_name`,
          [
            template.id, userId, ex.exercise_id ?? null, ex.exercise_name, ex.order_index,
            ex.target_sets, ex.target_reps, ex.target_rpe ?? null, ex.rest_seconds, ex.notes ?? null,
            ex.equipment_id ?? null, ex.equipment_dedupe_key ?? null, ex.equipment_brand_name ?? null,
          ]
        );
        exercises.push(eResult.rows[0]);
      }

      await client.query("COMMIT");
      return { ...template, exercises };
    } catch (err) {
      await client.query("ROLLBACK");
      throw err;
    } finally {
      client.release();
    }
  }

  async updateTemplateName(
    templateId: string,
    userId: string,
    name: string
  ): Promise<WorkoutTemplate | null> {
    const result = await this.db.query<Omit<WorkoutTemplate, "exercises">>(
      `UPDATE workout_templates SET name = $1
       WHERE id = $2 AND user_id = $3
       RETURNING id, user_id, name, created_at::text`,
      [name, templateId, userId]
    );
    if (!result.rows[0]) return null;
    const exResult = await this.db.query<TemplateExercise>(
      `SELECT id, template_id, exercise_id::text, exercise_name, order_index,
         target_sets, target_reps, target_rpe, rest_seconds, notes,
         equipment_id, equipment_dedupe_key, equipment_brand_name
       FROM template_exercises WHERE template_id = $1 ORDER BY order_index`,
      [templateId]
    );
    return { ...result.rows[0], exercises: exResult.rows };
  }

  async deleteTemplate(templateId: string, userId: string): Promise<boolean> {
    const result = await this.db.query(
      `DELETE FROM workout_templates WHERE id = $1 AND user_id = $2`,
      [templateId, userId]
    );
    return (result.rowCount ?? 0) > 0;
  }

  async shareTemplate(templateId: string, userId: string): Promise<{ shareCode: string }> {
    const ownerCheck = await this.db.query(
      `SELECT id FROM workout_templates WHERE id = $1 AND user_id = $2`,
      [templateId, userId]
    );
    if (!ownerCheck.rows[0]) throw new Error("NOT_FOUND");

    const exResult = await this.db.query<SharedTemplateExercise>(
      `SELECT exercise_name, exercise_id::text, order_index,
              target_sets, target_reps, target_rpe, rest_seconds, notes,
              equipment_id, equipment_dedupe_key, equipment_brand_name
       FROM template_exercises WHERE template_id = $1 ORDER BY order_index`,
      [templateId]
    );
    const tmplResult = await this.db.query<{ name: string }>(
      `SELECT name FROM workout_templates WHERE id = $1`,
      [templateId]
    );
    if (!tmplResult.rows[0]) throw new Error("NOT_FOUND");
    const payload = {
      template_name: tmplResult.rows[0].name,
      exercises: exResult.rows,
    };

    const tryInsert = async (code: string): Promise<string> => {
      const result = await this.db.query<{ share_code: string }>(
        `WITH ins AS (
           INSERT INTO template_shares (template_id, owner_id, share_code, payload_json)
           VALUES ($1, $2, $3, $4)
           ON CONFLICT (template_id, owner_id)
             DO UPDATE SET payload_json = EXCLUDED.payload_json
           RETURNING share_code
         )
         SELECT share_code FROM ins
         UNION ALL
         SELECT share_code FROM template_shares WHERE template_id = $1 AND owner_id = $2
         LIMIT 1`,
        [templateId, userId, code, JSON.stringify(payload)]
      );
      return result.rows[0].share_code;
    };

    const code = crypto.randomBytes(8).toString("hex");
    try {
      return { shareCode: await tryInsert(code) };
    } catch {
      // Rare share_code unique collision — retry once with a new code
      const retry = crypto.randomBytes(8).toString("hex");
      return { shareCode: await tryInsert(retry) };
    }
  }

  async getSharedTemplate(shareCode: string): Promise<SharedTemplate | null> {
    const result = await this.db.query<{
      share_code: string;
      owner_name: string;
      payload_json: { template_name: string; exercises: SharedTemplateExercise[] };
    }>(
      // Names live on `profiles` (keyed by the Supabase auth user_id), not the abandoned
      // local `users` table — match the pattern used by feed/friend/leaderboard services.
      `SELECT ts.share_code,
              TRIM(COALESCE(p.first_name, '') || ' ' || COALESCE(p.last_name, '')) AS owner_name,
              ts.payload_json
       FROM template_shares ts
       LEFT JOIN profiles p ON p.user_id = ts.owner_id
       WHERE ts.share_code = $1`,
      [shareCode]
    );
    if (!result.rows[0]) return null;
    const row = result.rows[0];
    return {
      share_code: row.share_code,
      owner_name: row.owner_name,
      template_name: row.payload_json.template_name,
      exercises: row.payload_json.exercises,
    };
  }
}
