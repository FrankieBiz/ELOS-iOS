import React from 'react'
import { I } from '../icons.jsx'
import { Ring } from '../shell.jsx'
import { MuscleBody } from '../muscle_body.jsx'
const { useState: uS_as, useEffect: uE_as, useRef: uR_as } = React;

const DEFAULT_EXERCISES = [
  { id:'e1', name:'Incline DB Press', muscle:'chest',   target:'chest',   secondary:['shoulders','triceps'] },
  { id:'e2', name:'Flat Bench Press', muscle:'chest',   target:'chest',   secondary:['triceps'] },
  { id:'e3', name:'Cable Fly',        muscle:'chest',   target:'chest',   secondary:[] },
  { id:'e4', name:'Chest Dips',       muscle:'triceps', target:'triceps', secondary:['chest'] },
  { id:'e5', name:'Skull Crushers',   muscle:'triceps', target:'triceps', secondary:[] },
];

const INIT_SETS = {
  'Incline DB Press': [{w:195,r:8,rpe:7,done:true},{w:205,r:6,rpe:8,done:true},{w:215,r:5,rpe:9,done:false},{w:215,r:5,rpe:9,done:false}],
  'Flat Bench Press': [{w:185,r:6,done:false},{w:185,r:6,done:false},{w:185,r:6,done:false},{w:185,r:6,done:false}],
  'Cable Fly':        [{w:55,r:12,done:false},{w:55,r:12,done:false},{w:55,r:12,done:false}],
  'Chest Dips':       [{w:0,r:10,done:false},{w:0,r:8,done:false},{w:0,r:8,done:false}],
  'Skull Crushers':   [{w:85,r:10,done:false},{w:85,r:10,done:false},{w:85,r:10,done:false},{w:85,r:10,done:false}],
};

const REST_DEFAULT = 90;

function buildInitSets(exerciseList) {
  const result = {};
  for (const ex of exerciseList) {
    if (INIT_SETS[ex.name]) {
      result[ex.name] = JSON.parse(JSON.stringify(INIT_SETS[ex.name]));
    } else {
      result[ex.name] = [{w:0,r:8,rpe:'',done:false},{w:0,r:8,rpe:'',done:false},{w:0,r:8,rpe:'',done:false}];
    }
  }
  return result;
}

function RestBanner({ secs, running, onToggle, onSkip }) {
  const m = Math.floor(secs/60), s = secs%60;
  const color = secs > 45 ? 'var(--m-gym)' : secs > 15 ? 'var(--warn)' : 'var(--bad)';
  const lowPulse = secs <= 10 && running;
  return (
    <div className="rest-banner">
      <div style={{flex:1,minWidth:0}}>
        <div className="eyebrow">Rest timer</div>
        <div className={`mono tabular${lowPulse?' pulse':''}`} style={{fontSize:30,fontWeight:800,color,letterSpacing:'-0.04em',lineHeight:1,marginTop:4}}>
          {String(m).padStart(2,'0')}:{String(s).padStart(2,'0')}
        </div>
      </div>
      <button className="btn-primary xs secondary" onClick={onToggle} style={{marginRight:6}}>
        {running ? 'Pause' : 'Resume'}
      </button>
      <button className="btn-primary xs" style={{background:'var(--bg-card2)',color:'var(--ink-3)'}} onClick={onSkip}>
        Skip
      </button>
    </div>
  );
}

function ExerciseCard({ ex, sets, setSets, onComplete, isActive, onActivate, activeMusc, setActiveMuscle, onSwap, recommendedWeights = {} }) {
  const allDone = sets.every(s=>s.done);
  const doneCt = sets.filter(s=>s.done).length;
  const [expanded, setExpanded] = uS_as(isActive);
  const [justChecked, setJustChecked] = uS_as(null);

  const toggleSet = (i) => {
    const wasNotDone = !sets[i].done;
    const next = sets.map((s,j) => j===i ? {...s, done:!s.done} : s);
    setSets(next);
    if (wasNotDone) {
      setActiveMuscle(ex.muscle);
      setJustChecked(i);
      setTimeout(() => setJustChecked(c => c === i ? null : c), 350);
      onComplete(i);
    }
  };

  const updateSet = (i, field, val) => {
    setSets(sets.map((s,j) => j===i ? {...s, [field]: parseFloat(val)||0} : s));
  };

  return (
    <div className="exercise-block" style={{marginBottom:8,border: isActive ? '1.5px solid var(--tint)' : '1px solid var(--sep)'}}>
      <div className="exercise-header" onClick={() => { setExpanded(v=>!v); onActivate(); }}>
        <div className="dot" style={{background: allDone ? 'var(--m-gym)' : isActive ? 'var(--tint)' : 'var(--sep-strong)'}}/>
        <div className="ex-name">{ex.name}</div>
        <span className="ex-badge">{doneCt}/{sets.length} sets</span>
        {expanded ? <I.chevronU size={16} stroke="var(--ink-4)"/> : <I.chevronD size={16} stroke="var(--ink-4)"/>}
      </div>

      {expanded && (
        <div>
          <div style={{paddingLeft:44,paddingBottom:4,display:'flex',gap:6,alignItems:'center'}}>
            <span className="small muted" style={{textTransform:'capitalize'}}>{ex.muscle}</span>
            {(ex.secondary||[]).map(s => <span key={s} className="small muted" style={{textTransform:'capitalize'}}>· {s}</span>)}
          </div>
          {recommendedWeights[ex.name] > 0 && (
            <div style={{paddingLeft:44,paddingRight:12,paddingBottom:8}}>
              <div style={{display:'flex',alignItems:'center',gap:6,padding:'6px 10px',background:'color-mix(in srgb, var(--tint) 12%, var(--bg-card))',borderRadius:8}}>
                <span style={{fontSize:13,color:'var(--tint)',fontWeight:700}}>↑</span>
                <span style={{fontSize:12,fontWeight:700,color:'var(--tint)',flex:1}}>Rec: {recommendedWeights[ex.name]} lbs this session</span>
                <span style={{fontSize:10,color:'var(--ink-3)',fontWeight:600}}>SMART LOAD</span>
              </div>
            </div>
          )}

          {/* Column headers */}
          <div className="set-row" style={{paddingBottom:4}}>
            <span className="eyebrow">#</span>
            <span className="eyebrow" style={{textAlign:'center'}}>Weight (lb)</span>
            <span className="eyebrow" style={{textAlign:'center'}}>Reps</span>
            <span className="eyebrow" style={{textAlign:'center'}}>RPE</span>
            <span></span>
          </div>

          {sets.map((s,i) => (
            <React.Fragment key={i}>
              <div className="set-row" style={{opacity: s.done ? 0.55 : 1}}>
                <span className="tiny mono muted" style={{textAlign:'center'}}>{i+1}</span>
                <input className="set-input" type="number" inputMode="decimal" value={s.w} onChange={e => updateSet(i,'w',e.target.value)}/>
                <input className="set-input" type="number" inputMode="numeric" value={s.r} onChange={e => updateSet(i,'r',e.target.value)}/>
                <input className="set-input" type="number" inputMode="numeric" value={s.rpe||''} placeholder="—" onChange={e => updateSet(i,'rpe',e.target.value)}/>
                <button className={`set-check${s.done?' done':''}${justChecked===i?' check-pop':''}`} onClick={() => toggleSet(i)}>
                  {s.done && <I.check size={14}/>}
                </button>
              </div>
              {s.done && (
                <div style={{display:'flex',gap:5,paddingLeft:44,paddingRight:12,paddingBottom:8,alignItems:'center'}}>
                  <span style={{fontSize:10,color:'var(--ink-4)',fontWeight:700,letterSpacing:'0.04em',flexShrink:0}}>RATE:</span>
                  {[
                    {k:'easy',l:'Too Easy',  c:'var(--m-gym)'},
                    {k:'good',l:'Just Right',c:'var(--m-habits)'},
                    {k:'hard',l:'Too Hard',  c:'var(--bad)'},
                  ].map(d => (
                    <button key={d.k}
                      onClick={() => setSets(sets.map((ss,j) => j===i ? {...ss,difficulty:d.k} : ss))}
                      style={{
                        fontSize:10,fontWeight:700,padding:'3px 8px',borderRadius:8,
                        border:`1.5px solid ${s.difficulty===d.k ? d.c : 'var(--sep-strong)'}`,
                        background:s.difficulty===d.k ? d.c : 'transparent',
                        color:s.difficulty===d.k ? '#fff' : 'var(--ink-3)',
                        transition:'background .15s,border .15s,color .15s',
                      }}>
                      {d.l}
                    </button>
                  ))}
                </div>
              )}
            </React.Fragment>
          ))}

          <div style={{padding:'8px 12px 12px',display:'flex',gap:8}}>
            <button className="btn-primary xs secondary"
                    onClick={() => setSets([...sets,{w:sets[sets.length-1]?.w||0,r:8,rpe:'',done:false}])}>
              <I.plus size={14}/>
              Add set
            </button>
            <button className="btn-primary xs" style={{background:'var(--bg-card2)',color:'var(--ink-3)'}} onClick={onSwap}>
              <I.swap size={14}/>
              Swap
            </button>
          </div>
        </div>
      )}
    </div>
  );
}

function ActiveSession({ state, dispatch }) {
  const pushedExercises = state && state.pushedData && state.pushedData.exercises;
  const exerciseList = pushedExercises ? pushedExercises.map(ex => ({
    id: ex.id || ex.name,
    name: ex.name,
    muscle: ex.muscle,
    target: ex.target || ex.muscle,
    secondary: ex.secondary || [],
  })) : DEFAULT_EXERCISES;

  const [exercises, setExercises] = uS_as(exerciseList);
  const [sets, setSets] = uS_as(() => buildInitSets(exerciseList));
  const [elapsed, setElapsed] = uS_as(0);
  const [restSecs, setRestSecs] = uS_as(0);
  const [restOn, setRestOn] = uS_as(false);
  const [activeEx, setActiveEx] = uS_as(0);
  const [activeMusc, setActiveMusc] = uS_as(exercises[0]?.muscle || 'chest');
  const [celebData, setCelebData] = uS_as(null);

  uE_as(() => {
    const id = setInterval(() => setElapsed(e=>e+1), 1000);
    return () => clearInterval(id);
  }, []);

  uE_as(() => {
    if (!restOn) return;
    if (restSecs <= 0) { setRestOn(false); return; }
    const id = setInterval(() => setRestSecs(r => { if (r<=1) { setRestOn(false); return 0; } return r-1; }), 1000);
    return () => clearInterval(id);
  }, [restOn, restSecs]);

  const em = Math.floor(elapsed/60), es = elapsed%60;

  /* Build flat arrays from current exercises list so order stays in sync */
  const allSets = exercises.flatMap(ex => sets[ex.name] || []);
  const doneSets = allSets.filter(s=>s.done).length;
  const vol = exercises.reduce((tot, ex) => {
    return tot + (sets[ex.name]||[]).filter(s=>s.done).reduce((t,s) => t + (s.w||0)*(s.r||0), 0);
  }, 0);

  const onSetComplete = () => {
    setRestSecs(REST_DEFAULT);
    setRestOn(true);
  };

  const updateExerciseName = (exId, newName) => {
    setExercises(prev => prev.map(e => e.id === exId ? {...e, name: newName} : e));
    setSets(prev => {
      const oldEx = exercises.find(e => e.id === exId);
      if (!oldEx) return prev;
      const next = {...prev};
      if (next[oldEx.name]) {
        next[newName] = next[oldEx.name];
        delete next[oldEx.name];
      }
      return next;
    });
  };

  const finish = () => {
    const totalSets = allSets.filter(s=>s.done).length;
    const workout = {
      date: new Date().toISOString(),
      durationSec: elapsed,
      totalSets,
      totalVolume: vol,
      exercises: exercises.map(ex => ({
        name: ex.name,
        sets: (sets[ex.name]||[]).filter(s=>s.done).map(s => ({weight:s.w, reps:s.r, rpe:s.rpe||null, difficulty:s.difficulty||null})),
      })),
    };
    setCelebData({ workout, vol, elapsed });
  };

  return (
    <div className="push-screen">

      {/* ── Workout Complete celebration overlay ── */}
      {celebData && (
        <div style={{
          position:'absolute',inset:0,zIndex:100,overflow:'auto',
          background:'linear-gradient(180deg,#0E3D20 0%,rgba(48,209,88,0.35) 45%,var(--bg) 100%)',
          display:'flex',flexDirection:'column',alignItems:'center',padding:'0 24px',
        }}>
          <div style={{flex:1,minHeight:48}}/>
          <div style={{
            width:96,height:96,borderRadius:48,background:'rgba(255,255,255,0.15)',
            display:'flex',alignItems:'center',justifyContent:'center',
            marginBottom:18,fontSize:48,color:'#fff',fontWeight:800,lineHeight:1,
          }}>✓</div>
          <div style={{fontSize:32,fontWeight:800,color:'#fff',letterSpacing:'-0.03em',marginBottom:6}}>Workout Complete</div>
          <div style={{fontSize:15,color:'rgba(255,255,255,0.7)',marginBottom:32,textAlign:'center'}}>
            {state?.pushedData?.sessionTitle || 'Push · Chest + Tri'}
          </div>
          <div style={{display:'grid',gridTemplateColumns:'1fr 1fr',gap:10,width:'100%',marginBottom:24}}>
            {[
              {l:'Duration',  v:`${Math.max(1,Math.round(celebData.elapsed/60))}m`},
              {l:'Sets Done', v:`${celebData.workout.totalSets}`},
              {l:'Volume',    v:celebData.vol>=1000?`${Math.round(celebData.vol/1000)}k lb`:`${Math.round(celebData.vol)} lb`},
              {l:'Exercises', v:`${exercises.length}`},
            ].map(({l,v}) => (
              <div key={l} style={{background:'rgba(255,255,255,0.12)',borderRadius:14,padding:'16px 12px',textAlign:'center'}}>
                <div style={{fontSize:28,fontWeight:800,color:'#fff',letterSpacing:'-0.03em'}}>{v}</div>
                <div style={{fontSize:10,fontWeight:700,color:'rgba(255,255,255,0.6)',marginTop:4,letterSpacing:'0.05em',textTransform:'uppercase'}}>{l}</div>
              </div>
            ))}
          </div>
          <div style={{flex:1,minHeight:16}}/>
          <button
            onClick={() => dispatch({type:'LOG_WORKOUT',workout:celebData.workout})}
            style={{
              width:'100%',height:56,borderRadius:18,
              background:'#fff',color:'#0E3D20',
              fontSize:18,fontWeight:800,border:'none',marginBottom:48,
            }}>
            Done
          </button>
        </div>
      )}

      {/* Nav */}
      <div className="nav-bar" style={{borderBottom:'1px solid var(--sep)'}}>
        <div className="nav-left">
          <button className="nav-btn" onClick={() => dispatch({type:'POP_SCREEN'})}>
            <I.chevronL size={20}/> Train
          </button>
        </div>
        <div className="nav-title">{state?.pushedData?.sessionTitle || 'Push · Chest + Tri'}</div>
        <div className="nav-right">
          <button className="nav-btn danger" onClick={finish} style={{fontWeight:600}}>Finish</button>
        </div>
      </div>

      {/* Stats row */}
      <div style={{display:'flex',borderBottom:'1px solid var(--sep)',flexShrink:0}}>
        {[
          ['ELAPSED', `${String(em).padStart(2,'0')}:${String(es).padStart(2,'0')}`],
          ['SETS', `${doneSets}/${allSets.length}`],
          ['VOL', `${Math.round(vol/1000)}k`],
        ].map(([l,v],i) => (
          <div key={i} style={{flex:1,padding:'14px 0',textAlign:'center',borderLeft:i?'1px solid var(--sep)':'none'}}>
            <div className="eyebrow">{l}</div>
            <div className="mono tabular" style={{fontSize:22,fontWeight:800,marginTop:4,color:'var(--ink)',letterSpacing:'-0.03em'}}>{v}</div>
          </div>
        ))}
      </div>

      <div className="screen-area">
        {restOn && restSecs > 0 && (
          <div style={{padding:'12px 0 0'}}>
            <RestBanner secs={restSecs} running={restOn} onToggle={() => setRestOn(v=>!v)} onSkip={() => {setRestSecs(0);setRestOn(false);}}/>
          </div>
        )}

        {/* Muscle diagram */}
        <div style={{padding:'12px 16px 4px',display:'flex',alignItems:'center',justifyContent:'space-between'}}>
          <div>
            <div style={{fontWeight:800,fontSize:20,letterSpacing:'-0.02em',textTransform:'uppercase',color:'var(--ink)'}}>{activeMusc}</div>
            <div className="eyebrow" style={{marginTop:3}}>ACTIVE MUSCLE</div>
          </div>
          <MuscleBody active={activeMusc} secondary={exercises[activeEx]?.secondary||[]} height={110} interactive={false}/>
        </div>

        {/* Exercises */}
        <div style={{padding:'4px 16px'}}>
          {exercises.map((ex,i) => (
            <ExerciseCard
              key={ex.id || ex.name} ex={ex}
              sets={sets[ex.name] || []}
              setSets={ss => setSets(prev => ({...prev, [ex.name]: ss}))}
              isActive={activeEx===i}
              onActivate={() => { setActiveEx(i); setActiveMusc(ex.muscle); }}
              onComplete={onSetComplete}
              activeMusc={activeMusc}
              setActiveMuscle={setActiveMusc}
              onSwap={() => dispatch({
                type: 'OPEN_SHEET',
                sheet: 'swapExercise',
                data: {
                  currentName: ex.name,
                  target: ex.target || ex.muscle || 'chest',
                  onSwap: (newName) => updateExerciseName(ex.id, newName),
                },
              })}
            />
          ))}
        </div>

        {/* Finish CTA */}
        <div style={{padding:'8px 16px 32px'}}>
          <button className="btn-primary danger" onClick={finish}>
            <I.stop size={18}/>
            Finish Workout
          </button>
        </div>
      </div>
    </div>
  );
}

export { ActiveSession };
