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

  // Regression: getFavorites joins user_favorite_exercises (also has id/created_at),
  // so the projection MUST be ed-qualified or Postgres raises "ambiguous column".
  // Stubbed pools can't catch this at runtime, so assert the alias at the SQL level.
  it("getFavorites qualifies the projection with the ed alias", async () => {
    const { pool, query } = stubPool([]);
    await new ExerciseService(pool).getFavorites(USER);
    const sql = query.mock.calls[0][0] as string;
    expect(sql).toContain("ed.instructions");
    expect(sql).toContain("ed.image_key");
    expect(sql).toContain("ed.created_at");
    expect(sql).toContain("ed.id");
  });

  it("getRecentExercises qualifies the projection with the ed alias", async () => {
    const { pool, query } = stubPool([]);
    await new ExerciseService(pool).getRecentExercises(USER);
    const sql = query.mock.calls[0][0] as string;
    expect(sql).toContain("ed.instructions");
    expect(sql).toContain("ed.image_key");
    expect(sql).toContain("ed.created_at");
    expect(sql).toContain("ed.id");
  });

  // Regression: RETURNING runs on the base INSERT target with no alias in scope,
  // so the projection must NOT be ed-qualified.
  it("createCustomExercise RETURNING is not ed-qualified", async () => {
    const { pool, query } = stubPool([{ id: "x" }]);
    await new ExerciseService(pool).createCustomExercise(USER, {
      name: "Test",
      primary_muscle: "chest",
    });
    const sql = query.mock.calls[0][0] as string;
    const returning = sql.slice(sql.indexOf("RETURNING"));
    expect(returning).not.toContain("ed.");
  });
});
