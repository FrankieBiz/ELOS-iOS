CREATE TABLE IF NOT EXISTS profiles (
  user_id             UUID        PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  first_name          TEXT,
  last_name           TEXT,
  height_cm           NUMERIC,
  weight_kg           NUMERIC,
  age_years           INTEGER,
  training_experience TEXT        CHECK (training_experience IN ('beginner','intermediate','advanced')),
  training_goal       TEXT        CHECK (training_goal IN ('strength','hypertrophy','endurance','weight_loss')),
  school_name         TEXT,
  school_year         TEXT        CHECK (school_year IN ('freshman','sophomore','junior','senior')),
  cal_goal            INTEGER,
  protein_goal        INTEGER,
  carb_goal           INTEGER,
  fat_goal            INTEGER,
  onboarding_complete BOOLEAN     NOT NULL DEFAULT false,
  updated_at          TIMESTAMPTZ NOT NULL DEFAULT now()
);
