CREATE TABLE IF NOT EXISTS workouts (
  id           UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id      UUID        NOT NULL,
  exercise_name TEXT       NOT NULL,
  sets         INTEGER     NOT NULL,
  reps         INTEGER     NOT NULL,
  weight       NUMERIC,
  rpe          NUMERIC     CHECK (rpe IS NULL OR (rpe >= 1 AND rpe <= 10)),
  created_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS workouts_user_id_idx ON workouts (user_id);
