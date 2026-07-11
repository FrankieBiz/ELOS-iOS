import { describe, it, expect, vi } from "vitest";
import type { Pool } from "pg";
import { CommunitySplitService } from "../communitySplitService";

/** Minimal Pool stub whose query() returns a canned result. */
function stubPool(result: { rows?: unknown[]; rowCount?: number }) {
  const query = vi.fn().mockResolvedValue({ rows: result.rows ?? [], rowCount: result.rowCount ?? 0 });
  return { pool: { query } as unknown as Pool, query };
}

/** Pool stub returning a different canned result per successive query() call. */
function sequencedPool(results: Array<{ rows?: unknown[]; rowCount?: number }>) {
  const query = vi.fn();
  for (const r of results) {
    query.mockResolvedValueOnce({ rows: r.rows ?? [], rowCount: r.rowCount ?? 0 });
  }
  return { pool: { query } as unknown as Pool, query };
}

const USER = "11111111-1111-1111-1111-111111111111";
const OTHER = "33333333-3333-3333-3333-333333333333";
const SPLIT = "22222222-2222-2222-2222-222222222222";
const LISTING = "44444444-4444-4444-4444-444444444444";

const communityRow = (authorId: string) => ({
  id: LISTING,
  author_id: authorId,
  name: "My PPL",
  description: "6-day push/pull/legs",
  days_json: "[]",
  imports_count: 2,
  created_at: "2026-07-11T00:00:00Z",
  username: "frank",
  first_name: "Frank",
  last_name: "B",
  avatar_color: "#6C47FF",
});

describe("CommunitySplitService.publish", () => {
  it("returns null when the source split is not owned by the caller", async () => {
    const { pool, query } = stubPool({ rows: [] });
    const svc = new CommunitySplitService(pool);
    await expect(svc.publish(USER, SPLIT, "desc")).resolves.toBeNull();
    // Ownership is enforced in SQL: caller id bound as a parameter.
    expect(query.mock.calls[0][1]).toEqual([SPLIT, USER]);
  });

  it("snapshots the split and returns the assembled listing", async () => {
    const { pool, query } = sequencedPool([
      { rows: [{ name: "My PPL" }] },        // ownership + name
      { rows: [] },                          // days snapshot
      { rows: [{ id: LISTING }] },           // upsert
      { rows: [communityRow(USER)] },        // assembled listing
    ]);
    const svc = new CommunitySplitService(pool);
    const published = await svc.publish(USER, SPLIT, "6-day push/pull/legs");
    expect(published?.id).toBe(LISTING);
    expect(published?.is_mine).toBe(true);
    expect(published?.author.username).toBe("frank");
    // The upsert binds author, source split, name and description.
    const upsertParams = query.mock.calls[2][1];
    expect(upsertParams.slice(0, 4)).toEqual([USER, SPLIT, "My PPL", "6-day push/pull/legs"]);
  });
});

describe("CommunitySplitService.unpublish", () => {
  it("reports success only when a row owned by the caller was deleted", async () => {
    const { pool, query } = stubPool({ rowCount: 1 });
    const svc = new CommunitySplitService(pool);
    await expect(svc.unpublish(USER, LISTING)).resolves.toBe(true);
    const [sql, params] = query.mock.calls[0];
    expect(sql).toContain("author_id = $2");
    expect(params).toEqual([LISTING, USER]);
  });

  it("returns false when nothing was deleted (not the caller's listing)", async () => {
    const { pool } = stubPool({ rowCount: 0 });
    const svc = new CommunitySplitService(pool);
    await expect(svc.unpublish(USER, LISTING)).resolves.toBe(false);
  });
});

describe("CommunitySplitService.importSplit", () => {
  it("returns null when the listing does not exist", async () => {
    const { pool } = stubPool({ rows: [] });
    const svc = new CommunitySplitService(pool);
    await expect(svc.importSplit(USER, LISTING)).resolves.toBeNull();
  });
});

describe("CommunitySplitService.list", () => {
  it("marks the caller's own listings and assembles authors", async () => {
    const { pool, query } = stubPool({ rows: [communityRow(USER), { ...communityRow(OTHER), id: "5" }] });
    const svc = new CommunitySplitService(pool);
    const page = await svc.list(USER);
    expect(page.splits).toHaveLength(2);
    expect(page.splits[0].is_mine).toBe(true);
    expect(page.splits[1].is_mine).toBe(false);
    expect(page.next_cursor).toBeNull();
    // Block filtering binds the caller id.
    expect(query.mock.calls[0][1]).toContain(USER);
  });
});
