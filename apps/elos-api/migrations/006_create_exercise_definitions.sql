CREATE TABLE exercise_definitions (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_id         UUID,
  name             TEXT NOT NULL,
  primary_muscle   TEXT NOT NULL,
  secondary_muscles TEXT[] NOT NULL DEFAULT '{}',
  equipment        TEXT NOT NULL DEFAULT '',
  movement_pattern TEXT NOT NULL DEFAULT '',
  is_custom        BOOLEAN NOT NULL DEFAULT false,
  created_at       TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX exercise_definitions_owner_idx ON exercise_definitions (owner_id);
CREATE INDEX exercise_definitions_name_idx ON exercise_definitions (lower(name));

INSERT INTO exercise_definitions (name, primary_muscle, secondary_muscles, equipment, movement_pattern) VALUES
  ('Barbell Back Squat',     'quads',        '{glutes,hamstrings,core}',     'barbell',    'squat'),
  ('Barbell Bench Press',    'chest',        '{triceps,front_delts}',        'barbell',    'push'),
  ('Conventional Deadlift',  'hamstrings',   '{glutes,back,traps}',          'barbell',    'hinge'),
  ('Barbell Overhead Press', 'front_delts',  '{triceps,upper_chest}',        'barbell',    'push'),
  ('Pull-Up',                'lats',         '{biceps,rear_delts}',          'bodyweight', 'pull'),
  ('Barbell Row',            'lats',         '{biceps,rear_delts,traps}',    'barbell',    'pull'),
  ('Romanian Deadlift',      'hamstrings',   '{glutes,back}',                'barbell',    'hinge'),
  ('Dumbbell Lunges',        'quads',        '{glutes,hamstrings}',          'dumbbell',   'squat'),
  ('Incline Dumbbell Press', 'upper_chest',  '{front_delts,triceps}',        'dumbbell',   'push'),
  ('Cable Row',              'lats',         '{biceps,rear_delts}',          'cable',      'pull'),
  ('Leg Press',              'quads',        '{glutes,hamstrings}',          'machine',    'squat'),
  ('Dumbbell Curl',          'biceps',       '{brachialis}',                 'dumbbell',   'isolation'),
  ('Tricep Pushdown',        'triceps',      '{}',                           'cable',      'isolation'),
  ('Leg Curl',               'hamstrings',   '{}',                           'machine',    'isolation'),
  ('Calf Raise',             'calves',       '{}',                           'machine',    'isolation'),
  ('Hip Thrust',             'glutes',       '{hamstrings,core}',            'barbell',    'hinge'),
  ('Face Pull',              'rear_delts',   '{traps,external_rotators}',    'cable',      'pull'),
  ('Lat Pulldown',           'lats',         '{biceps,rear_delts}',          'machine',    'pull'),
  ('Chest Fly',              'chest',        '{front_delts}',                'cable',      'isolation'),
  ('Lateral Raise',          'side_delts',   '{}',                           'dumbbell',   'isolation'),
  ('Front Squat',            'quads',        '{glutes,core}',                'barbell',    'squat'),
  ('Sumo Deadlift',          'glutes',       '{hamstrings,quads,back}',      'barbell',    'hinge'),
  ('Close-Grip Bench Press', 'triceps',      '{chest,front_delts}',          'barbell',    'push'),
  ('Hammer Curl',            'brachialis',   '{biceps}',                     'dumbbell',   'isolation'),
  ('Skull Crusher',          'triceps',      '{}',                           'barbell',    'isolation'),
  ('Leg Extension',          'quads',        '{}',                           'machine',    'isolation'),
  ('Seated Cable Row',       'lats',         '{biceps,rear_delts}',          'cable',      'pull'),
  ('Dumbbell Row',           'lats',         '{biceps,rear_delts}',          'dumbbell',   'pull'),
  ('Push-Up',                'chest',        '{triceps,front_delts}',        'bodyweight', 'push'),
  ('Plank',                  'core',         '{glutes}',                     'bodyweight', 'carry');
