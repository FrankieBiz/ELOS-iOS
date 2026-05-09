import React from 'react'
import { I } from '../icons.jsx'
import { Ring } from '../shell.jsx'
const { useState: uS_m } = React;

function SleepCard({ sleepLog, dispatch }) {
  const last = sleepLog[0];
  const qualityLabels = ['','Terrible','Poor','Okay','Good','Great'];

  const raw = (sleepLog || []).slice(0, 7).reverse().map(s => s.dur);
  const bars = Array.from({length: 7}, (_, i) => raw[i] != null ? raw[i] : 0);

  return (
    <div className="card" style={{margin:'0 16px'}}>
      <div className="cell">
        <div className="cell-label" style={{fontWeight:600}}>Sleep</div>
        <button className="btn-primary xs" onClick={() => dispatch({type:'OPEN_SHEET',sheet:'logSleep'})}>
          + Log
        </button>
      </div>
      {last ? (
        <div style={{padding:'0 16px 16px'}}>
          <div style={{display:'grid',gridTemplateColumns:'1fr 1fr 1fr',gap:0,paddingTop:8,paddingBottom:12,borderBottom:'1px solid var(--sep)'}}>
            <div>
              <div className="eyebrow">Duration</div>
              <div className="mono tabular" style={{fontSize:30,fontWeight:800,letterSpacing:'-0.03em',color:'var(--ink)',marginTop:4,lineHeight:1}}>{last.dur}<span style={{fontSize:13,color:'var(--ink-3)',marginLeft:3,fontWeight:500}}>h</span></div>
            </div>
            <div>
              <div className="eyebrow">Quality</div>
              <div style={{fontSize:18,fontWeight:800,letterSpacing:'-0.01em',color:'var(--ink)',marginTop:8}}>{qualityLabels[last.quality]}</div>
            </div>
            <div style={{textAlign:'right'}}>
              <div className="eyebrow">Bed · Wake</div>
              <div className="mono tabular" style={{fontSize:13,fontWeight:600,color:'var(--ink)',marginTop:6}}>{last.bed}</div>
              <div className="mono tabular" style={{fontSize:13,fontWeight:600,color:'var(--ink-3)',marginTop:2}}>{last.wake}</div>
            </div>
          </div>
          <div style={{display:'flex',gap:4,alignItems:'flex-end',height:40,paddingTop:14}}>
            {bars.map((h, i) => (
              <div key={i} style={{flex:1,background:i===bars.length-1?'var(--tint)':'var(--sep-strong)',height:`${(h/9)*100}%`,minHeight:h>0?6:3,opacity:h===0?0.3:1}}/>
            ))}
          </div>
          <div className="eyebrow" style={{marginTop:8,textAlign:'center'}}>Last 7 nights</div>
        </div>
      ) : (
        <div style={{padding:'12px 16px',color:'var(--ink-3)',fontSize:14}}>No sleep logged yet.</div>
      )}
    </div>
  );
}

function HydrationCard({ hydration, hydGoal, dispatch }) {
  const pct = Math.min(100, hydration/hydGoal*100);
  return (
    <div className="card" style={{margin:'0 16px'}}>
      <div className="cell">
        <div className="cell-label" style={{fontWeight:600}}>Hydration</div>
        <div className="mono tabular" style={{fontSize:14,fontWeight:700,color:'var(--ink)'}}>{hydration}<span style={{color:'var(--ink-3)',fontWeight:500}}>/{hydGoal} oz</span></div>
      </div>
      <div style={{padding:'4px 16px 14px'}}>
        <div className="prog" style={{height:6,marginBottom:14}}>
          <div className="fill" style={{width:`${pct}%`,background:'var(--tint)'}}/>
        </div>
        <div style={{display:'flex',gap:8}}>
          {[8,16,32].map(oz => (
            <button key={oz} className="btn-primary secondary xs" style={{flex:1,height:38}}
                    onClick={() => dispatch({type:'ADD_HYDRATION',oz})}>
              +{oz} oz
            </button>
          ))}
        </div>
      </div>
    </div>
  );
}

function RecentWorkouts({ workoutHistory, dispatch }) {
  const recent = (workoutHistory || []).slice(0, 3);
  const total = (workoutHistory || []).length;
  return (
    <div className="card" style={{margin:'0 16px'}}>
      <div className="cell">
        <div className="cell-label" style={{fontWeight:600}}>Recent workouts</div>
        <button className="btn-primary xs" onClick={() => dispatch({type:'SET_TAB',tab:'train'})}>Train</button>
      </div>
      {recent.length === 0 ? (
        <div style={{padding:'12px 16px 14px',display:'flex',alignItems:'center',justifyContent:'space-between'}}>
          <span style={{color:'var(--ink-3)',fontSize:13}}>No sessions yet</span>
          <button className="btn-primary xs secondary" onClick={() => dispatch({type:'SET_TAB',tab:'train'})}>
            <I.play size={13}/>
            Start one
          </button>
        </div>
      ) : (
        <div style={{paddingBottom:6}}>
          {recent.map((w, i) => (
            <div key={i} className="cell" style={{paddingTop:10,paddingBottom:10}}>
              <div style={{flex:1,minWidth:0}}>
                <div className="eyebrow">{new Date(w.date).toLocaleDateString('en-US',{weekday:'short',month:'short',day:'numeric'})}</div>
                <div style={{fontSize:13,fontWeight:600,color:'var(--ink-3)',marginTop:3,overflow:'hidden',textOverflow:'ellipsis',whiteSpace:'nowrap'}}>
                  {(w.exercises||[]).map(e=>e.name).slice(0,2).join(', ') || `${Math.round((w.durationSec||0)/60)} min`}
                </div>
              </div>
              <div style={{textAlign:'right',flexShrink:0}}>
                <div className="mono tabular" style={{fontSize:18,fontWeight:800,letterSpacing:'-0.02em',color:'var(--ink)'}}>{(w.totalVolume||0).toLocaleString()}<span className="eyebrow" style={{marginLeft:4}}>lb</span></div>
                <div className="eyebrow" style={{marginTop:2}}>{w.totalSets} sets</div>
              </div>
            </div>
          ))}
          {total > 3 && (
            <div className="cell tappable" onClick={() => dispatch({type:'PUSH_SCREEN', screen:'workoutHistory'})}>
              <div className="cell-label" style={{fontSize:14,color:'var(--tint)'}}>View all {total} sessions</div>
              <I.chevronR size={16} stroke="var(--tint)"/>
            </div>
          )}
        </div>
      )}
    </div>
  );
}

function HabitsHeatmap({ habits }) {
  const [selected, setSelected] = uS_m(null);
  const weeks = 24;
  const cells = Array.from({length:weeks*7},(_,i) => {
    const seed = (i*31)%100;
    return seed>85?0:seed>65?1:seed>40?2:seed>15?3:4;
  });
  const done = habits.filter(h=>h.done).length;
  const best = habits.reduce((m,h) => Math.max(m,h.streak),0);
  const avg30 = habits.length > 0
    ? Math.round(habits.reduce((s,h) => s + Math.min(h.streak, 30), 0) / habits.length / 30 * 100)
    : 0;

  const handleCellClick = (v, i) => {
    if (selected === i) { setSelected(null); return; }
    setSelected(i);
  };

  const selV = selected != null ? cells[selected] : null;
  const total = habits.length || 1;
  const selDone = selV != null ? Math.round((selV / 4) * total) : null;
  const selPct = selV != null ? Math.round((selV / 4) * 100) : null;

  return (
    <div className="card" style={{margin:'0 16px'}}>
      <div className="cell">
        <div className="cell-label" style={{fontWeight:600}}>Habits</div>
        <div className="mono tabular" style={{fontSize:14,fontWeight:700,color:'var(--ink)'}}>{done}<span style={{color:'var(--ink-3)',fontWeight:500}}>/{habits.length} today</span></div>
      </div>
      <div style={{padding:'8px 16px 16px'}}>
        <div className="heatmap">
          {cells.map((v,i) => (
            <div key={i} className="hm-cell" data-l={v||''}
                 style={{cursor:'pointer', outline: selected===i ? '1.5px solid var(--tint)' : 'none'}}
                 onClick={() => handleCellClick(v, i)}/>
          ))}
        </div>
        {selected != null && (
          <div style={{marginTop:10,padding:'6px 10px',background:'var(--bg-card2)',
                       fontSize:11,color:'var(--ink-2)',display:'inline-flex',gap:8,alignItems:'center',letterSpacing:'0.04em'}}>
            <span className="mono tabular" style={{fontWeight:700,color:'var(--tint)'}}>{selDone}/{total}</span>
            <span className="mono tabular" style={{fontWeight:700}}>{selPct}%</span>
            <button style={{marginLeft:4,background:'none',border:'none',padding:0,cursor:'pointer',color:'var(--ink-4)',fontSize:14,lineHeight:1}}
                    onClick={() => setSelected(null)}>×</button>
          </div>
        )}
        <div style={{display:'grid',gridTemplateColumns:'repeat(3,1fr)',gap:0,marginTop:14,paddingTop:14,borderTop:'1px solid var(--sep)'}}>
          <div>
            <div className="eyebrow">Best streak</div>
            <div className="mono tabular" style={{fontSize:24,fontWeight:800,letterSpacing:'-0.03em',color:'var(--ink)',marginTop:4,lineHeight:1}}>{best}<span style={{fontSize:12,color:'var(--ink-3)',marginLeft:2}}>d</span></div>
          </div>
          <div>
            <div className="eyebrow">30-day avg</div>
            <div className="mono tabular" style={{fontSize:24,fontWeight:800,letterSpacing:'-0.03em',color:'var(--ink)',marginTop:4,lineHeight:1}}>{avg30}<span style={{fontSize:12,color:'var(--ink-3)',marginLeft:2}}>%</span></div>
          </div>
          <div>
            <div className="eyebrow">Today</div>
            <div className="mono tabular" style={{fontSize:24,fontWeight:800,letterSpacing:'-0.03em',color:'var(--ink)',marginTop:4,lineHeight:1}}>{done}<span style={{fontSize:12,color:'var(--ink-3)',marginLeft:2}}>/{habits.length}</span></div>
          </div>
        </div>
      </div>
    </div>
  );
}

const PERSONA_META_ME = {
  peak:         {l:'Peak Mode',      c:'var(--m-gym)'},
  examSeason:   {l:'Exam Season',    c:'var(--m-assign)'},
  summerAthlete:{l:'Summer Athlete', c:'var(--m-habits)'},
  inSeason:     {l:'In-Season',      c:'var(--m-nutri)'},
  bulk:         {l:'Bulk Mode',      c:'var(--tint)'},
};

function ProfileHeader({ profile, onToggleTheme, theme, personaMode, dispatch }) {
  const name = (profile && profile.name) || 'ELOS User';
  const subtitle = (profile && profile.subtitle) || '';
  const initials = (profile && profile.initials) ||
    (name.length >= 2 ? name.slice(0,2).toUpperCase() : 'EL');
  const meta = PERSONA_META_ME[personaMode] || PERSONA_META_ME.peak;
  return (
    <div style={{padding:'4px 16px 18px',display:'flex',alignItems:'center',gap:14}}>
      <div style={{width:54,height:54,borderRadius:8,background:'var(--ink)',
                   display:'flex',alignItems:'center',justifyContent:'center',flexShrink:0,
                   color:'var(--bg)',fontSize:18,fontWeight:800,letterSpacing:'0.02em'}}>{initials}</div>
      <div style={{flex:1,minWidth:0}}>
        <div style={{fontSize:24,fontWeight:800,letterSpacing:'-0.025em',lineHeight:1}}>{name}</div>
        {subtitle ? <div className="eyebrow" style={{marginTop:6}}>{subtitle}</div> : null}
        <div onClick={() => dispatch({type:'OPEN_SHEET',sheet:'personaPicker'})}
             style={{display:'inline-flex',alignItems:'center',gap:5,marginTop:7,paddingLeft:8,paddingRight:10,
                     height:24,borderRadius:12,background:`color-mix(in srgb, ${meta.c} 15%, var(--bg-card2))`,
                     border:`1px solid color-mix(in srgb, ${meta.c} 30%, transparent)`,cursor:'pointer'}}>
          <div style={{width:7,height:7,borderRadius:4,background:meta.c}}/>
          <span style={{fontSize:11,fontWeight:700,color:meta.c,letterSpacing:'0.04em'}}>{meta.l}</span>
        </div>
      </div>
      <button className="icon-btn muted" onClick={onToggleTheme} style={{flexShrink:0}}>
        {theme==='light' ? <I.moon size={20}/> : <I.sun size={20}/>}
      </button>
    </div>
  );
}

function SettingsLinks({ dispatch, personaMode }) {
  const meta = PERSONA_META_ME[personaMode] || PERSONA_META_ME.peak;
  const items = [
    { icon: I.gear,     l:'Preferences',     color:'var(--ink-3)',    screen:'preferences'    },
    { icon: I.calendar, l:'Canvas LMS sync',  color:'var(--m-sched)',  screen:'canvas'         },
    { icon: I.dumbbell, l:'Training profile', color:'var(--m-gym)',    screen:'trainingProfile'},
    { icon: I.fork,     l:'Nutrition goals',  color:'var(--m-nutri)',  screen:'nutritionGoals' },
    { icon: I.note,     l:'Spaces & notes',   color:'var(--m-assign)', screen:'spaces'         },
    { icon: I.info,     l:'About ELOS',       color:'var(--ink-3)',    screen:'about'          },
  ];
  return (
    <div className="card" style={{margin:'0 16px'}}>
      {/* Program Persona row */}
      <div className="cell tappable" onClick={() => dispatch({type:'OPEN_SHEET',sheet:'personaPicker'})}>
        <div style={{width:30,height:30,borderRadius:8,
                     background:`color-mix(in srgb, ${meta.c} 15%, var(--bg-card2))`,
                     display:'flex',alignItems:'center',justifyContent:'center',flexShrink:0}}>
          <div style={{width:12,height:12,borderRadius:6,background:meta.c}}/>
        </div>
        <div className="cell-label">Program Persona</div>
        <span style={{fontSize:11,fontWeight:700,color:meta.c,marginRight:4}}>{meta.l}</span>
        <I.chevronR size={16} stroke="var(--ink-4)"/>
      </div>
      {items.map((it,i) => {
        const Ico = it.icon;
        return (
          <div key={i} className="cell tappable" onClick={() => dispatch({type:'PUSH_SCREEN', screen: it.screen})}>
            <div style={{width:30,height:30,borderRadius:8,background:it.color==='var(--ink-3)'?'var(--bg-card2)':`color-mix(in srgb, ${it.color} 15%, var(--bg-card2))`,
                         display:'flex',alignItems:'center',justifyContent:'center',flexShrink:0}}>
              <Ico size={16} stroke={it.color}/>
            </div>
            <div className="cell-label">{it.l}</div>
            <I.chevronR size={16} stroke="var(--ink-4)"/>
          </div>
        );
      })}
    </div>
  );
}

function Me({ state, dispatch }) {
  return (
    <div className="screen-area enter">
      <div className="nav-bar">
        <div className="nav-title">Me</div>
        <div className="nav-right">
          <button className="icon-btn muted" onClick={() => dispatch({type:'PUSH_SCREEN', screen:'preferences'})}>
            <I.gear size={20}/>
          </button>
        </div>
      </div>

      <ProfileHeader
        profile={state.profile}
        onToggleTheme={() => dispatch({type:'SET_THEME',theme:state.theme==='light'?'dark':'light'})}
        theme={state.theme}
        personaMode={state.personaMode}
        dispatch={dispatch}
      />

      <div className="section-header" style={{padding:'0 20px 10px'}}>Health</div>
      <SleepCard sleepLog={state.sleepLog} dispatch={dispatch}/>
      <div style={{height:10}}/>
      <HydrationCard hydration={state.hydration} hydGoal={state.hydGoal} dispatch={dispatch}/>

      <div className="section-header" style={{padding:'20px 20px 10px'}}>Workouts</div>
      <RecentWorkouts workoutHistory={state.workoutHistory} dispatch={dispatch}/>

      <div className="section-header" style={{padding:'20px 20px 10px'}}>Habits</div>
      <HabitsHeatmap habits={state.habits}/>

      <div className="section-header" style={{padding:'20px 20px 10px'}}>Settings</div>
      <SettingsLinks dispatch={dispatch} personaMode={state.personaMode}/>
      <div style={{height:32}}/>
    </div>
  );
}

export { Me };
