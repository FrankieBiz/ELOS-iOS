import { describe, it, expect } from "vitest";
import { normalize, deriveMovementPattern, matchCatalog } from "../matcher";
import type { SourceExercise, CatalogExercise } from "../matcher";

describe("normalize", () => {
  it("lowercases, strips punctuation, collapses whitespace", () => {
    expect(normalize("3/4 Sit-Up")).toBe("3 4 sit up");
    expect(normalize("Leg  Extensions")).toBe("leg extensions");
  });
});

describe("deriveMovementPattern", () => {
  it("maps push/pull force, squat/hinge/isolation heuristics", () => {
    expect(deriveMovementPattern({ force: "push", mechanic: "compound", name: "Bench Press" } as SourceExercise)).toBe("push");
    expect(deriveMovementPattern({ force: "pull", mechanic: "compound", name: "Barbell Row" } as SourceExercise)).toBe("pull");
    expect(deriveMovementPattern({ force: "push", mechanic: "compound", name: "Barbell Squat" } as SourceExercise)).toBe("squat");
    expect(deriveMovementPattern({ force: "pull", mechanic: "compound", name: "Romanian Deadlift" } as SourceExercise)).toBe("hinge");
    expect(deriveMovementPattern({ force: "pull", mechanic: "isolation", name: "Bicep Curl" } as SourceExercise)).toBe("isolation");
  });
});

describe("matchCatalog", () => {
  const source: SourceExercise[] = [
    { id: "Leg_Extensions", name: "Leg Extensions", instructions: ["a", "b"], images: ["Leg_Extensions/0.jpg"], primaryMuscles: ["quadriceps"], secondaryMuscles: [], equipment: "machine", force: "push", mechanic: "isolation", category: "strength" },
    { id: "Butterfly", name: "Butterfly", instructions: ["x"], images: ["Butterfly/0.jpg"], primaryMuscles: ["chest"], secondaryMuscles: ["shoulders"], equipment: "machine", force: "push", mechanic: "isolation", category: "strength" },
  ];
  it("matches by exact normalized name (no alias needed)", () => {
    const catalog: CatalogExercise[] = [{ name: "Leg Extensions", movement_pattern: "" }];
    const { enriched, unmatched } = matchCatalog(catalog, source, {});
    expect(unmatched).toHaveLength(0);
    expect(enriched).toHaveLength(1);
    expect(enriched[0].sourceName).toBe("Leg Extensions");
    expect(enriched[0].instructions).toEqual(["a", "b"]);
    expect(enriched[0].imageKey).toBe("Leg_Extensions");
  });
  it("rejects near-miss names differing only by suffix", () => {
    const catalog: CatalogExercise[] = [{ name: "Leg Extension", movement_pattern: "" }];
    const { enriched, unmatched } = matchCatalog(catalog, source, {});
    expect(unmatched).toContain("Leg Extension");
    expect(enriched).toHaveLength(0);
  });
  it("matches via alias map", () => {
    const catalog: CatalogExercise[] = [{ name: "Pec Deck", movement_pattern: "" }];
    const { enriched } = matchCatalog(catalog, source, { "pec deck": "butterfly" });
    expect(enriched).toHaveLength(1);
    expect(enriched[0].instructions).toEqual(["x"]);
    expect(enriched[0].imageKey).toBe("Butterfly");
  });
  it("leaves ambiguous names unmatched (never guesses)", () => {
    const catalog: CatalogExercise[] = [{ name: "Some Novel Lift", movement_pattern: "" }];
    const { enriched, unmatched } = matchCatalog(catalog, source, {});
    expect(enriched).toHaveLength(0);
    expect(unmatched).toContain("Some Novel Lift");
  });
});
