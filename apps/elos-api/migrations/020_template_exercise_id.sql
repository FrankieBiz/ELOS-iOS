-- Templates: link template_exercises to the canonical exercise_definitions row by id (nullable for backfill).
-- Keep exercise_name for display and for rows that don't resolve.

ALTER TABLE template_exercises
  ADD COLUMN exercise_id UUID REFERENCES exercise_definitions(id);

-- Backfill: match by lowercase name, scoped to user-custom OR global exercises.
UPDATE template_exercises te
SET exercise_id = ed.id
FROM exercise_definitions ed
WHERE te.exercise_id IS NULL
  AND lower(ed.name) = lower(te.exercise_name)
  AND (ed.owner_id IS NULL OR ed.owner_id = te.user_id);

CREATE INDEX template_exercises_exercise_idx
  ON template_exercises (exercise_id);
