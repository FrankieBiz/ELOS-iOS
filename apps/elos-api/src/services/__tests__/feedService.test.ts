import { describe, it, expect, vi } from "vitest";
import type { Pool } from "pg";
import { FeedService } from "../feedService";

/** Minimal Pool stub whose query() returns a canned result. */
function stubPool(result: { rows?: unknown[]; rowCount?: number }) {
  const query = vi.fn().mockResolvedValue({ rows: result.rows ?? [], rowCount: result.rowCount ?? 0 });
  return { pool: { query } as unknown as Pool, query };
}

const USER = "11111111-1111-1111-1111-111111111111";
const POST = "22222222-2222-2222-2222-222222222222";

describe("FeedService.canView", () => {
  it("returns true when the visibility query matches a row", async () => {
    const { pool, query } = stubPool({ rows: [{ ok: 1 }] });
    const svc = new FeedService(pool);
    await expect(svc.canView(USER, POST)).resolves.toBe(true);
    // Ownership is enforced in SQL: the caller id must be bound as a parameter.
    expect(query.mock.calls[0][1]).toEqual([POST, USER]);
  });

  it("returns false when no row is visible to the caller", async () => {
    const { pool } = stubPool({ rows: [] });
    const svc = new FeedService(pool);
    await expect(svc.canView(USER, POST)).resolves.toBe(false);
  });
});

describe("FeedService.deletePost", () => {
  it("reports success only when a row owned by the caller was deleted", async () => {
    const { pool, query } = stubPool({ rowCount: 1 });
    const svc = new FeedService(pool);
    await expect(svc.deletePost(USER, POST)).resolves.toBe(true);
    const [sql, params] = query.mock.calls[0];
    expect(sql).toContain("author_id = $2");
    expect(params).toEqual([POST, USER]);
  });

  it("returns false when nothing was deleted (not the caller's post)", async () => {
    const { pool } = stubPool({ rowCount: 0 });
    const svc = new FeedService(pool);
    await expect(svc.deletePost(USER, POST)).resolves.toBe(false);
  });
});

describe("FeedService.unreact", () => {
  it("scopes the delete to the caller's own reaction", async () => {
    const { pool, query } = stubPool({ rowCount: 1 });
    const svc = new FeedService(pool);
    await svc.unreact(USER, POST);
    const [sql, params] = query.mock.calls[0];
    expect(sql).toContain("user_id = $2");
    expect(params).toEqual([POST, USER]);
  });
});

describe("FeedService.getPostKind", () => {
  it("returns the kind when found", async () => {
    const { pool } = stubPool({ rows: [{ kind: "split" }] });
    const svc = new FeedService(pool);
    await expect(svc.getPostKind(POST)).resolves.toBe("split");
  });
  it("returns null when not found", async () => {
    const { pool } = stubPool({ rows: [] });
    const svc = new FeedService(pool);
    await expect(svc.getPostKind(POST)).resolves.toBeNull();
  });
});
