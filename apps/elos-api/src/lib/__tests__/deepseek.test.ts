import { describe, it, expect } from "vitest";
import { parseMoodAndBrief } from "../deepseek";

describe("parseMoodAndBrief", () => {
  it("extracts positive mood and strips tag", () => {
    const raw = "You're well-rested and ready for today's workout. No major deadlines ahead.\nMOOD: positive";
    const { briefText, mood } = parseMoodAndBrief(raw);
    expect(mood).toBe("positive");
    expect(briefText).toBe("You're well-rested and ready for today's workout. No major deadlines ahead.");
    expect(briefText).not.toContain("MOOD:");
  });

  it("extracts cautious mood (case-insensitive)", () => {
    const { mood } = parseMoodAndBrief("Some text.\nMOOD: Cautious");
    expect(mood).toBe("cautious");
  });

  it("extracts alert mood", () => {
    const { mood } = parseMoodAndBrief("Fatigue detected.\nMOOD: alert");
    expect(mood).toBe("alert");
  });

  it("defaults to cautious when MOOD tag is absent", () => {
    const { briefText, mood } = parseMoodAndBrief("Plain text, no tag.");
    expect(mood).toBe("cautious");
    expect(briefText).toBe("Plain text, no tag.");
  });

  it("handles extra whitespace around tag", () => {
    const { mood } = parseMoodAndBrief("Text here.\nMOOD:  positive  ");
    expect(mood).toBe("positive");
  });
});
