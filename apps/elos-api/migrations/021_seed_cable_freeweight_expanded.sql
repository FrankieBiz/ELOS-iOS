-- Expand cable and free-weight exercise catalog so every common and uncommon
-- movement available on any cable machine or with any free weight is present.
-- Uses INSERT … ON CONFLICT to safely re-run without creating duplicates.

INSERT INTO exercise_definitions
  (name, primary_muscle, secondary_muscles, equipment, movement_pattern)
VALUES

  -- ═══════════════════════════════════════════════════════════════
  -- CABLE — CHEST
  -- ═══════════════════════════════════════════════════════════════
  ('Cable Incline Fly',                     'upper_chest',  '{front_delts}',                     'cable',    'isolation'),
  ('Cable Decline Fly',                     'lower_chest',  '{front_delts}',                     'cable',    'isolation'),
  ('Single-Arm Cable Fly',                  'chest',        '{front_delts}',                     'cable',    'isolation'),
  ('Cable Crossover',                       'chest',        '{front_delts}',                     'cable',    'isolation'),
  ('Cable Chest Press',                     'chest',        '{triceps,front_delts}',             'cable',    'push'),
  ('Cable Incline Press',                   'upper_chest',  '{triceps,front_delts}',             'cable',    'push'),
  ('Low-to-High Cable Fly',                 'upper_chest',  '{front_delts}',                     'cable',    'isolation'),
  ('High-to-Low Cable Fly',                 'lower_chest',  '{front_delts}',                     'cable',    'isolation'),
  ('Single-Arm Cable Crossover',            'chest',        '{front_delts}',                     'cable',    'isolation'),
  ('Cable Squeeze Press',                   'chest',        '{triceps}',                         'cable',    'push'),

  -- ═══════════════════════════════════════════════════════════════
  -- CABLE — BACK
  -- ═══════════════════════════════════════════════════════════════
  ('High Cable Row',                        'lats',         '{rear_delts,biceps}',               'cable',    'pull'),
  ('Single-Arm High Cable Row',             'lats',         '{rear_delts,biceps}',               'cable',    'pull'),
  ('Half-Kneeling Cable Row',               'lats',         '{rear_delts,biceps}',               'cable',    'pull'),
  ('Supinated Cable Row',                   'lats',         '{biceps,rear_delts}',               'cable',    'pull'),
  ('Kneeling Lat Pulldown',                 'lats',         '{biceps,rear_delts}',               'cable',    'pull'),
  ('Close-Grip Cable Row',                  'lats',         '{biceps,rear_delts}',               'cable',    'pull'),
  ('Wide-Grip Cable Row',                   'lats',         '{rear_delts,traps}',                'cable',    'pull'),
  ('Bayesian Cable Curl',                   'lats',         '{rear_delts,biceps}',               'cable',    'pull'),
  ('Cable Scapular Retraction',             'traps',        '{rear_delts,rhomboids}',            'cable',    'pull'),
  ('Cable Prone Row',                       'lats',         '{rear_delts,biceps}',               'cable',    'pull'),
  ('Single-Arm Cable Lat Pulldown',         'lats',         '{biceps}',                          'cable',    'pull'),
  ('Cable Deadlift',                        'back',         '{glutes,hamstrings,traps}',         'cable',    'hinge'),

  -- ═══════════════════════════════════════════════════════════════
  -- CABLE — SHOULDERS
  -- ═══════════════════════════════════════════════════════════════
  ('Cable Shoulder Press',                  'front_delts',  '{triceps,side_delts}',              'cable',    'push'),
  ('Half-Kneeling Cable Shoulder Press',    'front_delts',  '{core,triceps}',                    'cable',    'push'),
  ('Cable Y-Raise',                         'rear_delts',   '{traps,lower_traps}',               'cable',    'isolation'),
  ('Cable External Rotation',               'rear_delts',   '{external_rotators}',               'cable',    'isolation'),
  ('Cable Internal Rotation',               'front_delts',  '{internal_rotators}',               'cable',    'isolation'),
  ('Single-Arm Cable Lateral Raise',        'side_delts',   '{}',                                'cable',    'isolation'),
  ('Seated Cable Lateral Raise',            'side_delts',   '{}',                                'cable',    'isolation'),
  ('Cable Rear Delt Fly',                   'rear_delts',   '{traps}',                           'cable',    'isolation'),
  ('Cable Front Raise (single arm)',        'front_delts',  '{}',                                'cable',    'isolation'),
  ('Cable Prone Rear Delt Raise',           'rear_delts',   '{traps}',                           'cable',    'isolation'),

  -- ═══════════════════════════════════════════════════════════════
  -- CABLE — BICEPS
  -- ═══════════════════════════════════════════════════════════════
  ('High Cable Curl',                       'biceps',       '{brachialis}',                      'cable',    'isolation'),
  ('Low Cable Curl',                        'biceps',       '{brachialis}',                      'cable',    'isolation'),
  ('Preacher Cable Curl',                   'biceps',       '{brachialis}',                      'cable',    'isolation'),
  ('Single-Arm Cable Curl',                 'biceps',       '{brachialis}',                      'cable',    'isolation'),
  ('Overhead Cable Curl',                   'biceps',       '{}',                                'cable',    'isolation'),
  ('Reverse Cable Curl',                    'forearms',     '{biceps,brachialis}',               'cable',    'isolation'),
  ('Cable Bar Curl',                        'biceps',       '{brachialis,forearms}',             'cable',    'isolation'),
  ('Incline Cable Curl',                    'biceps',       '{}',                                'cable',    'isolation'),
  ('Cable Spider Curl',                     'biceps',       '{}',                                'cable',    'isolation'),
  ('Cable Drag Curl',                       'biceps',       '{}',                                'cable',    'isolation'),

  -- ═══════════════════════════════════════════════════════════════
  -- CABLE — TRICEPS
  -- ═══════════════════════════════════════════════════════════════
  ('Bar Pushdown',                          'triceps',      '{}',                                'cable',    'isolation'),
  ('V-Bar Pushdown',                        'triceps',      '{}',                                'cable',    'isolation'),
  ('Reverse Grip Tricep Pushdown',          'triceps',      '{}',                                'cable',    'isolation'),
  ('Straight Bar Pushdown',                 'triceps',      '{}',                                'cable',    'isolation'),
  ('Single-Arm Overhead Cable Extension',   'triceps',      '{}',                                'cable',    'isolation'),
  ('Cable Skull Crusher',                   'triceps',      '{}',                                'cable',    'isolation'),
  ('Cable Tate Press',                      'triceps',      '{}',                                'cable',    'isolation'),
  ('Kneeling Overhead Cable Extension',     'triceps',      '{}',                                'cable',    'isolation'),

  -- ═══════════════════════════════════════════════════════════════
  -- CABLE — LEGS & GLUTES
  -- ═══════════════════════════════════════════════════════════════
  ('Cable Romanian Deadlift',               'hamstrings',   '{glutes,lower_back}',               'cable',    'hinge'),
  ('Cable Stiff-Leg Deadlift',              'hamstrings',   '{glutes,lower_back}',               'cable',    'hinge'),
  ('Cable B-Stance Romanian Deadlift',      'hamstrings',   '{glutes}',                          'cable',    'hinge'),
  ('Cable Squat',                           'quads',        '{glutes,core}',                     'cable',    'squat'),
  ('Cable Lunge',                           'quads',        '{glutes,hamstrings}',               'cable',    'squat'),
  ('Cable Reverse Lunge',                   'glutes',       '{quads,hamstrings}',                'cable',    'squat'),
  ('Cable Hip Abduction',                   'glutes',       '{hip_abductors}',                   'cable',    'isolation'),
  ('Cable Hip Adduction',                   'adductors',    '{}',                                'cable',    'isolation'),
  ('Kneeling Cable Hip Extension',          'glutes',       '{}',                                'cable',    'isolation'),
  ('Cable Ankle Kickback',                  'glutes',       '{}',                                'cable',    'isolation'),
  ('Cable Hamstring Curl',                  'hamstrings',   '{}',                                'cable',    'isolation'),
  ('Cable Calf Raise',                      'calves',       '{}',                                'cable',    'isolation'),
  ('Cable Step-Through Lunge',              'quads',        '{glutes,hamstrings}',               'cable',    'squat'),
  ('Cable Donkey Kick',                     'glutes',       '{}',                                'cable',    'isolation'),
  ('Cable Hip Hinge',                       'hamstrings',   '{glutes,lower_back}',               'cable',    'hinge'),

  -- ═══════════════════════════════════════════════════════════════
  -- CABLE — CORE
  -- ═══════════════════════════════════════════════════════════════
  ('Kneeling Cable Crunch',                 'core',         '{hip_flexors}',                     'cable',    'isolation'),
  ('Standing Cable Crunch',                 'core',         '{}',                                'cable',    'isolation'),
  ('Cable Side Bend',                       'obliques',     '{core}',                            'cable',    'isolation'),
  ('Half-Kneeling Cable Chop',              'obliques',     '{core,glutes}',                     'cable',    'rotation'),
  ('Half-Kneeling Cable Lift',              'obliques',     '{core,glutes}',                     'cable',    'rotation'),
  ('Cable Russian Twist',                   'obliques',     '{core}',                            'cable',    'rotation'),
  ('Cable Seated Crunch',                   'core',         '{}',                                'cable',    'isolation'),
  ('Cable Oblique Crunch',                  'obliques',     '{core}',                            'cable',    'isolation'),
  ('Cable Anti-Rotation Press',             'obliques',     '{core}',                            'cable',    'rotation'),
  ('Cable Twist',                           'obliques',     '{core}',                            'cable',    'rotation'),

  -- ═══════════════════════════════════════════════════════════════
  -- FREE WEIGHT — BARBELL (additional)
  -- ═══════════════════════════════════════════════════════════════
  ('Barbell Lunge',                         'quads',        '{glutes,hamstrings}',               'barbell',  'squat'),
  ('Barbell Reverse Lunge',                 'glutes',       '{quads,hamstrings}',                'barbell',  'squat'),
  ('Barbell Step-Up',                       'quads',        '{glutes}',                          'barbell',  'squat'),
  ('Overhead Squat',                        'quads',        '{glutes,core,front_delts}',         'barbell',  'squat'),
  ('Zercher Squat',                         'quads',        '{glutes,core,biceps}',              'barbell',  'squat'),
  ('Hatfield Squat',                        'quads',        '{glutes,hamstrings}',               'barbell',  'squat'),
  ('Jefferson Deadlift',                    'quads',        '{glutes,hamstrings,back}',          'barbell',  'hinge'),
  ('Suitcase Deadlift',                     'hamstrings',   '{glutes,core,back}',                'barbell',  'hinge'),
  ('Barbell Glute Bridge',                  'glutes',       '{hamstrings}',                      'barbell',  'hinge'),
  ('Floor Press',                           'chest',        '{triceps,front_delts}',             'barbell',  'push'),
  ('Spoto Press',                           'chest',        '{triceps,front_delts}',             'barbell',  'push'),
  ('Close-Grip Incline Bench Press',        'triceps',      '{upper_chest,front_delts}',         'barbell',  'push'),
  ('Barbell Calf Raise',                    'calves',       '{}',                                'barbell',  'isolation'),
  ('EZ-Bar Skullcrusher',                   'triceps',      '{}',                                'barbell',  'isolation'),
  ('EZ-Bar Overhead Extension',             'triceps',      '{}',                                'barbell',  'isolation'),
  ('EZ-Bar Upright Row',                    'side_delts',   '{traps,biceps}',                    'barbell',  'pull'),
  ('Barbell Bulgarian Split Squat',         'quads',        '{glutes,hamstrings}',               'barbell',  'squat'),
  ('Barbell Split Squat',                   'quads',        '{glutes,hamstrings}',               'barbell',  'squat'),
  ('Hang Power Clean',                      'traps',        '{quads,glutes,hamstrings}',         'barbell',  'pull'),
  ('High Pull',                             'traps',        '{quads,front_delts}',               'barbell',  'pull'),
  ('Barbell Hip Hinge',                     'hamstrings',   '{glutes,lower_back}',               'barbell',  'hinge'),
  ('Jefferson Curl',                        'lower_back',   '{hamstrings,glutes}',               'barbell',  'hinge'),
  ('Barbell Incline Row',                   'lats',         '{biceps,rear_delts}',               'barbell',  'pull'),
  ('Barbell Rear Delt Row',                 'rear_delts',   '{traps}',                           'barbell',  'pull'),
  ('Barbell Wrist Extension',               'forearms',     '{}',                                'barbell',  'isolation'),
  ('Barbell Rollout',                       'core',         '{lats}',                            'barbell',  'isolation'),
  ('Barbell Hip Thrust (single-leg)',        'glutes',       '{hamstrings,core}',                 'barbell',  'hinge'),
  ('Staggered Stance Deadlift',             'hamstrings',   '{glutes,core}',                     'barbell',  'hinge'),

  -- ═══════════════════════════════════════════════════════════════
  -- FREE WEIGHT — DUMBBELL (additional)
  -- ═══════════════════════════════════════════════════════════════
  ('Dumbbell Skullcrusher',                 'triceps',      '{}',                                'dumbbell', 'isolation'),
  ('Dumbbell Floor Press',                  'chest',        '{triceps,front_delts}',             'dumbbell', 'push'),
  ('Dumbbell Hip Thrust',                   'glutes',       '{hamstrings}',                      'dumbbell', 'hinge'),
  ('Single-Leg Dumbbell Hip Thrust',        'glutes',       '{hamstrings,core}',                 'dumbbell', 'hinge'),
  ('Dumbbell Sumo Deadlift',                'glutes',       '{quads,hamstrings}',                'dumbbell', 'hinge'),
  ('Dumbbell Deadlift',                     'hamstrings',   '{glutes,back}',                     'dumbbell', 'hinge'),
  ('Dumbbell Clean',                        'traps',        '{quads,glutes,hamstrings}',         'dumbbell', 'pull'),
  ('Dumbbell Snatch',                       'traps',        '{quads,glutes,front_delts}',        'dumbbell', 'pull'),
  ('Dumbbell Power Clean',                  'traps',        '{quads,glutes}',                    'dumbbell', 'pull'),
  ('Dumbbell Upright Row',                  'side_delts',   '{traps,biceps}',                    'dumbbell', 'pull'),
  ('Dumbbell Y-Raise',                      'rear_delts',   '{lower_traps}',                     'dumbbell', 'isolation'),
  ('Dumbbell W-Raise',                      'rear_delts',   '{traps}',                           'dumbbell', 'isolation'),
  ('Dumbbell External Rotation',            'rear_delts',   '{external_rotators}',               'dumbbell', 'isolation'),
  ('Dumbbell Internal Rotation',            'front_delts',  '{internal_rotators}',               'dumbbell', 'isolation'),
  ('Side-Lying Dumbbell External Rotation', 'rear_delts',   '{external_rotators}',               'dumbbell', 'isolation'),
  ('Renegade Row',                          'lats',         '{core,rear_delts}',                 'dumbbell', 'pull'),
  ('Dumbbell Close-Grip Press',             'triceps',      '{chest,front_delts}',               'dumbbell', 'push'),
  ('Neutral Grip Dumbbell Press',           'chest',        '{triceps,front_delts}',             'dumbbell', 'push'),
  ('Single-Arm Dumbbell Press',             'chest',        '{triceps,front_delts}',             'dumbbell', 'push'),
  ('Dumbbell Chest-Supported Rear Delt Row','rear_delts',   '{traps}',                           'dumbbell', 'pull'),
  ('Dumbbell Side Bend',                    'obliques',     '{core}',                            'dumbbell', 'isolation'),
  ('Dumbbell Turkish Get-Up',               'core',         '{glutes,front_delts,hip_flexors}',  'dumbbell', 'carry'),
  ('Dumbbell Thruster',                     'front_delts',  '{quads,glutes,triceps}',            'dumbbell', 'push'),
  ('Hex Press',                             'chest',        '{triceps}',                         'dumbbell', 'push'),
  ('Dumbbell Rear Delt Row',                'rear_delts',   '{traps,biceps}',                    'dumbbell', 'pull'),
  ('Dumbbell Front Squat',                  'quads',        '{glutes,core}',                     'dumbbell', 'squat'),
  ('Dumbbell Staggered Stance RDL',         'hamstrings',   '{glutes,core}',                     'dumbbell', 'hinge'),
  ('Dumbbell Calf Raise',                   'calves',       '{}',                                'dumbbell', 'isolation'),
  ('Single-Leg Dumbbell Calf Raise',        'calves',       '{}',                                'dumbbell', 'isolation'),
  ('Dumbbell Bulgarian Split Squat',        'quads',        '{glutes,hamstrings}',               'dumbbell', 'squat'),
  ('Dumbbell Step-Up',                      'quads',        '{glutes}',                          'dumbbell', 'squat'),
  ('Dumbbell Reverse Lunge',                'glutes',       '{quads,hamstrings}',                'dumbbell', 'squat'),
  ('Dumbbell Lateral Lunge',                'adductors',    '{quads,glutes}',                    'dumbbell', 'squat'),
  ('Dumbbell Stiff-Leg Deadlift',           'hamstrings',   '{glutes,lower_back}',               'dumbbell', 'hinge'),
  ('Suitcase Carry',                        'core',         '{traps,forearms}',                  'dumbbell', 'carry'),
  ('Bottoms-Up Press',                      'front_delts',  '{core,triceps}',                    'dumbbell', 'push'),
  ('Dumbbell Face Pull',                    'rear_delts',   '{traps,external_rotators}',         'dumbbell', 'pull'),
  ('Dumbbell Around the World',             'chest',        '{front_delts}',                     'dumbbell', 'isolation'),
  ('Double Dumbbell Row',                   'lats',         '{rear_delts,biceps}',               'dumbbell', 'pull'),
  ('Dumbbell Incline Row',                  'lats',         '{rear_delts,biceps}',               'dumbbell', 'pull'),
  ('Dumbbell Box Squat',                    'quads',        '{glutes,hamstrings}',               'dumbbell', 'squat')

ON CONFLICT DO NOTHING;
