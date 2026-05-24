CREATE TABLE IF NOT EXISTS ai_briefs (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  date        DATE NOT NULL,
  brief_text  TEXT NOT NULL,
  mood        TEXT NOT NULL CHECK (mood IN ('positive', 'cautious', 'alert')),
  generated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (user_id, date)
);
