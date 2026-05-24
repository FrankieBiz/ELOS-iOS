import { Pool } from "pg";
import type { WorkoutTemplate, TemplateExercise, CreateTemplateBody } from "elos-shared";

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
         target_sets, target_reps, target_rpe, rest_seconds
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
              target_sets, target_reps, target_rpe, rest_seconds)
           VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
           RETURNING id, template_id, exercise_id::text, exercise_name, order_index,
             target_sets, target_reps, target_rpe, rest_seconds`,
          [
            template.id, userId, ex.exercise_id ?? null, ex.exercise_name, ex.order_index,
            ex.target_sets, ex.target_reps, ex.target_rpe ?? null, ex.rest_seconds,
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
         target_sets, target_reps, target_rpe, rest_seconds
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
}
