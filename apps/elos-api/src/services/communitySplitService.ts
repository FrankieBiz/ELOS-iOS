import { Pool } from "pg";
import type {
  CommunitySplit,
  CommunitySplitPage,
  SplitPayloadDay,
  UserSplit,
} from "elos-shared";
import { SplitService } from "./splitService";

const PAGE_SIZE = 20;

type CommunityRow = {
  id: string;
  author_id: string;
  name: string;
  description: string;
  days_json: string;
  imports_count: number;
  created_at: string;
  username: string | null;
  first_name: string | null;
  last_name: string | null;
  avatar_color: string | null;
};

export class CommunitySplitService {
  private readonly splitService: SplitService;

  constructor(private readonly pool: Pool) {
    this.splitService = new SplitService(pool);
  }

  /**
   * Publish a split the caller owns as an immutable community snapshot.
   * Re-publishing the same source split replaces the existing listing.
   */
  async publish(
    userId: string,
    splitId: string,
    description: string
  ): Promise<CommunitySplit | null> {
    const splitRes = await this.pool.query<{ name: string }>(
      `SELECT name FROM user_splits WHERE id = $1 AND user_id = $2`,
      [splitId, userId]
    );
    const split = splitRes.rows[0];
    if (!split) return null;

    const daysRes = await this.pool.query<SplitPayloadDay>(
      `SELECT order_index, day_label, day_name, template_id, is_rest, exercises_json
       FROM user_split_days WHERE split_id = $1 ORDER BY order_index`,
      [splitId]
    );

    const result = await this.pool.query<{ id: string }>(
      `INSERT INTO community_splits (author_id, source_split_id, name, description, days_json)
       VALUES ($1, $2, $3, $4, $5)
       ON CONFLICT (author_id, source_split_id) WHERE source_split_id IS NOT NULL
       DO UPDATE SET name = EXCLUDED.name,
                     description = EXCLUDED.description,
                     days_json = EXCLUDED.days_json,
                     created_at = now()
       RETURNING id`,
      [userId, splitId, split.name, description, JSON.stringify(daysRes.rows)]
    );
    return this.getSplit(userId, result.rows[0].id);
  }

  /** Newest-first community listings, keyset-paginated, hiding blocked users. */
  async list(userId: string, cursor?: string): Promise<CommunitySplitPage> {
    const params: unknown[] = [userId];
    let cursorClause = "";
    if (cursor) {
      params.push(cursor);
      cursorClause = `AND cs.created_at < $${params.length}`;
    }
    params.push(PAGE_SIZE + 1);

    const rows = await this.pool.query<CommunityRow>(
      `SELECT cs.id, cs.author_id, cs.name, cs.description, cs.days_json,
              cs.imports_count, cs.created_at::text,
              p.username, p.first_name, p.last_name, p.avatar_color
       FROM community_splits cs
       LEFT JOIN profiles p ON p.user_id = cs.author_id
       WHERE cs.author_id NOT IN (
               SELECT blocked_id FROM user_blocks WHERE blocker_id = $1
               UNION
               SELECT blocker_id FROM user_blocks WHERE blocked_id = $1
             )
             ${cursorClause}
       ORDER BY cs.created_at DESC
       LIMIT $${params.length}`,
      params
    );

    const hasMore = rows.rows.length > PAGE_SIZE;
    const pageRows = hasMore ? rows.rows.slice(0, PAGE_SIZE) : rows.rows;
    return {
      splits: pageRows.map((r) => this.assemble(userId, r)),
      next_cursor: hasMore ? pageRows[pageRows.length - 1].created_at : null,
    };
  }

  /** The caller's own published listings (for publish-state UI). */
  async listMine(userId: string): Promise<CommunitySplit[]> {
    const rows = await this.pool.query<CommunityRow>(
      `SELECT cs.id, cs.author_id, cs.name, cs.description, cs.days_json,
              cs.imports_count, cs.created_at::text,
              p.username, p.first_name, p.last_name, p.avatar_color
       FROM community_splits cs
       LEFT JOIN profiles p ON p.user_id = cs.author_id
       WHERE cs.author_id = $1
       ORDER BY cs.created_at DESC`,
      [userId]
    );
    return rows.rows.map((r) => this.assemble(userId, r));
  }

  /** Copy a community snapshot into the caller's own splits. */
  async importSplit(userId: string, communityId: string): Promise<UserSplit | null> {
    const res = await this.pool.query<{ name: string; days_json: string }>(
      `SELECT name, days_json FROM community_splits WHERE id = $1`,
      [communityId]
    );
    const row = res.rows[0];
    if (!row) return null;

    const days = JSON.parse(row.days_json) as SplitPayloadDay[];
    const result = await this.splitService.createSplit(userId, {
      name: row.name,
      library_key: "", // fresh user-owned copy; no unique conflict
      days,
    });
    if (result.conflict) return null;

    await this.pool.query(
      `UPDATE community_splits SET imports_count = imports_count + 1 WHERE id = $1`,
      [communityId]
    );
    return result.split;
  }

  async unpublish(userId: string, communityId: string): Promise<boolean> {
    const res = await this.pool.query(
      `DELETE FROM community_splits WHERE id = $1 AND author_id = $2`,
      [communityId, userId]
    );
    return (res.rowCount ?? 0) > 0;
  }

  private async getSplit(userId: string, id: string): Promise<CommunitySplit | null> {
    const rows = await this.pool.query<CommunityRow>(
      `SELECT cs.id, cs.author_id, cs.name, cs.description, cs.days_json,
              cs.imports_count, cs.created_at::text,
              p.username, p.first_name, p.last_name, p.avatar_color
       FROM community_splits cs
       LEFT JOIN profiles p ON p.user_id = cs.author_id
       WHERE cs.id = $1`,
      [id]
    );
    const row = rows.rows[0];
    return row ? this.assemble(userId, row) : null;
  }

  private assemble(userId: string, row: CommunityRow): CommunitySplit {
    return {
      id: row.id,
      name: row.name,
      description: row.description,
      days: JSON.parse(row.days_json) as SplitPayloadDay[],
      imports_count: row.imports_count,
      created_at: row.created_at,
      is_mine: row.author_id === userId,
      author: {
        user_id: row.author_id,
        username: row.username ?? "",
        first_name: row.first_name ?? "",
        last_name: row.last_name ?? "",
        avatar_color: row.avatar_color ?? "#6C47FF",
      },
    };
  }
}
