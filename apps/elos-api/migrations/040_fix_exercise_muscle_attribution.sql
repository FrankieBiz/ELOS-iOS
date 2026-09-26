-- 040_fix_exercise_muscle_attribution.sql
--
-- Corrects exercise → muscle attribution, which drives every muscle-coverage bar and the
-- workout-quality score. Two classes of change:
--
--   1. FIX. Hinge movements listed a secondary muscle of 'back'. That is a region, not a muscle,
--      and it resolves to the UPPER back (traps/rhomboids) — but a deadlift's spinal load is borne
--      by the erectors. Every deadlift variant was therefore crediting the wrong muscle, and the
--      erectors received nothing: a full push/pull/legs week containing both squats and RDLs
--      scored 0 sets of lower back. All 'back' references are now 'lower_back' (or 'traps' where
--      the upper back genuinely is the target).
--
--   2. ENRICH. 46% of exercises carried 0 or 1 secondary muscles, with a hard ceiling of 3 that
--      looks like an authoring cap rather than anatomy. Applied by movement family so the catalog
--      stays internally consistent:
--        deadlifts      + lower_back, forearms, traps   (erectors, grip, shoulder girdle)
--        vertical pulls + traps, forearms
--        rows           + traps, rhomboids, forearms
--        overhead press + side_delts, traps, core
--        loaded squats  + lower_back, adductors
--        carries        + forearms, traps, core
--
-- Deliberately NOT touched: presses such as the bench (chest + triceps + front_delts is already
-- correct). Adding stabilisers indiscriminately would inflate volume without improving accuracy.
--
-- Measured effect on a representative PPL week: prime movers (chest, quads, hamstrings, lats,
-- biceps, triceps, glutes, calves) are unchanged, so the volume landmarks in TrainingScience.swift
-- stay valid. The added volume lands on the assisting muscles that were previously under-counted:
-- lower_back 0 → 3.5, forearms 1.5 → 7.0, upper back 5.0 → 8.5.
--
-- Also inserts the 56 exercises that existed only in the iOS seed, so the server becomes the
-- superset and the two catalogs stop drifting.

BEGIN;

-- 1 + 2: corrections to existing rows (128 exercises)
UPDATE exercise_definitions SET primary_muscle = 'chest', secondary_muscles = '{triceps,front_delts}' WHERE lower(name) = lower('Cable Squeeze Press') AND owner_id IS NULL AND is_custom = false;
UPDATE exercise_definitions SET primary_muscle = 'chest', secondary_muscles = '{triceps,front_delts}' WHERE lower(name) = lower('Hex Press') AND owner_id IS NULL AND is_custom = false;
UPDATE exercise_definitions SET primary_muscle = 'lats', secondary_muscles = '{biceps,rear_delts,traps,forearms}' WHERE lower(name) = lower('Pull-Up') AND owner_id IS NULL AND is_custom = false;
UPDATE exercise_definitions SET primary_muscle = 'biceps', secondary_muscles = '{lats,rear_delts,traps,forearms}' WHERE lower(name) = lower('Chin-Up') AND owner_id IS NULL AND is_custom = false;
UPDATE exercise_definitions SET primary_muscle = 'lats', secondary_muscles = '{biceps,rear_delts,traps,forearms}' WHERE lower(name) = lower('Wide-Grip Pull-Up') AND owner_id IS NULL AND is_custom = false;
UPDATE exercise_definitions SET primary_muscle = 'lats', secondary_muscles = '{biceps,brachialis,traps,forearms}' WHERE lower(name) = lower('Neutral-Grip Pull-Up') AND owner_id IS NULL AND is_custom = false;
UPDATE exercise_definitions SET primary_muscle = 'lats', secondary_muscles = '{biceps,rear_delts,traps,rhomboids,forearms}' WHERE lower(name) = lower('Inverted Row') AND owner_id IS NULL AND is_custom = false;
UPDATE exercise_definitions SET primary_muscle = 'lats', secondary_muscles = '{biceps,rear_delts,traps,rhomboids,forearms}' WHERE lower(name) = lower('Barbell Row') AND owner_id IS NULL AND is_custom = false;
UPDATE exercise_definitions SET primary_muscle = 'lats', secondary_muscles = '{biceps,rear_delts,traps,rhomboids,forearms}' WHERE lower(name) = lower('Pendlay Row') AND owner_id IS NULL AND is_custom = false;
UPDATE exercise_definitions SET primary_muscle = 'lats', secondary_muscles = '{biceps,rear_delts,traps,rhomboids,forearms}' WHERE lower(name) = lower('Yates Row') AND owner_id IS NULL AND is_custom = false;
UPDATE exercise_definitions SET primary_muscle = 'lats', secondary_muscles = '{biceps,rear_delts,traps,rhomboids,forearms}' WHERE lower(name) = lower('Seal Row') AND owner_id IS NULL AND is_custom = false;
UPDATE exercise_definitions SET primary_muscle = 'lats', secondary_muscles = '{biceps,rear_delts,traps,rhomboids,forearms}' WHERE lower(name) = lower('Meadows Row') AND owner_id IS NULL AND is_custom = false;
UPDATE exercise_definitions SET primary_muscle = 'lats', secondary_muscles = '{biceps,rear_delts,traps,rhomboids,forearms}' WHERE lower(name) = lower('T-Bar Row') AND owner_id IS NULL AND is_custom = false;
UPDATE exercise_definitions SET primary_muscle = 'lats', secondary_muscles = '{biceps,rear_delts,traps,rhomboids,forearms}' WHERE lower(name) = lower('Barbell Incline Row') AND owner_id IS NULL AND is_custom = false;
UPDATE exercise_definitions SET primary_muscle = 'rear_delts', secondary_muscles = '{traps,rhomboids,forearms}' WHERE lower(name) = lower('Barbell Rear Delt Row') AND owner_id IS NULL AND is_custom = false;
UPDATE exercise_definitions SET primary_muscle = 'lats', secondary_muscles = '{biceps,rear_delts,traps,rhomboids,forearms}' WHERE lower(name) = lower('One-Arm Dumbbell Row') AND owner_id IS NULL AND is_custom = false;
UPDATE exercise_definitions SET primary_muscle = 'lats', secondary_muscles = '{biceps,rear_delts,traps,rhomboids,forearms}' WHERE lower(name) = lower('Dumbbell Row') AND owner_id IS NULL AND is_custom = false;
UPDATE exercise_definitions SET primary_muscle = 'lats', secondary_muscles = '{biceps,rear_delts,traps,rhomboids,forearms}' WHERE lower(name) = lower('Kroc Row') AND owner_id IS NULL AND is_custom = false;
UPDATE exercise_definitions SET primary_muscle = 'lats', secondary_muscles = '{core,rear_delts,traps,rhomboids,forearms}' WHERE lower(name) = lower('Renegade Row') AND owner_id IS NULL AND is_custom = false;
UPDATE exercise_definitions SET primary_muscle = 'lats', secondary_muscles = '{rear_delts,biceps,traps,rhomboids,forearms}' WHERE lower(name) = lower('Double Dumbbell Row') AND owner_id IS NULL AND is_custom = false;
UPDATE exercise_definitions SET primary_muscle = 'lats', secondary_muscles = '{rear_delts,biceps,traps,rhomboids,forearms}' WHERE lower(name) = lower('Dumbbell Incline Row') AND owner_id IS NULL AND is_custom = false;
UPDATE exercise_definitions SET primary_muscle = 'rear_delts', secondary_muscles = '{traps,rhomboids,forearms}' WHERE lower(name) = lower('Dumbbell Chest-Supported Rear Delt Row') AND owner_id IS NULL AND is_custom = false;
UPDATE exercise_definitions SET primary_muscle = 'rear_delts', secondary_muscles = '{traps,biceps,rhomboids,forearms}' WHERE lower(name) = lower('Dumbbell Rear Delt Row') AND owner_id IS NULL AND is_custom = false;
UPDATE exercise_definitions SET primary_muscle = 'lats', secondary_muscles = '{biceps,rear_delts,traps,rhomboids,forearms}' WHERE lower(name) = lower('Cable Row') AND owner_id IS NULL AND is_custom = false;
UPDATE exercise_definitions SET primary_muscle = 'lats', secondary_muscles = '{biceps,rear_delts,traps,rhomboids,forearms}' WHERE lower(name) = lower('Seated Cable Row') AND owner_id IS NULL AND is_custom = false;
UPDATE exercise_definitions SET primary_muscle = 'lats', secondary_muscles = '{biceps,rear_delts,traps,rhomboids,forearms}' WHERE lower(name) = lower('Single-Arm Cable Row') AND owner_id IS NULL AND is_custom = false;
UPDATE exercise_definitions SET primary_muscle = 'lats', secondary_muscles = '{rear_delts,biceps,traps,rhomboids,forearms}' WHERE lower(name) = lower('High Cable Row') AND owner_id IS NULL AND is_custom = false;
UPDATE exercise_definitions SET primary_muscle = 'lats', secondary_muscles = '{rear_delts,biceps,traps,rhomboids,forearms}' WHERE lower(name) = lower('Single-Arm High Cable Row') AND owner_id IS NULL AND is_custom = false;
UPDATE exercise_definitions SET primary_muscle = 'lats', secondary_muscles = '{rear_delts,biceps,traps,rhomboids,forearms}' WHERE lower(name) = lower('Half-Kneeling Cable Row') AND owner_id IS NULL AND is_custom = false;
UPDATE exercise_definitions SET primary_muscle = 'lats', secondary_muscles = '{biceps,rear_delts,traps,rhomboids,forearms}' WHERE lower(name) = lower('Close-Grip Cable Row') AND owner_id IS NULL AND is_custom = false;
UPDATE exercise_definitions SET primary_muscle = 'lats', secondary_muscles = '{rear_delts,traps,rhomboids,forearms}' WHERE lower(name) = lower('Wide-Grip Cable Row') AND owner_id IS NULL AND is_custom = false;
UPDATE exercise_definitions SET primary_muscle = 'lats', secondary_muscles = '{biceps,rear_delts,traps,rhomboids,forearms}' WHERE lower(name) = lower('Supinated Cable Row') AND owner_id IS NULL AND is_custom = false;
UPDATE exercise_definitions SET primary_muscle = 'lats', secondary_muscles = '{rear_delts,biceps,traps,rhomboids,forearms}' WHERE lower(name) = lower('Cable Prone Row') AND owner_id IS NULL AND is_custom = false;
UPDATE exercise_definitions SET primary_muscle = 'lats', secondary_muscles = '{biceps,rear_delts,traps,forearms}' WHERE lower(name) = lower('Kneeling Lat Pulldown') AND owner_id IS NULL AND is_custom = false;
UPDATE exercise_definitions SET primary_muscle = 'lats', secondary_muscles = '{biceps,traps,forearms,rear_delts}' WHERE lower(name) = lower('Single-Arm Cable Lat Pulldown') AND owner_id IS NULL AND is_custom = false;
UPDATE exercise_definitions SET primary_muscle = 'hamstrings', secondary_muscles = '{glutes,traps,lower_back,forearms}' WHERE lower(name) = lower('Cable Deadlift') AND owner_id IS NULL AND is_custom = false;
UPDATE exercise_definitions SET primary_muscle = 'lats', secondary_muscles = '{biceps,rear_delts,traps,forearms}' WHERE lower(name) = lower('Lat Pulldown') AND owner_id IS NULL AND is_custom = false;
UPDATE exercise_definitions SET primary_muscle = 'lats', secondary_muscles = '{biceps,traps,forearms,rear_delts}' WHERE lower(name) = lower('Reverse-Grip Lat Pulldown') AND owner_id IS NULL AND is_custom = false;
UPDATE exercise_definitions SET primary_muscle = 'lats', secondary_muscles = '{biceps,rear_delts,traps,forearms}' WHERE lower(name) = lower('Close-Grip Lat Pulldown') AND owner_id IS NULL AND is_custom = false;
UPDATE exercise_definitions SET primary_muscle = 'lats', secondary_muscles = '{biceps,traps,forearms,rear_delts}' WHERE lower(name) = lower('V-Bar Pulldown') AND owner_id IS NULL AND is_custom = false;
UPDATE exercise_definitions SET primary_muscle = 'lats', secondary_muscles = '{biceps,rear_delts,traps,rhomboids,forearms}' WHERE lower(name) = lower('Chest-Supported Row') AND owner_id IS NULL AND is_custom = false;
UPDATE exercise_definitions SET primary_muscle = 'lats', secondary_muscles = '{biceps,rear_delts,traps,forearms}' WHERE lower(name) = lower('Assisted Pull-Up') AND owner_id IS NULL AND is_custom = false;
UPDATE exercise_definitions SET primary_muscle = 'hamstrings', secondary_muscles = '{glutes,lower_back,forearms,traps}' WHERE lower(name) = lower('Good Morning') AND owner_id IS NULL AND is_custom = false;
UPDATE exercise_definitions SET primary_muscle = 'lower_back', secondary_muscles = '{glutes,hamstrings,traps,forearms}' WHERE lower(name) = lower('Rack Pull') AND owner_id IS NULL AND is_custom = false;
UPDATE exercise_definitions SET primary_muscle = 'hamstrings', secondary_muscles = '{glutes,traps,lower_back,forearms}' WHERE lower(name) = lower('Snatch-Grip Deadlift') AND owner_id IS NULL AND is_custom = false;
UPDATE exercise_definitions SET primary_muscle = 'hamstrings', secondary_muscles = '{glutes,lower_back,forearms,traps}' WHERE lower(name) = lower('Deficit Deadlift') AND owner_id IS NULL AND is_custom = false;
UPDATE exercise_definitions SET primary_muscle = 'front_delts', secondary_muscles = '{triceps,upper_chest,side_delts,traps,core}' WHERE lower(name) = lower('Barbell Overhead Press') AND owner_id IS NULL AND is_custom = false;
UPDATE exercise_definitions SET primary_muscle = 'front_delts', secondary_muscles = '{triceps,side_delts}' WHERE lower(name) = lower('Seated Barbell Press') AND owner_id IS NULL AND is_custom = false;
UPDATE exercise_definitions SET primary_muscle = 'front_delts', secondary_muscles = '{triceps,quads,side_delts,traps,core}' WHERE lower(name) = lower('Push Press') AND owner_id IS NULL AND is_custom = false;
UPDATE exercise_definitions SET primary_muscle = 'front_delts', secondary_muscles = '{triceps,core,side_delts,traps}' WHERE lower(name) = lower('Z-Press') AND owner_id IS NULL AND is_custom = false;
UPDATE exercise_definitions SET primary_muscle = 'front_delts', secondary_muscles = '{triceps,upper_chest,side_delts,traps,core}' WHERE lower(name) = lower('Dumbbell Shoulder Press') AND owner_id IS NULL AND is_custom = false;
UPDATE exercise_definitions SET primary_muscle = 'front_delts', secondary_muscles = '{side_delts,triceps,traps,core}' WHERE lower(name) = lower('Arnold Press') AND owner_id IS NULL AND is_custom = false;
UPDATE exercise_definitions SET primary_muscle = 'front_delts', secondary_muscles = '{triceps,side_delts}' WHERE lower(name) = lower('Seated Dumbbell Press') AND owner_id IS NULL AND is_custom = false;
UPDATE exercise_definitions SET primary_muscle = 'front_delts', secondary_muscles = '{triceps,side_delts,traps,core}' WHERE lower(name) = lower('Machine Shoulder Press') AND owner_id IS NULL AND is_custom = false;
UPDATE exercise_definitions SET primary_muscle = 'front_delts', secondary_muscles = '{triceps,side_delts,traps,core}' WHERE lower(name) = lower('Smith Shoulder Press') AND owner_id IS NULL AND is_custom = false;
UPDATE exercise_definitions SET primary_muscle = 'front_delts', secondary_muscles = '{triceps,side_delts,traps,core}' WHERE lower(name) = lower('Handstand Push-Up') AND owner_id IS NULL AND is_custom = false;
UPDATE exercise_definitions SET primary_muscle = 'front_delts', secondary_muscles = '{triceps,upper_chest,side_delts,traps,core}' WHERE lower(name) = lower('Pike Push-Up') AND owner_id IS NULL AND is_custom = false;
UPDATE exercise_definitions SET primary_muscle = 'front_delts', secondary_muscles = '{triceps,side_delts,traps,core}' WHERE lower(name) = lower('Cable Shoulder Press') AND owner_id IS NULL AND is_custom = false;
UPDATE exercise_definitions SET primary_muscle = 'front_delts', secondary_muscles = '{core,triceps,side_delts,traps}' WHERE lower(name) = lower('Half-Kneeling Cable Shoulder Press') AND owner_id IS NULL AND is_custom = false;
UPDATE exercise_definitions SET primary_muscle = 'triceps', secondary_muscles = '{front_delts,lower_chest}' WHERE lower(name) = lower('Bench Dip') AND owner_id IS NULL AND is_custom = false;
UPDATE exercise_definitions SET primary_muscle = 'forearms', secondary_muscles = '{traps,core}' WHERE lower(name) = lower('Plate Pinch') AND owner_id IS NULL AND is_custom = false;
UPDATE exercise_definitions SET primary_muscle = 'quads', secondary_muscles = '{glutes,hamstrings,core,lower_back,adductors}' WHERE lower(name) = lower('Barbell Back Squat') AND owner_id IS NULL AND is_custom = false;
UPDATE exercise_definitions SET primary_muscle = 'quads', secondary_muscles = '{glutes,core,lower_back,adductors}' WHERE lower(name) = lower('Front Squat') AND owner_id IS NULL AND is_custom = false;
UPDATE exercise_definitions SET primary_muscle = 'quads', secondary_muscles = '{glutes,hamstrings,lower_back,adductors}' WHERE lower(name) = lower('Box Squat') AND owner_id IS NULL AND is_custom = false;
UPDATE exercise_definitions SET primary_muscle = 'quads', secondary_muscles = '{glutes,hamstrings,lower_back,adductors}' WHERE lower(name) = lower('Pause Squat') AND owner_id IS NULL AND is_custom = false;
UPDATE exercise_definitions SET primary_muscle = 'quads', secondary_muscles = '{glutes,lower_back,adductors,hamstrings}' WHERE lower(name) = lower('Cyclist Squat') AND owner_id IS NULL AND is_custom = false;
UPDATE exercise_definitions SET primary_muscle = 'quads', secondary_muscles = '{glutes,core,front_delts,lower_back,adductors}' WHERE lower(name) = lower('Overhead Squat') AND owner_id IS NULL AND is_custom = false;
UPDATE exercise_definitions SET primary_muscle = 'quads', secondary_muscles = '{glutes,core,biceps,lower_back,adductors}' WHERE lower(name) = lower('Zercher Squat') AND owner_id IS NULL AND is_custom = false;
UPDATE exercise_definitions SET primary_muscle = 'quads', secondary_muscles = '{glutes,hamstrings,lower_back,adductors}' WHERE lower(name) = lower('Hatfield Squat') AND owner_id IS NULL AND is_custom = false;
UPDATE exercise_definitions SET primary_muscle = 'quads', secondary_muscles = '{glutes,hamstrings,lower_back,adductors}' WHERE lower(name) = lower('Barbell Lunge') AND owner_id IS NULL AND is_custom = false;
UPDATE exercise_definitions SET primary_muscle = 'glutes', secondary_muscles = '{quads,hamstrings,lower_back,adductors}' WHERE lower(name) = lower('Barbell Reverse Lunge') AND owner_id IS NULL AND is_custom = false;
UPDATE exercise_definitions SET primary_muscle = 'quads', secondary_muscles = '{glutes,lower_back,adductors}' WHERE lower(name) = lower('Barbell Step-Up') AND owner_id IS NULL AND is_custom = false;
UPDATE exercise_definitions SET primary_muscle = 'quads', secondary_muscles = '{glutes,hamstrings,lower_back,adductors}' WHERE lower(name) = lower('Barbell Bulgarian Split Squat') AND owner_id IS NULL AND is_custom = false;
UPDATE exercise_definitions SET primary_muscle = 'quads', secondary_muscles = '{glutes,hamstrings,lower_back,adductors}' WHERE lower(name) = lower('Barbell Split Squat') AND owner_id IS NULL AND is_custom = false;
UPDATE exercise_definitions SET primary_muscle = 'quads', secondary_muscles = '{glutes,core,lower_back,adductors}' WHERE lower(name) = lower('Goblet Squat') AND owner_id IS NULL AND is_custom = false;
UPDATE exercise_definitions SET primary_muscle = 'quads', secondary_muscles = '{glutes,hamstrings,lower_back,adductors}' WHERE lower(name) = lower('Dumbbell Lunges') AND owner_id IS NULL AND is_custom = false;
UPDATE exercise_definitions SET primary_muscle = 'quads', secondary_muscles = '{glutes,hamstrings,lower_back,adductors}' WHERE lower(name) = lower('Walking Lunge') AND owner_id IS NULL AND is_custom = false;
UPDATE exercise_definitions SET primary_muscle = 'glutes', secondary_muscles = '{quads,hamstrings,lower_back,adductors}' WHERE lower(name) = lower('Reverse Lunge') AND owner_id IS NULL AND is_custom = false;
UPDATE exercise_definitions SET primary_muscle = 'glutes', secondary_muscles = '{quads,hamstrings,lower_back,adductors}' WHERE lower(name) = lower('Dumbbell Reverse Lunge') AND owner_id IS NULL AND is_custom = false;
UPDATE exercise_definitions SET primary_muscle = 'quads', secondary_muscles = '{glutes,lower_back,adductors}' WHERE lower(name) = lower('Step-Up') AND owner_id IS NULL AND is_custom = false;
UPDATE exercise_definitions SET primary_muscle = 'quads', secondary_muscles = '{glutes,lower_back,adductors}' WHERE lower(name) = lower('Dumbbell Step-Up') AND owner_id IS NULL AND is_custom = false;
UPDATE exercise_definitions SET primary_muscle = 'quads', secondary_muscles = '{glutes,hamstrings,lower_back,adductors}' WHERE lower(name) = lower('Bulgarian Split Squat') AND owner_id IS NULL AND is_custom = false;
UPDATE exercise_definitions SET primary_muscle = 'quads', secondary_muscles = '{glutes,hamstrings,lower_back,adductors}' WHERE lower(name) = lower('Dumbbell Bulgarian Split Squat') AND owner_id IS NULL AND is_custom = false;
UPDATE exercise_definitions SET primary_muscle = 'adductors', secondary_muscles = '{quads,glutes,lower_back}' WHERE lower(name) = lower('Lateral Lunge') AND owner_id IS NULL AND is_custom = false;
UPDATE exercise_definitions SET primary_muscle = 'adductors', secondary_muscles = '{quads,glutes,lower_back}' WHERE lower(name) = lower('Dumbbell Lateral Lunge') AND owner_id IS NULL AND is_custom = false;
UPDATE exercise_definitions SET primary_muscle = 'glutes', secondary_muscles = '{quads,adductors,lower_back}' WHERE lower(name) = lower('Curtsy Lunge') AND owner_id IS NULL AND is_custom = false;
UPDATE exercise_definitions SET primary_muscle = 'quads', secondary_muscles = '{glutes,core,lower_back,adductors}' WHERE lower(name) = lower('Dumbbell Front Squat') AND owner_id IS NULL AND is_custom = false;
UPDATE exercise_definitions SET primary_muscle = 'quads', secondary_muscles = '{glutes,hamstrings,lower_back,adductors}' WHERE lower(name) = lower('Dumbbell Box Squat') AND owner_id IS NULL AND is_custom = false;
UPDATE exercise_definitions SET primary_muscle = 'quads', secondary_muscles = '{glutes,core,lower_back,adductors}' WHERE lower(name) = lower('Cable Squat') AND owner_id IS NULL AND is_custom = false;
UPDATE exercise_definitions SET primary_muscle = 'quads', secondary_muscles = '{glutes,hamstrings,lower_back,adductors}' WHERE lower(name) = lower('Cable Lunge') AND owner_id IS NULL AND is_custom = false;
UPDATE exercise_definitions SET primary_muscle = 'glutes', secondary_muscles = '{quads,hamstrings,lower_back,adductors}' WHERE lower(name) = lower('Cable Reverse Lunge') AND owner_id IS NULL AND is_custom = false;
UPDATE exercise_definitions SET primary_muscle = 'quads', secondary_muscles = '{glutes,hamstrings,lower_back,adductors}' WHERE lower(name) = lower('Cable Step-Through Lunge') AND owner_id IS NULL AND is_custom = false;
UPDATE exercise_definitions SET primary_muscle = 'quads', secondary_muscles = '{glutes,lower_back,adductors,hamstrings}' WHERE lower(name) = lower('Hack Squat Machine') AND owner_id IS NULL AND is_custom = false;
UPDATE exercise_definitions SET primary_muscle = 'quads', secondary_muscles = '{glutes,hamstrings,lower_back,adductors}' WHERE lower(name) = lower('Smith Machine Squat') AND owner_id IS NULL AND is_custom = false;
UPDATE exercise_definitions SET primary_muscle = 'quads', secondary_muscles = '{glutes,lower_back,adductors,hamstrings}' WHERE lower(name) = lower('Belt Squat') AND owner_id IS NULL AND is_custom = false;
UPDATE exercise_definitions SET primary_muscle = 'quads', secondary_muscles = '{glutes,core,lower_back,adductors}' WHERE lower(name) = lower('Pistol Squat') AND owner_id IS NULL AND is_custom = false;
UPDATE exercise_definitions SET primary_muscle = 'quads', secondary_muscles = '{glutes,adductors,lower_back}' WHERE lower(name) = lower('Cossack Squat') AND owner_id IS NULL AND is_custom = false;
UPDATE exercise_definitions SET primary_muscle = 'quads', secondary_muscles = '{glutes,calves,lower_back,adductors}' WHERE lower(name) = lower('Jump Squat') AND owner_id IS NULL AND is_custom = false;
UPDATE exercise_definitions SET primary_muscle = 'hamstrings', secondary_muscles = '{glutes,lower_back,traps,forearms}' WHERE lower(name) = lower('Conventional Deadlift') AND owner_id IS NULL AND is_custom = false;
UPDATE exercise_definitions SET primary_muscle = 'hamstrings', secondary_muscles = '{glutes,lower_back,forearms,traps}' WHERE lower(name) = lower('Romanian Deadlift') AND owner_id IS NULL AND is_custom = false;
UPDATE exercise_definitions SET primary_muscle = 'glutes', secondary_muscles = '{hamstrings,quads,lower_back,forearms,traps}' WHERE lower(name) = lower('Sumo Deadlift') AND owner_id IS NULL AND is_custom = false;
UPDATE exercise_definitions SET primary_muscle = 'hamstrings', secondary_muscles = '{glutes,lower_back,forearms,traps}' WHERE lower(name) = lower('Stiff-Leg Deadlift') AND owner_id IS NULL AND is_custom = false;
UPDATE exercise_definitions SET primary_muscle = 'quads', secondary_muscles = '{glutes,hamstrings,traps,lower_back,forearms}' WHERE lower(name) = lower('Trap Bar Deadlift') AND owner_id IS NULL AND is_custom = false;
UPDATE exercise_definitions SET primary_muscle = 'quads', secondary_muscles = '{glutes,hamstrings,lower_back,forearms,traps}' WHERE lower(name) = lower('Jefferson Deadlift') AND owner_id IS NULL AND is_custom = false;
UPDATE exercise_definitions SET primary_muscle = 'hamstrings', secondary_muscles = '{glutes,core,lower_back,forearms,traps}' WHERE lower(name) = lower('Suitcase Deadlift') AND owner_id IS NULL AND is_custom = false;
UPDATE exercise_definitions SET primary_muscle = 'hamstrings', secondary_muscles = '{glutes,core,lower_back,forearms,traps}' WHERE lower(name) = lower('Staggered Stance Deadlift') AND owner_id IS NULL AND is_custom = false;
UPDATE exercise_definitions SET primary_muscle = 'hamstrings', secondary_muscles = '{glutes,core,lower_back,forearms,traps}' WHERE lower(name) = lower('Single-Leg Romanian Deadlift') AND owner_id IS NULL AND is_custom = false;
UPDATE exercise_definitions SET primary_muscle = 'hamstrings', secondary_muscles = '{glutes,lower_back,forearms,traps}' WHERE lower(name) = lower('Dumbbell Romanian Deadlift') AND owner_id IS NULL AND is_custom = false;
UPDATE exercise_definitions SET primary_muscle = 'hamstrings', secondary_muscles = '{glutes,lower_back,forearms,traps}' WHERE lower(name) = lower('Dumbbell Deadlift') AND owner_id IS NULL AND is_custom = false;
UPDATE exercise_definitions SET primary_muscle = 'glutes', secondary_muscles = '{quads,hamstrings,lower_back,forearms,traps}' WHERE lower(name) = lower('Dumbbell Sumo Deadlift') AND owner_id IS NULL AND is_custom = false;
UPDATE exercise_definitions SET primary_muscle = 'hamstrings', secondary_muscles = '{glutes,lower_back,forearms,traps}' WHERE lower(name) = lower('Dumbbell Stiff-Leg Deadlift') AND owner_id IS NULL AND is_custom = false;
UPDATE exercise_definitions SET primary_muscle = 'hamstrings', secondary_muscles = '{glutes,core,lower_back,forearms,traps}' WHERE lower(name) = lower('Dumbbell Staggered Stance RDL') AND owner_id IS NULL AND is_custom = false;
UPDATE exercise_definitions SET primary_muscle = 'hamstrings', secondary_muscles = '{glutes,lower_back,forearms,traps}' WHERE lower(name) = lower('Cable Romanian Deadlift') AND owner_id IS NULL AND is_custom = false;
UPDATE exercise_definitions SET primary_muscle = 'hamstrings', secondary_muscles = '{glutes,lower_back,forearms,traps}' WHERE lower(name) = lower('Cable Stiff-Leg Deadlift') AND owner_id IS NULL AND is_custom = false;
UPDATE exercise_definitions SET primary_muscle = 'hamstrings', secondary_muscles = '{glutes,lower_back,forearms,traps}' WHERE lower(name) = lower('Cable B-Stance Romanian Deadlift') AND owner_id IS NULL AND is_custom = false;
UPDATE exercise_definitions SET primary_muscle = 'glutes', secondary_muscles = '{hamstrings,core,lower_back}' WHERE lower(name) = lower('Barbell Hip Thrust') AND owner_id IS NULL AND is_custom = false;
UPDATE exercise_definitions SET primary_muscle = 'glutes', secondary_muscles = '{hamstrings,lower_back,core}' WHERE lower(name) = lower('B-Stance Hip Thrust') AND owner_id IS NULL AND is_custom = false;
UPDATE exercise_definitions SET primary_muscle = 'glutes', secondary_muscles = '{hamstrings,lower_back}' WHERE lower(name) = lower('Barbell Glute Bridge') AND owner_id IS NULL AND is_custom = false;
UPDATE exercise_definitions SET primary_muscle = 'glutes', secondary_muscles = '{hamstrings,core,lower_back}' WHERE lower(name) = lower('Hip Thrust') AND owner_id IS NULL AND is_custom = false;
UPDATE exercise_definitions SET primary_muscle = 'glutes', secondary_muscles = '{hamstrings,lower_back}' WHERE lower(name) = lower('Dumbbell Hip Thrust') AND owner_id IS NULL AND is_custom = false;
UPDATE exercise_definitions SET primary_muscle = 'glutes', secondary_muscles = '{hamstrings,core,lower_back}' WHERE lower(name) = lower('Single-Leg Dumbbell Hip Thrust') AND owner_id IS NULL AND is_custom = false;
UPDATE exercise_definitions SET primary_muscle = 'glutes', secondary_muscles = '{hamstrings,lower_back}' WHERE lower(name) = lower('Machine Hip Thrust') AND owner_id IS NULL AND is_custom = false;
UPDATE exercise_definitions SET primary_muscle = 'glutes', secondary_muscles = '{hamstrings,lower_back}' WHERE lower(name) = lower('Glute Bridge') AND owner_id IS NULL AND is_custom = false;
UPDATE exercise_definitions SET primary_muscle = 'glutes', secondary_muscles = '{hamstrings,core,lower_back}' WHERE lower(name) = lower('Single-Leg Glute Bridge') AND owner_id IS NULL AND is_custom = false;
UPDATE exercise_definitions SET primary_muscle = 'glutes', secondary_muscles = '{hamstrings,core,lower_back}' WHERE lower(name) = lower('Single-Leg Hip Thrust') AND owner_id IS NULL AND is_custom = false;
UPDATE exercise_definitions SET primary_muscle = 'core', secondary_muscles = '{glutes,forearms,traps}' WHERE lower(name) = lower('Plank') AND owner_id IS NULL AND is_custom = false;
UPDATE exercise_definitions SET primary_muscle = 'obliques', secondary_muscles = '{core,glutes,forearms,traps}' WHERE lower(name) = lower('Side Plank') AND owner_id IS NULL AND is_custom = false;
UPDATE exercise_definitions SET primary_muscle = 'core', secondary_muscles = '{glutes,front_delts,hip_flexors,forearms,traps}' WHERE lower(name) = lower('Dumbbell Turkish Get-Up') AND owner_id IS NULL AND is_custom = false;

-- 3: exercises previously missing from the server catalog
INSERT INTO exercise_definitions (name, primary_muscle, secondary_muscles, equipment, movement_pattern)
SELECT v.name, v.primary_muscle, v.secondary_muscles::text[], v.equipment, v.movement_pattern
FROM (VALUES
  ('Chest-Supported T-Bar Row', 'lats', '{biceps,rear_delts,traps,rhomboids,forearms}', 'barbell', 'pull'),
  ('T-Bar Row Machine', 'lats', '{biceps,rear_delts,traps,rhomboids,forearms}', 'machine', 'pull'),
  ('Spider Row', 'lats', '{biceps,rear_delts,traps,rhomboids,forearms}', 'dumbbell', 'pull'),
  ('Pec Deck Rear Delt Fly', 'rear_delts', '{traps}', 'machine', 'isolation'),
  ('Machine Shrug', 'traps', '{}', 'machine', 'isolation'),
  ('Smith Machine Shrug', 'traps', '{}', 'machine', 'isolation'),
  ('Behind-the-Back Barbell Shrug', 'traps', '{}', 'barbell', 'isolation'),
  ('Behind-the-Back Smith Shrug', 'traps', '{}', 'machine', 'isolation'),
  ('Kelso Shrug', 'traps', '{rear_delts,rhomboids}', 'barbell', 'isolation'),
  ('T-Bar Kelso Shrug', 'traps', '{rear_delts,rhomboids}', 'machine', 'isolation'),
  ('Barbell Hack Squat', 'quads', '{glutes,hamstrings,lower_back,adductors}', 'barbell', 'squat'),
  ('Landmine Press', 'front_delts', '{upper_chest,triceps,side_delts,traps,core}', 'barbell', 'push'),
  ('Single-Arm Landmine Press', 'front_delts', '{upper_chest,triceps,side_delts,traps,core}', 'barbell', 'push'),
  ('Kneeling Landmine Press', 'front_delts', '{core,triceps,side_delts,traps}', 'barbell', 'push'),
  ('Half-Kneeling Landmine Press', 'front_delts', '{core,triceps,side_delts,traps}', 'barbell', 'push'),
  ('Landmine Row', 'lats', '{biceps,rear_delts,traps,rhomboids,forearms}', 'barbell', 'pull'),
  ('Single-Arm Landmine Row', 'lats', '{biceps,rear_delts,traps,rhomboids,forearms}', 'barbell', 'pull'),
  ('Landmine Meadows Row', 'lats', '{biceps,rear_delts,traps,rhomboids,forearms}', 'barbell', 'pull'),
  ('Landmine Squat', 'quads', '{glutes,core,lower_back,adductors}', 'barbell', 'squat'),
  ('Landmine Goblet Squat', 'quads', '{glutes,core,lower_back,adductors}', 'barbell', 'squat'),
  ('Landmine Romanian Deadlift', 'hamstrings', '{glutes,lower_back,forearms,traps}', 'barbell', 'hinge'),
  ('Single-Leg Landmine RDL', 'hamstrings', '{glutes,core,lower_back,forearms,traps}', 'barbell', 'hinge'),
  ('Landmine Hip Thrust', 'glutes', '{hamstrings,lower_back}', 'barbell', 'hinge'),
  ('Landmine Lateral Raise', 'side_delts', '{}', 'barbell', 'isolation'),
  ('Landmine Shrug', 'traps', '{}', 'barbell', 'isolation'),
  ('Landmine Twist', 'obliques', '{core}', 'barbell', 'rotation'),
  ('Landmine Anti-Rotation Press', 'obliques', '{core}', 'barbell', 'rotation'),
  ('Kettlebell Goblet Squat', 'quads', '{glutes,core,lower_back,adductors}', 'kettlebell', 'squat'),
  ('Kettlebell Front Squat', 'quads', '{glutes,core,lower_back,adductors}', 'kettlebell', 'squat'),
  ('Kettlebell Lunge', 'quads', '{glutes,hamstrings,lower_back,adductors}', 'kettlebell', 'squat'),
  ('Kettlebell Reverse Lunge', 'glutes', '{quads,hamstrings,lower_back,adductors}', 'kettlebell', 'squat'),
  ('Kettlebell Clean', 'traps', '{quads,glutes,hamstrings}', 'kettlebell', 'pull'),
  ('Kettlebell Clean And Press', 'front_delts', '{quads,glutes,triceps}', 'kettlebell', 'push'),
  ('Kettlebell Snatch', 'traps', '{quads,glutes,front_delts}', 'kettlebell', 'pull'),
  ('Kettlebell Turkish Get-Up', 'core', '{glutes,front_delts,hip_flexors,forearms,traps}', 'kettlebell', 'carry'),
  ('Kettlebell Row', 'lats', '{biceps,rear_delts,traps,rhomboids,forearms}', 'kettlebell', 'pull'),
  ('Kettlebell Single-Arm Row', 'lats', '{biceps,rear_delts,traps,rhomboids,forearms}', 'kettlebell', 'pull'),
  ('Kettlebell Overhead Press', 'front_delts', '{triceps,core,side_delts,traps}', 'kettlebell', 'push'),
  ('Kettlebell Windmill', 'obliques', '{core,hamstrings}', 'kettlebell', 'isolation'),
  ('Kettlebell Farmer''s Walk', 'traps', '{core,forearms}', 'kettlebell', 'carry'),
  ('Cable Front Squat', 'quads', '{glutes,core,lower_back,adductors}', 'cable', 'squat'),
  ('Cable Lateral Lunge', 'adductors', '{quads,glutes,lower_back}', 'cable', 'squat'),
  ('Cable Step-Up', 'quads', '{glutes,lower_back,adductors}', 'cable', 'squat'),
  ('Cable Hip Thrust', 'glutes', '{hamstrings,lower_back}', 'cable', 'hinge'),
  ('Cable Good Morning', 'hamstrings', '{lower_back,glutes,forearms,traps}', 'cable', 'hinge'),
  ('Cable Standing Leg Extension', 'quads', '{}', 'cable', 'isolation'),
  ('Cable Forward Lunge', 'quads', '{glutes,hamstrings,lower_back,adductors}', 'cable', 'squat'),
  ('Kneeling Pallof Press', 'obliques', '{core}', 'cable', 'rotation'),
  ('Cable Reverse Crunch', 'abs', '{hip_flexors}', 'cable', 'isolation'),
  ('Cable Decline Press', 'lower_chest', '{triceps,front_delts}', 'cable', 'push'),
  ('Cable Pullover', 'lats', '{triceps,traps,forearms}', 'cable', 'pull'),
  ('Shotgun Row', 'lats', '{biceps,rear_delts,traps,rhomboids,forearms}', 'cable', 'pull'),
  ('Cable Row To Triceps Extension', 'lats', '{triceps,biceps,traps,rhomboids,forearms}', 'cable', 'pull'),
  ('Cable Thruster', 'quads', '{front_delts,glutes,triceps}', 'cable', 'push'),
  ('Cable Split Squat To Press', 'quads', '{front_delts,glutes}', 'cable', 'push'),
  ('Cable Farmer Walk', 'traps', '{core,forearms}', 'cable', 'carry')
) AS v(name, primary_muscle, secondary_muscles, equipment, movement_pattern)
WHERE NOT EXISTS (
  SELECT 1 FROM exercise_definitions e
  WHERE lower(e.name) = lower(v.name) AND e.owner_id IS NULL AND e.is_custom = false
);

COMMIT;
