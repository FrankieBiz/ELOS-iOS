CREATE TABLE user_splits (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  name        TEXT NOT NULL,
  library_key TEXT NOT NULL DEFAULT '',
  is_active   BOOLEAN NOT NULL DEFAULT FALSE,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE user_split_days (
  id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  split_id       UUID NOT NULL REFERENCES user_splits(id) ON DELETE CASCADE,
  order_index    INTEGER NOT NULL,
  day_label      TEXT NOT NULL,
  day_name       TEXT NOT NULL,
  template_id    TEXT NOT NULL DEFAULT '',
  is_rest        BOOLEAN NOT NULL DEFAULT FALSE,
  exercises_json TEXT NOT NULL DEFAULT '[]'
);

CREATE INDEX ON user_splits(user_id);
CREATE INDEX ON user_split_days(split_id);

-- Prevent duplicate library splits per user (only when library_key is non-empty)
CREATE UNIQUE INDEX ON user_splits(user_id, library_key) WHERE library_key <> '';
