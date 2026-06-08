import { describe, it, expect } from "vitest";
import { qs, intParam } from "../query";

describe("qs", () => {
  it("returns strings unchanged", () => {
    expect(qs("hello")).toBe("hello");
  });
  it("returns undefined for arrays (duplicated query params)", () => {
    expect(qs(["a", "b"])).toBeUndefined();
  });
  it("returns undefined for missing/non-string values", () => {
    expect(qs(undefined)).toBeUndefined();
    expect(qs(42)).toBeUndefined();
  });
});

describe("intParam", () => {
  it("parses a numeric string", () => {
    expect(intParam("25", 8, 1, 52)).toBe(25);
  });
  it("falls back to the default for non-numeric input (no NaN reaches SQL)", () => {
    expect(intParam("abc", 8, 1, 52)).toBe(8);
  });
  it("falls back to the default for a missing value", () => {
    expect(intParam(undefined, 30, 1, 100)).toBe(30);
  });
  it("clamps to the max", () => {
    expect(intParam("9999", 8, 1, 52)).toBe(52);
  });
  it("clamps to the min", () => {
    expect(intParam("0", 8, 1, 52)).toBe(1);
  });
  it("truncates fractional input", () => {
    expect(intParam("12.9", 8, 1, 52)).toBe(12);
  });
});
