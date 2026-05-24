-- ─────────────────────────────────────────────────────────
-- Brands
-- ─────────────────────────────────────────────────────────
INSERT INTO machine_brands (name, slug, website_url) VALUES
  ('Life Fitness',      'life-fitness',      'https://www.lifefitness.com'),
  ('Hammer Strength',   'hammer-strength',   'https://www.hammerstrength.com'),
  ('Cybex',             'cybex',             'https://www.cybexintl.com'),
  ('Nautilus',          'nautilus',          'https://www.nautilus.com'),
  ('Matrix',            'matrix',            'https://www.matrixfitness.com'),
  ('Technogym',         'technogym',         'https://www.technogym.com'),
  ('Panatta',           'panatta',           'https://www.panattasport.com'),
  ('Prime Fitness',     'prime-fitness',     'https://www.primefitness.com'),
  ('Arsenal Strength',  'arsenal-strength',  'https://www.arsenalstrength.com'),
  ('Hoist',             'hoist',             'https://www.hoistfitness.com'),
  ('Precor',            'precor',            'https://www.precor.com'),
  ('Body-Solid',        'body-solid',        'https://www.bodysolid.com'),
  ('Atlantis',          'atlantis',          'https://www.atlantisfitness.com'),
  ('Freemotion',        'freemotion',        'https://www.freemotionfitness.com'),
  ('Legend Fitness',    'legend-fitness',    'https://www.legendfitness.com');

-- ─────────────────────────────────────────────────────────
-- Machines
-- ─────────────────────────────────────────────────────────
INSERT INTO machines (name, slug, alternate_names, category, equipment_type, primary_muscles, secondary_muscles, movement_pattern, description) VALUES
  ('Seated Chest Press',
   'seated-chest-press',
   ARRAY['Machine Chest Press','Plate Press Machine'],
   'chest', 'selectorized',
   ARRAY['chest'], ARRAY['front_delts','triceps'],
   'horizontal_push',
   'A selectorized pressing machine that targets the chest through a guided horizontal push movement. Ideal for beginners learning chest pressing mechanics safely.'),

  ('Plate-Loaded Chest Press',
   'plate-chest-press',
   ARRAY['Hammer Chest Press','Leverage Chest Press'],
   'chest', 'plate_loaded',
   ARRAY['chest'], ARRAY['front_delts','triceps'],
   'horizontal_push',
   'A plate-loaded chest press offering a natural arc of motion with higher resistance potential than selectorized versions.'),

  ('Incline Chest Press Machine',
   'incline-chest-press',
   ARRAY['Incline Press Machine'],
   'chest', 'selectorized',
   ARRAY['upper_chest'], ARRAY['front_delts','triceps'],
   'incline_push',
   'Targets the upper chest with a fixed incline angle. Allows safe overloading of the clavicular pectoralis head.'),

  ('Pec Deck / Fly Machine',
   'pec-deck',
   ARRAY['Butterfly Machine','Chest Fly Machine'],
   'chest', 'selectorized',
   ARRAY['chest'], ARRAY['front_delts'],
   'fly',
   'An isolation machine that mimics the pec fly movement, maintaining constant tension on the chest throughout the range of motion.'),

  ('Cable Crossover / Functional Trainer',
   'cable-crossover',
   ARRAY['Functional Trainer','Dual Adjustable Pulley'],
   'cable', 'cable',
   ARRAY['chest'], ARRAY['front_delts','core'],
   'fly',
   'Dual adjustable cable pulleys that allow chest flys, crossovers, and a wide variety of exercises at any angle.'),

  ('Lat Pulldown Machine',
   'lat-pulldown',
   ARRAY['Pulldown Machine'],
   'back', 'selectorized',
   ARRAY['lats'], ARRAY['biceps','rear_delts'],
   'vertical_pull',
   'Selectorized machine for vertical pulling. Develops lat width and is an accessible alternative to pull-ups for all levels.'),

  ('Seated Row Machine',
   'seated-row',
   ARRAY['Cable Row Machine','Low Row Machine'],
   'back', 'selectorized',
   ARRAY['lats'], ARRAY['rear_delts','biceps','traps'],
   'horizontal_pull',
   'Targets the lats and mid-back through a horizontal pulling motion. Builds back thickness and improves posture.'),

  ('Smith Machine',
   'smith-machine',
   ARRAY['Smith Press'],
   'smith', 'smith',
   ARRAY[], ARRAY[],
   'varies',
   'A barbell fixed to vertical rails, allowing pressing, squatting, and row variations with added stability. Suitable for many compound lifts.'),

  ('Leg Press Machine',
   'leg-press',
   ARRAY['45-Degree Leg Press','Horizontal Leg Press'],
   'legs', 'plate_loaded',
   ARRAY['quads'], ARRAY['glutes','hamstrings'],
   'leg_press',
   'A plate-loaded incline platform that targets the quads, glutes, and hamstrings. Allows heavy loading with lower spinal stress compared to squats.'),

  ('Hack Squat Machine',
   'hack-squat',
   ARRAY['Reverse Hack Squat'],
   'legs', 'plate_loaded',
   ARRAY['quads'], ARRAY['glutes','hamstrings'],
   'squat',
   'Guides the body through a squat pattern emphasising quad activation. The fixed path reduces balance demands and allows heavy quad overloading.'),

  ('Leg Extension Machine',
   'leg-extension',
   ARRAY['Knee Extension Machine'],
   'legs', 'selectorized',
   ARRAY['quads'], ARRAY[],
   'knee_extension',
   'An isolation machine for the quadriceps. Effective for finishing sets and targeting VMO development through the full extension range.'),

  ('Seated Leg Curl',
   'seated-leg-curl',
   ARRAY['Seated Hamstring Curl'],
   'legs', 'selectorized',
   ARRAY['hamstrings'], ARRAY['calves'],
   'knee_flexion',
   'Seated variation of the hamstring curl that keeps the hip flexed, lengthening the hamstring and increasing its stretch-mediated hypertrophy stimulus.'),

  ('Lying Leg Curl',
   'lying-leg-curl',
   ARRAY['Prone Leg Curl','Hamstring Curl Machine'],
   'legs', 'selectorized',
   ARRAY['hamstrings'], ARRAY['calves'],
   'knee_flexion',
   'Prone hamstring curl machine. The hip-neutral position allows natural hamstring activation through a full range of motion.'),

  ('Hip Thrust Machine',
   'hip-thrust-machine',
   ARRAY['Glute Bridge Machine','B-Stance Hip Thrust Machine'],
   'glutes', 'selectorized',
   ARRAY['glutes'], ARRAY['hamstrings'],
   'hip_extension',
   'Dedicated glute machine that loads the hip thrust pattern. Provides peak glute contraction at full hip extension without the setup of a barbell hip thrust.'),

  ('Hip Abductor Machine',
   'hip-abductor',
   ARRAY['Outer Thigh Machine','Glute Machine'],
   'glutes', 'selectorized',
   ARRAY['glutes'], ARRAY['hip_abductors'],
   'hip_abduction',
   'Isolates the hip abductors and gluteus medius. Useful for glute development and hip stability work.'),

  ('Hip Adductor Machine',
   'hip-adductor',
   ARRAY['Inner Thigh Machine'],
   'glutes', 'selectorized',
   ARRAY['adductors'], ARRAY[],
   'hip_adduction',
   'Trains the inner thigh adductors through a controlled hip adduction movement. Supports knee stability and overall leg balance.'),

  ('Seated Calf Raise',
   'calf-raise',
   ARRAY['Calf Raise Machine','Standing Calf Raise'],
   'legs', 'selectorized',
   ARRAY['calves'], ARRAY[],
   'plantarflexion',
   'Isolates the calf muscles (gastrocnemius and soleus) through loaded plantarflexion. The seated version emphasises the soleus due to the bent knee.'),

  ('Shoulder Press Machine',
   'shoulder-press-machine',
   ARRAY['Overhead Press Machine','Seated Shoulder Press'],
   'shoulders', 'selectorized',
   ARRAY['front_delts'], ARRAY['side_delts','triceps'],
   'vertical_push',
   'A guided overhead pressing machine that targets the deltoids and triceps. Reduces core demand compared to free-weight overhead pressing.'),

  ('Preacher Curl Machine',
   'preacher-curl',
   ARRAY['Scott Curl Machine'],
   'arms', 'selectorized',
   ARRAY['biceps'], ARRAY[],
   'elbow_flexion',
   'An arm-isolation machine that stabilises the upper arm against a pad, preventing cheating and maximising bicep tension throughout the curl.'),

  ('Tricep Extension Machine',
   'tricep-extension-machine',
   ARRAY['Overhead Tricep Machine','Tricep Pushdown Machine'],
   'arms', 'selectorized',
   ARRAY['triceps'], ARRAY[],
   'elbow_extension',
   'Isolates all three heads of the triceps through a guided extension. Overhead variation emphasises the long head for complete tricep development.'),

  ('Assisted Pull-Up/Dip Machine',
   'assisted-pullup-dip',
   ARRAY['Gravitron','Assisted Chin-Up Machine'],
   'back', 'assisted',
   ARRAY['lats'], ARRAY['biceps','chest','triceps'],
   'vertical_pull',
   'A counterweight machine that reduces effective bodyweight, enabling pull-ups and dips for those building towards unassisted reps.'),

  ('Reverse Fly Machine',
   'reverse-fly-machine',
   ARRAY['Rear Delt Machine','Pec Deck Reverse'],
   'shoulders', 'selectorized',
   ARRAY['rear_delts'], ARRAY['traps','rhomboids'],
   'horizontal_pull',
   'Isolates the rear deltoids and upper back through a reverse fly pattern. Essential for shoulder health and balanced delt development.');

-- ─────────────────────────────────────────────────────────
-- Machine exercises (representative pairings)
-- ─────────────────────────────────────────────────────────
INSERT INTO machine_exercises (machine_id, exercise_name, notes)
SELECT m.id, 'Barbell Bench Press', 'Free-weight alternative on flat bench'
FROM machines m WHERE m.slug = 'seated-chest-press';

INSERT INTO machine_exercises (machine_id, exercise_name, notes)
SELECT m.id, 'Cable Fly', 'Cable alternative for chest isolation'
FROM machines m WHERE m.slug = 'pec-deck';

INSERT INTO machine_exercises (machine_id, exercise_name, notes)
SELECT m.id, 'Barbell Row', 'Free-weight alternative for back thickness'
FROM machines m WHERE m.slug = 'seated-row';

INSERT INTO machine_exercises (machine_id, exercise_name, notes)
SELECT m.id, 'Pull-Up', 'Bodyweight progression target'
FROM machines m WHERE m.slug = 'lat-pulldown';

INSERT INTO machine_exercises (machine_id, exercise_name, notes)
SELECT m.id, 'Barbell Back Squat', 'Free-weight quad dominant alternative'
FROM machines m WHERE m.slug = 'leg-press';

INSERT INTO machine_exercises (machine_id, exercise_name, notes)
SELECT m.id, 'Barbell Hip Thrust', 'Free-weight alternative'
FROM machines m WHERE m.slug = 'hip-thrust-machine';

INSERT INTO machine_exercises (machine_id, exercise_name, notes)
SELECT m.id, 'Barbell Overhead Press', 'Free-weight overhead press alternative'
FROM machines m WHERE m.slug = 'shoulder-press-machine';

INSERT INTO machine_exercises (machine_id, exercise_name, notes)
SELECT m.id, 'Barbell Curl', 'Free-weight bicep curl'
FROM machines m WHERE m.slug = 'preacher-curl';

INSERT INTO machine_exercises (machine_id, exercise_name, notes)
SELECT m.id, 'Tricep Pushdown', 'Cable pushdown alternative'
FROM machines m WHERE m.slug = 'tricep-extension-machine';

-- ─────────────────────────────────────────────────────────
-- Creators
-- ─────────────────────────────────────────────────────────
INSERT INTO creators (name, slug, bio, category, training_style, goals, split_types, difficulty, is_verified, source_urls) VALUES
  ('Jeff Nippard',
   'jeff-nippard',
   'Canadian natural bodybuilder and powerlifter known for science-based training content. Publicly advocates for evidence-based hypertrophy and strength programming.',
   'educator',
   'Science-based hypertrophy and strength',
   ARRAY['muscle_gain','strength','aesthetics'],
   ARRAY['ppl','upper_lower'],
   'intermediate',
   false,
   ARRAY['https://www.youtube.com/@JeffNippard']),

  ('Arnold Schwarzenegger',
   'arnold-schwarzenegger',
   'Seven-time Mr. Olympia champion. His training philosophies are documented in "The Encyclopedia of Modern Bodybuilding" and numerous public interviews.',
   'bodybuilder',
   'High-volume bodybuilding with mind-muscle connection',
   ARRAY['muscle_gain','aesthetics'],
   ARRAY['arnold_split','bro_split'],
   'advanced',
   false,
   ARRAY['https://www.muscleandfitness.com']),

  ('Mike Mentzer',
   'mike-mentzer',
   'IFBB professional known for his Heavy Duty training philosophy. His approach to high-intensity, low-volume training is detailed in his published books.',
   'bodybuilder',
   'High-Intensity Training (HIT)',
   ARRAY['muscle_gain','strength'],
   ARRAY['hit'],
   'advanced',
   false,
   ARRAY['https://www.mikementzer.com']),

  ('Dorian Yates',
   'dorian-yates',
   'Six-time Mr. Olympia champion known for his Blood and Guts training style — low volume, extreme intensity, taken to failure.',
   'bodybuilder',
   'High-intensity, low-volume to failure',
   ARRAY['muscle_gain','aesthetics'],
   ARRAY['hit'],
   'advanced',
   false,
   ARRAY['https://www.dorianyates.net']),

  ('Jeff Cavaliere',
   'jeff-cavaliere',
   'Physical therapist and strength coach behind AthleanX. Publicly advocates for athletic performance combined with physique training using sport science principles.',
   'educator',
   'Athletic performance and physique training',
   ARRAY['muscle_gain','strength','athletic'],
   ARRAY['upper_lower','full_body'],
   'intermediate',
   false,
   ARRAY['https://www.youtube.com/@athleanx']),

  ('Chris Bumstead',
   'cbum',
   'Multiple Classic Physique Olympia champion. His training style is documented in YouTube content and public interviews focusing on classic physique proportions.',
   'bodybuilder',
   'Classic physique hypertrophy',
   ARRAY['muscle_gain','aesthetics'],
   ARRAY['ppl'],
   'advanced',
   false,
   ARRAY['https://www.youtube.com/@cbum']),

  ('Mike Israetel',
   'mike-israetel',
   'Co-founder of Renaissance Periodization (RP). PhD in Sport Physiology. His volume landmark frameworks are publicly documented in articles and YouTube content.',
   'educator',
   'Maximum Adaptive Volume (MAV) periodization',
   ARRAY['muscle_gain','strength'],
   ARRAY['upper_lower','ppl'],
   'intermediate',
   false,
   ARRAY['https://www.youtube.com/@RenaissancePeriodization']),

  ('Ronnie Coleman',
   'ronnie-coleman',
   'Eight-time Mr. Olympia champion. His high-volume, high-frequency training approach is documented in multiple training documentaries and interviews.',
   'bodybuilder',
   'High-volume, high-frequency bodybuilding',
   ARRAY['muscle_gain','aesthetics'],
   ARRAY['bro_split'],
   'advanced',
   false,
   ARRAY['https://www.ronniecoleman.net']),

  ('Phil Heath',
   'phil-heath',
   'Seven-time Mr. Olympia champion known as "The Gift." His training protocols are described in various public interviews and fitness publications.',
   'bodybuilder',
   'High-volume bodybuilding with precise form',
   ARRAY['muscle_gain','aesthetics'],
   ARRAY['bro_split'],
   'advanced',
   false,
   ARRAY['https://www.philheath.com']),

  ('Nick Bare',
   'nick-bare',
   'Hybrid athlete, founder of Bare Performance Nutrition, and Army veteran. Publicly trains and races marathons while maintaining a muscular physique.',
   'athlete',
   'Hybrid training — strength and endurance',
   ARRAY['strength','athletic','fat_loss'],
   ARRAY['upper_lower'],
   'intermediate',
   false,
   ARRAY['https://www.youtube.com/@NickBare']),

  ('Greg Doucette',
   'greg-doucette',
   'IFBB pro and former powerlifter known for evidence-based nutrition and training content on YouTube. Holds multiple powerlifting world records.',
   'educator',
   'Hypertrophy with evidence-based nutrition',
   ARRAY['muscle_gain','fat_loss'],
   ARRAY['upper_lower','ppl'],
   'intermediate',
   false,
   ARRAY['https://www.youtube.com/@GregDoucette']),

  ('Bradley Martyn',
   'bradley-martyn',
   'Popular fitness YouTuber and gym owner known for creative training methods and high-volume workouts documented extensively on social media.',
   'youtuber',
   'High-volume aesthetic bodybuilding',
   ARRAY['muscle_gain','aesthetics'],
   ARRAY['ppl','bro_split'],
   'intermediate',
   false,
   ARRAY['https://www.youtube.com/@BradleyMartyn']);

-- ─────────────────────────────────────────────────────────
-- Creator Workouts
-- ─────────────────────────────────────────────────────────

-- Jeff Nippard PPL
WITH c AS (SELECT id FROM creators WHERE slug = 'jeff-nippard')
INSERT INTO creator_workouts (creator_id, title, description, program_type, days_per_week, goal, difficulty, duration_weeks, est_session_mins, equipment, muscle_groups, tags, source_url, attribution, confidence_level)
SELECT c.id,
  'Science-Based PPL',
  'A Push/Pull/Legs split based on Jeff Nippard''s publicly described evidence-based approach to hypertrophy. Emphasises progressive overload, compound lifts first, and isolation finishers.',
  'ppl', 6, 'muscle_gain', 'intermediate', 12, 60,
  ARRAY['barbell','dumbbell','cable','machine'],
  ARRAY['chest','lats','quads','hamstrings','front_delts','side_delts','rear_delts','biceps','triceps'],
  ARRAY['hypertrophy','progressive_overload','natural'],
  'https://www.youtube.com/@JeffNippard',
  'Structure inspired by Jeff Nippard''s publicly available PPL content on YouTube.',
  'medium'
FROM c;

-- Jeff Nippard Upper/Lower
WITH c AS (SELECT id FROM creators WHERE slug = 'jeff-nippard')
INSERT INTO creator_workouts (creator_id, title, description, program_type, days_per_week, goal, difficulty, duration_weeks, est_session_mins, equipment, muscle_groups, tags, source_url, attribution, confidence_level)
SELECT c.id,
  'Upper/Lower Hypertrophy Program',
  'A 4-day upper/lower split reflecting the training principles Nippard has publicly described for intermediate lifters. Alternates heavy compound sessions with higher-rep hypertrophy days.',
  'upper_lower', 4, 'muscle_gain', 'intermediate', 8, 55,
  ARRAY['barbell','dumbbell','cable','machine'],
  ARRAY['chest','lats','quads','hamstrings','front_delts','biceps','triceps'],
  ARRAY['hypertrophy','upper_lower','intermediate'],
  'https://www.youtube.com/@JeffNippard',
  'Structure inspired by Nippard''s upper/lower programming content.',
  'medium'
FROM c;

-- Arnold Split
WITH c AS (SELECT id FROM creators WHERE slug = 'arnold-schwarzenegger')
INSERT INTO creator_workouts (creator_id, title, description, program_type, days_per_week, goal, difficulty, duration_weeks, est_session_mins, equipment, muscle_groups, tags, source_url, attribution, confidence_level)
SELECT c.id,
  'The Arnold Split',
  'A 6-day bodybuilding split pairing chest/back, shoulders/arms, and legs — as described in Arnold''s publicly available writings and interviews. Known for high volume and supersets.',
  'arnold_split', 6, 'muscle_gain', 'advanced', 16, 90,
  ARRAY['barbell','dumbbell','cable','machine'],
  ARRAY['chest','lats','quads','front_delts','side_delts','biceps','triceps'],
  ARRAY['classic_bodybuilding','high_volume','golden_era'],
  'https://www.muscleandfitness.com',
  'Inspired by training methods described in Arnold Schwarzenegger''s public writings and interviews. Not a direct reproduction of any paid program.',
  'medium'
FROM c;

-- Mike Mentzer HIT
WITH c AS (SELECT id FROM creators WHERE slug = 'mike-mentzer')
INSERT INTO creator_workouts (creator_id, title, description, program_type, days_per_week, goal, difficulty, duration_weeks, est_session_mins, equipment, muscle_groups, tags, source_url, attribution, confidence_level)
SELECT c.id,
  'Heavy Duty HIT',
  'Based on Mike Mentzer''s Heavy Duty philosophy as described in his published work. Trains each muscle group once per week to absolute failure with 1–2 working sets per exercise.',
  'hit', 4, 'muscle_gain', 'advanced', 12, 45,
  ARRAY['barbell','dumbbell','cable','machine'],
  ARRAY['chest','lats','quads','hamstrings','front_delts','biceps','triceps'],
  ARRAY['hit','high_intensity','low_volume','failure'],
  'https://www.mikementzer.com',
  'Inspired by principles described in Mike Mentzer''s published Heavy Duty books.',
  'high'
FROM c;

-- CBum PPL
WITH c AS (SELECT id FROM creators WHERE slug = 'cbum')
INSERT INTO creator_workouts (creator_id, title, description, program_type, days_per_week, goal, difficulty, duration_weeks, est_session_mins, equipment, muscle_groups, tags, source_url, attribution, confidence_level)
SELECT c.id,
  'Classic Physique PPL',
  'A Push/Pull/Legs program reflecting the classic physique training approach Chris Bumstead has discussed in YouTube content and interviews — high volume, aesthetic focus.',
  'ppl', 6, 'muscle_gain', 'advanced', 12, 70,
  ARRAY['barbell','dumbbell','cable','machine'],
  ARRAY['chest','lats','quads','hamstrings','front_delts','side_delts','rear_delts','biceps','triceps'],
  ARRAY['classic_physique','hypertrophy','aesthetic'],
  'https://www.youtube.com/@cbum',
  'Structure inspired by training content Chris Bumstead has shared publicly on YouTube and social media.',
  'medium'
FROM c;

-- RP Upper/Lower
WITH c AS (SELECT id FROM creators WHERE slug = 'mike-israetel')
INSERT INTO creator_workouts (creator_id, title, description, program_type, days_per_week, goal, difficulty, duration_weeks, est_session_mins, equipment, muscle_groups, tags, source_url, attribution, confidence_level)
SELECT c.id,
  'RP-Style Upper/Lower',
  'Reflects the volume landmark framework Mike Israetel has publicly described at Renaissance Periodization — starting at MEV, progressing toward MAV with weekly volume increases.',
  'upper_lower', 4, 'muscle_gain', 'intermediate', 6, 60,
  ARRAY['barbell','dumbbell','cable','machine'],
  ARRAY['chest','lats','quads','hamstrings','front_delts','side_delts','rear_delts','biceps','triceps'],
  ARRAY['evidence_based','volume_landmarks','periodization'],
  'https://www.youtube.com/@RenaissancePeriodization',
  'Inspired by Mike Israetel''s publicly documented volume landmark framework. Not affiliated with RP official programs.',
  'medium'
FROM c;

-- Nick Bare Hybrid
WITH c AS (SELECT id FROM creators WHERE slug = 'nick-bare')
INSERT INTO creator_workouts (creator_id, title, description, program_type, days_per_week, goal, difficulty, duration_weeks, est_session_mins, equipment, muscle_groups, tags, source_url, attribution, confidence_level)
SELECT c.id,
  'Hybrid Athlete Upper/Lower',
  'Reflects the training approach Nick Bare has publicly described for hybrid athletes — combining strength training with running/conditioning work within an upper/lower structure.',
  'upper_lower', 4, 'strength', 'intermediate', 12, 65,
  ARRAY['barbell','dumbbell','cable'],
  ARRAY['chest','lats','quads','hamstrings','front_delts'],
  ARRAY['hybrid','strength','endurance','athletic'],
  'https://www.youtube.com/@NickBare',
  'Inspired by training content Nick Bare has shared publicly on YouTube.',
  'medium'
FROM c;

-- ─────────────────────────────────────────────────────────
-- Workout Days — Jeff Nippard PPL (Push Day 1)
-- ─────────────────────────────────────────────────────────
WITH w AS (
  SELECT cw.id FROM creator_workouts cw
  JOIN creators c ON c.id = cw.creator_id
  WHERE c.slug = 'jeff-nippard' AND cw.program_type = 'ppl' AND cw.days_per_week = 6
)
INSERT INTO workout_days (workout_id, day_number, name, focus, notes, order_index)
SELECT w.id, 1, 'Push A', 'Chest / Front Delts / Triceps',
  'Start heavy on compound. Leave 1–2 RIR on most sets.',
  0 FROM w
UNION ALL
SELECT w.id, 2, 'Pull A', 'Lats / Rear Delts / Biceps',
  'Focus on vertical pull first, then horizontal.',
  1 FROM w
UNION ALL
SELECT w.id, 3, 'Legs A', 'Quads / Hamstrings / Glutes',
  'Squat pattern first when fresh.',
  2 FROM w
UNION ALL
SELECT w.id, 4, 'Push B', 'Shoulders / Chest / Triceps',
  'Higher rep ranges than Push A.',
  3 FROM w
UNION ALL
SELECT w.id, 5, 'Pull B', 'Lats / Biceps / Rear Delts',
  'Horizontal pull emphasis.',
  4 FROM w
UNION ALL
SELECT w.id, 6, 'Legs B', 'Hamstrings / Glutes / Calves',
  'Hip hinge pattern first.',
  5 FROM w;

-- ─────────────────────────────────────────────────────────
-- Workout Day Exercises — Nippard PPL Push A
-- ─────────────────────────────────────────────────────────
WITH d AS (
  SELECT wd.id FROM workout_days wd
  JOIN creator_workouts cw ON cw.id = wd.workout_id
  JOIN creators c ON c.id = cw.creator_id
  WHERE c.slug = 'jeff-nippard' AND cw.program_type = 'ppl' AND cw.days_per_week = 6 AND wd.day_number = 1
)
INSERT INTO workout_day_exercises (workout_day_id, exercise_name, order_index, sets, reps, rest_seconds, rpe_guidance, notes)
SELECT d.id, 'Barbell Bench Press',    0, 3, '4–6',  180, '8–9 RPE', 'First working set after warm-up. Control the eccentric.' FROM d UNION ALL
SELECT d.id, 'Incline Dumbbell Press', 1, 3, '8–12', 120, '8 RPE',   'Slight incline 30–45°. Full stretch at bottom.' FROM d UNION ALL
SELECT d.id, 'Cable Fly',              2, 3, '12–15',90,  '8 RPE',   'Cross body at peak. Hold 1s squeeze.' FROM d UNION ALL
SELECT d.id, 'Dumbbell Lateral Raise', 3, 4, '15–20',60,  '8 RPE',   'Lead with elbow. Slight lean forward.' FROM d UNION ALL
SELECT d.id, 'Overhead Tricep Extension', 4, 3, '10–15', 90, '8 RPE', 'Full stretch overhead. Long head emphasis.' FROM d UNION ALL
SELECT d.id, 'Tricep Pushdown',        5, 3, '12–15',75,  '8 RPE',   'Rope or bar. Elbows fixed at sides.' FROM d;

-- Nippard PPL Pull A
WITH d AS (
  SELECT wd.id FROM workout_days wd
  JOIN creator_workouts cw ON cw.id = wd.workout_id
  JOIN creators c ON c.id = cw.creator_id
  WHERE c.slug = 'jeff-nippard' AND cw.program_type = 'ppl' AND cw.days_per_week = 6 AND wd.day_number = 2
)
INSERT INTO workout_day_exercises (workout_day_id, exercise_name, order_index, sets, reps, rest_seconds, rpe_guidance, notes)
SELECT d.id, 'Pull-Up',               0, 3, '4–8',  180, '8–9 RPE', 'Add weight if bodyweight is too easy.' FROM d UNION ALL
SELECT d.id, 'Barbell Row',           1, 3, '6–8',  150, '8–9 RPE', 'Overhand grip. Pull to lower chest.' FROM d UNION ALL
SELECT d.id, 'Lat Pulldown',          2, 3, '10–12',120, '8 RPE',   'Lean back slightly. Full stretch at top.' FROM d UNION ALL
SELECT d.id, 'Face Pull',             3, 3, '15–20',60,  '8 RPE',   'External rotation cue at peak.' FROM d UNION ALL
SELECT d.id, 'Barbell Curl',          4, 3, '10–12',90,  '8 RPE',   'Full range. No swinging.' FROM d UNION ALL
SELECT d.id, 'Hammer Curl',           5, 2, '12–15',75,  '8 RPE',   'Neutral grip. Brachialis focus.' FROM d;

-- Nippard PPL Legs A
WITH d AS (
  SELECT wd.id FROM workout_days wd
  JOIN creator_workouts cw ON cw.id = wd.workout_id
  JOIN creators c ON c.id = cw.creator_id
  WHERE c.slug = 'jeff-nippard' AND cw.program_type = 'ppl' AND cw.days_per_week = 6 AND wd.day_number = 3
)
INSERT INTO workout_day_exercises (workout_day_id, exercise_name, order_index, sets, reps, rest_seconds, rpe_guidance, notes)
SELECT d.id, 'Barbell Back Squat',   0, 4, '4–6',  210, '8–9 RPE', 'Hip crease below parallel. Brace core.' FROM d UNION ALL
SELECT d.id, 'Leg Press',            1, 3, '10–12',120, '8 RPE',   'Feet shoulder width. Full range.' FROM d UNION ALL
SELECT d.id, 'Leg Extension',        2, 3, '12–15',90,  '8 RPE',   'Pause at top. Slow eccentric.' FROM d UNION ALL
SELECT d.id, 'Lying Leg Curl',       3, 3, '10–12',90,  '8 RPE',   'Full stretch. Flex at top.' FROM d UNION ALL
SELECT d.id, 'Seated Calf Raise',    4, 4, '12–15',60,  '8 RPE',   'Full range. Pause at bottom stretch.' FROM d;

-- ─────────────────────────────────────────────────────────
-- Workout Days — Arnold Split
-- ─────────────────────────────────────────────────────────
WITH w AS (
  SELECT cw.id FROM creator_workouts cw
  JOIN creators c ON c.id = cw.creator_id
  WHERE c.slug = 'arnold-schwarzenegger'
)
INSERT INTO workout_days (workout_id, day_number, name, focus, notes, order_index)
SELECT w.id, 1, 'Chest & Back',       'Chest / Back', 'Antagonist superset pairs. High volume.',    0 FROM w UNION ALL
SELECT w.id, 2, 'Shoulders & Arms',   'Delts / Biceps / Triceps', 'High rep pump work after heavy presses.', 1 FROM w UNION ALL
SELECT w.id, 3, 'Legs',               'Quads / Hamstrings / Calves', 'Full leg day. High rep squats.', 2 FROM w UNION ALL
SELECT w.id, 4, 'Chest & Back (B)',   'Chest / Back', 'Second session with incline emphasis.',      3 FROM w UNION ALL
SELECT w.id, 5, 'Shoulders & Arms (B)','Delts / Biceps / Triceps', 'Alternate exercise selection.',   4 FROM w UNION ALL
SELECT w.id, 6, 'Legs (B)',           'Quads / Hamstrings / Calves', 'Leg press and hack squat focus.', 5 FROM w;

-- Arnold Chest & Back exercises
WITH d AS (
  SELECT wd.id FROM workout_days wd
  JOIN creator_workouts cw ON cw.id = wd.workout_id
  JOIN creators c ON c.id = cw.creator_id
  WHERE c.slug = 'arnold-schwarzenegger' AND wd.day_number = 1
)
INSERT INTO workout_day_exercises (workout_day_id, exercise_name, order_index, sets, reps, rest_seconds, notes, is_superset, superset_group)
SELECT d.id, 'Barbell Bench Press',  0, 4, '8–12', 90,  'As described in Arnold''s public writings.',     true, 1 FROM d UNION ALL
SELECT d.id, 'Wide-Grip Pull-Up',    1, 4, '8–12', 90,  'Superset with bench for chest/back pump.',       true, 1 FROM d UNION ALL
SELECT d.id, 'Incline Dumbbell Press',2,3, '10–15',75,  'Incline for upper chest.',                       true, 2 FROM d UNION ALL
SELECT d.id, 'Barbell Row',          3, 3, '10–15',75,  'Superset with incline press.',                   true, 2 FROM d UNION ALL
SELECT d.id, 'Dumbbell Fly',         4, 3, '12–15',60,  'Stretch focus.',                                 false,NULL FROM d UNION ALL
SELECT d.id, 'Cable Row',            5, 3, '12–15',60,  'Squeeze at contraction.',                        false,NULL FROM d;

-- ─────────────────────────────────────────────────────────
-- Workout Days — Mike Mentzer HIT
-- ─────────────────────────────────────────────────────────
WITH w AS (
  SELECT cw.id FROM creator_workouts cw
  JOIN creators c ON c.id = cw.creator_id
  WHERE c.slug = 'mike-mentzer'
)
INSERT INTO workout_days (workout_id, day_number, name, focus, notes, order_index)
SELECT w.id, 1, 'Chest & Back',    'Chest / Back',
  'One or two all-out sets per exercise taken to absolute failure. Rest 3+ minutes between exercises.',
  0 FROM w UNION ALL
SELECT w.id, 2, 'Legs',           'Quads / Hamstrings / Calves',
  'Pre-exhaust with isolation before compound. 1–2 sets only.',
  1 FROM w UNION ALL
SELECT w.id, 3, 'Shoulders & Arms','Delts / Biceps / Triceps',
  'Maximum effort each set. No partial reps.',
  2 FROM w UNION ALL
SELECT w.id, 4, 'Rest', 'Active Recovery', 'Full rest day. No training.', 3 FROM w;

WITH d AS (
  SELECT wd.id FROM workout_days wd
  JOIN creator_workouts cw ON cw.id = wd.workout_id
  JOIN creators c ON c.id = cw.creator_id
  WHERE c.slug = 'mike-mentzer' AND wd.day_number = 1
)
INSERT INTO workout_day_exercises (workout_day_id, exercise_name, order_index, sets, reps, rest_seconds, rpe_guidance, notes)
SELECT d.id, 'Pec Deck / Chest Fly', 0, 1, '6–10',  180, '10 RPE', 'Pre-exhaust. Take to absolute failure.' FROM d UNION ALL
SELECT d.id, 'Barbell Bench Press',  1, 1, '6–10',  210, '10 RPE', 'Immediately after pre-exhaust. Failure required.' FROM d UNION ALL
SELECT d.id, 'Barbell Row',          2, 1, '6–10',  210, '10 RPE', 'Full range. Pull to waist.' FROM d UNION ALL
SELECT d.id, 'Lat Pulldown',         3, 1, '6–10',  180, '10 RPE', 'Behind neck variation or front — personal preference.' FROM d;
