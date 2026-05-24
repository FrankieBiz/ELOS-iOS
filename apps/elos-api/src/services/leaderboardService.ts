import { Pool } from "pg";
import type { LeaderboardEntry, WeeklyLeaderboard, MyStandings } from "elos-shared";

type Metric = "volume" | "sessions" | "streak" | "prs";

export class LeaderboardService {
  constructor(private readonly db: Pool) {}

  async getWeeklyBoard(
    userId: string,
    metric: Metric,
    weekStart: Date,
    weekEnd: Date
  ): Promise<WeeklyLeaderboard> {
    const peersQuery = `
      WITH peers AS (
        SELECT CASE WHEN requester_id = $1 THEN addressee_id ELSE requester_id END AS user_id
        FROM friendships
        WHERE (requester_id = $1 OR addressee_id = $1) AND status = 'accepted'
        UNION ALL SELECT $1::uuid
      )
    `;

    let valueQuery: string;

    if (metric === "volume") {
      valueQuery = `
        ${peersQuery},
        vals AS (
          SELECT es.user_id, COALESCE(SUM(es.weight_kg * es.reps), 0)::float AS value
          FROM exercise_sets es
          WHERE es.user_id IN (SELECT user_id FROM peers)
            AND es.completed_at >= $2 AND es.completed_at < $3
            AND es.weight_kg > 0 AND es.reps > 0
          GROUP BY es.user_id
        )
      `;
    } else if (metric === "sessions") {
      valueQuery = `
        ${peersQuery},
        vals AS (
          SELECT ws.user_id, COUNT(DISTINCT ws.id)::float AS value
          FROM workout_sessions ws
          WHERE ws.user_id IN (SELECT user_id FROM peers)
            AND ws.finished_at >= $2 AND ws.finished_at < $3
          GROUP BY ws.user_id
        )
      `;
    } else if (metric === "streak") {
      valueQuery = `
        ${peersQuery},
        daily AS (
          SELECT DISTINCT user_id, DATE(finished_at) AS d
          FROM workout_sessions
          WHERE user_id IN (SELECT user_id FROM peers)
            AND finished_at IS NOT NULL
        ),
        numbered AS (
          SELECT user_id, d, ROW_NUMBER() OVER (PARTITION BY user_id ORDER BY d) AS rn FROM daily
        ),
        grouped AS (
          SELECT user_id, d, (d - (rn || ' days')::interval)::date AS grp FROM numbered
        ),
        streaks AS (
          SELECT user_id, MAX(d) AS last_day, COUNT(*)::int AS len
          FROM grouped GROUP BY user_id, grp
        ),
        vals AS (
          SELECT user_id, COALESCE(MAX(len) FILTER (WHERE last_day >= CURRENT_DATE - 1), 0)::float AS value
          FROM streaks GROUP BY user_id
        )
      `;
    } else {
      // prs
      valueQuery = `
        ${peersQuery},
        this_week AS (
          SELECT user_id, exercise_name,
                 MAX(weight_kg * (1 + reps::float / 30)) AS best_e1rm
          FROM exercise_sets
          WHERE user_id IN (SELECT user_id FROM peers)
            AND completed_at >= $2 AND completed_at < $3
            AND reps BETWEEN 1 AND 30 AND weight_kg > 0
          GROUP BY user_id, exercise_name
        ),
        prior AS (
          SELECT user_id, exercise_name,
                 MAX(weight_kg * (1 + reps::float / 30)) AS best_e1rm
          FROM exercise_sets
          WHERE user_id IN (SELECT user_id FROM peers)
            AND completed_at < $2
            AND reps BETWEEN 1 AND 30 AND weight_kg > 0
          GROUP BY user_id, exercise_name
        ),
        vals AS (
          SELECT tw.user_id,
                 COUNT(DISTINCT tw.exercise_name)::float AS value
          FROM this_week tw
          LEFT JOIN prior p ON p.user_id = tw.user_id AND p.exercise_name = tw.exercise_name
          WHERE tw.best_e1rm > COALESCE(p.best_e1rm, 0)
          GROUP BY tw.user_id
        )
      `;
    }

    const includeStreakParams = metric === "streak";
    const params = includeStreakParams
      ? [userId]
      : [userId, weekStart, weekEnd];

    const finalQuery = `
      ${valueQuery},
      ranked AS (
        SELECT
          p.user_id,
          COALESCE(p.username, '') AS username,
          COALESCE(p.first_name, '') AS first_name,
          COALESCE(p.last_name, '') AS last_name,
          COALESCE(p.avatar_color, '#6C47FF') AS avatar_color,
          COALESCE(v.value, 0) AS value,
          (p.user_id = $1) AS is_self,
          ROW_NUMBER() OVER (ORDER BY COALESCE(v.value, 0) DESC) AS rank
        FROM peers pr
        JOIN profiles p ON p.user_id = pr.user_id
        LEFT JOIN vals v ON v.user_id = pr.user_id
        WHERE p.leaderboard_visible = true OR p.user_id = $1
      )
      SELECT * FROM ranked ORDER BY rank
    `;

    const result = await this.db.query<LeaderboardEntry & { is_self: boolean }>(
      finalQuery,
      params
    );

    const myRow = result.rows.find((r) => r.is_self);

    return {
      metric,
      week_start: weekStart.toISOString().split("T")[0],
      entries: result.rows,
      my_rank: myRow?.rank ?? result.rows.length + 1,
      my_value: myRow?.value ?? 0,
    };
  }

  async getExerciseBoard(userId: string, exerciseName: string): Promise<LeaderboardEntry[]> {
    const result = await this.db.query<LeaderboardEntry>(
      `WITH peers AS (
         SELECT CASE WHEN requester_id = $1 THEN addressee_id ELSE requester_id END AS user_id
         FROM friendships
         WHERE (requester_id = $1 OR addressee_id = $1) AND status = 'accepted'
         UNION ALL SELECT $1::uuid
       ),
       best AS (
         SELECT user_id,
                MAX(weight_kg * (1 + reps::float / 30))::float AS value
         FROM exercise_sets
         WHERE user_id IN (SELECT user_id FROM peers)
           AND lower(exercise_name) = lower($2)
           AND reps BETWEEN 1 AND 30 AND weight_kg > 0
         GROUP BY user_id
       )
       SELECT
         ROW_NUMBER() OVER (ORDER BY COALESCE(b.value, 0) DESC)::int AS rank,
         p.user_id,
         COALESCE(p.username, '') AS username,
         COALESCE(p.first_name, '') AS first_name,
         COALESCE(p.last_name, '') AS last_name,
         COALESCE(p.avatar_color, '#6C47FF') AS avatar_color,
         COALESCE(b.value, 0) AS value,
         (p.user_id = $1) AS is_self
       FROM peers pr
       JOIN profiles p ON p.user_id = pr.user_id
       LEFT JOIN best b ON b.user_id = pr.user_id
       WHERE p.leaderboard_visible = true OR p.user_id = $1
       ORDER BY rank`,
      [userId, exerciseName]
    );
    return result.rows;
  }

  async getMyStandings(
    userId: string,
    weekStart: Date,
    weekEnd: Date
  ): Promise<MyStandings> {
    const result = await this.db.query<{
      total_friends: number;
      volume_rank: number; volume_value: number;
      sessions_rank: number; sessions_value: number;
      streak_rank: number; streak_value: number;
      prs_rank: number; prs_value: number;
    }>(
      `WITH peers AS (
         SELECT CASE WHEN requester_id = $1 THEN addressee_id ELSE requester_id END AS user_id
         FROM friendships
         WHERE (requester_id = $1 OR addressee_id = $1) AND status = 'accepted'
         UNION ALL SELECT $1::uuid
       ),
       peer_profiles AS (
         SELECT pr.user_id FROM peers pr
         JOIN profiles p ON p.user_id = pr.user_id
         WHERE p.leaderboard_visible = true OR pr.user_id = $1
       ),
       volume_vals AS (
         SELECT user_id, COALESCE(SUM(weight_kg * reps), 0)::float AS value
         FROM exercise_sets
         WHERE user_id IN (SELECT user_id FROM peer_profiles)
           AND completed_at >= $2 AND completed_at < $3
           AND weight_kg > 0 AND reps > 0
         GROUP BY user_id
       ),
       session_vals AS (
         SELECT user_id, COUNT(DISTINCT id)::float AS value
         FROM workout_sessions
         WHERE user_id IN (SELECT user_id FROM peer_profiles)
           AND finished_at >= $2 AND finished_at < $3
         GROUP BY user_id
       ),
       daily AS (
         SELECT DISTINCT user_id, DATE(finished_at) AS d
         FROM workout_sessions
         WHERE user_id IN (SELECT user_id FROM peer_profiles) AND finished_at IS NOT NULL
       ),
       numbered AS (
         SELECT user_id, d, ROW_NUMBER() OVER (PARTITION BY user_id ORDER BY d) AS rn FROM daily
       ),
       grouped_streak AS (
         SELECT user_id, d, (d - (rn || ' days')::interval)::date AS grp FROM numbered
       ),
       streak_runs AS (
         SELECT user_id, MAX(d) AS last_day, COUNT(*)::int AS len
         FROM grouped_streak GROUP BY user_id, grp
       ),
       streak_vals AS (
         SELECT user_id, COALESCE(MAX(len) FILTER (WHERE last_day >= CURRENT_DATE - 1), 0)::float AS value
         FROM streak_runs GROUP BY user_id
       ),
       this_week_sets AS (
         SELECT user_id, exercise_name,
                MAX(weight_kg * (1 + reps::float / 30)) AS best_e1rm
         FROM exercise_sets
         WHERE user_id IN (SELECT user_id FROM peer_profiles)
           AND completed_at >= $2 AND completed_at < $3
           AND reps BETWEEN 1 AND 30 AND weight_kg > 0
         GROUP BY user_id, exercise_name
       ),
       prior_sets AS (
         SELECT user_id, exercise_name,
                MAX(weight_kg * (1 + reps::float / 30)) AS best_e1rm
         FROM exercise_sets
         WHERE user_id IN (SELECT user_id FROM peer_profiles)
           AND completed_at < $2
           AND reps BETWEEN 1 AND 30 AND weight_kg > 0
         GROUP BY user_id, exercise_name
       ),
       prs_vals AS (
         SELECT tw.user_id, COUNT(DISTINCT tw.exercise_name)::float AS value
         FROM this_week_sets tw
         LEFT JOIN prior_sets p ON p.user_id = tw.user_id AND p.exercise_name = tw.exercise_name
         WHERE tw.best_e1rm > COALESCE(p.best_e1rm, 0)
         GROUP BY tw.user_id
       ),
       all_users AS (SELECT user_id FROM peer_profiles),
       volume_ranked AS (
         SELECT u.user_id,
                ROW_NUMBER() OVER (ORDER BY COALESCE(v.value, 0) DESC)::int AS rank,
                COALESCE(v.value, 0) AS value
         FROM all_users u LEFT JOIN volume_vals v ON v.user_id = u.user_id
       ),
       session_ranked AS (
         SELECT u.user_id,
                ROW_NUMBER() OVER (ORDER BY COALESCE(v.value, 0) DESC)::int AS rank,
                COALESCE(v.value, 0) AS value
         FROM all_users u LEFT JOIN session_vals v ON v.user_id = u.user_id
       ),
       streak_ranked AS (
         SELECT u.user_id,
                ROW_NUMBER() OVER (ORDER BY COALESCE(v.value, 0) DESC)::int AS rank,
                COALESCE(v.value, 0) AS value
         FROM all_users u LEFT JOIN streak_vals v ON v.user_id = u.user_id
       ),
       prs_ranked AS (
         SELECT u.user_id,
                ROW_NUMBER() OVER (ORDER BY COALESCE(v.value, 0) DESC)::int AS rank,
                COALESCE(v.value, 0) AS value
         FROM all_users u LEFT JOIN prs_vals v ON v.user_id = u.user_id
       )
       SELECT
         (SELECT COUNT(*)::int FROM peers WHERE user_id != $1) AS total_friends,
         vr.rank  AS volume_rank,   vr.value  AS volume_value,
         sr.rank  AS sessions_rank, sr.value  AS sessions_value,
         str.rank AS streak_rank,   str.value AS streak_value,
         pr.rank  AS prs_rank,      pr.value  AS prs_value
       FROM volume_ranked  vr
       JOIN session_ranked sr  ON sr.user_id  = vr.user_id
       JOIN streak_ranked  str ON str.user_id = vr.user_id
       JOIN prs_ranked     pr  ON pr.user_id  = vr.user_id
       WHERE vr.user_id = $1`,
      [userId, weekStart, weekEnd]
    );

    const row = result.rows[0];
    return {
      week_start: weekStart.toISOString().split("T")[0],
      total_friends: row?.total_friends ?? 0,
      volume:   { rank: row?.volume_rank ?? 1,   value: row?.volume_value ?? 0 },
      sessions: { rank: row?.sessions_rank ?? 1, value: row?.sessions_value ?? 0 },
      streak:   { rank: row?.streak_rank ?? 1,   value: row?.streak_value ?? 0 },
      prs:      { rank: row?.prs_rank ?? 1,      value: row?.prs_value ?? 0 },
    };
  }
}

export function getWeekStart(): Date {
  const now = new Date();
  const day = now.getUTCDay();
  const diff = day === 0 ? -6 : 1 - day;
  const monday = new Date(now);
  monday.setUTCDate(now.getUTCDate() + diff);
  monday.setUTCHours(0, 0, 0, 0);
  return monday;
}
