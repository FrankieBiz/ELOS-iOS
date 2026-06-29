CREATE TABLE template_shares (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  template_id  UUID NOT NULL REFERENCES workout_templates(id) ON DELETE CASCADE,
  -- owner_id is the Supabase auth uid; the local `users` table is abandoned (see migrations/README),
  -- so this is a bare UUID like every other user-scoped column rather than a FK to users(id).
  owner_id     UUID NOT NULL,
  share_code   TEXT NOT NULL UNIQUE,
  payload_json JSONB NOT NULL,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (template_id, owner_id)
);
