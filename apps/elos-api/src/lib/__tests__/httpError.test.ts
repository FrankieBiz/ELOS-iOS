import { describe, it, expect } from "vitest";
import { HttpError, badRequest, unauthorized, forbidden, notFound, conflict } from "../httpError";

describe("HttpError factories", () => {
  it("badRequest yields 400", () => {
    const e = badRequest("bad");
    expect(e).toBeInstanceOf(HttpError);
    expect(e.status).toBe(400);
    expect(e.message).toBe("bad");
  });

  it("unauthorized yields 401 with default message", () => {
    expect(unauthorized().status).toBe(401);
    expect(unauthorized().message).toBe("Unauthorized");
  });

  it("forbidden yields 403", () => {
    expect(forbidden().status).toBe(403);
  });

  it("notFound yields 404", () => {
    expect(notFound().status).toBe(404);
  });

  it("conflict yields 409 with passed message and code", () => {
    const e = conflict("dup", "DUPLICATE");
    expect(e.status).toBe(409);
    expect(e.code).toBe("DUPLICATE");
  });
});
