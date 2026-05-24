CREATE TABLE creators (
  id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name           TEXT NOT NULL,
  slug           TEXT UNIQUE NOT NULL,
  bio            TEXT,
  image_url      TEXT,
  category       TEXT NOT NULL,
  training_style TEXT,
  goals          TEXT[] DEFAULT '{}',
  split_types    TEXT[] DEFAULT '{}',
  difficulty     TEXT DEFAULT 'intermediate',
  is_verified    BOOLEAN DEFAULT false,
  source_urls    TEXT[] DEFAULT '{}',
  review_status  TEXT DEFAULT 'pending',
  created_at     TIMESTAMPTZ DEFAULT now()
);
CREATE INDEX creators_category_idx ON creators(category);

CREATE TABLE creator_workouts (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  creator_id       UUID NOT NULL REFERENCES creators(id) ON DELETE CASCADE,
  title            TEXT NOT NULL,
  description      TEXT,
  program_type     TEXT NOT NULL,
  days_per_week    INTEGER,
  goal             TEXT,
  difficulty       TEXT DEFAULT 'intermediate',
  duration_weeks   INTEGER,
  est_session_mins INTEGER,
  equipment        TEXT[] DEFAULT '{}',
  muscle_groups    TEXT[] DEFAULT '{}',
  tags             TEXT[] DEFAULT '{}',
  source_url       TEXT,
  attribution      TEXT,
  disclaimer       TEXT DEFAULT 'Inspired by publicly available information. Does not represent the creator''s full official program.',
  confidence_level TEXT DEFAULT 'medium',
  review_status    TEXT DEFAULT 'pending',
  is_public        BOOLEAN DEFAULT true,
  created_at       TIMESTAMPTZ DEFAULT now()
);
CREATE INDEX creator_workouts_creator_idx ON creator_workouts(creator_id);
CREATE INDEX creator_workouts_goal_idx    ON creator_workouts(goal);

CREATE TABLE workout_days (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  workout_id  UUID NOT NULL REFERENCES creator_workouts(id) ON DELETE CASCADE,
  day_number  INTEGER NOT NULL,
  name        TEXT NOT NULL,
  focus       TEXT,
  notes       TEXT,
  order_index INTEGER NOT NULL
);

CREATE TABLE workout_day_exercises (
  id                 UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  workout_day_id     UUID NOT NULL REFERENCES workout_days(id) ON DELETE CASCADE,
  exercise_id        UUID REFERENCES exercise_definitions(id),
  exercise_name      TEXT NOT NULL,
  order_index        INTEGER NOT NULL,
  sets               INTEGER,
  reps               TEXT,
  rest_seconds       INTEGER,
  tempo              TEXT,
  rpe_guidance       TEXT,
  notes              TEXT,
  substitution_notes TEXT,
  is_superset        BOOLEAN DEFAULT false,
  superset_group     INTEGER
);
