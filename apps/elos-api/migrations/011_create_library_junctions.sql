CREATE TABLE machine_exercises (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  machine_id    UUID NOT NULL REFERENCES machines(id) ON DELETE CASCADE,
  exercise_id   UUID REFERENCES exercise_definitions(id),
  exercise_name TEXT NOT NULL,
  notes         TEXT
);

CREATE TABLE machine_substitutions (
  id                     UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  machine_id             UUID NOT NULL REFERENCES machines(id),
  substitute_machine_id  UUID REFERENCES machines(id),
  substitute_exercise_id UUID REFERENCES exercise_definitions(id),
  substitution_type      TEXT,
  notes                  TEXT
);

CREATE TABLE saved_library_workouts (
  id                 UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id            UUID NOT NULL,
  creator_workout_id UUID NOT NULL REFERENCES creator_workouts(id) ON DELETE CASCADE,
  saved_at           TIMESTAMPTZ DEFAULT now(),
  UNIQUE(user_id, creator_workout_id)
);
CREATE INDEX saved_library_user_idx ON saved_library_workouts(user_id);
