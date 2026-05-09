import React from 'react'
import { I } from '../icons.jsx'
import { Ring } from '../shell.jsx'
import { MuscleBody } from '../muscle_body.jsx'
const { useState: uS_tr, useEffect: uE_tr } = React;

const PROGRAM_DAYS = [
  { d:'M', t:'Push',  sub:'Chest·Tri',     done:true  },
  { d:'T', t:'Pull',  sub:'Back·Bi',       done:true  },
  { d:'W', t:'Legs',  sub:'Quad·Glute',    done:true  },
  { d:'T', t:'Push',  sub:'Hypertrophy',   done:false },
  { d:'F', t:'Pull',  sub:'Back focus',    done:false },
  { d:'S', t:'Legs',  sub:'Posterior',     done:false },
  { d:'S', t:'Rest',  sub:'Mobility',      done:false },
];

const DEFAULT_EXERCISES = [
  { id:'e1', name:'Incline DB Press',  muscle:'chest',     target:'chest',    secondary:['shoulders','triceps'], sets:'4×8',  last:'185×8' },
  { id:'e2', name:'Flat Bench Press',  muscle:'chest',     target:'chest',    secondary:['triceps'],             sets:'4×6',  last:'205×6' },
  { id:'e3', name:'Cable Fly',         muscle:'chest',     target:'chest',    secondary:[],                      sets:'3×12', last:'55×12' },
  { id:'e4', name:'Chest Dips',        muscle:'triceps',   target:'triceps',  secondary:['chest'],               sets:'3×AMRAP', last:'BW×12' },
  { id:'e5', name:'Skull Crushers',    muscle:'triceps',   target:'triceps',  secondary:[],                      sets:'4×10', last:'85×10' },
];

const MUSCLE_GROUPS = [
  { k:'chest',     l:'Chest',     sets:22, target:20, trend:'+8%',  ok:true  },
  { k:'back',      l:'Back',      sets:18, target:22, trend:'-4%',  ok:false },
  { k:'shoulders', l:'Shoulders', sets:9,  target:14, trend:'-12%', ok:false },
  { k:'biceps',    l:'Biceps',    sets:12, target:12, trend:'+3%',  ok:true  },
  { k:'triceps',   l:'Triceps',   sets:10, target:12, trend:'+1%',  ok:true  },
  { k:'legs',      l:'Legs',      sets:14, target:18, trend:'-6%',  ok:false },
  { k:'core',      l:'Core',      sets:8,  target:10, trend:'+15%', ok:true  },
];

const INIT_PRS = [
  { ex:'Bench Press',    w:225, unit:'lb', reps:5 },
  { ex:'Back Squat',     w:315, unit:'lb', reps:3 },
  { ex:'Deadlift',       w:405, unit:'lb', reps:1 },
  { ex:'Overhead Press', w:135, unit:'lb', reps:5 },
];

/* today index: Mon=0 … Sun=6 */
const TODAY_IDX = (new Date().getDay() + 6) % 7;

const PERSONA_META = {
  peak:          { l:'Peak Mode',       c:'var(--m-gym)'    },
  examSeason:    { l:'Exam Season',     c:'var(--m-assign)' },
  summerAthlete: { l:'Summer Athlete',  c:'var(--m-habits)' },
  inSeason:      { l:'In-Season',       c:'var(--m-nutri)'  },
  bulk:          { l:'Bulk Mode',       c:'var(--tint)'     },
};

const MODE_META = {
  peak:        { label:'Peak Mode',           desc:'Full program — crush it today',        c:'var(--m-gym)',    count:5 },
  maintenance: { label:'Maintenance Mode',    desc:'Exam in 3 days — reduce volume',       c:'var(--m-habits)', count:4 },
  deload:      { label:'Deload — Exam Alert', desc:'Exam tomorrow — light movement only',  c:'var(--bad)',      count:3 },
};

function getTrainingMode(exams, personaMode) {
  if (personaMode === 'examSeason') return 'deload';
  if (personaMode === 'inSeason')   return 'maintenance';
  const now = new Date(); now.setHours(0,0,0,0);
  const days = (exams||[])
    .filter(e => e.date)
    .map(e => Math.ceil((new Date(e.date) - now) / 86400000))
    .filter(d => d > 0)
    .sort((a,b) => a-b);
  if (!days.length) return 'peak';
  if (days[0] <= 1) return 'deload';
  if (days[0] <= 3) return 'maintenance';
  return 'peak';
}

function ExamModeBanner({ mode }) {
  const m = MODE_META[mode];
  return (
    <div style={{
      margin:'0 16px 12px', padding:'10px 14px',
      background:`color-mix(in srgb, ${m.c} 12%, var(--bg-card))`,
      border:`1px solid color-mix(in srgb, ${m.c} 22%, transparent)`,
      borderRadius:12, display:'flex', alignItems:'center', gap:10,
    }}>
      <div style={{flex:1,minWidth:0}}>
        <div style={{fontSize:13,fontWeight:700,color:m.c,marginBottom:2}}>{m.label}</div>
        <div className="small muted">{m.desc}</div>
      </div>
      <div style={{
        fontSize:10,fontWeight:700,color:m.c,padding:'4px 10px',borderRadius:8,flexShrink:0,
        background:`color-mix(in srgb, ${m.c} 15%, transparent)`,
      }}>{m.count} exercises today</div>
    </div>
  );
}

function WeekStrip() {
  return (
    <div style={{display:'grid',gridTemplateColumns:'repeat(7, 1fr)',padding:'0 16px 14px',borderTop:'1px solid var(--sep)',borderBottom:'1px solid var(--sep)',marginBottom:14}}>
      {PROGRAM_DAYS.map((d,i) => {
        const isToday = i === TODAY_IDX;
        return (
          <div key={i} style={{
            textAlign:'center',
            padding:'12px 2px 10px',
            background: isToday ? 'var(--tint)' : 'transparent',
            borderRight: i < 6 ? '1px solid var(--sep)' : 'none',
          }}>
            <div className="eyebrow" style={{color: isToday ? 'rgba(255,255,255,0.78)' : 'var(--ink-3)'}}>{d.d}</div>
            <div className="mono tabular" style={{fontSize:14,fontWeight:800,marginTop:6,letterSpacing:'-0.01em',color: isToday ? '#fff' : d.done ? 'var(--ink-3)' : 'var(--ink)',overflow:'hidden',textOverflow:'ellipsis',whiteSpace:'nowrap'}}>{d.t}</div>
            <div style={{height:3,marginTop:8,background: d.done ? 'var(--m-gym)' : 'var(--sep)',opacity: isToday ? 1 : d.done ? 1 : 0.6}}/>
          </div>
        );
      })}
    </div>
  );
}

function ExercisePreview({ ex, idx, recommendedWeights = {} }) {
  const [open, setOpen] = uS_tr(idx===0);
  const overloadHint = (() => {
    const rec = recommendedWeights[ex.name];
    if (rec) return { text: `Rec: ${rec} lbs this session`, isRec: true };
    if (!ex.last || ex.last === '—') return null;
    const m = ex.last.match(/^(\d+)/);
    if (!m) return null;
    const next = parseInt(m[1]) + 5;
    return { text: `Try ${next} lbs  (+5 from last)`, isRec: false };
  })();
  return (
    <div className="exercise-block" style={{marginBottom:10}}>
      <div className="exercise-header" onClick={() => setOpen(v=>!v)}>
        <div className="dot" style={{background:'var(--m-gym)'}}/>
        <div className="ex-name">{ex.name}</div>
        <span className="ex-badge">{ex.sets}</span>
        <span style={{color:'var(--ink-4)',marginLeft:4}}>{open ? <I.chevronU size={16}/> : <I.chevronD size={16}/>}</span>
      </div>
      {open && (
        <div style={{padding:'0 16px 14px'}}>
          <div style={{display:'flex',justifyContent:'space-between',marginBottom:8}}>
            <span className="small muted">Primary: <span style={{color:'var(--ink)',textTransform:'capitalize'}}>{ex.muscle}</span></span>
            <span className="small muted">Last: <span className="mono" style={{color:'var(--ink)'}}>{ex.last}</span></span>
          </div>
          {overloadHint && (
            <div style={{
              display:'flex',alignItems:'center',gap:6,padding:'7px 10px',marginBottom:10,
              background: overloadHint.isRec ? 'color-mix(in srgb, var(--tint) 12%, var(--bg-card))' : 'var(--m-gym-s)',
              borderRadius:8,
            }}>
              <span style={{fontSize:14,color: overloadHint.isRec ? 'var(--tint)' : 'var(--m-gym)',fontWeight:700}}>↑</span>
              <span style={{fontSize:12,fontWeight:700,color: overloadHint.isRec ? 'var(--tint)' : 'var(--m-gym)',flex:1}}>{overloadHint.text}</span>
              <span style={{fontSize:10,color:'var(--ink-3)',fontWeight:600}}>{overloadHint.isRec ? 'SMART LOAD' : 'OVERLOAD'}</span>
            </div>
          )}
          {['Set 1','Set 2','Set 3','Set 4','Set 5'].slice(0, Math.min(5, Math.max(1, parseInt(String(ex.sets).split(/[×x]/)[0]) || 3))).map((s,i) => (
            <div key={i} style={{display:'flex',gap:10,marginBottom:6,alignItems:'center'}}>
              <span className="small muted mono" style={{width:36}}>{s}</span>
              <div style={{flex:1,height:36,background:'var(--bg-input)',borderRadius:8,display:'flex',alignItems:'center',justifyContent:'center'}}>
                <span className="small muted">— lbs</span>
              </div>
              <div style={{flex:1,height:36,background:'var(--bg-input)',borderRadius:8,display:'flex',alignItems:'center',justifyContent:'center'}}>
                <span className="small muted">— reps</span>
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}

function MuscleVolPanel({ onMuscleSelect, activeFilter }) {
  const [active, setActive] = uS_tr('chest');
  const handleClick = (k) => {
    setActive(k);
    if (onMuscleSelect) onMuscleSelect(k === activeFilter ? null : k);
  };
  return (
    <div>
      <div className="card" style={{margin:'0 16px'}}>
        {MUSCLE_GROUPS.map((m) => {
          const pct = Math.min(100, m.sets/m.target*100);
          return (
            <div key={m.k} className="muscle-vol-row"
                 style={{background: active===m.k ? 'color-mix(in srgb, var(--muscle-hi) 10%, var(--bg-card))' : ''}}
                 onClick={() => handleClick(m.k)}>
              <div className="mvr-label" style={{color: active===m.k ? 'var(--muscle-hi)' : 'var(--ink)', fontWeight: active===m.k ? 600 : 400}}>{m.l}</div>
              <div className="mvr-bar">
                <div className="prog"><div className="fill" style={{width:`${pct}%`,background:m.ok?'var(--m-gym)':'var(--warn)'}}/></div>
              </div>
              <div className="mvr-val">{m.sets}/{m.target}</div>
              <div className="small mono" style={{width:40,textAlign:'right',color:m.trend.startsWith('+')? 'var(--m-gym)':'var(--m-health)'}}>{m.trend}</div>
            </div>
          );
        })}
        <div style={{padding:'8px 12px',fontSize:12,color:'var(--ink-3)',textAlign:'center'}}>
          Tap a muscle to filter the program preview.
        </div>
      </div>
      <div style={{display:'flex',justifyContent:'center',padding:'14px 16px 4px'}}>
        <MuscleBody active={active} secondary={[]} height={220} interactive={false}/>
      </div>
    </div>
  );
}

function PRsList() {
  const [open, setOpen] = uS_tr(false);
  const [prs, setPrs] = uS_tr(INIT_PRS);
  const [editing, setEditing] = uS_tr(null); // index being edited
  const [draftW, setDraftW] = uS_tr('');

  const startEdit = (i, currentW) => {
    setEditing(i);
    setDraftW(String(currentW));
  };

  const saveEdit = (i) => {
    const val = parseFloat(draftW);
    if (!isNaN(val) && val > 0) {
      setPrs(prev => prev.map((p, idx) => idx === i ? {...p, w: val} : p));
    }
    setEditing(null);
    setDraftW('');
  };

  return (
    <div className="card" style={{margin:'0 16px'}}>
      <div className="cell tappable" onClick={() => setOpen(v=>!v)}>
        <I.trending size={18} stroke="var(--m-gym)"/>
        <div className="cell-label" style={{fontWeight:600}}>Personal Records</div>
        {open ? <I.chevronU size={16} stroke="var(--ink-4)"/> : <I.chevronD size={16} stroke="var(--ink-4)"/>}
      </div>
      {open && prs.map((p,i) => (
        <div key={i}>
          <div className="cell" style={{paddingLeft:46}}>
            <div className="cell-label" style={{fontSize:15}}>{p.ex}</div>
            <div className="mono tabular" style={{fontSize:18,fontWeight:800,letterSpacing:'-0.02em',color:'var(--ink)'}}>{p.w}<span className="eyebrow" style={{marginLeft:4}}>{p.unit}</span></div>
            <div className="chip" style={{marginLeft:8}}>×{p.reps}</div>
          </div>
          {editing === i ? (
            <div style={{paddingLeft:46,paddingRight:12,paddingBottom:10,display:'flex',gap:8,alignItems:'center'}}>
              <input
                type="number"
                inputMode="decimal"
                value={draftW}
                onChange={e => setDraftW(e.target.value)}
                className="set-input"
                style={{width:80}}
                autoFocus
              />
              <span className="small muted">{p.unit}</span>
              <button className="btn-primary xs" onClick={() => saveEdit(i)} style={{marginLeft:4}}>Save</button>
              <button className="btn-primary xs secondary" onClick={() => setEditing(null)}>Cancel</button>
            </div>
          ) : (
            <div style={{paddingLeft:46,paddingBottom:8}}>
              <span
                style={{fontSize:12,color:'var(--tint)',cursor:'pointer'}}
                onClick={() => startEdit(i, p.w)}
              >+ Update PR</span>
            </div>
          )}
        </div>
      ))}
    </div>
  );
}

function Train({ state, dispatch }) {
  const [exercises, setExercises] = uS_tr(DEFAULT_EXERCISES);
  const [muscleFilter, setMuscleFilter] = uS_tr(null);

  const trainingMode = getTrainingMode(state?.exams, state?.personaMode);
  const modeMeta     = MODE_META[trainingMode];
  const personaMeta  = PERSONA_META[state?.personaMode || 'peak'];
  const recWeights   = state?.recommendedWeights || {};

  const visibleExercises = muscleFilter
    ? exercises.filter(ex => ex.target === muscleFilter || ex.muscle === muscleFilter)
    : exercises.slice(0, modeMeta.count);

  const openAddCustom = () => {
    dispatch({
      type: 'OPEN_SHEET',
      sheet: 'addCustomExercise',
      data: {
        onAdd: (ex) => {
          setExercises(prev => [...prev, { ...ex, id: 'c' + Date.now() }]);
        },
      },
    });
  };

  return (
    <div className="screen-area enter">
      <div className="nav-bar">
        <div className="nav-title">Train</div>
        <div className="nav-right">
          <button className="icon-btn muted" style={{fontSize:11,fontWeight:700,letterSpacing:'0.06em',width:'auto',paddingLeft:8,paddingRight:8}}
                  onClick={() => dispatch({type:'PUSH_SCREEN', screen:'workoutHistory'})}>
            History
          </button>
          <button className="icon-btn muted" onClick={openAddCustom}><I.weight size={20}/></button>
        </div>
      </div>

      {/* program strip */}
      <div style={{padding:'4px 16px 14px'}}>
        <div className="eyebrow">Today's Session · Wk 3</div>
        <div style={{display:'flex',justifyContent:'space-between',alignItems:'center',marginTop:6,gap:10}}>
          <div style={{fontSize:32,fontWeight:800,letterSpacing:'-0.03em',color:'var(--ink)',lineHeight:1,flex:1,minWidth:0}}>{PROGRAM_DAYS[TODAY_IDX].t} · Day {TODAY_IDX + 1}</div>
          <button
            onClick={() => dispatch({type:'OPEN_SHEET',sheet:'personaPicker'})}
            style={{
              fontSize:11,fontWeight:700,padding:'4px 10px',borderRadius:20,flexShrink:0,
              background:`color-mix(in srgb, ${personaMeta.c} 15%, transparent)`,
              color:personaMeta.c,
              border:`1px solid color-mix(in srgb, ${personaMeta.c} 28%, transparent)`,
            }}>
            {personaMeta.l}
          </button>
        </div>
        <div className="eyebrow" style={{marginTop:8}}>PPL Hypertrophy · {PROGRAM_DAYS[TODAY_IDX].sub.replace('·',' · ')}</div>
      </div>
      <WeekStrip/>
      {trainingMode !== 'peak' && <ExamModeBanner mode={trainingMode}/>}

      {/* CTA */}
      <div style={{padding:'0 16px 20px'}}>
        <button className="btn-primary" onClick={() => dispatch({
          type:'PUSH_SCREEN', screen:'activeSession',
          data:{ exercises, sessionTitle: `${PROGRAM_DAYS[TODAY_IDX].t} · ${PROGRAM_DAYS[TODAY_IDX].sub}` }
        })}>
          <I.play size={18}/>
          Start Today's Workout
        </button>
      </div>

      {/* Exercises preview */}
      <div style={{display:'flex',alignItems:'center',justifyContent:'space-between',padding:'0 20px 10px'}}>
        <div className="section-header" style={{padding:0}}>Today's exercises</div>
        {muscleFilter && (
          <span
            className="chip"
            style={{fontSize:12,padding:'3px 10px',cursor:'pointer',background:'var(--m-gym)',color:'#fff'}}
            onClick={() => setMuscleFilter(null)}
          >Show all</span>
        )}
      </div>
      <div style={{padding:'0 16px'}}>
        {visibleExercises.map((ex,i) => <ExercisePreview key={ex.id || ex.name} ex={ex} idx={i} recommendedWeights={recWeights}/>)}
        {visibleExercises.length === 0 && (
          <div className="small muted" style={{textAlign:'center',padding:'16px 0'}}>No exercises for this muscle. <span style={{color:'var(--tint)',cursor:'pointer'}} onClick={() => setMuscleFilter(null)}>Show all</span></div>
        )}
      </div>

      {/* Volume */}
      <div className="section-header" style={{padding:'16px 20px 10px'}}>Muscle volume · this week</div>
      <MuscleVolPanel onMuscleSelect={setMuscleFilter} activeFilter={muscleFilter}/>

      {/* PRs */}
      <div style={{height:16}}/>
      <PRsList/>
      <div style={{height:32}}/>
    </div>
  );
}

export { Train };
