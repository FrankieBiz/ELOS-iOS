import { Pool } from "pg";

export class LibraryService {
  constructor(private readonly db: Pool) {}

  async getCreators(filters: { category?: string; difficulty?: string; goal?: string } = {}) {
    const conditions: string[] = [];
    const params: unknown[] = [];

    if (filters.category) {
      params.push(filters.category);
      conditions.push(`c.category = $${params.length}`);
    }
    if (filters.difficulty) {
      params.push(filters.difficulty);
      conditions.push(`c.difficulty = $${params.length}`);
    }
    if (filters.goal) {
      params.push(filters.goal);
      conditions.push(`$${params.length} = ANY(c.goals)`);
    }

    const where = conditions.length ? `WHERE ${conditions.join(" AND ")}` : "";
    const { rows } = await this.db.query(
      `SELECT c.id, c.name, c.slug, c.bio, c.category, c.training_style,
              c.goals, c.split_types, c.difficulty, c.image_url, c.is_verified,
              c.source_urls,
              COUNT(cw.id)::int AS workout_count
       FROM creators c
       LEFT JOIN creator_workouts cw ON cw.creator_id = c.id AND cw.is_public = true
       ${where}
       GROUP BY c.id
       ORDER BY c.name`,
      params
    );
    return rows;
  }

  async getCreator(slug: string) {
    const { rows: creators } = await this.db.query(
      `SELECT id, name, slug, bio, category, training_style,
              goals, split_types, difficulty, image_url, is_verified, source_urls
       FROM creators WHERE slug = $1`,
      [slug]
    );
    if (!creators.length) return null;
    const creator = creators[0];

    const { rows: workouts } = await this.db.query(
      `SELECT id, title, description, program_type, days_per_week, goal,
              difficulty, duration_weeks, est_session_mins, equipment,
              muscle_groups, tags, attribution, disclaimer, confidence_level
       FROM creator_workouts
       WHERE creator_id = $1 AND is_public = true
       ORDER BY created_at`,
      [creator.id]
    );
    return { ...creator, workouts };
  }

  async getWorkouts(filters: { goal?: string; split?: string; days?: number } = {}) {
    const conditions: string[] = ["cw.is_public = true"];
    const params: unknown[] = [];

    if (filters.goal) {
      params.push(filters.goal);
      conditions.push(`cw.goal = $${params.length}`);
    }
    if (filters.split) {
      params.push(filters.split);
      conditions.push(`cw.program_type = $${params.length}`);
    }
    if (filters.days) {
      params.push(filters.days);
      conditions.push(`cw.days_per_week = $${params.length}`);
    }

    const { rows } = await this.db.query(
      `SELECT cw.id, cw.title, cw.description, cw.program_type, cw.days_per_week,
              cw.goal, cw.difficulty, cw.duration_weeks, cw.est_session_mins,
              cw.equipment, cw.muscle_groups, cw.tags, cw.disclaimer, cw.confidence_level,
              c.id AS creator_id, c.name AS creator_name, c.slug AS creator_slug
       FROM creator_workouts cw
       JOIN creators c ON c.id = cw.creator_id
       WHERE ${conditions.join(" AND ")}
       ORDER BY c.name, cw.created_at`,
      params
    );
    return rows;
  }

  async getWorkoutDetail(workoutId: string) {
    const { rows: workouts } = await this.db.query(
      `SELECT cw.id, cw.title, cw.description, cw.program_type, cw.days_per_week,
              cw.goal, cw.difficulty, cw.duration_weeks, cw.est_session_mins,
              cw.equipment, cw.muscle_groups, cw.tags, cw.source_url,
              cw.attribution, cw.disclaimer, cw.confidence_level,
              c.id AS creator_id, c.name AS creator_name, c.slug AS creator_slug
       FROM creator_workouts cw
       JOIN creators c ON c.id = cw.creator_id
       WHERE cw.id = $1 AND cw.is_public = true`,
      [workoutId]
    );
    if (!workouts.length) return null;
    const workout = workouts[0];

    const { rows: days } = await this.db.query(
      `SELECT id, day_number, name, focus, notes, order_index
       FROM workout_days
       WHERE workout_id = $1
       ORDER BY order_index`,
      [workoutId]
    );

    const dayIds = days.map((d) => d.id);
    let exercises: Record<string, unknown>[] = [];
    if (dayIds.length) {
      const { rows } = await this.db.query(
        `SELECT workout_day_id, exercise_name, order_index, sets, reps,
                rest_seconds, tempo, rpe_guidance, notes, substitution_notes,
                is_superset, superset_group
         FROM workout_day_exercises
         WHERE workout_day_id = ANY($1)
         ORDER BY order_index`,
        [dayIds]
      );
      exercises = rows;
    }

    const daysWithExercises = days.map((day) => ({
      ...day,
      exercises: exercises.filter((e) => e.workout_day_id === day.id),
    }));

    return { ...workout, days: daysWithExercises };
  }

  async searchLibrary(query: string, type?: string) {
    const tsquery = query
      .trim()
      .split(/\s+/)
      .filter(Boolean)
      .map((w) => w + ":*")
      .join(" & ");

    const results: Record<string, unknown[]> = {};

    if (!type || type === "creators") {
      const { rows } = await this.db.query(
        `SELECT id, name, slug, category, difficulty, image_url, 'creator' AS type
         FROM creators
         WHERE search_vector @@ to_tsquery('english', $1)
         LIMIT 10`,
        [tsquery]
      );
      results.creators = rows;
    }

    if (!type || type === "workouts") {
      const { rows } = await this.db.query(
        `SELECT cw.id, cw.title, cw.program_type, cw.goal, cw.difficulty,
                c.name AS creator_name, c.slug AS creator_slug, 'workout' AS type
         FROM creator_workouts cw
         JOIN creators c ON c.id = cw.creator_id
         WHERE cw.search_vector @@ to_tsquery('english', $1) AND cw.is_public = true
         LIMIT 10`,
        [tsquery]
      );
      results.workouts = rows;
    }

    if (!type || type === "machines") {
      const { rows } = await this.db.query(
        `SELECT id, name, slug, category, equipment_type, primary_muscles, 'machine' AS type
         FROM machines
         WHERE search_vector @@ to_tsquery('english', $1)
         LIMIT 10`,
        [tsquery]
      );
      results.machines = rows;
    }

    return results;
  }

  async saveWorkout(userId: string, workoutId: string) {
    await this.db.query(
      `INSERT INTO saved_library_workouts (user_id, creator_workout_id)
       VALUES ($1, $2)
       ON CONFLICT (user_id, creator_workout_id) DO NOTHING`,
      [userId, workoutId]
    );
  }

  async unsaveWorkout(userId: string, workoutId: string) {
    await this.db.query(
      `DELETE FROM saved_library_workouts
       WHERE user_id = $1 AND creator_workout_id = $2`,
      [userId, workoutId]
    );
  }

  async getSavedWorkouts(userId: string) {
    const { rows } = await this.db.query(
      `SELECT cw.id, cw.title, cw.program_type, cw.goal, cw.difficulty,
              cw.days_per_week, cw.est_session_mins, cw.muscle_groups,
              c.name AS creator_name, c.slug AS creator_slug,
              slw.saved_at
       FROM saved_library_workouts slw
       JOIN creator_workouts cw ON cw.id = slw.creator_workout_id
       JOIN creators c ON c.id = cw.creator_id
       WHERE slw.user_id = $1
       ORDER BY slw.saved_at DESC`,
      [userId]
    );
    return rows;
  }
}
