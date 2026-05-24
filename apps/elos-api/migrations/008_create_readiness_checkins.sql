CREATE TABLE readiness_checkins (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id       UUID NOT NULL,
  log_date      DATE NOT NULL,
  sleep_quality INTEGER NOT NULL CHECK (sleep_quality BETWEEN 1 AND 5),
  soreness      INTEGER NOT NULL CHECK (soreness BETWEEN 1 AND 5),
  stress        INTEGER NOT NULL CHECK (stress BETWEEN 1 AND 5),
  motivation    INTEGER NOT NULL CHECK (motivation BETWEEN 1 AND 5),
  overall_score NUMERIC NOT NULL,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (user_id, log_date)
);

CREATE INDEX readiness_checkins_user_date_idx ON readiness_checkins (user_id, log_date DESC);
