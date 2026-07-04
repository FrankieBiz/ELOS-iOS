import { describe, it, expect, vi } from "vitest";
import type { Pool } from "pg";
import { ExerciseService } from "../exerciseService";

function stubPool(rows: unknown[] = []) {
  const query = vi.fn().mockResolvedValue({ rows, rowCount: rows.length });
  return { pool: { query } as unknown as Pool, query };
}

const USER = "11111111-1111-1111-1111-111111111111";

describe("ExerciseService projection", () => {
  it("searchExercises selects instructions and image_key", async () => {
    const { pool, query } = stubPool([]);
    await new ExerciseService(pool).searchExercises(USER, {});
    const sql = query.mock.calls[0][0] as string;
    expect(sql).toContain("instructions");
    expect(sql).toContain("image_key");
  });

  it("createCustomExercise returns instructions and image_key", async () => {
    const { pool, query } = stubPool([{ id: "x" }]);
    await new ExerciseService(pool).createCustomExercise(USER, {
      name: "Test",
      primary_muscle: "chest",
    });
    const sql = query.mock.calls[0][0] as string;
    expect(sql).toContain("instructions");
    expect(sql).toContain("image_key");
  });
});
