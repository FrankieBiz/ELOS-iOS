ALTER TABLE profiles
  ADD COLUMN IF NOT EXISTS username            TEXT UNIQUE,
  ADD COLUMN IF NOT EXISTS avatar_color        TEXT DEFAULT '#6C47FF',
  ADD COLUMN IF NOT EXISTS leaderboard_visible BOOLEAN DEFAULT true,
  ADD COLUMN IF NOT EXISTS bio                 TEXT DEFAULT '';

CREATE INDEX IF NOT EXISTS profiles_username_idx ON profiles(username);

CREATE TABLE IF NOT EXISTS friendships (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  requester_id  UUID NOT NULL,
  addressee_id  UUID NOT NULL,
  status        TEXT NOT NULL DEFAULT 'pending',
  created_at    TIMESTAMPTZ DEFAULT now(),
  updated_at    TIMESTAMPTZ DEFAULT now(),
  UNIQUE(requester_id, addressee_id),
  CHECK (requester_id != addressee_id),
  CHECK (status IN ('pending', 'accepted', 'blocked'))
);

CREATE INDEX IF NOT EXISTS friendships_requester_idx ON friendships(requester_id);
CREATE INDEX IF NOT EXISTS friendships_addressee_idx ON friendships(addressee_id);
CREATE INDEX IF NOT EXISTS friendships_status_idx   ON friendships(status);
