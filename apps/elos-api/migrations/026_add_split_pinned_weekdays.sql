ALTER TABLE user_splits
  ADD COLUMN IF NOT EXISTS pinned_weekdays_json TEXT NOT NULL DEFAULT '';
