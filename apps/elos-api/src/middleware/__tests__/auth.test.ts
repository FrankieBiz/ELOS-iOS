import { describe, it, expect, vi, beforeEach } from "vitest";
import type { Request, Response, NextFunction } from "express";

const getUser = vi.fn();
vi.mock("../../supabase", () => ({
  supabaseAdmin: { auth: { get getUser() { return getUser; } } },
}));
vi.mock("../../lib/logger", () => ({
  logger: { warn: vi.fn(), error: vi.fn(), info: vi.fn() },
}));

import { requireAuth, _clearTokenCache } from "../auth";

function mockRes() {
  const res = {
    statusCode: 0,
    body: undefined as unknown,
    status(code: number) { this.statusCode = code; return this; },
    json(payload: unknown) { this.body = payload; return this; },
  };
  return res as unknown as Response & { statusCode: number; body: unknown };
}

function mockReq(authorization?: string) {
  return { headers: { authorization }, path: "/test" } as unknown as Request;
}

const USER = { id: "11111111-1111-1111-1111-111111111111", email: "a@b.co" };

beforeEach(() => {
  getUser.mockReset();
  _clearTokenCache();
});

describe("requireAuth", () => {
  it("rejects a missing Authorization header without calling Supabase", async () => {
    const res = mockRes();
    const next = vi.fn() as NextFunction;
    await requireAuth(mockReq(undefined), res, next);
    expect(res.statusCode).toBe(401);
    expect(getUser).not.toHaveBeenCalled();
    expect(next).not.toHaveBeenCalled();
  });

  it("rejects an invalid token with 401 and does not cache it", async () => {
    getUser.mockResolvedValue({ data: { user: null }, error: { message: "bad token" } });
    const res = mockRes();
    await requireAuth(mockReq("Bearer bad"), res, vi.fn() as NextFunction);
    expect(res.statusCode).toBe(401);

    // A second attempt with the same bad token must hit Supabase again.
    await requireAuth(mockReq("Bearer bad"), mockRes(), vi.fn() as NextFunction);
    expect(getUser).toHaveBeenCalledTimes(2);
  });

  it("accepts a valid token and attaches the user", async () => {
    getUser.mockResolvedValue({ data: { user: USER }, error: null });
    const req = mockReq("Bearer good");
    const next = vi.fn() as NextFunction;
    await requireAuth(req, mockRes(), next);
    expect(next).toHaveBeenCalledOnce();
    expect((req as Request).user).toEqual({ id: USER.id, email: USER.email });
  });

  it("serves repeat requests from the cache without re-verifying", async () => {
    getUser.mockResolvedValue({ data: { user: USER }, error: null });
    await requireAuth(mockReq("Bearer good"), mockRes(), vi.fn() as NextFunction);

    const req2 = mockReq("Bearer good");
    const next2 = vi.fn() as NextFunction;
    await requireAuth(req2, mockRes(), next2);
    expect(next2).toHaveBeenCalledOnce();
    expect((req2 as Request).user).toEqual({ id: USER.id, email: USER.email });
    expect(getUser).toHaveBeenCalledTimes(1); // second request never hit Supabase
  });

  it("caches per-token, not globally", async () => {
    getUser.mockResolvedValue({ data: { user: USER }, error: null });
    await requireAuth(mockReq("Bearer one"), mockRes(), vi.fn() as NextFunction);
    await requireAuth(mockReq("Bearer two"), mockRes(), vi.fn() as NextFunction);
    expect(getUser).toHaveBeenCalledTimes(2);
  });
});
