CREATE TABLE exercise_sets (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  session_id    UUID NOT NULL REFERENCES workout_sessions (id) ON DELETE CASCADE,
  user_id       UUID NOT NULL,
  exercise_name TEXT NOT NULL,
  set_index     INTEGER NOT NULL,
  weight_kg     NUMERIC NOT NULL DEFAULT 0,
  reps          INTEGER NOT NULL DEFAULT 0,
  rpe           NUMERIC CHECK (rpe IS NULL OR (rpe BETWEEN 1 AND 10)),
  rir           INTEGER,
  completed_at  TIMESTAMPTZ,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX exercise_sets_session_idx ON exercise_sets (session_id);
CREATE INDEX exercise_sets_user_exercise_idx ON exercise_sets (user_id, exercise_name);
