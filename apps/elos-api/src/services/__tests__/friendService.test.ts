import { describe, it, expect, vi } from "vitest";
import type { Pool } from "pg";
import { FriendService } from "../friendService";

function stubPool(result: { rows?: unknown[]; rowCount?: number } = {}) {
  const query = vi.fn().mockResolvedValue({ rows: result.rows ?? [], rowCount: result.rowCount ?? 0 });
  return { pool: { query } as unknown as Pool, query };
}

const A = "11111111-1111-1111-1111-111111111111";
const B = "22222222-2222-2222-2222-222222222222";
const FRIENDSHIP = "33333333-3333-3333-3333-333333333333";

describe("FriendService.reportUser", () => {
  it("inserts the report and defaults a missing note to null", async () => {
    const { pool, query } = stubPool();
    const svc = new FriendService(pool);
    await svc.reportUser(A, B, "spam");
    const [, params] = query.mock.calls[0];
    expect(params).toEqual([A, B, "spam", null]);
  });

  it("passes the note through when provided", async () => {
    const { pool, query } = stubPool();
    const svc = new FriendService(pool);
    await svc.reportUser(A, B, "harassment", "abusive DMs");
    expect(query.mock.calls[0][1]).toEqual([A, B, "harassment", "abusive DMs"]);
  });
});

describe("FriendService ownership-scoped mutations", () => {
  it("acceptRequest only accepts a request addressed to the caller", async () => {
    const { pool, query } = stubPool();
    const svc = new FriendService(pool);
    await svc.acceptRequest(A, FRIENDSHIP);
    const [sql, params] = query.mock.calls[0];
    expect(sql).toContain("addressee_id = $2");
    expect(params).toEqual([FRIENDSHIP, A]);
  });

  it("removeFriend requires the caller to be a participant", async () => {
    const { pool, query } = stubPool();
    const svc = new FriendService(pool);
    await svc.removeFriend(A, FRIENDSHIP);
    const [sql, params] = query.mock.calls[0];
    expect(sql).toContain("requester_id = $2 OR addressee_id = $2");
    expect(params).toEqual([FRIENDSHIP, A]);
  });
});

describe("FriendService.unblockUser", () => {
  it("deletes the block row scoped to the blocker", async () => {
    const { pool, query } = stubPool();
    const svc = new FriendService(pool);
    await svc.unblockUser(A, B);
    const [sql, params] = query.mock.calls[0];
    expect(sql).toContain("DELETE FROM user_blocks");
    expect(params).toEqual([A, B]);
  });
});

describe("FriendService.getFriendStats", () => {
  it("returns null for a non-friend (no accepted friendship row)", async () => {
    const { pool } = stubPool({ rows: [] });
    const svc = new FriendService(pool);
    await expect(svc.getFriendStats(A, B)).resolves.toBeNull();
  });
});
