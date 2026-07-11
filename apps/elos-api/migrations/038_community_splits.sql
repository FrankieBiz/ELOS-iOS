-- Community-published splits: an immutable snapshot of a user's split that
-- anyone can browse and import. Snapshot (days_json) is copied at publish time
-- so later edits/deletes of the source split don't affect the published copy.
CREATE TABLE community_splits (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  author_id       UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  source_split_id UUID,
  name            TEXT NOT NULL,
  description     TEXT NOT NULL DEFAULT '',
  days_json       TEXT NOT NULL,
  imports_count   INTEGER NOT NULL DEFAULT 0,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX community_splits_created_idx ON community_splits(created_at DESC);
CREATE INDEX community_splits_author_idx ON community_splits(author_id);

-- Re-publishing the same split updates the existing listing instead of duplicating it.
CREATE UNIQUE INDEX community_splits_source_idx
  ON community_splits(author_id, source_split_id)
  WHERE source_split_id IS NOT NULL;
