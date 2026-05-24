CREATE TABLE workout_sessions (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id      UUID NOT NULL,
  started_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
  finished_at  TIMESTAMPTZ,
  session_rpe  INTEGER CHECK (session_rpe IS NULL OR (session_rpe BETWEEN 1 AND 10)),
  notes        TEXT NOT NULL DEFAULT '',
  template_id  UUID,
  total_volume NUMERIC NOT NULL DEFAULT 0,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX workout_sessions_user_id_idx ON workout_sessions (user_id);
CREATE INDEX workout_sessions_started_at_idx ON workout_sessions (user_id, started_at DESC);
