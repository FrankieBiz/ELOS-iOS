-- Machine/equipment identity for template exercises, so a template can pin a
-- specific machine and that context round-trips across devices/reinstall.
--
-- Also adds `notes`: the iOS client has been sending template_exercises.notes
-- for a while, but the column never existed so the value was silently dropped.
-- Adding it here fixes that latent data-loss bug in the same area.
ALTER TABLE template_exercises
  ADD COLUMN equipment_id         TEXT,
  ADD COLUMN equipment_dedupe_key TEXT,
  ADD COLUMN equipment_brand_name TEXT,
  ADD COLUMN notes                TEXT;
