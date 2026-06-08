import { Pool } from "pg";
import type { FriendProfile, UserSearchResult } from "elos-shared";
import { getWeekStart } from "./leaderboardService";

export class FriendService {
  constructor(private readonly db: Pool) {}

  async reportUser(
    reporterId: string,
    reportedId: string,
    category: string,
    note?: string
  ): Promise<void> {
    await this.db.query(
      `INSERT INTO user_reports (reporter_id, reported_id, category, note)
       VALUES ($1, $2, $3, $4)`,
      [reporterId, reportedId, category, note ?? null]
    );
  }

  /** Block a user: record the block and sever any friendship in either direction. */
  async blockUser(blockerId: string, blockedId: string): Promise<void> {
    const client = await this.db.connect();
    try {
      await client.query("BEGIN");
      await client.query(
        `INSERT INTO user_blocks (blocker_id, blocked_id)
         VALUES ($1, $2) ON CONFLICT (blocker_id, blocked_id) DO NOTHING`,
        [blockerId, blockedId]
      );
      await client.query(
        `DELETE FROM friendships
         WHERE (requester_id = $1 AND addressee_id = $2)
            OR (requester_id = $2 AND addressee_id = $1)`,
        [blockerId, blockedId]
      );
      await client.query("COMMIT");
    } catch (err) {
      await client.query("ROLLBACK");
      throw err;
    } finally {
      client.release();
    }
  }

  async unblockUser(blockerId: string, blockedId: string): Promise<void> {
    await this.db.query(
      `DELETE FROM user_blocks WHERE blocker_id = $1 AND blocked_id = $2`,
      [blockerId, blockedId]
    );
  }

  async getFriends(userId: string): Promise<FriendProfile[]> {
    const result = await this.db.query<FriendProfile>(
      `SELECT
         f.id               AS friendship_id,
         p.user_id,
         COALESCE(p.username, '')        AS username,
         COALESCE(p.first_name, '')      AS first_name,
         COALESCE(p.last_name, '')       AS last_name,
         COALESCE(p.avatar_color, '#6C47FF') AS avatar_color,
         f.status,
         (f.requester_id = $1) AS is_requester
       FROM friendships f
       JOIN profiles p ON p.user_id = CASE
         WHEN f.requester_id = $1 THEN f.addressee_id
         ELSE f.requester_id
       END
       WHERE (f.requester_id = $1 OR f.addressee_id = $1)
         AND f.status = 'accepted'
       ORDER BY p.first_name, p.last_name`,
      [userId]
    );
    return result.rows;
  }

  async getPendingRequests(userId: string): Promise<FriendProfile[]> {
    const result = await this.db.query<FriendProfile>(
      `SELECT
         f.id               AS friendship_id,
         p.user_id,
         COALESCE(p.username, '')        AS username,
         COALESCE(p.first_name, '')      AS first_name,
         COALESCE(p.last_name, '')       AS last_name,
         COALESCE(p.avatar_color, '#6C47FF') AS avatar_color,
         f.status,
         false              AS is_requester
       FROM friendships f
       JOIN profiles p ON p.user_id = f.requester_id
       WHERE f.addressee_id = $1 AND f.status = 'pending'
       ORDER BY f.created_at DESC`,
      [userId]
    );
    return result.rows;
  }

  async getSentRequests(userId: string): Promise<FriendProfile[]> {
    const result = await this.db.query<FriendProfile>(
      `SELECT
         f.id               AS friendship_id,
         p.user_id,
         COALESCE(p.username, '')        AS username,
         COALESCE(p.first_name, '')      AS first_name,
         COALESCE(p.last_name, '')       AS last_name,
         COALESCE(p.avatar_color, '#6C47FF') AS avatar_color,
         f.status,
         true               AS is_requester
       FROM friendships f
       JOIN profiles p ON p.user_id = f.addressee_id
       WHERE f.requester_id = $1 AND f.status = 'pending'
       ORDER BY f.created_at DESC`,
      [userId]
    );
    return result.rows;
  }

  async sendRequest(requesterId: string, addresseeId: string): Promise<void> {
    // No-op if either party has blocked the other.
    await this.db.query(
      `INSERT INTO friendships (requester_id, addressee_id, status)
       SELECT $1, $2, 'pending'
       WHERE NOT EXISTS (
         SELECT 1 FROM user_blocks
         WHERE (blocker_id = $1 AND blocked_id = $2)
            OR (blocker_id = $2 AND blocked_id = $1)
       )
       ON CONFLICT (requester_id, addressee_id) DO NOTHING`,
      [requesterId, addresseeId]
    );
  }

  async acceptRequest(userId: string, friendshipId: string): Promise<void> {
    await this.db.query(
      `UPDATE friendships
       SET status = 'accepted', updated_at = now()
       WHERE id = $1 AND addressee_id = $2 AND status = 'pending'`,
      [friendshipId, userId]
    );
  }

  async declineRequest(userId: string, friendshipId: string): Promise<void> {
    await this.db.query(
      `DELETE FROM friendships
       WHERE id = $1 AND addressee_id = $2 AND status = 'pending'`,
      [friendshipId, userId]
    );
  }

  async removeFriend(userId: string, friendshipId: string): Promise<void> {
    await this.db.query(
      `DELETE FROM friendships
       WHERE id = $1 AND (requester_id = $2 OR addressee_id = $2)`,
      [friendshipId, userId]
    );
  }

  async searchUsers(query: string, currentUserId: string): Promise<UserSearchResult[]> {
    const result = await this.db.query<UserSearchResult>(
      `SELECT
         p.user_id,
         COALESCE(p.username, '')        AS username,
         COALESCE(p.first_name, '')      AS first_name,
         COALESCE(p.last_name, '')       AS last_name,
         COALESCE(p.avatar_color, '#6C47FF') AS avatar_color,
         CASE
           WHEN f.id IS NULL THEN 'none'
           WHEN f.status = 'accepted' THEN 'accepted'
           WHEN f.requester_id = $2 AND f.status = 'pending' THEN 'pending_sent'
           WHEN f.addressee_id = $2 AND f.status = 'pending' THEN 'pending_received'
           ELSE 'none'
         END AS friendship_status
       FROM profiles p
       LEFT JOIN friendships f
         ON (f.requester_id = $2 AND f.addressee_id = p.user_id)
         OR (f.addressee_id = $2 AND f.requester_id = p.user_id)
       WHERE p.user_id != $2
         AND p.search_vector @@ plainto_tsquery('english', $1)
         AND p.user_id NOT IN (
           SELECT blocked_id FROM user_blocks WHERE blocker_id = $2
           UNION
           SELECT blocker_id FROM user_blocks WHERE blocked_id = $2
         )
       ORDER BY p.first_name, p.last_name
       LIMIT 30`,
      [query, currentUserId]
    );
    return result.rows;
  }

  async getFriendStats(viewerUserId: string, friendUserId: string) {
    const isFriend = await this.db.query(
      `SELECT 1 FROM friendships
       WHERE ((requester_id = $1 AND addressee_id = $2)
           OR (addressee_id = $1 AND requester_id = $2))
         AND status = 'accepted'`,
      [viewerUserId, friendUserId]
    );
    if (!isFriend.rows.length) return null;

    const weekStart = getWeekStart();
    const weekEnd = new Date(weekStart.getTime() + 7 * 24 * 60 * 60 * 1000);

    const [profile, weeklyVolume, sessionCount, streak, topPRs] = await Promise.all([
      this.db.query(
        `SELECT first_name, last_name, username, avatar_color FROM profiles WHERE user_id = $1`,
        [friendUserId]
      ),
      this.db.query<{ volume: number }>(
        `SELECT COALESCE(SUM(weight_kg * reps), 0)::float AS volume
         FROM exercise_sets
         WHERE user_id = $1 AND completed_at >= $2 AND completed_at < $3
           AND weight_kg > 0 AND reps > 0`,
        [friendUserId, weekStart, weekEnd]
      ),
      this.db.query<{ count: number }>(
        `SELECT COUNT(DISTINCT id)::int AS count
         FROM workout_sessions
         WHERE user_id = $1 AND finished_at >= $2 AND finished_at < $3`,
        [friendUserId, weekStart, weekEnd]
      ),
      this.db.query<{ streak: number }>(
        `WITH daily AS (
           SELECT DISTINCT DATE(finished_at) AS d
           FROM workout_sessions
           WHERE user_id = $1 AND finished_at IS NOT NULL
         ),
         numbered AS (
           SELECT d, ROW_NUMBER() OVER (ORDER BY d) AS rn FROM daily
         ),
         grouped AS (
           SELECT d, (d - (rn || ' days')::interval)::date AS grp FROM numbered
         ),
         streaks AS (
           SELECT MAX(d) AS last_day, COUNT(*)::int AS len FROM grouped GROUP BY grp
         )
         SELECT COALESCE(MAX(len) FILTER (WHERE last_day >= CURRENT_DATE - 1), 0) AS streak
         FROM streaks`,
        [friendUserId]
      ),
      this.db.query(
        `WITH best AS (
           SELECT exercise_name,
                  MAX(weight_kg * (1 + reps::float / 30)) AS e1rm,
                  MAX(weight_kg) AS best_weight,
                  MAX(reps) AS best_reps
           FROM exercise_sets
           WHERE user_id = $1 AND reps BETWEEN 1 AND 30 AND weight_kg > 0
           GROUP BY exercise_name
         )
         SELECT exercise_name, e1rm::float, best_weight::float, best_reps
         FROM best ORDER BY e1rm DESC LIMIT 5`,
        [friendUserId]
      ),
    ]);

    const p = profile.rows[0];
    return {
      user_id: friendUserId,
      first_name: p?.first_name ?? "",
      last_name: p?.last_name ?? "",
      username: p?.username ?? null,
      avatar_color: p?.avatar_color ?? "#6C47FF",
      weekly_volume: weeklyVolume.rows[0]?.volume ?? 0,
      weekly_sessions: sessionCount.rows[0]?.count ?? 0,
      current_streak: streak.rows[0]?.streak ?? 0,
      top_prs: topPRs.rows,
    };
  }
}
