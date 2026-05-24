-- Per-user exercise favorites.

CREATE TABLE user_favorite_exercises (
  user_id     UUID NOT NULL,
  exercise_id UUID NOT NULL REFERENCES exercise_definitions(id) ON DELETE CASCADE,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, exercise_id)
);

CREATE INDEX user_favorite_exercises_user_idx
  ON user_favorite_exercises (user_id, created_at DESC);
