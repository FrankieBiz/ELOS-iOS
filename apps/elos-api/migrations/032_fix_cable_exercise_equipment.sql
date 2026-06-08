-- Fix pulldown exercises that are done on a cable rack but were seeded as 'machine'
UPDATE exercise_definitions
SET equipment = 'cable'
WHERE name IN (
  'Lat Pulldown',
  'Reverse-Grip Lat Pulldown',
  'Close-Grip Lat Pulldown',
  'V-Bar Pulldown'
)
AND owner_id IS NULL;

-- Add missing cable exercises that users commonly perform on a cable rack
INSERT INTO exercise_definitions
  (owner_id, name, primary_muscle, secondary_muscles, equipment, movement_pattern, is_custom)
SELECT NULL, name, primary_muscle, secondary_muscles::text[], equipment, movement_pattern, false
FROM (VALUES
  ('Wide-Grip Lat Pulldown',   'lats',        '{biceps,rear_delts}',       'cable', 'pull'),
  ('Behind-the-Neck Pulldown', 'lats',        '{biceps}',                  'cable', 'pull'),
  ('Cable Romanian Deadlift',  'hamstrings',  '{glutes,lower_back}',       'cable', 'hinge'),
  ('Cable Hip Abduction',      'glutes',      '{hip_abductors}',           'cable', 'isolation'),
  ('Cable Hip Adduction',      'adductors',   '{}',                        'cable', 'isolation')
) AS new(name, primary_muscle, secondary_muscles, equipment, movement_pattern)
WHERE NOT EXISTS (
  SELECT 1 FROM exercise_definitions ed
  WHERE lower(ed.name) = lower(new.name) AND ed.owner_id IS NULL
);
