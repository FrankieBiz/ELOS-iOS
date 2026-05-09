import React from 'react'
import { I } from '../icons.jsx'
import { Ring, SegCtrl } from '../shell.jsx'
const { useState: uS_t, useEffect: uE_t } = React;

function ElosScoreCard({ state }) {
  const habits = state.habits || [];
  const done = habits.filter(h=>h.done).length;
  const total = habits.length || 1;
  const habitScore   = Math.round((done/total) * 300);
  const hydScore     = Math.round(Math.min(1,(state.hydration||0)/(state.hydGoal||128)) * 200);
  const lastSleep    = (state.sleepLog||[])[0];
  const sleepScore   = lastSleep ? Math.round((lastSleep.quality/5) * 250) : 0;
  const lastWorkout  = (state.workoutHistory||[])[0];
  const workoutScore = lastWorkout ? Math.min(250, Math.round((lastWorkout.totalSets||0) * 10)) : 0;
  const score = Math.min(1000, habitScore + hydScore + sleepScore + workoutScore);
  const pct   = score / 10;
  const scoreColor = score < 300 ? 'var(--ink-3)' : score < 600 ? 'var(--m-habits)' : score < 800 ? 'var(--m-gym)' : 'var(--tint)';
  const label = score < 300 ? 'Rest Mode' : score < 600 ? 'Building Momentum' : score < 800 ? 'Elite Form' : 'Peak Performance';
  const comps = [
    {l:'Habits',    v:habitScore,   max:300, c:'var(--m-habits)'},
    {l:'Hydration', v:hydScore,     max:200, c:'var(--m-nutri)'},
    {l:'Sleep',     v:sleepScore,   max:250, c:'var(--m-health)'},
    {l:'Training',  v:workoutScore, max:250, c:'var(--m-gym)'},
  ];
  return (
    <div className="card" style={{margin:'0 16px 14px',padding:'14px 16px 16px'}}>
      <div style={{display:'flex',alignItems:'center',gap:16,marginBottom:12}}>
        <div style={{position:'relative',width:72,height:72,flexShrink:0}}>
          <svg width="72" height="72" viewBox="0 0 72 72">
            <circle cx="36" cy="36" r="30" fill="none" stroke="var(--sep-strong)" strokeWidth="6"/>
            <circle cx="36" cy="36" r="30" fill="none" stroke={scoreColor} strokeWidth="6"
                    strokeDasharray={`${(pct/100)*188.5} 188.5`}
                    strokeLinecap="round" transform="rotate(-90 36 36)"/>
          </svg>
          <div style={{position:'absolute',inset:0,display:'flex',alignItems:'center',justifyContent:'center'}}>
            <div className="mono tabular" style={{fontSize:17,fontWeight:800,color:'var(--ink)',lineHeight:1}}>{score}</div>
          </div>
        </div>
        <div style={{flex:1,minWidth:0}}>
          <div className="eyebrow">ELOS ATHLETE SCORE</div>
          <div style={{fontSize:20,fontWeight:800,letterSpacing:'-0.025em',color:scoreColor,marginTop:4,lineHeight:1.1}}>{label}</div>
          <div className="small muted" style={{marginTop:4}}>out of 1,000 pts today</div>
        </div>
      </div>
      {comps.map(c => (
        <div key={c.l} style={{display:'flex',alignItems:'center',gap:10,marginBottom:5}}>
          <div style={{width:68,fontSize:10,fontWeight:600,color:'var(--ink-3)',textTransform:'uppercase',letterSpacing:'0.04em',flexShrink:0}}>{c.l}</div>
          <div className="prog" style={{flex:1,height:4}}>
            <div className="fill" style={{width:`${Math.min(100,(c.v/c.max)*100)}%`,background:c.c,height:4}}/>
          </div>
          <div className="mono tabular" style={{fontSize:11,fontWeight:700,color:'var(--ink-3)',width:38,textAlign:'right'}}>{c.v}/{c.max}</div>
        </div>
      ))}
    </div>
  );
}

function HabitStrip({ habits, dispatch }) {
  return (
    <div className="hide-scroll" style={{ display:'flex', gap:10, overflowX:'auto', padding:'0 16px 4px' }}>
      {habits.map(h => (
        <div key={h.k} className={`habit-pill${h.done?' done':''}`}
             onClick={() => dispatch({type:'TOGGLE_HABIT',k:h.k})}>
          <div className={`habit-check${h.done?' done':''}`}>
            {h.done && <I.check size={13}/>}
          </div>
          <div style={{minWidth:0}}>
            <div style={{fontSize:13,fontWeight:600,overflow:'hidden',textOverflow:'ellipsis',whiteSpace:'nowrap',letterSpacing:'-0.01em'}}>{h.l}</div>
            <div className="eyebrow" style={{marginTop:3}}>{h.streak}d streak</div>
          </div>
        </div>
      ))}
      <div style={{paddingRight:6, flexShrink:0, display:'flex', alignItems:'center'}}>
        <button className="icon-btn muted" style={{width:36,height:36}} onClick={() => dispatch({type:'OPEN_SHEET',sheet:'addHabit'})}>
          <I.plus size={18}/>
        </button>
      </div>
    </div>
  );
}

function TodayBlocks({ state, dispatch }) {
  if (!state) return null; // guard against HMR undefined-state renders
  const colorMap = { health:'var(--m-health)', schedule:'var(--m-sched)', nutrition:'var(--m-nutri)', gym:'var(--m-gym)', assign:'var(--m-assign)', exams:'var(--m-exams)' };
  const blocks = [
    { k:'b-hydrate', t:'07:00', l:'Morning hydrate + stretch', mod:'health',   dur:'15m' },
    { k:'b-calc',    t:'08:10', l:'AP Calc BC · Period 2',     mod:'schedule', dur:'55m' },
    { k:'b-lunch',   t:'12:05', l:'Lunch · chicken & rice',    mod:'nutrition',dur:'30m' },
    { k:'b-push',    t:'15:30', l:'Push · Chest + Triceps',    mod:'gym',      dur:'65m', cta:true },
    { k:'b-physics', t:'17:00', l:'AP Physics exam prep',      mod:'exams',    dur:'90m' },
    { k:'b-sleep',   t:'22:30', l:'Wind down · sleep 7.5h',    mod:'health',   dur:'—'   },
  ];
  const completed = state.scheduleCompleted || {};
  return (
    <div className="card" style={{margin:'0 16px', overflow:'hidden'}}>
      {blocks.map((b) => {
        const done = !!completed[b.k];
        return (
          <div key={b.k} className="time-block tappable"
               onClick={b.cta
                 ? () => dispatch({type:'PUSH_SCREEN',screen:'activeSession'})
                 : () => dispatch({type:'TOGGLE_SCHEDULE_BLOCK', key:b.k})}>
            <div className="tb-time">{b.t}</div>
            <div className="tb-bar" style={{background: done ? 'var(--sep-strong)' : colorMap[b.mod], opacity: done ? 0.4 : 1}}/>
            <div className="tb-body">
              <div className="tb-label" style={{color: done ? 'var(--ink-3)' : 'var(--ink)', textDecoration: done ? 'line-through' : 'none'}}>{b.l}</div>
              {b.cta && !done && <div className="tb-sub" style={{color:'var(--m-gym)',fontWeight:600,letterSpacing:'0.06em',textTransform:'uppercase',fontSize:10}}>Tap to start →</div>}
            </div>
            <div className="tb-dur">{b.dur}</div>
          </div>
        );
      })}
    </div>
  );
}

function UpNext({ assignments, dispatch }) {
  const pending = assignments.filter(a => !a.done).slice(0,3);
  if (!pending.length) return null;
  return (
    <div className="card" style={{margin:'0 16px'}}>
      {pending.map((a,i) => (
        <div key={a.id} className="assign-row" style={{position:'relative'}}
             onClick={() => dispatch({type:'TOGGLE_ASSIGNMENT',id:a.id})}>
          <div className={`assign-check${a.done?' done':''}`}>{a.done && <I.check size={13}/>}</div>
          <div className="assign-label">
            <div className={`assign-name${a.done?' done':''}`}>{a.l}</div>
            <div className="assign-meta">{a.cls} · {a.due}</div>
          </div>
          {a.urgent && !a.done && <span className="chip" style={{background:'var(--m-exams-s)',color:'var(--m-exams)',fontSize:11}}>Due soon</span>}
        </div>
      ))}
      <div className="cell tappable" onClick={() => { dispatch({type:'SET_TAB',tab:'plan'}); dispatch({type:'SET_PLAN_TAB',tab:'assignments'}); }}>
        <div className="cell-label" style={{fontSize:14,color:'var(--tint)'}}>View all assignments</div>
        <I.chevronR size={16} stroke="var(--ink-4)"/>
      </div>
    </div>
  );
}

function QuickStats({ state, dispatch }) {
  if (!state) return null;
  const meals = Object.values(state.meals || {}).flat();
  const cal = meals.reduce((s,m) => s+m.kcal, 0);
  const sleep = state.sleepLog[0];
  const lastWorkout = (state.workoutHistory || [])[0];
  const vol = lastWorkout?.totalVolume ?? null;
  const over = cal > state.calGoal;
  const qualLabel = ['','Terrible','Poor','Okay','Good','Great'];
  return (
    <>
      <div className="stats-strip">
        <div className="stat-card tappable" onClick={() => dispatch({type:'SET_TAB',tab:'eat'})}>
          <div className="stat-label">KCAL</div>
          <div className="stat-value" style={{color: over ? 'var(--warn)' : undefined}}>{cal}</div>
          <div className="stat-sub">{over ? `+${cal - state.calGoal} over` : `${state.calGoal - cal} left`}</div>
        </div>
        <div className="stat-card tappable" onClick={() => dispatch({type:'OPEN_SHEET',sheet:'logSleep'})}>
          <div className="stat-label">SLEEP</div>
          <div className="stat-value">{sleep ? sleep.dur : '—'}</div>
          <div className="stat-sub">{sleep ? qualLabel[sleep.quality] : 'tap to log'}</div>
        </div>
        <div className="stat-card tappable" onClick={() => dispatch({type:'SET_TAB',tab:'train'})}>
          <div className="stat-label">VOL</div>
          <div className="stat-value">{vol != null ? `${Math.round(vol/1000)}k` : '—'}</div>
          <div className="stat-sub">{vol != null ? 'lb lifted' : 'no session'}</div>
        </div>
        <div className="stat-card tappable" onClick={() => dispatch({type:'SET_TAB',tab:'me'})}>
          <div className="stat-label">H₂O</div>
          <div className="stat-value">{state.hydration}</div>
          <div className="stat-sub">of {state.hydGoal} oz</div>
        </div>
      </div>
      <div style={{display:'flex',gap:8,padding:'10px 16px 16px'}}>
        {[8,16,32].map(oz => (
          <button key={oz} className="btn-primary secondary xs" style={{flex:1,height:34}}
                  onClick={() => dispatch({type:'ADD_HYDRATION',oz})}>+{oz} oz</button>
        ))}
      </div>
    </>
  );
}

function Today({ state, dispatch }) {
  uE_t(() => {
    const intent = new URLSearchParams(location.search).get('intent');
    if (intent === 'logMeal') {
      dispatch({type:'OPEN_SHEET', sheet:'logMeal', data:{mealKey:'snacks', title:'Snack'}});
    } else if (intent === 'startWorkout') {
      dispatch({type:'PUSH_SCREEN', screen:'activeSession'});
    } else if (intent === 'logSleep') {
      dispatch({type:'OPEN_SHEET', sheet:'logSleep'});
    }
    if (intent) {
      history.replaceState({}, '', location.pathname);
    }
  }, []);

  const done = state.habits.filter(h=>h.done).length;
  const total = state.habits.length;
  const pct = total ? Math.round(done/total*100) : 0;
  const greeting = ['Good evening','Good morning','Good afternoon','Good evening'][(() => { const h=new Date().getHours(); return h<5?3:h<12?1:h<17?2:3; })()];
  const dateLine = new Date().toLocaleDateString('en-US',{weekday:'long',month:'long',day:'numeric'}).toUpperCase();
  return (
    <div className="screen-area enter">
      <div className="nav-bar">
        <div className="nav-title">{dateLine}</div>
      </div>
      <div className="large-title">
        {greeting},<br/>{(state.profile?.name||'Frank').split(' ')[0]}.
      </div>

      {/* ELOS Athlete Score */}
      <ElosScoreCard state={state}/>

      {/* Habits */}
      <div style={{marginBottom:8}}>
        <div style={{display:'flex',alignItems:'center',justifyContent:'space-between',padding:'0 16px 10px'}}>
          <div className="section-header" style={{marginBottom:0}}>Habits · {done}/{total}</div>
          <Ring value={pct} size={36} stroke={4} color="var(--m-habits)">
            <span className="mono" style={{fontSize:9,fontWeight:600}}>{pct}%</span>
          </Ring>
        </div>
        <HabitStrip habits={state.habits} dispatch={dispatch}/>
      </div>

      {/* Today schedule */}
      <div className="section-header" style={{padding:'10px 20px 8px'}}>Today's schedule</div>
      <TodayBlocks state={state} dispatch={dispatch}/>

      {/* Up next */}
      <div className="section-header" style={{padding:'20px 20px 8px'}}>Upcoming due</div>
      <UpNext assignments={state.assignments} dispatch={dispatch}/>

      {/* Stats */}
      <div className="section-header" style={{padding:'20px 20px 8px'}}>Today at a glance</div>
      <QuickStats state={state} dispatch={dispatch}/>
    </div>
  );
}

export { Today };
