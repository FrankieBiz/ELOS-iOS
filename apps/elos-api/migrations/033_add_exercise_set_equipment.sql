-- Machine/equipment identity for logged sets, powering per-machine progressive
-- overload and PRs. equipment_id is the client's EquipmentDatabase id (eq_...),
-- not a FK to exercise_definitions, so it is TEXT. All nullable (generic = NULL).
ALTER TABLE exercise_sets
  ADD COLUMN equipment_id         TEXT,
  ADD COLUMN equipment_dedupe_key TEXT,
  ADD COLUMN equipment_brand_name TEXT;

-- Per-machine history lookups (PRs / overload) filter on (user_id, dedupe_key).
CREATE INDEX exercise_sets_user_dedupe_idx
  ON exercise_sets (user_id, equipment_dedupe_key);

-- Analytics (weekly volume, e1RM) all filter on (user_id, completed_at);
-- add the supporting index here while we are touching this table.
CREATE INDEX exercise_sets_user_completed_idx
  ON exercise_sets (user_id, completed_at);
