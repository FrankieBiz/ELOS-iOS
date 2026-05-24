CREATE TABLE workout_templates (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id    UUID NOT NULL,
  name       TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX workout_templates_user_idx ON workout_templates (user_id);

CREATE TABLE template_exercises (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  template_id   UUID NOT NULL REFERENCES workout_templates (id) ON DELETE CASCADE,
  user_id       UUID NOT NULL,
  exercise_name TEXT NOT NULL,
  order_index   INTEGER NOT NULL,
  target_sets   INTEGER NOT NULL DEFAULT 3,
  target_reps   TEXT NOT NULL DEFAULT '8-10',
  target_rpe    NUMERIC CHECK (target_rpe IS NULL OR (target_rpe BETWEEN 1 AND 10)),
  rest_seconds  INTEGER NOT NULL DEFAULT 90,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX template_exercises_template_idx ON template_exercises (template_id);
