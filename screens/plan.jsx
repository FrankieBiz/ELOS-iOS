import React from 'react'
import { I } from '../icons.jsx'
import { SegCtrl } from '../shell.jsx'
const { useState: uS_p, useEffect: uE_p } = React;

const DAY_LABELS = ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'];
const LOAD_COLOR = {Light:'var(--m-gym)',Medium:'var(--m-sched)',Heavy:'var(--m-health)',Rest:'var(--ink-4)'};

const BASE_SCHEDULE_BLOCKS = [
  {t:'07:00',l:'Wake + hydrate',      mod:'health',    dur:'15m', pri:1, sub:''},
  {t:'07:30',l:'Breakfast',           mod:'nutrition', dur:'25m', pri:2, sub:'Target 35g protein'},
  {t:'08:10',l:'AP Calc BC · P2',     mod:'schedule',  dur:'55m', pri:3, sub:'Derivatives ch. 4'},
  {t:'09:15',l:'AP Physics · P3',     mod:'schedule',  dur:'55m', pri:3, sub:'Momentum lab'},
  {t:'10:20',l:'Free · study buffer', mod:'assign',    dur:'40m', pri:4, sub:'Lit essay'},
  {t:'12:05',l:'Lunch',               mod:'nutrition', dur:'30m', pri:2, sub:''},
  {t:'13:10',l:'AP English · P5',     mod:'schedule',  dur:'55m', pri:3, sub:''},
  {t:'14:15',l:'AP US History · P6',  mod:'schedule',  dur:'55m', pri:3, sub:'DBQ workshop'},
  {t:'15:30',l:'Push · Chest + Tri',  mod:'gym',       dur:'65m', pri:5, sub:'PPL day 4'},
  {t:'17:00',l:'Physics exam prep',   mod:'exams',     dur:'90m', pri:4, sub:'Unit 4 · 2 days out'},
  {t:'19:00',l:'Dinner',              mod:'nutrition', dur:'40m', pri:2, sub:''},
  {t:'20:00',l:'Nonprofit tutoring',  mod:'assign',    dur:'60m', pri:4, sub:''},
  {t:'22:30',l:'Wind down',           mod:'health',    dur:'—',   pri:1, sub:''},
];
const MOD_COLOR = {schedule:'var(--m-sched)',gym:'var(--m-gym)',nutrition:'var(--m-nutri)',assign:'var(--m-assign)',health:'var(--m-health)',exams:'var(--m-exams)'};

/* Parse "HH:MM" → total minutes */
function parseTime(t) {
  const [h, m] = t.split(':').map(Number);
  return h * 60 + (m || 0);
}
/* Minutes → "HH:MM" */
function fmtTime(mins) {
  const h = Math.floor(mins / 60) % 24;
  const m = mins % 60;
  return String(h).padStart(2,'0') + ':' + String(m).padStart(2,'0');
}

function regenerateBlocks(blocks) {
  /* Sort by priority (asc), then apply ±5-15 min jitter to start times */
  const sorted = [...blocks].sort((a, b) => a.pri - b.pri || parseTime(a.t) - parseTime(b.t));
  let moved = 0;
  const jittered = sorted.map((b, i) => {
    const base = parseTime(b.t);
    const jitter = (((i * 7 + 3) % 4) - 1) * 5; /* deterministic: -5, 0, +5, +10 pattern */
    const newMins = Math.max(0, base + jitter);
    if (fmtTime(newMins) !== b.t) moved++;
    return { ...b, t: fmtTime(newMins) };
  });
  return { blocks: jittered, moved };
}

function parseDate(dateStr) {
  /* Parse YYYY-MM-DD as local time to avoid UTC midnight off-by-one */
  const iso = /^(\d{4})-(\d{2})-(\d{2})$/.exec(dateStr);
  if (iso) return new Date(+iso[1], +iso[2]-1, +iso[3]);
  return new Date(dateStr);
}

function daysUntil(dateStr) {
  const d = parseDate(dateStr);
  if (isNaN(d)) return null;
  const today = new Date(); today.setHours(0,0,0,0);
  return Math.ceil((d - today) / 86400000);
}

function fmtExamDate(dateStr) {
  const d = parseDate(dateStr);
  if (isNaN(d)) return dateStr;
  return d.toLocaleDateString('en-US', { weekday:'short', month:'short', day:'numeric' }).toUpperCase();
}

function ScheduleView({ planDay, dispatch }) {
  const [blocks, setBlocks] = uS_p(BASE_SCHEDULE_BLOCKS);
  const [toast, setToast] = uS_p(null);
  const [doneBlocks, setDoneBlocks] = uS_p({});

  /* Compute today index: Mon=0 … Sun=6 */
  const todayIndex = (new Date().getDay() + 6) % 7;

  /* On first mount, sync planDay to actual today */
  uE_p(() => {
    if (planDay !== todayIndex) {
      dispatch({ type: 'SET_PLAN_DAY', day: todayIndex });
    }
  /* eslint-disable-next-line react-hooks/exhaustive-deps */
  }, []);

  /* Build week labels dynamically around today */
  const weekDays = DAY_LABELS.map((label, i) => {
    const offset = i - todayIndex;
    const d = new Date();
    d.setDate(d.getDate() + offset);
    const dateNum = d.getDate();
    const load = ['Medium','Heavy','Medium','Light','Heavy','Light','Rest'][i];
    return { d: label.slice(0,2), n: `${label} ${dateNum}`, load, today: i === todayIndex };
  });

  function handleRegenerate() {
    const { blocks: newBlocks, moved } = regenerateBlocks(blocks);
    setBlocks(newBlocks);
    setToast(`Schedule regenerated · ${moved} block${moved !== 1 ? 's' : ''} moved`);
    setTimeout(() => setToast(null), 2000);
  }

  return (
    <div>
      {/* Toast */}
      {toast && (
        <div style={{
          position:'sticky', top:0, zIndex:10,
          margin:'0 16px 8px', padding:'10px 14px',
          background:'var(--tint)', color:'#fff',
          borderRadius:10, fontSize:13, fontWeight:600, textAlign:'center',
        }}>
          {toast}
        </div>
      )}

      {/* Day picker */}
      <div style={{display:'grid',gridTemplateColumns:'repeat(7, 1fr)',padding:'0',borderTop:'1px solid var(--sep)',borderBottom:'1px solid var(--sep)',marginBottom:14}}>
        {weekDays.map((d,i) => (
          <button key={i} onClick={() => dispatch({type:'SET_PLAN_DAY',day:i})}
                  style={{
                    padding:'12px 2px 10px', textAlign:'center', cursor:'pointer',
                    background: planDay===i ? 'var(--tint)' : 'transparent',
                    borderRight: i < 6 ? '1px solid var(--sep)' : 'none',
                  }}>
            <div className="eyebrow" style={{color: planDay===i ? 'rgba(255,255,255,0.78)' : 'var(--ink-3)'}}>{d.d}</div>
            <div className="mono tabular" style={{fontSize:18,fontWeight:800,letterSpacing:'-0.02em',color: planDay===i ? '#fff' : 'var(--ink)',marginTop:4}}>{d.n.split(' ')[1]}</div>
            <div style={{height:3,marginTop:6,background:LOAD_COLOR[d.load],opacity: planDay===i ? 0.95 : 0.7}}/>
          </button>
        ))}
      </div>

      {/* Timeline */}
      <div className="card" style={{margin:'0 16px'}}>
        {blocks.map((b,i) => {
          const done = !!doneBlocks[i];
          return (
            <div key={i} className="time-block tappable"
                 onClick={() => {
                   if (b.mod === 'gym') {
                     dispatch({type:'PUSH_SCREEN', screen:'activeSession'});
                   } else {
                     setDoneBlocks(prev => ({...prev, [i]: !prev[i]}));
                   }
                 }}>
              <div className="tb-time" style={{color: done ? 'var(--ink-4)' : 'var(--ink-3)'}}>{b.t}</div>
              <div className="tb-bar" style={{background: done ? 'var(--sep-strong)' : MOD_COLOR[b.mod], opacity: done ? 0.4 : 1}}/>
              <div className="tb-body">
                <div className="tb-label" style={{color: done ? 'var(--ink-3)' : 'var(--ink)', textDecoration: done ? 'line-through' : 'none'}}>{b.l}</div>
                {b.sub && !done ? <div className="tb-sub">{b.sub}</div> : null}
                {b.mod === 'gym' && !done ? <div className="tb-sub" style={{color:'var(--m-gym)',fontWeight:600,letterSpacing:'0.06em',textTransform:'uppercase',fontSize:10}}>Tap to start →</div> : null}
              </div>
              <div style={{display:'flex',alignItems:'center',gap:8}}>
                {done && <I.check size={14} stroke="var(--m-gym)"/>}
                <div className="tb-dur" style={{color: done ? 'var(--ink-4)' : 'var(--ink-3)'}}>{b.dur}</div>
              </div>
            </div>
          );
        })}
      </div>

      {/* Load summary */}
      <div style={{padding:'14px 16px 4px'}}>
        <div className="card" style={{padding:'12px 16px'}}>
          <div style={{display:'flex',justifyContent:'space-between',alignItems:'center',marginBottom:8}}>
            <div style={{fontWeight:600,fontSize:15}}>Load: {weekDays[planDay]?.load}</div>
            <button className="btn-primary xs"
                    style={{background:'var(--bg-card2)',color:'var(--tint)'}}
                    onClick={handleRegenerate}>
              Regenerate
            </button>
          </div>
          <div style={{fontSize:13,color:'var(--ink-3)'}}>Gym shifted from Friday — Physics exam. Study buffer added before Lit essay.</div>
        </div>
      </div>
    </div>
  );
}

function AssignmentsView({ assignments, dispatch }) {
  const [filter, setFilter] = uS_p('all');
  const filtered = filter==='done' ? assignments.filter(a=>a.done) : filter==='pending' ? assignments.filter(a=>!a.done) : assignments;
  return (
    <div>
      <div className="hide-scroll" style={{display:'flex',gap:6,padding:'0 16px 12px',overflowX:'auto'}}>
        {[['all','All'],['pending','Pending'],['done','Done']].map(([k,l]) => (
          <button key={k} className={`chip${filter===k?' active':''}`} onClick={() => setFilter(k)}>{l}</button>
        ))}
      </div>
      <div className="card" style={{margin:'0 16px'}}>
        {filtered.length === 0 && (
          <div style={{padding:'24px 16px',color:'var(--ink-3)',textAlign:'center',fontSize:15}}>
            No assignments — tap + to add one.
          </div>
        )}
        {filtered.map((a) => (
          <div key={a.id} className="assign-row" style={{position:'relative',cursor:'pointer'}}
               onClick={() => dispatch({type:'TOGGLE_ASSIGNMENT',id:a.id})}>
            <div className={`assign-check${a.done?' done':''}`}>{a.done && <I.check size={13}/>}</div>
            <div className="assign-label">
              <div className={`assign-name${a.done?' done':''}`}>{a.l}</div>
              <div className="assign-meta">{a.cls} · {a.due}</div>
            </div>
            {a.urgent && !a.done && (
              <span className="chip" style={{background:'var(--m-exams-s)',color:'var(--m-exams)',fontSize:11}}>Urgent</span>
            )}
            {/* Edit chevron — tap stops propagation so it doesn't also toggle */}
            <button
              onClick={ev => { ev.stopPropagation(); dispatch({type:'OPEN_SHEET',sheet:'editAssignment',data:{assignment:a}}); }}
              style={{
                background:'none', border:'none', padding:'4px 0 4px 8px',
                cursor:'pointer', color:'var(--ink-3)', display:'flex', alignItems:'center', flexShrink:0,
              }}
              aria-label="Edit assignment">
              <I.chevronR size={16}/>
            </button>
          </div>
        ))}
      </div>
      <div style={{padding:'12px 16px 0'}}>
        <button className="btn-primary secondary" style={{height:44,fontSize:15}}
                onClick={() => dispatch({type:'OPEN_SHEET',sheet:'addAssignment'})}>
          <I.plus size={16}/>
          Add assignment
        </button>
      </div>
    </div>
  );
}

function ExamsView({ exams, dispatch }) {
  return (
    <div style={{padding:'0 16px'}}>
      {/* Add exam button */}
      <div style={{paddingBottom:12}}>
        <button className="btn-primary secondary" style={{height:44,fontSize:15}}
                onClick={() => dispatch({type:'OPEN_SHEET',sheet:'addExam'})}>
          <I.plus size={16}/>
          Add Exam
        </button>
      </div>

      {exams.length === 0 && (
        <div style={{padding:'32px 0',textAlign:'center',color:'var(--ink-3)',fontSize:15}}>
          No upcoming exams — tap + to add one.
        </div>
      )}

      {exams.map(e => {
        const days = daysUntil(e.date);
        const past = days !== null && days < 0;
        const urgency = past ? 'done' : days <= 2 ? 'urgent' : days <= 5 ? 'soon' : 'ok';
        return (
          <div key={e.id} className="exam-card" style={{opacity: past ? 0.55 : 1}}>
            <div style={{display:'flex',alignItems:'flex-start',justifyContent:'space-between',gap:12}}>
              <div style={{flex:1,minWidth:0}}>
                <div className="eyebrow">{e.cls}</div>
                <div style={{fontSize:18,fontWeight:700,overflow:'hidden',textOverflow:'ellipsis',whiteSpace:'nowrap',marginTop:4,letterSpacing:'-0.01em'}}>{e.l}</div>
                <div className="eyebrow" style={{marginTop:4}}>{fmtExamDate(e.date)}</div>
              </div>
              <div style={{display:'flex',alignItems:'flex-start',gap:4,flexShrink:0}}>
                <div style={{textAlign:'center',minWidth:60}}>
                  {past
                    ? <span className="exam-days done" style={{fontSize:11,letterSpacing:'0.04em'}}>DONE</span>
                    : <span className={`exam-days ${urgency}`}>{days}</span>
                  }
                  {!past && <div className="eyebrow" style={{marginTop:2}}>days</div>}
                </div>
                <button
                  onClick={() => { if (window.confirm(`Delete "${e.l}"?`)) dispatch({type:'DELETE_EXAM',id:e.id}); }}
                  style={{
                    background:'none', border:'none', padding:4,
                    cursor:'pointer', color:'var(--ink-4)', display:'flex', alignItems:'center',
                  }}
                  aria-label="Delete exam">
                  <I.x size={16}/>
                </button>
              </div>
            </div>
            <div style={{marginTop:14,display:'flex',gap:8}}>
              <button className="btn-primary xs secondary"
                      onClick={() => dispatch({type:'OPEN_SHEET',sheet:'studyPlan',data:{exam:e}})}>
                Study plan
              </button>
              <button className="btn-primary xs secondary"
                      onClick={() => dispatch({type:'OPEN_SHEET',sheet:'practiceQs',data:{exam:e}})}>
                Practice Qs
              </button>
            </div>
          </div>
        );
      })}
    </div>
  );
}

function Plan({ state, dispatch }) {
  const tabs = [
    {k:'schedule',l:'Schedule'},
    {k:'assignments',l:'Assignments'},
    {k:'exams',l:'Exams'},
  ];
  const addAction = () => {
    if (state.planTab === 'assignments') dispatch({type:'OPEN_SHEET', sheet:'addAssignment'});
    else if (state.planTab === 'exams')  dispatch({type:'OPEN_SHEET', sheet:'addExam'});
  };
  const showAdd = state.planTab !== 'schedule';
  return (
    <div className="screen-area enter">
      <div className="nav-bar">
        <div className="nav-title">Plan</div>
        {showAdd && (
          <div className="nav-right">
            <button className="icon-btn" onClick={addAction}><I.plus size={20}/></button>
          </div>
        )}
      </div>
      <SegCtrl tabs={tabs} active={state.planTab} onChange={t => dispatch({type:'SET_PLAN_TAB',tab:t})}/>

      {state.planTab==='schedule'     && <ScheduleView planDay={state.planDay} dispatch={dispatch}/>}
      {state.planTab==='assignments'  && <AssignmentsView assignments={state.assignments} dispatch={dispatch}/>}
      {state.planTab==='exams'        && <ExamsView exams={state.exams} dispatch={dispatch}/>}

      <div style={{height:32}}/>
    </div>
  );
}

export { Plan };
