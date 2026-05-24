-- Seed machine_models for every brand, so brand filtering returns meaningful results.
-- Subqueries resolve machine_id and brand_id by slug to keep this declarative.

INSERT INTO machine_models (machine_id, brand_id, model_name, equipment_type, rep_range_rec, form_cues, beginner_tips)
SELECT m.id, b.id, model_name, equipment_type, rep_range_rec, form_cues, beginner_tips
FROM (VALUES
  -- ── Seated Chest Press ──
  ('seated-chest-press',      'life-fitness',     'Insignia Series Chest Press',      'selectorized', '8-12', ARRAY['Squeeze chest at lockout','Keep shoulders pinned to pad'], ARRAY['Start with low weight to learn the path']),
  ('seated-chest-press',      'hammer-strength',  'Iso-Lateral Chest Press',          'plate_loaded', '6-12', ARRAY['Drive evenly through both arms','Brace the back against the pad'], ARRAY['Start with one plate per side']),
  ('seated-chest-press',      'hoist',            'HD-3700 Chest Press',              'selectorized', '8-12', ARRAY['Maintain neutral wrists'], ARRAY['Adjust seat so handles align with mid-chest']),
  ('seated-chest-press',      'matrix',           'Aura Chest Press',                 'selectorized', '8-15', ARRAY['Control eccentric'], ARRAY['Use the converging path for natural arc']),

  -- ── Plate-Loaded Chest Press ──
  ('plate-chest-press',       'hammer-strength',  'MTS Iso-Lateral Decline Press',    'plate_loaded', '6-10', ARRAY['Initiate with chest, not delts'], ARRAY['Asymmetric loading allowed for unilateral focus']),
  ('plate-chest-press',       'cybex',            'Eagle NX Chest Press',             'plate_loaded', '6-12', ARRAY['Pause at chest for tension'], ARRAY['Counterweighted for smoother return']),
  ('plate-chest-press',       'atlantis',         'Precision Plate Chest Press',      'plate_loaded', '6-12', ARRAY['Keep elbows tucked ~45°'], ARRAY['Adjust foot pedal to assist lift-off']),

  -- ── Incline Chest Press ──
  ('incline-chest-press',     'life-fitness',     'Signature Series Incline Press',   'selectorized', '8-12', ARRAY['Focus on upper chest fibers'], ARRAY['Pull shoulders down and back']),
  ('incline-chest-press',     'hammer-strength',  'Iso-Lateral Incline Press',        'plate_loaded', '6-12', ARRAY['Press up and slightly together'], ARRAY['Settle into seat before unracking']),
  ('incline-chest-press',     'cybex',            'Eagle NX Incline Press',           'selectorized', '8-12', ARRAY['Stop at mid-chest'], ARRAY['Don''t over-extend at lockout']),

  -- ── Pec Deck ──
  ('pec-deck',                'life-fitness',     'Signature Series Pec Fly',         'selectorized', '10-15', ARRAY['Squeeze and hold at midline'], ARRAY['Use a slight elbow bend']),
  ('pec-deck',                'cybex',            'Eagle NX Pec Fly',                 'selectorized', '10-15', ARRAY['Move only at the shoulder'], ARRAY['Pads should rest at mid-forearm']),
  ('pec-deck',                'nautilus',         'Reactive Pec Fly',                 'selectorized', '10-15', ARRAY['Slow eccentric'], ARRAY['Cam-based resistance peaks mid-rep']),

  -- ── Cable Crossover ──
  ('cable-crossover',         'freemotion',       'Genesis Dual Cable Cross',         'cable',        '10-15', ARRAY['Maintain steady rib position'], ARRAY['Step forward to set tension before pressing']),
  ('cable-crossover',         'life-fitness',     'Signature Dual Adjustable Pulley', 'cable',        '8-15', ARRAY['Soft elbows'], ARRAY['Match pulley height to target angle']),
  ('cable-crossover',         'precor',           'Discovery Strength DAP',           'cable',        '8-15', ARRAY['Avoid shrugging'], ARRAY['Stand with split stance for stability']),

  -- ── Lat Pulldown ──
  ('lat-pulldown',            'life-fitness',     'Insignia Series Lat Pulldown',     'selectorized', '8-12', ARRAY['Initiate with elbow drive, not biceps'], ARRAY['Lock thighs under the pad']),
  ('lat-pulldown',            'hammer-strength',  'MTS Iso-Lateral Front Pulldown',   'plate_loaded', '8-12', ARRAY['Pull to upper chest'], ARRAY['Use neutral grip if shoulders are cranky']),
  ('lat-pulldown',            'cybex',            'Eagle NX Pulldown',                'selectorized', '8-12', ARRAY['Keep torso upright'], ARRAY['Don''t lean back excessively']),
  ('lat-pulldown',            'prime-fitness',    'Hybrid Plate-Selector Pulldown',   'selectorized', '8-15', ARRAY['Use the SmartStrength setting for variable resistance'], ARRAY['Pre-stretch the lats at the top']),

  -- ── Seated Row ──
  ('seated-row',              'life-fitness',     'Signature Series Row',             'selectorized', '8-12', ARRAY['Lead with the elbows','Squeeze shoulder blades'], ARRAY['Adjust chest pad before loading']),
  ('seated-row',              'hammer-strength',  'Iso-Lateral High Row',             'plate_loaded', '8-12', ARRAY['Drive elbow back, not down'], ARRAY['Independent arms — train weak side first']),
  ('seated-row',              'matrix',           'Aura Mid Row',                     'selectorized', '8-12', ARRAY['Pause at full contraction'], ARRAY['Keep chest against pad throughout']),

  -- ── Smith Machine ──
  ('smith-machine',           'hammer-strength',  'HD Elite Smith Machine',           'smith',        '5-12', ARRAY['Twist bar to unrack'], ARRAY['Use safeties for solo training']),
  ('smith-machine',           'hoist',            'CF-3753 Smith Machine',            'smith',        '5-12', ARRAY['Counterbalanced for honest loading'], ARRAY['Bar is lighter than 45 lb — check spec sheet']),
  ('smith-machine',           'body-solid',       'Series 7 Smith Machine',           'smith',        '5-12', ARRAY['Stay over the bar path'], ARRAY['Add bands for accommodating resistance']),
  ('smith-machine',           'legend-fitness',   '3-Way Smith Press',                'smith',        '5-12', ARRAY['Use angled rails for natural press groove'], ARRAY['Try at 7° for bench, 0° for squat']),

  -- ── Leg Press ──
  ('leg-press',               'hammer-strength',  'Linear Leg Press',                 'plate_loaded', '8-15', ARRAY['Drive through the whole foot'], ARRAY['Knees track over toes']),
  ('leg-press',               'cybex',            'Eagle NX Leg Press',               'plate_loaded', '8-15', ARRAY['Don''t lock out the knees'], ARRAY['Foot position high = more glutes']),
  ('leg-press',               'atlantis',         'Pendulum Leg Press',               'plate_loaded', '8-15', ARRAY['Pause briefly at depth'], ARRAY['Choose the rotating sled for free movement']),
  ('leg-press',               'panatta',          'Freeweight Leg Press',             'plate_loaded', '6-12', ARRAY['Keep lower back flat'], ARRAY['Suited for very heavy loads']),

  -- ── Hack Squat ──
  ('hack-squat',              'hammer-strength',  'Linear Hack Squat',                'plate_loaded', '8-12', ARRAY['Sit back into heels'], ARRAY['Slight toe-out is fine']),
  ('hack-squat',              'atlantis',         'Pendulum Hack Squat',              'plate_loaded', '8-15', ARRAY['Pause at the bottom'], ARRAY['Belt squat-style hip path']),
  ('hack-squat',              'arsenal-strength', 'Iron Hack Squat',                  'plate_loaded', '8-12', ARRAY['Brace before descent'], ARRAY['Use the wide platform']),

  -- ── Leg Extension ──
  ('leg-extension',           'life-fitness',     'Signature Leg Extension',          'selectorized', '10-15', ARRAY['Squeeze quads at lockout'], ARRAY['Pad should sit on top of foot, not shin']),
  ('leg-extension',           'cybex',            'Eagle NX Leg Extension',           'selectorized', '10-15', ARRAY['Two-second pause at top'], ARRAY['Use isolation cam for VMO focus']),
  ('leg-extension',           'nautilus',         'Reactive Leg Extension',           'selectorized', '10-15', ARRAY['Avoid kicking out'], ARRAY['Cam matches strength curve']),
  ('leg-extension',           'prime-fitness',    'PRIME RO-T8 Leg Extension',        'selectorized', '10-15', ARRAY['Try different grip angles'], ARRAY['Variable resistance — set the level low first']),

  -- ── Seated Leg Curl ──
  ('seated-leg-curl',         'life-fitness',     'Signature Seated Leg Curl',        'selectorized', '10-15', ARRAY['Drive the heel down and back'], ARRAY['Strap thigh down for full ROM']),
  ('seated-leg-curl',         'prime-fitness',    'Seated Leg Curl Pro',              'selectorized', '10-15', ARRAY['Use the lengthened bias setting'], ARRAY['Pre-set RO-T8 setting before lift']),
  ('seated-leg-curl',         'atlantis',         'Pendulum Seated Leg Curl',         'selectorized', '10-15', ARRAY['Hold contraction 1s'], ARRAY['Knee should align with pivot axis']),

  -- ── Lying Leg Curl ──
  ('lying-leg-curl',          'life-fitness',     'Signature Prone Leg Curl',         'selectorized', '10-15', ARRAY['Point toes for less calf'], ARRAY['Hips stay down — don''t pop up']),
  ('lying-leg-curl',          'hammer-strength',  'Plate-Loaded Lying Leg Curl',      'plate_loaded', '10-15', ARRAY['Slow controlled descent'], ARRAY['Start one plate per side']),
  ('lying-leg-curl',          'cybex',            'Eagle NX Lying Leg Curl',          'selectorized', '10-15', ARRAY['Brace abs to lock pelvis'], ARRAY['Adjust pad to land just above ankle']),
  ('lying-leg-curl',          'atlantis',         'Pendulum Lying Leg Curl',          'selectorized', '10-15', ARRAY['No bouncing at bottom'], ARRAY['Use partial reps near failure for stretch overload']),

  -- ── Hip Thrust Machine ──
  ('hip-thrust-machine',      'prime-fitness',    'PRIME Hip Thrust Pro',             'selectorized', '8-12', ARRAY['Squeeze glutes hard at top'], ARRAY['Set pad just below hip crease']),
  ('hip-thrust-machine',      'nautilus',         'Reactive Glute Drive',             'selectorized', '8-12', ARRAY['Tuck chin and rib down'], ARRAY['Hold lockout for 1s']),
  ('hip-thrust-machine',      'arsenal-strength', 'Glute Bridge Pro',                 'plate_loaded', '8-12', ARRAY['Drive through heels, not toes'], ARRAY['Use the B-stance setting for unilateral']),

  -- ── Hip Abductor ──
  ('hip-abductor',            'life-fitness',     'Signature Hip Abductor',           'selectorized', '12-20', ARRAY['Lean forward slightly for glute med'], ARRAY['Don''t swing — control eccentric']),
  ('hip-abductor',            'cybex',            'Eagle NX Hip Abductor',            'selectorized', '12-20', ARRAY['Pause at peak abduction'], ARRAY['Sit upright for thigh focus']),
  ('hip-abductor',            'matrix',           'Aura Hip Abductor',                'selectorized', '12-20', ARRAY['Hold contraction 1-2s'], ARRAY['Pad against outer thigh, not knee']),

  -- ── Hip Adductor ──
  ('hip-adductor',            'life-fitness',     'Signature Hip Adductor',           'selectorized', '12-20', ARRAY['Slow controlled return'], ARRAY['Match pad position to thigh length']),
  ('hip-adductor',            'cybex',            'Eagle NX Hip Adductor',            'selectorized', '12-20', ARRAY['Sit upright'], ARRAY['Don''t go below safe ROM']),
  ('hip-adductor',            'matrix',           'Aura Hip Adductor',                'selectorized', '12-20', ARRAY['Squeeze through full range'], ARRAY['Brace abs to anchor pelvis']),

  -- ── Calf Raise ──
  ('calf-raise',              'hammer-strength',  'Plate-Loaded Seated Calf Raise',   'plate_loaded', '10-15', ARRAY['Pause at full stretch'], ARRAY['Soleus emphasis when knee bent']),
  ('calf-raise',              'body-solid',       'Pro Clubline Calf Raise',          'selectorized', '10-15', ARRAY['Press through ball of foot'], ARRAY['Slow 2s eccentric']),

  -- ── Shoulder Press ──
  ('shoulder-press-machine',  'life-fitness',     'Signature Shoulder Press',         'selectorized', '8-12', ARRAY['Don''t arch the lower back'], ARRAY['Press path should be slightly forward of skull']),
  ('shoulder-press-machine',  'hammer-strength',  'Iso-Lateral Shoulder Press',       'plate_loaded', '6-12', ARRAY['Lock core before press'], ARRAY['Asymmetric loading for weak side']),
  ('shoulder-press-machine',  'cybex',            'Eagle NX Shoulder Press',          'selectorized', '8-12', ARRAY['Stay seated firmly'], ARRAY['Adjust seat so handles align with shoulders']),
  ('shoulder-press-machine',  'matrix',           'Aura Shoulder Press',              'selectorized', '8-12', ARRAY['Don''t crash at the bottom'], ARRAY['Two-handed neutral grip option available']),

  -- ── Preacher Curl ──
  ('preacher-curl',           'hammer-strength',  'Plate-Loaded Preacher Curl',       'plate_loaded', '8-12', ARRAY['Don''t hyperextend at the bottom'], ARRAY['Keep upper arms flat on the pad']),
  ('preacher-curl',           'body-solid',       'Pro Clubline Preacher',            'selectorized', '8-12', ARRAY['Squeeze at top'], ARRAY['Use the rotating handle for supinated curl']),
  ('preacher-curl',           'legend-fitness',   'Pro Series Preacher Curl',         'selectorized', '8-12', ARRAY['Slow eccentric'], ARRAY['Use light load for the first set']),

  -- ── Tricep Extension Machine ──
  ('tricep-extension-machine','cybex',            'Eagle NX Tricep Extension',        'selectorized', '10-15', ARRAY['Press elbows down before extending'], ARRAY['Don''t flare the elbows']),
  ('tricep-extension-machine','nautilus',         'Reactive Tricep Extension',        'selectorized', '10-15', ARRAY['Pause at lockout'], ARRAY['Cam-based — peak resistance mid-rep']),
  ('tricep-extension-machine','hoist',            'Roc-It Tricep Extension',          'selectorized', '10-15', ARRAY['Use the dynamic seat'], ARRAY['Sit upright, no leaning']),

  -- ── Assisted Pull-Up ──
  ('assisted-pullup-dip',     'cybex',            'Eagle NX Total Access Assist',     'assisted',     '6-10', ARRAY['Pull until chin clears bar'], ARRAY['Reduce assist by 5 lb per session']),
  ('assisted-pullup-dip',     'matrix',           'Versa Assisted Pull-Up',           'assisted',     '6-10', ARRAY['Keep core tight'], ARRAY['Use neutral grip handles if shoulders complain']),
  ('assisted-pullup-dip',     'precor',           'Discovery Strength Assisted',      'assisted',     '6-12', ARRAY['Avoid swinging'], ARRAY['Step on the platform after engaging the cable']),

  -- ── Reverse Fly Machine ──
  ('reverse-fly-machine',     'life-fitness',     'Signature Rear Delt Fly',          'selectorized', '12-15', ARRAY['Squeeze shoulder blades together'], ARRAY['Don''t shrug the traps']),
  ('reverse-fly-machine',     'nautilus',         'Reactive Rear Delt',               'selectorized', '12-15', ARRAY['Lead with the pinkies'], ARRAY['Use neutral grip for rear delt emphasis']),
  ('reverse-fly-machine',     'cybex',            'Eagle NX Rear Delt',               'selectorized', '12-15', ARRAY['Pause at full retraction'], ARRAY['Chest against pad before pulling'])
) AS seed(machine_slug, brand_slug, model_name, equipment_type, rep_range_rec, form_cues, beginner_tips)
JOIN machines m       ON m.slug = seed.machine_slug
JOIN machine_brands b ON b.slug = seed.brand_slug;
