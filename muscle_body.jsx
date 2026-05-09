import React from 'react'
const { useState: useS_mb } = React;

/* ── helpers ─────────────────────────────────────────── */
function mFill(g, active, secondary) {
  if (active === g) return 'var(--muscle-hi)';
  if ((secondary || []).includes(g)) return 'var(--muscle-sec)';
  return 'var(--muscle-base)';
}
function mStroke(g, active, secondary) {
  if (active === g || (secondary || []).includes(g)) return 'rgba(0,0,0,0.38)';
  return 'var(--muscle-line)';
}
function mStrokeW(g, active, secondary) {
  return (active === g || (secondary || []).includes(g)) ? 1.1 : 0.8;
}
function mBind(g, onHover) {
  return {
    onMouseEnter: () => onHover && onHover(g),
    onMouseLeave: () => onHover && onHover(null),
    style: { cursor: onHover ? 'pointer' : 'default', transition: 'fill .2s' },
  };
}

/* ── Shared silhouette path (front) ─────────────────── */
const FRONT_SILHOUETTE =
  'M110 12 C131 12,145 27,145 45 C145 63,137 73,123 79 ' +
  'L129 87 Q150 91,166 103 Q180 116,186 138 L192 178 ' +
  'Q196 206,196 238 L194 270 Q190 290,184 304 ' +
  'L175 310 L167 303 Q163 284,159 263 L157 239 L151 237 ' +
  'L147 262 Q145 284,147 310 L151 348 ' +
  'Q151 408,145 462 Q141 496,139 512 L122 514 ' +
  'Q116 481,114 449 Q112 411,112 379 L110 371 L108 379 ' +
  'Q108 411,106 449 Q104 481,98 514 L81 512 ' +
  'Q79 496,75 462 Q69 408,69 348 L73 310 ' +
  'Q75 284,73 262 L69 237 L63 239 L61 263 ' +
  'Q57 284,53 303 L45 310 L36 304 ' +
  'Q30 290,26 270 L24 238 Q24 206,28 178 L34 138 ' +
  'Q40 116,54 103 Q70 91,91 87 L97 79 ' +
  'C83 73,75 63,75 45 C75 27,89 12,110 12 Z';

/* ── FRONT VIEW ─────────────────────────────────────── */
function FrontFigure({ active, secondary, onHover }) {
  const f = (g) => mFill(g, active, secondary);
  const s = (g) => mStroke(g, active, secondary);
  const w = (g) => mStrokeW(g, active, secondary);
  const b = (g) => mBind(g, onHover);
  const def = 'var(--muscle-def)';

  return (
    <svg viewBox="0 0 220 520" width="100%" height="100%" xmlns="http://www.w3.org/2000/svg">
      <defs>
        {/* Lighting overlay — top-left highlight */}
        <radialGradient id="fg-light" cx="0.36" cy="0.16" r="0.72">
          <stop offset="0%" stopColor="rgba(255,255,255,0.18)"/>
          <stop offset="100%" stopColor="rgba(0,0,0,0)"/>
        </radialGradient>
        {/* Bottom darkening */}
        <linearGradient id="fg-shadow" x1="0" y1="0.4" x2="0" y2="1">
          <stop offset="0%" stopColor="rgba(0,0,0,0)"/>
          <stop offset="100%" stopColor="rgba(0,0,0,0.14)"/>
        </linearGradient>
        <clipPath id="fg-clip">
          <path d={FRONT_SILHOUETTE}/>
        </clipPath>
      </defs>

      {/* ── Base body ── */}
      <path d={FRONT_SILHOUETTE}
            fill="var(--muscle-base)" stroke="var(--muscle-line)" strokeWidth="1.3"/>

      {/* ── SHOULDERS (anterior deltoid) ── */}
      <g {...b('shoulders')}>
        <path d="M91 81 Q66 87,50 104 Q40 122,44 148 Q56 156,72 148 Q82 136,84 114 Q85 96,91 83 Z"
              fill={f('shoulders')} stroke={s('shoulders')} strokeWidth={w('shoulders')}/>
        <path d="M129 81 Q154 87,170 104 Q180 122,176 148 Q164 156,148 148 Q138 136,136 114 Q135 96,129 83 Z"
              fill={f('shoulders')} stroke={s('shoulders')} strokeWidth={w('shoulders')}/>
        <path d="M73 104 Q77 126,73 146" fill="none" stroke={def} strokeWidth="0.7" opacity="0.4"/>
        <path d="M147 104 Q143 126,147 146" fill="none" stroke={def} strokeWidth="0.7" opacity="0.4"/>
      </g>

      {/* ── CHEST (pectoralis) ── */}
      <g {...b('chest')}>
        <path d="M91 88 Q70 93,60 110 Q52 130,58 154 Q68 165,96 163 Q109 157,110 140 Z"
              fill={f('chest')} stroke={s('chest')} strokeWidth={w('chest')}/>
        <path d="M129 88 Q150 93,160 110 Q168 130,162 154 Q152 165,124 163 Q111 157,110 140 Z"
              fill={f('chest')} stroke={s('chest')} strokeWidth={w('chest')}/>
        {/* pec groove + sternal notch */}
        <path d="M110 94 Q95 99,82 110" fill="none" stroke={def} strokeWidth="0.9" opacity="0.38"/>
        <path d="M110 94 Q125 99,138 110" fill="none" stroke={def} strokeWidth="0.9" opacity="0.38"/>
        <path d="M107 87 L110 82 L113 87" fill="none" stroke={def} strokeWidth="0.8" opacity="0.35"/>
      </g>

      {/* ── BICEPS ── */}
      <g {...b('biceps')}>
        <path d="M43 152 Q31 180,31 215 Q33 237,47 243 Q63 237,67 213 Q69 181,57 152 Z"
              fill={f('biceps')} stroke={s('biceps')} strokeWidth={w('biceps')}/>
        <path d="M177 152 Q189 180,189 215 Q187 237,173 243 Q157 237,153 213 Q151 181,163 152 Z"
              fill={f('biceps')} stroke={s('biceps')} strokeWidth={w('biceps')}/>
        <path d="M44 172 Q48 202,46 228" fill="none" stroke={def} strokeWidth="0.8" opacity="0.38"/>
        <path d="M176 172 Q172 202,174 228" fill="none" stroke={def} strokeWidth="0.8" opacity="0.38"/>
      </g>

      {/* ── FOREARMS ── */}
      <g clipPath="url(#fg-clip)">
        <path d="M31 246 Q25 276,25 306 Q27 318,39 322 Q53 316,57 298 Q59 272,55 248 Z"
              fill="var(--muscle-deep)" stroke="var(--muscle-line)" strokeWidth="0.8"/>
        <path d="M189 246 Q195 276,195 306 Q193 318,181 322 Q167 316,163 298 Q161 272,165 248 Z"
              fill="var(--muscle-deep)" stroke="var(--muscle-line)" strokeWidth="0.8"/>
        <path d="M33 260 Q35 284,38 310" fill="none" stroke={def} strokeWidth="0.6" opacity="0.30"/>
        <path d="M187 260 Q185 284,182 310" fill="none" stroke={def} strokeWidth="0.6" opacity="0.30"/>
      </g>

      {/* ── CORE / ABS ── */}
      <g {...b('core')}>
        <path d="M88 165 Q82 198,82 234 Q84 258,92 268 L128 268 Q136 258,138 234 Q138 198,132 165 Z"
              fill={f('core')} stroke={s('core')} strokeWidth={w('core')}/>
        {/* linea alba */}
        <path d="M110 167 L110 266" stroke={def} strokeWidth="1.2" opacity="0.52"/>
        {/* ab segments */}
        <path d="M88 182 Q110 180,132 182" stroke={def} strokeWidth="0.85" fill="none" opacity="0.46"/>
        <path d="M86 202 Q110 200,134 202" stroke={def} strokeWidth="0.85" fill="none" opacity="0.46"/>
        <path d="M86 224 Q110 222,134 224" stroke={def} strokeWidth="0.85" fill="none" opacity="0.46"/>
        <path d="M86 246 Q110 244,134 246" stroke={def} strokeWidth="0.85" fill="none" opacity="0.46"/>
        {/* serratus anterior (side fingers) */}
        <path d="M82 176 Q76 186,82 196" stroke={def} strokeWidth="0.75" fill="none" opacity="0.35"/>
        <path d="M82 200 Q76 212,84 220" stroke={def} strokeWidth="0.75" fill="none" opacity="0.35"/>
        <path d="M138 176 Q144 186,138 196" stroke={def} strokeWidth="0.75" fill="none" opacity="0.35"/>
        <path d="M138 200 Q144 212,136 220" stroke={def} strokeWidth="0.75" fill="none" opacity="0.35"/>
        {/* oblique sweeps */}
        <path d="M82 182 Q76 214,82 252" stroke={def} strokeWidth="0.85" fill="none" opacity="0.32"/>
        <path d="M138 182 Q144 214,138 252" stroke={def} strokeWidth="0.85" fill="none" opacity="0.32"/>
      </g>

      {/* ── QUADS + calves ── */}
      <g {...b('legs')}>
        {/* left quad */}
        <path d="M72 270 Q61 318,61 366 Q63 406,77 428 Q93 433,108 427 Q112 383,110 336 Q108 291,100 272 Z"
              fill={f('legs')} stroke={s('legs')} strokeWidth={w('legs')}/>
        {/* quad separation lines */}
        <path d="M78 286 Q81 336,82 406" fill="none" stroke={def} strokeWidth="0.85" opacity="0.42"/>
        <path d="M98 280 Q100 330,97 406" fill="none" stroke={def} strokeWidth="0.85" opacity="0.42"/>
        {/* right quad */}
        <path d="M148 270 Q159 318,159 366 Q157 406,143 428 Q127 433,112 427 Q108 383,110 336 Q112 291,120 272 Z"
              fill={f('legs')} stroke={s('legs')} strokeWidth={w('legs')}/>
        <path d="M142 286 Q139 336,138 406" fill="none" stroke={def} strokeWidth="0.85" opacity="0.42"/>
        <path d="M122 280 Q120 330,123 406" fill="none" stroke={def} strokeWidth="0.85" opacity="0.42"/>
        {/* patella caps */}
        <ellipse cx="90" cy="440" rx="14" ry="9"
                 fill="var(--muscle-deep)" stroke="var(--muscle-line)" strokeWidth="0.9"/>
        <ellipse cx="130" cy="440" rx="14" ry="9"
                 fill="var(--muscle-deep)" stroke="var(--muscle-line)" strokeWidth="0.9"/>
        {/* tibialis / shins */}
        <path d="M79 452 Q74 484,77 512 L94 516 Q98 486,98 454 Z"
              fill={f('legs')} stroke={s('legs')} strokeWidth="0.8" opacity="0.88"/>
        <path d="M141 452 Q146 484,143 512 L126 516 Q122 486,122 454 Z"
              fill={f('legs')} stroke={s('legs')} strokeWidth="0.8" opacity="0.88"/>
      </g>

      {/* ── Clavicle cue ── */}
      <path d="M91 83 Q110 88,129 83" stroke={def} strokeWidth="1.0" fill="none" opacity="0.42"/>

      {/* ── Lighting overlay ── */}
      <path d={FRONT_SILHOUETTE} fill="url(#fg-light)" stroke="none"/>
      <path d={FRONT_SILHOUETTE} fill="url(#fg-shadow)" stroke="none"/>
    </svg>
  );
}

/* ── BACK VIEW ──────────────────────────────────────── */
const BACK_SILHOUETTE = FRONT_SILHOUETTE; // same silhouette, mirrored internally

function BackFigure({ active, secondary, onHover }) {
  const f = (g) => mFill(g, active, secondary);
  const s = (g) => mStroke(g, active, secondary);
  const w = (g) => mStrokeW(g, active, secondary);
  const b = (g) => mBind(g, onHover);
  const def = 'var(--muscle-def)';

  return (
    <svg viewBox="0 0 220 520" width="100%" height="100%" xmlns="http://www.w3.org/2000/svg">
      <defs>
        <radialGradient id="bg-light" cx="0.64" cy="0.16" r="0.72">
          <stop offset="0%" stopColor="rgba(255,255,255,0.18)"/>
          <stop offset="100%" stopColor="rgba(0,0,0,0)"/>
        </radialGradient>
        <linearGradient id="bg-shadow" x1="0" y1="0.4" x2="0" y2="1">
          <stop offset="0%" stopColor="rgba(0,0,0,0)"/>
          <stop offset="100%" stopColor="rgba(0,0,0,0.14)"/>
        </linearGradient>
        <clipPath id="bg-clip">
          <path d={BACK_SILHOUETTE}/>
        </clipPath>
      </defs>

      {/* ── Base body ── */}
      <path d={BACK_SILHOUETTE}
            fill="var(--muscle-base)" stroke="var(--muscle-line)" strokeWidth="1.3"/>

      {/* ── TRAPEZIUS ── */}
      <g {...b('back')}>
        <path d="M93 76 Q110 69,127 76 L142 106 Q124 100,110 100 Q96 100,78 106 Z"
              fill={f('back')} stroke={s('back')} strokeWidth={w('back')}/>
        <path d="M108 78 L110 74 L112 78" fill="none" stroke={def} strokeWidth="0.8" opacity="0.4"/>
      </g>

      {/* ── REAR DELTOIDS ── */}
      <g {...b('shoulders')}>
        <path d="M91 81 Q66 87,50 104 Q40 122,44 148 Q56 156,72 148 Q82 136,84 114 Q85 96,91 83 Z"
              fill={f('shoulders')} stroke={s('shoulders')} strokeWidth={w('shoulders')}/>
        <path d="M129 81 Q154 87,170 104 Q180 122,176 148 Q164 156,148 148 Q138 136,136 114 Q135 96,129 83 Z"
              fill={f('shoulders')} stroke={s('shoulders')} strokeWidth={w('shoulders')}/>
        <path d="M73 104 Q77 126,73 146" fill="none" stroke={def} strokeWidth="0.7" opacity="0.4"/>
        <path d="M147 104 Q143 126,147 146" fill="none" stroke={def} strokeWidth="0.7" opacity="0.4"/>
      </g>

      {/* ── LATS + rhomboids + mid-back ── */}
      <g {...b('back')}>
        {/* rhomboid / mid back plate */}
        <path d="M80 110 Q76 148,78 188 L110 198 L142 188 Q144 148,140 110 Q110 118,80 110 Z"
              fill={f('back')} stroke={s('back')} strokeWidth={w('back')}/>
        {/* spine */}
        <path d="M110 112 L110 258" stroke={def} strokeWidth="1.3" opacity="0.52"/>
        {/* lat wings */}
        <path d="M76 138 Q62 166,66 218 Q78 228,94 222 Q98 192,98 164 Z"
              fill={f('back')} stroke={s('back')} strokeWidth={w('back')} opacity="0.94"/>
        <path d="M144 138 Q158 166,154 218 Q142 228,126 222 Q122 192,122 164 Z"
              fill={f('back')} stroke={s('back')} strokeWidth={w('back')} opacity="0.94"/>
        {/* lat striations */}
        <path d="M78 160 Q88 188,86 216" fill="none" stroke={def} strokeWidth="0.85" opacity="0.38"/>
        <path d="M142 160 Q132 188,134 216" fill="none" stroke={def} strokeWidth="0.85" opacity="0.38"/>
        {/* erector spinae */}
        <path d="M105 118 Q104 180,106 250" stroke={def} strokeWidth="1.0" fill="none" opacity="0.38"/>
        <path d="M115 118 Q116 180,114 250" stroke={def} strokeWidth="1.0" fill="none" opacity="0.38"/>
        {/* lower back */}
        <path d="M92 220 L128 220 Q132 244,128 260 L92 260 Q88 244,92 220 Z"
              fill={f('back')} stroke={s('back')} strokeWidth={w('back')} opacity="0.82"/>
      </g>

      {/* ── TRICEPS ── */}
      <g {...b('triceps')}>
        <path d="M43 152 Q31 180,31 215 Q33 237,47 243 Q63 237,67 213 Q69 181,57 152 Z"
              fill={f('triceps')} stroke={s('triceps')} strokeWidth={w('triceps')}/>
        <path d="M177 152 Q189 180,189 215 Q187 237,173 243 Q157 237,153 213 Q151 181,163 152 Z"
              fill={f('triceps')} stroke={s('triceps')} strokeWidth={w('triceps')}/>
        <path d="M46 180 L52 210" stroke={def} strokeWidth="0.85" opacity="0.42" fill="none"/>
        <path d="M174 180 L168 210" stroke={def} strokeWidth="0.85" opacity="0.42" fill="none"/>
      </g>

      {/* ── FOREARMS ── */}
      <g clipPath="url(#bg-clip)">
        <path d="M31 246 Q25 276,25 306 Q27 318,39 322 Q53 316,57 298 Q59 272,55 248 Z"
              fill="var(--muscle-deep)" stroke="var(--muscle-line)" strokeWidth="0.8"/>
        <path d="M189 246 Q195 276,195 306 Q193 318,181 322 Q167 316,163 298 Q161 272,165 248 Z"
              fill="var(--muscle-deep)" stroke="var(--muscle-line)" strokeWidth="0.8"/>
      </g>

      {/* ── GLUTES ── */}
      <g {...b('legs')}>
        {/* left glute */}
        <path d="M76 260 Q70 292,82 318 Q96 330,110 326 Q110 292,108 264 Z"
              fill={f('legs')} stroke={s('legs')} strokeWidth={w('legs')}/>
        {/* right glute */}
        <path d="M144 260 Q150 292,138 318 Q124 330,110 326 Q110 292,112 264 Z"
              fill={f('legs')} stroke={s('legs')} strokeWidth={w('legs')}/>
        {/* glute crease */}
        <path d="M110 268 L110 324" stroke={def} strokeWidth="1.0" opacity="0.50"/>
        <path d="M94 312 Q110 322,126 312" stroke={def} strokeWidth="0.9" fill="none" opacity="0.40"/>

        {/* hamstrings */}
        <path d="M80 322 Q74 368,76 418 Q90 428,106 424 Q108 378,106 330 Z"
              fill={f('legs')} stroke={s('legs')} strokeWidth={w('legs')} opacity="0.94"/>
        <path d="M140 322 Q146 368,144 418 Q130 428,114 424 Q112 378,114 330 Z"
              fill={f('legs')} stroke={s('legs')} strokeWidth={w('legs')} opacity="0.94"/>
        {/* ham lines */}
        <path d="M90 340 Q88 384,92 418" fill="none" stroke={def} strokeWidth="0.85" opacity="0.40"/>
        <path d="M130 340 Q132 384,128 418" fill="none" stroke={def} strokeWidth="0.85" opacity="0.40"/>

        {/* patella backs */}
        <ellipse cx="90" cy="440" rx="14" ry="9"
                 fill="var(--muscle-deep)" stroke="var(--muscle-line)" strokeWidth="0.9"/>
        <ellipse cx="130" cy="440" rx="14" ry="9"
                 fill="var(--muscle-deep)" stroke="var(--muscle-line)" strokeWidth="0.9"/>

        {/* gastrocnemius (calves) */}
        <path d="M76 452 Q68 482,73 512 L94 516 Q100 486,100 454 Z"
              fill={f('legs')} stroke={s('legs')} strokeWidth="0.9"/>
        <path d="M144 452 Q152 482,147 512 L126 516 Q120 486,120 454 Z"
              fill={f('legs')} stroke={s('legs')} strokeWidth="0.9"/>
        {/* calf peak line */}
        <path d="M84 458 Q82 486,86 510" fill="none" stroke={def} strokeWidth="0.85" opacity="0.42"/>
        <path d="M136 458 Q138 486,134 510" fill="none" stroke={def} strokeWidth="0.85" opacity="0.42"/>
      </g>

      {/* ── Lighting overlay ── */}
      <path d={BACK_SILHOUETTE} fill="url(#bg-light)" stroke="none"/>
      <path d={BACK_SILHOUETTE} fill="url(#bg-shadow)" stroke="none"/>
    </svg>
  );
}

/* ── MuscleBody wrapper ─────────────────────────────── */
function MuscleBody({ active = null, secondary = [], height = 280, interactive = true, onSelect }) {
  const [hover, setHover] = useS_mb(null);
  const curr = hover || active;

  return (
    <div className="body-stage" style={{ alignItems: 'flex-start', gap: 6 }}>
      <div style={{ height, aspectRatio: '220/520', flexShrink: 0 }}>
        <FrontFigure active={curr} secondary={secondary}
                     onHover={interactive ? setHover : null}/>
      </div>
      <div style={{ height, aspectRatio: '220/520', flexShrink: 0 }}>
        <BackFigure active={curr} secondary={secondary}
                    onHover={interactive ? setHover : null}/>
      </div>
    </div>
  );
}

export { MuscleBody, FrontFigure, BackFigure };
