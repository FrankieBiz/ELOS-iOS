import { Pool } from "pg";
import type {
  FeedPage,
  FeedPost,
  FeedPostKind,
  FeedPayload,
  FeedReactionSummary,
  SplitPayload,
  UserSplit,
} from "elos-shared";
import { FEED_REACTION_EMOJIS } from "elos-shared";
import { SplitService } from "./splitService";

const PAGE_SIZE = 20;
const ALLOWED_EMOJIS = new Set<string>(FEED_REACTION_EMOJIS);

type PostRow = {
  id: string;
  author_id: string;
  kind: FeedPostKind;
  payload_json: string;
  created_at: string;
  username: string | null;
  first_name: string | null;
  last_name: string | null;
  avatar_color: string | null;
};

export class FeedService {
  private readonly splitService: SplitService;

  constructor(private readonly pool: Pool) {
    this.splitService = new SplitService(pool);
  }

  isValidEmoji(emoji: string): boolean {
    return ALLOWED_EMOJIS.has(emoji);
  }

  /** Create a client-supplied workout/pr post. Returns the assembled FeedPost. */
  async createPost(userId: string, kind: "workout" | "pr", payload: FeedPayload): Promise<FeedPost> {
    const result = await this.pool.query<{ id: string }>(
      `INSERT INTO feed_posts (author_id, kind, payload_json)
       VALUES ($1, $2, $3)
       RETURNING id`,
      [userId, kind, JSON.stringify(payload)]
    );
    return (await this.getPost(userId, result.rows[0].id))!;
  }

  /** Share a split the caller owns: snapshot it server-side into a feed post. */
  async shareSplit(userId: string, splitId: string): Promise<FeedPost | null> {
    const splitRes = await this.pool.query<{ name: string }>(
      `SELECT name FROM user_splits WHERE id = $1 AND user_id = $2`,
      [splitId, userId]
    );
    const split = splitRes.rows[0];
    if (!split) return null;

    const daysRes = await this.pool.query(
      `SELECT order_index, day_label, day_name, template_id, is_rest, exercises_json
       FROM user_split_days WHERE split_id = $1 ORDER BY order_index`,
      [splitId]
    );

    const payload: SplitPayload = {
      name: split.name,
      days: daysRes.rows,
    };

    const result = await this.pool.query<{ id: string }>(
      `INSERT INTO feed_posts (author_id, kind, payload_json)
       VALUES ($1, 'split', $2)
       RETURNING id`,
      [userId, JSON.stringify(payload)]
    );
    return this.getPost(userId, result.rows[0].id);
  }

  /** Friends' + own posts, newest first, keyset-paginated on created_at. */
  async getFeed(userId: string, cursor?: string): Promise<FeedPage> {
    const params: unknown[] = [userId];
    let cursorClause = "";
    if (cursor) {
      params.push(cursor);
      cursorClause = `AND fp.created_at < $${params.length}`;
    }
    params.push(PAGE_SIZE + 1);

    const rows = await this.pool.query<PostRow>(
      `SELECT fp.id, fp.author_id, fp.kind, fp.payload_json, fp.created_at::text,
              p.username, p.first_name, p.last_name, p.avatar_color
       FROM feed_posts fp
       LEFT JOIN profiles p ON p.user_id = fp.author_id
       WHERE (
               fp.author_id = $1
               OR fp.author_id IN (
                 SELECT CASE WHEN requester_id = $1 THEN addressee_id ELSE requester_id END
                 FROM friendships
                 WHERE (requester_id = $1 OR addressee_id = $1) AND status = 'accepted'
               )
             )
             AND fp.author_id NOT IN (
               SELECT blocked_id FROM user_blocks WHERE blocker_id = $1
               UNION
               SELECT blocker_id FROM user_blocks WHERE blocked_id = $1
             )
             ${cursorClause}
       ORDER BY fp.created_at DESC
       LIMIT $${params.length}`,
      params
    );

    const hasMore = rows.rows.length > PAGE_SIZE;
    const pageRows = hasMore ? rows.rows.slice(0, PAGE_SIZE) : rows.rows;
    const posts = await this.assemblePosts(userId, pageRows);

    return {
      posts,
      next_cursor: hasMore ? pageRows[pageRows.length - 1].created_at : null,
    };
  }

  private async getPost(userId: string, postId: string): Promise<FeedPost | null> {
    const rows = await this.pool.query<PostRow>(
      `SELECT fp.id, fp.author_id, fp.kind, fp.payload_json, fp.created_at::text,
              p.username, p.first_name, p.last_name, p.avatar_color
       FROM feed_posts fp
       LEFT JOIN profiles p ON p.user_id = fp.author_id
       WHERE fp.id = $1`,
      [postId]
    );
    if (!rows.rows[0]) return null;
    const assembled = await this.assemblePosts(userId, rows.rows);
    return assembled[0] ?? null;
  }

  private async assemblePosts(userId: string, rows: PostRow[]): Promise<FeedPost[]> {
    if (rows.length === 0) return [];
    const ids = rows.map((r) => r.id);

    const reactions = await this.pool.query<{ post_id: string; emoji: string; count: string }>(
      `SELECT post_id, emoji, COUNT(*)::text AS count
       FROM post_reactions
       WHERE post_id = ANY($1)
       GROUP BY post_id, emoji`,
      [ids]
    );
    const mine = await this.pool.query<{ post_id: string; emoji: string }>(
      `SELECT post_id, emoji FROM post_reactions WHERE post_id = ANY($1) AND user_id = $2`,
      [ids, userId]
    );

    const byPost = new Map<string, FeedReactionSummary[]>();
    for (const r of reactions.rows) {
      const list = byPost.get(r.post_id) ?? [];
      list.push({ emoji: r.emoji, count: Number(r.count) });
      byPost.set(r.post_id, list);
    }
    const myByPost = new Map<string, string>();
    for (const m of mine.rows) myByPost.set(m.post_id, m.emoji);

    return rows.map((row) => ({
      id: row.id,
      kind: row.kind,
      created_at: row.created_at,
      author: {
        user_id: row.author_id,
        username: row.username ?? "",
        first_name: row.first_name ?? "",
        last_name: row.last_name ?? "",
        avatar_color: row.avatar_color ?? "#6C47FF",
      },
      is_mine: row.author_id === userId,
      payload: JSON.parse(row.payload_json) as FeedPayload,
      reactions: byPost.get(row.id) ?? [],
      my_reaction: myByPost.get(row.id) ?? null,
    }));
  }

  /** True if the post is visible to the caller (own or accepted friend's). */
  async canView(userId: string, postId: string): Promise<boolean> {
    const res = await this.pool.query(
      `SELECT 1
       FROM feed_posts fp
       WHERE fp.id = $1
         AND (
           fp.author_id = $2
           OR fp.author_id IN (
             SELECT CASE WHEN requester_id = $2 THEN addressee_id ELSE requester_id END
             FROM friendships
             WHERE (requester_id = $2 OR addressee_id = $2) AND status = 'accepted'
           )
         )`,
      [postId, userId]
    );
    return res.rows.length > 0;
  }

  async react(userId: string, postId: string, emoji: string): Promise<void> {
    await this.pool.query(
      `INSERT INTO post_reactions (post_id, user_id, emoji)
       VALUES ($1, $2, $3)
       ON CONFLICT (post_id, user_id) DO UPDATE SET emoji = EXCLUDED.emoji, created_at = now()`,
      [postId, userId, emoji]
    );
  }

  async unreact(userId: string, postId: string): Promise<void> {
    await this.pool.query(
      `DELETE FROM post_reactions WHERE post_id = $1 AND user_id = $2`,
      [postId, userId]
    );
  }

  async deletePost(userId: string, postId: string): Promise<boolean> {
    const res = await this.pool.query(
      `DELETE FROM feed_posts WHERE id = $1 AND author_id = $2`,
      [postId, userId]
    );
    return (res.rowCount ?? 0) > 0;
  }

  async getPostKind(postId: string): Promise<FeedPostKind | null> {
    const res = await this.pool.query<{ kind: FeedPostKind }>(
      `SELECT kind FROM feed_posts WHERE id = $1`,
      [postId]
    );
    return res.rows[0]?.kind ?? null;
  }

  /** Import a split post's snapshot into the caller's own splits. */
  async importSplit(userId: string, postId: string): Promise<UserSplit | null> {
    const res = await this.pool.query<{ kind: FeedPostKind; payload_json: string }>(
      `SELECT kind, payload_json FROM feed_posts WHERE id = $1`,
      [postId]
    );
    const row = res.rows[0];
    if (!row || row.kind !== "split") return null;

    const payload = JSON.parse(row.payload_json) as SplitPayload;
    const result = await this.splitService.createSplit(userId, {
      name: payload.name,
      library_key: "", // fresh user-owned copy; no unique conflict
      days: payload.days,
    });
    return result.conflict ? null : result.split;
  }
}
