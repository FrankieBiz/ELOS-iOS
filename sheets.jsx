import React from 'react'
import { I } from './icons.jsx'
import { BottomSheet } from './shell.jsx'
import { PrivacySheet, TermsSheet, EditSpaceSheet } from './settings_screens.jsx'
const { useState: uS_sh, useRef: uR_sh, useEffect: uE_sh } = React;

/* ─────────────────────────────────────────────────────────
   Local parser — no AI
   ───────────────────────────────────────────────────────── */
const FOOD_DB = {
  chicken:      {n:'Chicken breast 4oz', kcal:185, p:34, c:0,  f:4},
  rice:         {n:'White rice 1 cup',   kcal:206, p:4,  c:45, f:0},
  egg:          {n:'Whole egg',          kcal:70,  p:6,  c:0,  f:5},
  eggs:         {n:'Whole egg',          kcal:70,  p:6,  c:0,  f:5},
  banana:       {n:'Banana',             kcal:105, p:1,  c:27, f:0},
  oats:         {n:'Oatmeal 1 cup',      kcal:307, p:11, c:55, f:5},
  oatmeal:      {n:'Oatmeal 1 cup',      kcal:307, p:11, c:55, f:5},
  yogurt:       {n:'Greek yogurt',       kcal:100, p:17, c:6,  f:0},
  almonds:      {n:'Almonds 1 oz',       kcal:163, p:6,  c:6,  f:14},
  milk:         {n:'Milk 1 cup',         kcal:149, p:8,  c:12, f:8},
  broccoli:     {n:'Broccoli',           kcal:55,  p:4,  c:11, f:0},
  salmon:       {n:'Salmon 4oz',         kcal:233, p:25, c:0,  f:14},
  beef:         {n:'Ground beef 4oz',    kcal:284, p:20, c:0,  f:22},
  tuna:         {n:'Tuna 3oz',           kcal:100, p:22, c:0,  f:1},
  bread:        {n:'Bread slice',        kcal:80,  p:3,  c:15, f:1},
  pasta:        {n:'Pasta 1 cup cooked', kcal:220, p:8,  c:43, f:1},
  'peanut butter':{n:'Peanut butter 2tbsp',kcal:190,p:7,c:7,  f:16},
  'protein bar':{n:'Protein bar',        kcal:220, p:20, c:22, f:7},
  'protein shake':{n:'Protein shake',    kcal:150, p:25, c:8,  f:3},
  apple:        {n:'Apple',              kcal:95,  p:0,  c:25, f:0},
  cheese:       {n:'Cheese 1 oz',        kcal:113, p:7,  c:0,  f:9},
};

function parseMealText(text) {
  const lower = text.toLowerCase();
  // Try multi-word keys first (longest match)
  const keys = Object.keys(FOOD_DB).sort((a,b) => b.length - a.length);
  for (const key of keys) {
    if (lower.includes(key)) {
      const base = FOOD_DB[key];
      const numMatch = lower.match(/(\d+)\s*(?:x|×)?/);
      const qty = numMatch ? Math.max(1, parseInt(numMatch[1], 10)) : 1;
      const clamp = Math.min(qty, 10);
      return {
        n: clamp > 1 ? `${base.n} ×${clamp}` : base.n,
        kcal: Math.round(base.kcal * clamp),
        p: Math.round(base.p * clamp),
        c: Math.round(base.c * clamp),
        f: Math.round(base.f * clamp),
      };
    }
  }
  return { n: text.trim() || 'Custom food', kcal: 350, p: 20, c: 35, f: 12 };
}
window.elosParseMealText = parseMealText;

/* ─────────────────────────────────────────────────────────
   Quick foods list
   ───────────────────────────────────────────────────────── */
const QUICK_FOODS = [
  {n:'Chicken breast 4oz', kcal:185, p:34, c:0,  f:4},
  {n:'White rice 1 cup',   kcal:206, p:4,  c:45, f:0},
  {n:'Whole egg',          kcal:70,  p:6,  c:0,  f:5},
  {n:'Banana',             kcal:105, p:1,  c:27, f:0},
  {n:'Milk 1 cup',         kcal:149, p:8,  c:12, f:8},
  {n:'Greek yogurt',       kcal:100, p:17, c:6,  f:0},
  {n:'Almonds 1 oz',       kcal:163, p:6,  c:6,  f:14},
  {n:'Oatmeal 1 cup',      kcal:307, p:11, c:55, f:5},
];

/* ─────────────────────────────────────────────────────────
   LogMealSheet (extended)
   ───────────────────────────────────────────────────────── */
function LogMealSheet({ data, state, dispatch }) {
  const [query,   setQuery]   = uS_sh('');
  const [pending, setPending] = uS_sh([]);
  const [mode,    setMode]    = uS_sh('browse'); // 'browse' | 'describe'
  const [descTxt, setDescTxt] = uS_sh('');
  const title = data?.title || 'Meal';
  const savedMeals = state?.savedMeals || [];

  const filtered = query
    ? QUICK_FOODS.filter(f => f.n.toLowerCase().includes(query.toLowerCase()))
    : QUICK_FOODS;

  const addItem = (food) => {
    setPending(p => {
      const existing = p.find(i => i.n === food.n);
      return existing ? p.filter(i => i.n !== food.n) : [...p, food];
    });
  };

  const logAll = () => {
    pending.forEach(item => dispatch({type:'ADD_MEAL_ITEM', meal: data?.mealKey || 'snacks', item}));
    dispatch({type:'CLOSE_SHEET'});
  };

  const addDescribed = () => {
    if (!descTxt.trim()) return;
    const item = parseMealText(descTxt.trim());
    setPending(p => [...p, item]);
    setDescTxt('');
    setMode('browse');
  };

  const addSavedMeal = (sm) => {
    setPending(p => {
      const existing = new Set(p.map(i => i.n));
      const newItems = sm.items.filter(i => !existing.has(i.n));
      return [...p, ...newItems];
    });
  };

  return (
    <div className="sheet-backdrop" onClick={e => e.target===e.currentTarget && dispatch({type:'CLOSE_SHEET'})}>
      <div className="sheet" style={{maxHeight:'92%',display:'flex',flexDirection:'column'}}>
        <div className="sheet-handle"/>
        <div className="sheet-header">
          <button className="nav-btn" onClick={() => dispatch({type:'CLOSE_SHEET'})}>Cancel</button>
          <div className="sheet-title">Log {title}</div>
          <button className="nav-btn" style={{fontWeight:600,color:pending.length?'var(--tint)':'var(--ink-4)'}} onClick={logAll}>
            {pending.length ? `Add ${pending.length}` : 'Done'}
          </button>
        </div>

        <div className="sheet-body" style={{padding:0,overflowY:'auto',flex:1}}>
          {/* Search */}
          <div style={{padding:'10px 16px'}}>
            <div className="food-input-row">
              <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="var(--ink-4)" strokeWidth="2" strokeLinecap="round"><circle cx="11" cy="11" r="7"/><path d="m20 20-3.5-3.5"/></svg>
              <input value={query} onChange={e=>setQuery(e.target.value)} placeholder="Search foods…" autoFocus
                     autoCorrect="off" autoCapitalize="none" spellCheck={false} enterKeyHint="search"
                     style={{fontSize:16}}/>
              {query && <button onClick={() => setQuery('')} style={{color:'var(--ink-4)'}}><I.x size={16}/></button>}
            </div>
          </div>

          {/* Barcode + Describe row */}
          <div style={{display:'flex',gap:8,padding:'0 16px 10px'}}>
            <button className="btn-primary secondary sm" style={{flex:1,fontSize:14}}
              onClick={() => dispatch({type:'OPEN_SHEET', sheet:'scanBarcode', data:{mealKey:data?.mealKey, title:data?.title}})}>
              <I.barcode size={16}/> Scan barcode
            </button>
            <button className="btn-primary secondary sm" style={{flex:1,fontSize:14}}
              onClick={() => setMode(mode==='describe'?'browse':'describe')}>
              <I.mic size={16}/> Describe meal
            </button>
          </div>

          {/* Describe mode input */}
          {mode === 'describe' && (
            <div style={{padding:'0 16px 10px'}}>
              <div className="food-input-row">
                <input value={descTxt} onChange={e=>setDescTxt(e.target.value)}
                       placeholder="e.g. 2 eggs and oats…" autoFocus
                       onKeyDown={e=>e.key==='Enter'&&addDescribed()}
                       style={{fontSize:15,flex:1}}/>
              </div>
              <button className="btn-primary" style={{marginTop:8,height:40,fontSize:14}} onClick={addDescribed}>
                Add item
              </button>
            </div>
          )}

          <div style={{height:1,background:'var(--sep)'}}/>

          {/* Saved meals section */}
          {savedMeals.length > 0 && !query && (
            <>
              <div className="section-header" style={{paddingTop:12}}>Saved meals</div>
              {savedMeals.map(sm => (
                <div key={sm.id} className="cell tappable" onClick={() => addSavedMeal(sm)}>
                  <div>
                    <div className="cell-label" style={{fontSize:15}}>{sm.l}</div>
                    <div className="tiny muted">{sm.items?.length || 0} items · {sm.cal} kcal</div>
                  </div>
                  <I.plus size={18} stroke="var(--tint)"/>
                </div>
              ))}
              <div style={{height:1,background:'var(--sep)',margin:'8px 0'}}/>
              <div className="section-header">Quick foods</div>
            </>
          )}

          {/* Food list */}
          <div>
            {filtered.map((f,i) => {
              const sel = pending.some(p=>p.n===f.n);
              return (
                <div key={i} className="cell tappable" style={{background:sel?'var(--tint-soft)':''}} onClick={() => addItem(f)}>
                  <div className="cell-label" style={{fontSize:15}}>{f.n}</div>
                  <div style={{textAlign:'right',flexShrink:0}}>
                    <div className="small mono">{f.kcal} kcal</div>
                    <div className="tiny muted">P{f.p} C{f.c} F{f.f}</div>
                  </div>
                  <div style={{width:28,height:28,borderRadius:14,
                               border:`1.5px solid ${sel?'var(--tint)':'var(--sep-strong)'}`,
                               background:sel?'var(--tint)':'transparent',
                               display:'flex',alignItems:'center',justifyContent:'center',
                               color:'#fff',flexShrink:0,marginLeft:8}}>
                    {sel ? <I.check size={14}/> : <I.plus size={14} stroke="var(--ink-4)"/>}
                  </div>
                </div>
              );
            })}
          </div>
        </div>

        {/* Footer: Save as quick meal */}
        {pending.length > 0 && (
          <div style={{padding:'8px 16px 12px',borderTop:'1px solid var(--sep)'}}>
            <button className="btn-primary secondary" style={{fontSize:14,height:40}}
              onClick={() => dispatch({type:'OPEN_SHEET', sheet:'saveMeal', data:{items: pending}})}>
              Save as quick meal
            </button>
          </div>
        )}
      </div>
    </div>
  );
}

/* ─────────────────────────────────────────────────────────
   LogSleepSheet (unchanged)
   ───────────────────────────────────────────────────────── */
function LogSleepSheet({ dispatch }) {
  const [bed,  setBed]  = uS_sh('22:30');
  const [wake, setWake] = uS_sh('06:15');
  const [qual, setQual] = uS_sh(4);

  const calcDur = () => {
    const [bh,bm] = bed.split(':').map(Number);
    let [wh,wm] = wake.split(':').map(Number);
    let mins = (wh*60+wm) - (bh*60+bm);
    if (mins < 0) mins += 24*60;
    return Math.round(mins/60*10)/10;
  };

  const log = () => {
    dispatch({type:'LOG_SLEEP', entry:{date:'Today', bed, wake, dur:calcDur(), quality:qual}});
  };

  const qualLabels = ['','Terrible','Poor','Okay','Good','Great'];
  const qualColors = ['','var(--bad)','var(--m-health)','var(--warn)','var(--m-sched)','var(--m-gym)'];

  return (
    <div className="sheet-backdrop" onClick={e => e.target===e.currentTarget && dispatch({type:'CLOSE_SHEET'})}>
      <div className="sheet">
        <div className="sheet-handle"/>
        <div className="sheet-header">
          <button className="nav-btn" onClick={() => dispatch({type:'CLOSE_SHEET'})}>Cancel</button>
          <div className="sheet-title">Log Sleep</div>
          <button className="nav-btn" style={{fontWeight:600}} onClick={log}>Save</button>
        </div>
        <div className="sheet-body">
          <div style={{textAlign:'center',marginBottom:20}}>
            <div className="mono tabular" style={{fontSize:48,fontWeight:700,letterSpacing:'-0.04em',color:'var(--ink)'}}>
              {calcDur()}<span style={{fontSize:20,color:'var(--ink-3)',marginLeft:4}}>h</span>
            </div>
            <div className="small muted">Estimated duration</div>
          </div>
          <div className="card" style={{marginBottom:12}}>
            <div className="cell">
              <div className="cell-label">Bedtime</div>
              <input type="time" value={bed} onChange={e=>setBed(e.target.value)}
                     style={{background:'none',border:'none',outline:'none',fontSize:17,color:'var(--ink)',fontFamily:'inherit'}}/>
            </div>
            <div className="cell">
              <div className="cell-label">Wake time</div>
              <input type="time" value={wake} onChange={e=>setWake(e.target.value)}
                     style={{background:'none',border:'none',outline:'none',fontSize:17,color:'var(--ink)',fontFamily:'inherit'}}/>
            </div>
          </div>
          <div className="section-header">Sleep quality</div>
          <div style={{display:'flex',gap:8,marginBottom:16}}>
            {[1,2,3,4,5].map(q => (
              <button key={q} onClick={() => setQual(q)}
                      style={{flex:1,height:48,borderRadius:10,
                              background:qual===q?qualColors[q]:'var(--bg-card)',
                              color:qual===q?'#fff':'var(--ink)',
                              border:`1px solid ${qual===q?qualColors[q]:'var(--sep)'}`,
                              fontSize:11,fontWeight:600}}>
                {qualLabels[q]}
              </button>
            ))}
          </div>
        </div>
      </div>
    </div>
  );
}

/* ─────────────────────────────────────────────────────────
   AddHabitSheet (unchanged)
   ───────────────────────────────────────────────────────── */
const HABIT_CATS = ['Fitness','Mindset','Nutrition','Recovery','Learning','General'];

function AddHabitSheet({ dispatch }) {
  const [name, setName] = uS_sh('');
  const [cat,  setCat]  = uS_sh('General');

  const save = () => {
    if (!name.trim()) return;
    dispatch({type:'ADD_HABIT', habit:{k:name.toLowerCase().replace(/\s+/g,'_'), l:name, cat, streak:0, done:false, color:'var(--tint)'}});
    dispatch({type:'CLOSE_SHEET'});
  };

  return (
    <div className="sheet-backdrop" onClick={e => e.target===e.currentTarget && dispatch({type:'CLOSE_SHEET'})}>
      <div className="sheet">
        <div className="sheet-handle"/>
        <div className="sheet-header">
          <button className="nav-btn" onClick={() => dispatch({type:'CLOSE_SHEET'})}>Cancel</button>
          <div className="sheet-title">New Habit</div>
          <button className="nav-btn" style={{fontWeight:600,color:name.trim()?'var(--tint)':'var(--ink-4)'}} onClick={save}>Add</button>
        </div>
        <div className="sheet-body">
          <div className="card" style={{marginBottom:14}}>
            <div className="cell">
              <input value={name} onChange={e=>setName(e.target.value)} placeholder="Habit name…" autoFocus
                     style={{flex:1,background:'none',border:'none',outline:'none',fontSize:17,color:'var(--ink)'}}/>
            </div>
          </div>
          <div className="section-header">Category</div>
          <div style={{display:'flex',flexWrap:'wrap',gap:8,marginBottom:16}}>
            {HABIT_CATS.map(c => (
              <button key={c} className={`chip${cat===c?' active':''}`} onClick={() => setCat(c)}>{c}</button>
            ))}
          </div>
          <button className="btn-primary" onClick={save}>Add Habit</button>
        </div>
      </div>
    </div>
  );
}

/* ─────────────────────────────────────────────────────────
   AddAssignmentSheet — NEW
   ───────────────────────────────────────────────────────── */
function AddAssignmentSheet({ state, dispatch }) {
  const [title,   setTitle]   = uS_sh('');
  const [cls,     setCls]     = uS_sh('');
  const [due,     setDue]     = uS_sh('');
  const [urgent,  setUrgent]  = uS_sh(false);
  const [customCls, setCustomCls] = uS_sh('');
  const [showCustom, setShowCustom] = uS_sh(false);

  const existingClasses = [...new Set((state?.assignments || []).map(a => a.cls).filter(Boolean))];

  const effectiveCls = showCustom ? customCls : cls;

  const save = () => {
    if (!title.trim()) return;
    dispatch({type:'ADD_ASSIGNMENT', assignment:{id:Date.now(), l:title.trim(), cls:effectiveCls, due, done:false, urgent}});
    dispatch({type:'CLOSE_SHEET'});
  };

  return (
    <BottomSheet title="Add Assignment" dispatch={dispatch} action={save} actionLabel="Add"
                 actionColor={title.trim()?'var(--tint)':'var(--ink-4)'}>
      <div className="card" style={{marginBottom:12}}>
        <div className="cell">
          <input value={title} onChange={e=>setTitle(e.target.value)} placeholder="Assignment title…" autoFocus
                 style={{flex:1,background:'none',border:'none',outline:'none',fontSize:17,color:'var(--ink)'}}/>
        </div>
      </div>
      <div className="section-header">Class</div>
      <div style={{display:'flex',flexWrap:'wrap',gap:8,marginBottom:8}}>
        {existingClasses.map(c => (
          <button key={c} className={`chip${!showCustom&&cls===c?' active':''}`}
                  onClick={() => { setCls(c); setShowCustom(false); }}>{c}</button>
        ))}
        <button className={`chip${showCustom?' active':''}`} onClick={() => setShowCustom(true)}>+ Custom</button>
      </div>
      {showCustom && (
        <div className="food-input-row" style={{marginBottom:12}}>
          <input value={customCls} onChange={e=>setCustomCls(e.target.value)} placeholder="Class name…"
                 autoFocus style={{fontSize:15,flex:1}}/>
        </div>
      )}
      <div className="card" style={{marginBottom:12}}>
        <div className="cell">
          <div className="cell-label">Due</div>
          <input value={due} onChange={e=>setDue(e.target.value)} placeholder="e.g. Friday, Nov 3…"
                 style={{background:'none',border:'none',outline:'none',fontSize:15,color:'var(--ink)',textAlign:'right'}}/>
        </div>
        <div className="cell tappable" onClick={() => setUrgent(u=>!u)}>
          <div className="cell-label">Urgent</div>
          <div style={{width:32,height:20,borderRadius:10,background:urgent?'var(--tint)':'var(--sep-strong)',
                       position:'relative',transition:'background .2s',cursor:'pointer'}}>
            <div style={{width:16,height:16,borderRadius:8,background:'#fff',position:'absolute',
                         top:2,left:urgent?14:2,transition:'left .2s'}}/>
          </div>
        </div>
      </div>
      <button className="btn-primary" onClick={save}>Add Assignment</button>
    </BottomSheet>
  );
}

/* ─────────────────────────────────────────────────────────
   AddExamSheet — NEW
   ───────────────────────────────────────────────────────── */
function AddExamSheet({ state, dispatch }) {
  const [title, setTitle] = uS_sh('');
  const [cls,   setCls]   = uS_sh('');
  const [date,  setDate]  = uS_sh('');
  const [days,  setDays]  = uS_sh('');

  const existingClasses = [...new Set((state?.assignments || []).map(a => a.cls).filter(Boolean))];

  const handleDate = (val) => {
    setDate(val);
    const d = new Date(val);
    if (!isNaN(d)) {
      const diff = Math.ceil((d - Date.now()) / 86400000);
      setDays(String(Math.max(0, diff)));
    }
  };

  const save = () => {
    if (!title.trim()) return;
    dispatch({type:'ADD_EXAM', exam:{id:Date.now(), l:title.trim(), cls, date, days: parseInt(days)||0}});
    dispatch({type:'CLOSE_SHEET'});
  };

  return (
    <BottomSheet title="Add Exam" dispatch={dispatch} action={save} actionLabel="Add"
                 actionColor={title.trim()?'var(--tint)':'var(--ink-4)'}>
      <div className="card" style={{marginBottom:12}}>
        <div className="cell">
          <input value={title} onChange={e=>setTitle(e.target.value)} placeholder="Exam title…" autoFocus
                 style={{flex:1,background:'none',border:'none',outline:'none',fontSize:17,color:'var(--ink)'}}/>
        </div>
      </div>
      <div className="section-header">Class</div>
      <div style={{display:'flex',flexWrap:'wrap',gap:8,marginBottom:12}}>
        {existingClasses.map(c => (
          <button key={c} className={`chip${cls===c?' active':''}`} onClick={() => setCls(c)}>{c}</button>
        ))}
      </div>
      <div className="card" style={{marginBottom:12}}>
        <div className="cell">
          <div className="cell-label">Date</div>
          <input type="date" value={date} onChange={e=>handleDate(e.target.value)}
                 style={{background:'none',border:'none',outline:'none',fontSize:15,color:'var(--ink)',fontFamily:'inherit'}}/>
        </div>
        <div className="cell">
          <div className="cell-label">Days out</div>
          <input value={days} onChange={e=>setDays(e.target.value)} placeholder="auto"
                 style={{background:'none',border:'none',outline:'none',fontSize:15,color:'var(--ink)',textAlign:'right',width:60}}/>
        </div>
      </div>
      <button className="btn-primary" onClick={save}>Add Exam</button>
    </BottomSheet>
  );
}

/* ─────────────────────────────────────────────────────────
   StudyPlanSheet — NEW
   ───────────────────────────────────────────────────────── */
const STUDY_TOPICS = {
  'AP Physics': ['Kinematics & Vectors',"Force & Newton's Laws",'Energy & Momentum','Waves & Sound','E&M Basics'],
  'AP Calc':    ['Limits & Continuity','Derivatives','Integrals','Applications','Series (BC)'],
  'AP English': ['Close Reading','Rhetorical Analysis','Argument Essay','Synthesis Essay','Revision & Style'],
  'AP Chem':    ['Atomic Structure','Bonding','Stoichiometry','Kinetics & Equilibrium','Electrochemistry'],
  'AP USH':     ['Colonial Era','Revolution & Constitution','Antebellum & Civil War','Reconstruction & Gilded Age','20th Century'],
};
const GENERIC_TOPICS = ['Review core concepts','Practice problems','Flash cards review','Mock exam / timed practice','Rest & light review'];

function fmtSheetDate(dateStr) {
  const iso = /^(\d{4})-(\d{2})-(\d{2})$/.exec(dateStr);
  const d = iso ? new Date(+iso[1], +iso[2]-1, +iso[3]) : new Date(dateStr);
  if (isNaN(d)) return dateStr;
  return d.toLocaleDateString('en-US', { weekday:'short', month:'short', day:'numeric' });
}

function daysFromDate(dateStr) {
  const iso = /^(\d{4})-(\d{2})-(\d{2})$/.exec(dateStr);
  const d = iso ? new Date(+iso[1], +iso[2]-1, +iso[3]) : new Date(dateStr);
  if (isNaN(d)) return null;
  const today = new Date(); today.setHours(0,0,0,0);
  return Math.max(1, Math.ceil((d - today) / 86400000));
}

function StudyPlanSheet({ data, dispatch }) {
  const exam = data?.exam || {};
  const daysRemaining = exam.date ? (daysFromDate(exam.date) || 5) : (exam.days || 5);
  const days = Math.max(1, Math.min(5, daysRemaining));
  const topics = (STUDY_TOPICS[exam.cls] || GENERIC_TOPICS).slice(0, 5);
  const [checked, setChecked] = uS_sh([]);

  const toggle = (i) => setChecked(c => c.includes(i) ? c.filter(x=>x!==i) : [...c, i]);

  return (
    <BottomSheet title="Study Plan" dispatch={dispatch} action={() => dispatch({type:'CLOSE_SHEET'})} actionLabel="Got it">
      <div style={{marginBottom:8}}>
        <div style={{fontSize:17,fontWeight:600,color:'var(--ink)'}}>{exam.l}</div>
        <div className="small muted">{exam.cls} · {fmtSheetDate(exam.date)} · {daysRemaining} day{daysRemaining!==1?'s':''} to go</div>
      </div>
      <div style={{height:1,background:'var(--sep)',marginBottom:12}}/>
      {topics.map((topic, i) => {
        const day = i + 1;
        const done = checked.includes(i);
        return (
          <div key={i} className="cell tappable" style={{background:done?'var(--tint-soft)':''}}
               onClick={() => toggle(i)}>
            <div style={{width:32,height:32,borderRadius:8,background:'var(--tint)',
                         display:'flex',alignItems:'center',justifyContent:'center',
                         color:'#fff',fontWeight:700,fontSize:13,flexShrink:0}}>
              D{day}
            </div>
            <div style={{flex:1,marginLeft:12}}>
              <div style={{fontSize:15,color:done?'var(--ink-3)':'var(--ink)',
                           textDecoration:done?'line-through':'none'}}>{topic}</div>
              <div className="tiny muted">Day {day} of {days}</div>
            </div>
            {done && <I.check size={16} stroke="var(--tint)"/>}
          </div>
        );
      })}
    </BottomSheet>
  );
}

/* ─────────────────────────────────────────────────────────
   PracticeQsSheet — NEW
   ───────────────────────────────────────────────────────── */
const QUESTION_BANKS = {
  'AP Physics': [
    {q:'A 2 kg object accelerates at 5 m/s². What is the net force?',opts:['5 N','10 N','15 N','20 N'],ans:1},
    {q:'Which quantity is conserved in an elastic collision?',opts:['Momentum only','KE only','Both momentum and KE','Neither'],ans:2},
    {q:'A wave has frequency 4 Hz and wavelength 3 m. What is its speed?',opts:['0.75 m/s','7 m/s','12 m/s','16 m/s'],ans:2},
    {q:'What is the unit of electric potential?',opts:['Ampere','Coulomb','Volt','Watt'],ans:2},
    {q:'An object in free fall has zero acceleration. True or False?',opts:['True','False'],ans:1},
  ],
  'AP Calc': [
    {q:'What is the derivative of sin(x)?',opts:['cos(x)','-cos(x)','-sin(x)','tan(x)'],ans:0},
    {q:'∫x² dx = ?',opts:['x³','x³/3 + C','2x + C','3x²'],ans:1},
    {q:'lim(x→0) sin(x)/x = ?',opts:['0','∞','1','undefined'],ans:2},
    {q:'The chain rule applies when differentiating:',opts:['sums','composite functions','constants','polynomials only'],ans:1},
    {q:'The integral of e^x is:',opts:['e^x + C','xe^x + C','e^(x+1) + C','1/e^x + C'],ans:0},
  ],
  'AP English': [
    {q:'Logos in rhetoric refers to:',opts:['Emotional appeal','Ethical credibility','Logical argument','Visual imagery'],ans:2},
    {q:'A claim + evidence + warrant is the structure of:',opts:['Logos argument','Toulmin model','Anaphora','Chiasmus'],ans:1},
    {q:'Juxtaposition places __ side by side for contrast:',opts:['synonyms','similar ideas','contrasting elements','rhyming words'],ans:2},
    {q:'Which is an example of anaphora?',opts:['"It was the best of times, it was the worst..."','"We shall fight... we shall fight... we shall fight"','Neither','Both'],ans:1},
    {q:'A concession in argument means:',opts:['Denying the opposing view','Acknowledging the opposing view','Introducing evidence','Closing a paragraph'],ans:1},
  ],
  'AP Chem': [
    {q:'Which particle determines an element\'s identity?',opts:['Neutrons','Protons','Electrons','Isotopes'],ans:1},
    {q:'What is the pH of a neutral solution at 25°C?',opts:['0','7','14','depends on solution'],ans:1},
    {q:'Le Chatelier\'s principle: adding reactant shifts equilibrium:',opts:['Left','Right','No change','To products and back'],ans:1},
    {q:'An exothermic reaction releases:',opts:['Electrons','Light only','Energy as heat','Neutrons'],ans:2},
    {q:'Molarity is defined as:',opts:['g/L','mol/kg','mol/L','g/mol'],ans:2},
  ],
  'AP USH': [
    {q:'The Constitutional Convention took place in:',opts:['1776','1781','1787','1791'],ans:2},
    {q:'Manifest Destiny primarily justified:',opts:['Abolition','Westward expansion','Civil rights','Industrialization'],ans:1},
    {q:'The 13th Amendment abolished:',opts:['Slavery','Women\'s suffrage','Segregation','Child labor'],ans:0},
    {q:'FDR\'s New Deal primarily addressed:',opts:['WWI debt','The Great Depression','Cold War threats','Immigration'],ans:1},
    {q:'The Marshall Plan provided aid to rebuild:',opts:['Latin America','Asia','Post-WWII Europe','Africa'],ans:2},
  ],
};
const GENERIC_BANK = [
  {q:'Which of the following is an example of primary source?',opts:['Textbook chapter','Wikipedia article','Diary entry','Documentary film'],ans:2},
  {q:'The scientific method begins with:',opts:['Hypothesis','Experiment','Observation','Conclusion'],ans:2},
  {q:'Correlation implies causation. True or False?',opts:['True','False'],ans:1},
  {q:'Which logical fallacy attacks the person rather than the argument?',opts:['Straw man','Ad hominem','False dichotomy','Slippery slope'],ans:1},
  {q:'A control group in an experiment:',opts:['Gets the treatment','Is not given the treatment','Is ignored','Sets the hypothesis'],ans:1},
];

function PracticeQsSheet({ data, dispatch }) {
  const exam = data?.exam || {};
  const bank = QUESTION_BANKS[exam.cls] || GENERIC_BANK;
  const [chosen, setChosen] = uS_sh({});

  const pick = (qi, oi) => setChosen(c => c[qi]!==undefined ? c : {...c, [qi]:oi});

  return (
    <BottomSheet title="Practice Questions" dispatch={dispatch}
                 action={() => dispatch({type:'CLOSE_SHEET'})} actionLabel="Done">
      <div className="small muted" style={{marginBottom:12}}>{exam.cls} — {exam.l}</div>
      {bank.map((q, qi) => (
        <div key={qi} style={{marginBottom:20}}>
          <div style={{fontSize:15,fontWeight:600,color:'var(--ink)',marginBottom:8,lineHeight:1.4}}>
            {qi+1}. {q.q}
          </div>
          {q.opts.map((opt, oi) => {
            const picked = chosen[qi] !== undefined;
            const isChosen = chosen[qi] === oi;
            const correct = oi === q.ans;
            let bg = 'var(--bg-card)', border = 'var(--sep)', color = 'var(--ink)';
            if (picked && isChosen && correct)  { bg='var(--m-gym)';    border='var(--m-gym)';    color='#fff'; }
            if (picked && isChosen && !correct) { bg='var(--bad)';      border='var(--bad)';      color='#fff'; }
            if (picked && !isChosen && correct) { bg='var(--tint-soft)';border='var(--tint)'; }
            return (
              <button key={oi} onClick={() => pick(qi, oi)}
                      style={{display:'block',width:'100%',textAlign:'left',padding:'10px 14px',borderRadius:10,
                               marginBottom:6,background:bg,border:`1.5px solid ${border}`,
                               color,fontSize:14,cursor:picked?'default':'pointer'}}>
                {opt}
              </button>
            );
          })}
        </div>
      ))}
    </BottomSheet>
  );
}

/* ─────────────────────────────────────────────────────────
   ScanBarcodeSheet — NEW
   ───────────────────────────────────────────────────────── */
function ScanBarcodeSheet({ data, dispatch }) {
  const videoRef = uR_sh(null);
  const streamRef = uR_sh(null);
  const rafRef = uR_sh(null);
  const [status, setStatus] = uS_sh('idle'); // idle|scanning|found|error|unsupported
  const [errMsg, setErrMsg] = uS_sh('');
  const [product, setProduct] = uS_sh(null);

  const stopCamera = () => {
    if (rafRef.current) cancelAnimationFrame(rafRef.current);
    if (streamRef.current) streamRef.current.getTracks().forEach(t => t.stop());
  };

  uE_sh(() => {
    if (!('BarcodeDetector' in window)) { setStatus('unsupported'); return; }
    setStatus('scanning');
    navigator.mediaDevices.getUserMedia({video:{facingMode:'environment'}})
      .then(stream => {
        streamRef.current = stream;
        if (videoRef.current) {
          videoRef.current.srcObject = stream;
          videoRef.current.play();
        }
        const detector = new window.BarcodeDetector({formats:['ean_13','ean_8','upc_a','upc_e','code_128','code_39','qr_code']});
        const scan = async () => {
          if (videoRef.current && videoRef.current.readyState === 4) {
            try {
              const codes = await detector.detect(videoRef.current);
              if (codes.length > 0) {
                stopCamera();
                setStatus('found');
                const code = codes[0].rawValue;
                fetch(`https://world.openfoodfacts.org/api/v2/product/${code}.json`)
                  .then(r => r.json())
                  .then(json => {
                    const pr = json.product || {};
                    const nu = pr.nutriments || {};
                    const item = {
                      n: pr.product_name || code,
                      kcal: Math.round(nu['energy-kcal_100g'] || 0),
                      p:    Math.round(nu.proteins_100g || 0),
                      c:    Math.round(nu.carbohydrates_100g || 0),
                      f:    Math.round(nu.fat_100g || 0),
                    };
                    setProduct(item);
                  })
                  .catch(() => setErrMsg('Could not fetch product info.'));
                return;
              }
            } catch(_) {}
          }
          rafRef.current = requestAnimationFrame(scan);
        };
        rafRef.current = requestAnimationFrame(scan);
      })
      .catch(err => {
        setStatus('error');
        setErrMsg(err.name === 'NotAllowedError' ? 'Camera permission denied.' : 'Could not access camera.');
      });
    return stopCamera;
  }, []);

  const addProduct = () => {
    if (!product) return;
    dispatch({type:'ADD_MEAL_ITEM', meal: data?.mealKey || 'snacks', item: product});
    dispatch({type:'CLOSE_SHEET'});
  };

  const close = () => { stopCamera(); dispatch({type:'CLOSE_SHEET'}); };

  return (
    <div className="sheet-backdrop" onClick={e => e.target===e.currentTarget && close()}>
      <div className="sheet" style={{maxHeight:'88%'}}>
        <div className="sheet-handle"/>
        <div className="sheet-header">
          <button className="nav-btn" onClick={close}>Cancel</button>
          <div className="sheet-title">Scan Barcode</div>
          <div style={{width:70}}/>
        </div>
        <div className="sheet-body" style={{alignItems:'center'}}>
          {status === 'unsupported' && (
            <div style={{textAlign:'center',padding:'32px 16px'}}>
              <I.barcode size={48} stroke="var(--ink-3)"/>
              <div style={{fontSize:16,fontWeight:600,color:'var(--ink)',marginTop:12,marginBottom:8}}>
                Not supported on this device
              </div>
              <div className="small muted" style={{lineHeight:1.5}}>
                Barcode scanning requires iOS 17+ Safari or Chrome on Android/Desktop.
                Try Quick foods or Describe meal instead.
              </div>
            </div>
          )}
          {status === 'scanning' && (
            <>
              <video ref={videoRef} muted playsInline
                     style={{width:'100%',borderRadius:12,maxHeight:260,background:'#000',objectFit:'cover'}}/>
              <div className="small muted" style={{marginTop:12}}>Point camera at a product barcode…</div>
            </>
          )}
          {status === 'error' && (
            <div style={{textAlign:'center',padding:'24px 16px'}}>
              <I.warn size={36} stroke="var(--bad)"/>
              <div style={{fontSize:15,color:'var(--bad)',marginTop:8}}>{errMsg}</div>
            </div>
          )}
          {status === 'found' && !product && (
            <div style={{textAlign:'center',padding:'24px 16px'}}>
              <div className="small muted">Looking up product…</div>
            </div>
          )}
          {product && (
            <div style={{width:'100%'}}>
              <div className="card" style={{marginBottom:16}}>
                <div className="cell">
                  <div>
                    <div style={{fontSize:16,fontWeight:600,color:'var(--ink)'}}>{product.n}</div>
                    <div className="tiny muted">Per 100g · from Open Food Facts</div>
                  </div>
                  <div style={{textAlign:'right'}}>
                    <div className="small mono">{product.kcal} kcal</div>
                    <div className="tiny muted">P{product.p} C{product.c} F{product.f}</div>
                  </div>
                </div>
              </div>
              <button className="btn-primary" onClick={addProduct}>Add to {data?.title || 'meal'}</button>
            </div>
          )}
          {errMsg && status!=='error' && <div className="small muted" style={{color:'var(--bad)',marginTop:8}}>{errMsg}</div>}
        </div>
      </div>
    </div>
  );
}

/* ─────────────────────────────────────────────────────────
   AddCustomExerciseSheet — NEW
   ───────────────────────────────────────────────────────── */
const MUSCLE_GROUPS = ['chest','back','legs','shoulders','arms','core'];

function AddCustomExerciseSheet({ data, dispatch }) {
  const [name,   setName]   = uS_sh('');
  const [sets,   setSets]   = uS_sh(3);
  const [reps,   setReps]   = uS_sh(10);
  const [target, setTarget] = uS_sh('chest');

  const save = () => {
    if (!name.trim()) return;
    if (typeof data?.onAdd === 'function') data.onAdd({
      name: name.trim(),
      muscle: target,
      target,
      secondary: [],
      sets: `${sets}×${reps}`,
      last: '—',
    });
    dispatch({type:'CLOSE_SHEET'});
  };

  return (
    <BottomSheet title="Custom Exercise" dispatch={dispatch} action={save} actionLabel="Add"
                 actionColor={name.trim()?'var(--tint)':'var(--ink-4)'}>
      <div className="card" style={{marginBottom:12}}>
        <div className="cell">
          <input value={name} onChange={e=>setName(e.target.value)} placeholder="Exercise name…" autoFocus
                 style={{flex:1,background:'none',border:'none',outline:'none',fontSize:17,color:'var(--ink)'}}/>
        </div>
      </div>
      <div className="section-header">Target muscle</div>
      <div style={{display:'flex',flexWrap:'wrap',gap:8,marginBottom:14}}>
        {MUSCLE_GROUPS.map(m => (
          <button key={m} className={`chip${target===m?' active':''}`} onClick={() => setTarget(m)}>
            {m.charAt(0).toUpperCase()+m.slice(1)}
          </button>
        ))}
      </div>
      <div className="card" style={{marginBottom:14}}>
        <div className="cell">
          <div className="cell-label">Sets</div>
          <div style={{display:'flex',alignItems:'center',gap:12}}>
            <button onClick={() => setSets(s=>Math.max(1,s-1))} style={{width:32,height:32,borderRadius:8,background:'var(--bg)',fontSize:18,fontWeight:700,color:'var(--tint)'}}>−</button>
            <span style={{fontSize:17,fontWeight:600,minWidth:24,textAlign:'center'}}>{sets}</span>
            <button onClick={() => setSets(s=>Math.min(8,s+1))}  style={{width:32,height:32,borderRadius:8,background:'var(--bg)',fontSize:18,fontWeight:700,color:'var(--tint)'}}>+</button>
          </div>
        </div>
        <div className="cell">
          <div className="cell-label">Reps</div>
          <div style={{display:'flex',alignItems:'center',gap:12}}>
            <button onClick={() => setReps(r=>Math.max(1,r-1))}  style={{width:32,height:32,borderRadius:8,background:'var(--bg)',fontSize:18,fontWeight:700,color:'var(--tint)'}}>−</button>
            <span style={{fontSize:17,fontWeight:600,minWidth:24,textAlign:'center'}}>{reps}</span>
            <button onClick={() => setReps(r=>Math.min(30,r+1))} style={{width:32,height:32,borderRadius:8,background:'var(--bg)',fontSize:18,fontWeight:700,color:'var(--tint)'}}>+</button>
          </div>
        </div>
      </div>
      <button className="btn-primary" onClick={save}>Add Exercise</button>
    </BottomSheet>
  );
}

/* ─────────────────────────────────────────────────────────
   SwapExerciseSheet — NEW
   ───────────────────────────────────────────────────────── */
const SWAP_MAP = {
  chest:     ['Bench Press','Incline DB Press','Push-up','Cable Fly','Dips','Pec Deck'],
  back:      ['Pull-up','Lat Pulldown','Bent-over Row','Seated Cable Row','T-bar Row','Face Pull'],
  legs:      ['Squat','Leg Press','Romanian Deadlift','Leg Curl','Leg Extension','Bulgarian Split Squat'],
  shoulders: ['Overhead Press','DB Lateral Raise','Arnold Press','Front Raise','Rear Delt Fly','Upright Row'],
  arms:      ['Barbell Curl','Tricep Pushdown','Hammer Curl','Skull Crushers','Preacher Curl','Overhead Tricep Extension'],
  core:      ['Plank','Crunch','Leg Raise','Russian Twist','Cable Crunch','Ab Wheel'],
};

function SwapExerciseSheet({ data, dispatch }) {
  const { currentName='', target='chest', onSwap } = data || {};
  const list = (SWAP_MAP[target] || SWAP_MAP.chest).filter(n => n !== currentName);

  const pick = (name) => {
    if (typeof onSwap === 'function') onSwap(name);
    dispatch({type:'CLOSE_SHEET'});
  };

  return (
    <BottomSheet title="Swap Exercise" dispatch={dispatch}>
      <div className="small muted" style={{marginBottom:8}}>Replacing: <strong style={{color:'var(--ink)'}}>{currentName}</strong></div>
      <div className="section-header">Similar {target} exercises</div>
      {list.map((name, i) => (
        <div key={i} className="cell tappable" onClick={() => pick(name)}>
          <I.swap size={18} stroke="var(--tint)"/>
          <div className="cell-label" style={{fontSize:15,marginLeft:12}}>{name}</div>
          <I.chevronR size={16} stroke="var(--ink-4)"/>
        </div>
      ))}
    </BottomSheet>
  );
}

/* ─────────────────────────────────────────────────────────
   SaveMealSheet — NEW
   ───────────────────────────────────────────────────────── */
function SaveMealSheet({ data, dispatch }) {
  const [name, setName] = uS_sh('');
  const items = data?.items || [];
  const sumKcal = items.reduce((s,i) => s + (i.kcal||0), 0);

  const save = () => {
    if (!name.trim()) return;
    dispatch({type:'ADD_SAVED_MEAL', meal:{id:'sm'+Date.now(), l:name.trim(), cal:sumKcal, items}});
    dispatch({type:'CLOSE_SHEET'});
  };

  return (
    <BottomSheet title="Save Meal" dispatch={dispatch} action={save} actionLabel="Save"
                 actionColor={name.trim()?'var(--tint)':'var(--ink-4)'}>
      <div className="card" style={{marginBottom:12}}>
        <div className="cell">
          <input value={name} onChange={e=>setName(e.target.value)} placeholder="Meal name…" autoFocus
                 style={{flex:1,background:'none',border:'none',outline:'none',fontSize:17,color:'var(--ink)'}}/>
        </div>
      </div>
      <div className="section-header">{items.length} items · {sumKcal} kcal total</div>
      {items.map((item, i) => (
        <div key={i} className="cell" style={{paddingTop:8,paddingBottom:8}}>
          <div className="cell-label" style={{fontSize:14}}>{item.n}</div>
          <div className="tiny muted">{item.kcal} kcal</div>
        </div>
      ))}
      <button className="btn-primary" style={{marginTop:12}} onClick={save}>Save Meal</button>
    </BottomSheet>
  );
}

/* ─────────────────────────────────────────────────────────
   EditAssignmentSheet — NEW
   ───────────────────────────────────────────────────────── */
function EditAssignmentSheet({ data, state, dispatch }) {
  const assignment = data?.assignment || {};
  const [title,  setTitle]  = uS_sh(assignment.l  || '');
  const [cls,    setCls]    = uS_sh(assignment.cls || '');
  const [due,    setDue]    = uS_sh(assignment.due || '');
  const [urgent, setUrgent] = uS_sh(assignment.urgent || false);

  const existingClasses = [...new Set((state?.assignments || []).map(a => a.cls).filter(Boolean))];

  const save = () => {
    if (!title.trim()) return;
    // delete old, add updated
    dispatch({type:'DELETE_ASSIGNMENT', id: assignment.id});
    dispatch({type:'ADD_ASSIGNMENT', assignment:{...assignment, l:title.trim(), cls, due, urgent, done:assignment.done}});
    dispatch({type:'CLOSE_SHEET'});
  };

  const del = () => {
    dispatch({type:'DELETE_ASSIGNMENT', id: assignment.id});
    dispatch({type:'CLOSE_SHEET'});
  };

  return (
    <BottomSheet title="Edit Assignment" dispatch={dispatch} action={save} actionLabel="Save"
                 actionColor={title.trim()?'var(--tint)':'var(--ink-4)'}>
      <div className="card" style={{marginBottom:12}}>
        <div className="cell">
          <input value={title} onChange={e=>setTitle(e.target.value)} placeholder="Assignment title…" autoFocus
                 style={{flex:1,background:'none',border:'none',outline:'none',fontSize:17,color:'var(--ink)'}}/>
        </div>
      </div>
      <div className="section-header">Class</div>
      <div style={{display:'flex',flexWrap:'wrap',gap:8,marginBottom:12}}>
        {existingClasses.map(c => (
          <button key={c} className={`chip${cls===c?' active':''}`} onClick={() => setCls(c)}>{c}</button>
        ))}
      </div>
      <div className="card" style={{marginBottom:14}}>
        <div className="cell">
          <div className="cell-label">Due</div>
          <input value={due} onChange={e=>setDue(e.target.value)}
                 style={{background:'none',border:'none',outline:'none',fontSize:15,color:'var(--ink)',textAlign:'right'}}/>
        </div>
        <div className="cell tappable" onClick={() => setUrgent(u=>!u)}>
          <div className="cell-label">Urgent</div>
          <div style={{width:32,height:20,borderRadius:10,background:urgent?'var(--tint)':'var(--sep-strong)',
                       position:'relative',transition:'background .2s',cursor:'pointer'}}>
            <div style={{width:16,height:16,borderRadius:8,background:'#fff',position:'absolute',
                         top:2,left:urgent?14:2,transition:'left .2s'}}/>
          </div>
        </div>
      </div>
      <button className="btn-primary" onClick={save} style={{marginBottom:10}}>Save Changes</button>
      <button onClick={del}
              style={{width:'100%',height:48,borderRadius:12,background:'transparent',
                      border:'1.5px solid var(--bad)',color:'var(--bad)',fontSize:15,fontWeight:600,
                      display:'flex',alignItems:'center',justifyContent:'center',gap:6}}>
        <I.trash size={16}/> Delete Assignment
      </button>
    </BottomSheet>
  );
}

/* ─────────────────────────────────────────────────────────
   PersonaPickerSheet — NEW
   ───────────────────────────────────────────────────────── */
const PERSONAS = [
  {k:'peak',         l:'Peak Mode',        desc:'Full volume program — crush every session',       c:'var(--m-gym)'},
  {k:'examSeason',   l:'Exam Season',       desc:'Reduced volume, protect energy for studying',     c:'var(--m-assign)'},
  {k:'summerAthlete',l:'Summer Athlete',    desc:'Cardio-heavy, outdoor-friendly conditioning',     c:'var(--m-habits)'},
  {k:'inSeason',     l:'In-Season',         desc:'Maintenance volume, sport-specific recovery',     c:'var(--m-nutri)'},
  {k:'bulk',         l:'Bulk Mode',         desc:'High volume, progressive overload every week',    c:'var(--tint)'},
];

function PersonaPickerSheet({ state, dispatch }) {
  const current = state?.personaMode || 'peak';
  const pick = (k) => {
    dispatch({type:'SET_PERSONA', mode:k});
    dispatch({type:'CLOSE_SHEET'});
  };
  return (
    <div className="sheet-backdrop" onClick={e => e.target===e.currentTarget && dispatch({type:'CLOSE_SHEET'})}>
      <div className="sheet">
        <div className="sheet-handle"/>
        <div className="sheet-header">
          <button className="nav-btn" onClick={() => dispatch({type:'CLOSE_SHEET'})}>Cancel</button>
          <div className="sheet-title">Program Persona</div>
          <div style={{width:70}}/>
        </div>
        <div className="sheet-body" style={{paddingTop:8}}>
          <div className="small muted" style={{marginBottom:14,lineHeight:1.5}}>
            Your persona adapts training volume and intensity to match your current life season.
          </div>
          {PERSONAS.map(p => {
            const active = current === p.k;
            return (
              <div key={p.k} className="cell tappable" onClick={() => pick(p.k)}
                   style={{background:active?`color-mix(in srgb, ${p.c} 10%, var(--bg-card2))`:'',
                           border:active?`1.5px solid color-mix(in srgb, ${p.c} 30%, transparent)`:'1.5px solid transparent',
                           borderRadius:12,marginBottom:8,padding:'12px 14px'}}>
                <div style={{width:36,height:36,borderRadius:10,flexShrink:0,
                             background:`color-mix(in srgb, ${p.c} 18%, var(--bg-card2))`,
                             display:'flex',alignItems:'center',justifyContent:'center'}}>
                  <div style={{width:12,height:12,borderRadius:6,background:p.c}}/>
                </div>
                <div style={{flex:1,marginLeft:12,minWidth:0}}>
                  <div style={{fontSize:15,fontWeight:700,color:active?p.c:'var(--ink)',letterSpacing:'-0.01em'}}>{p.l}</div>
                  <div className="small muted" style={{marginTop:2,lineHeight:1.3}}>{p.desc}</div>
                </div>
                {active && (
                  <div style={{width:22,height:22,borderRadius:11,background:p.c,flexShrink:0,
                               display:'flex',alignItems:'center',justifyContent:'center'}}>
                    <I.check size={13} stroke="#fff"/>
                  </div>
                )}
              </div>
            );
          })}
        </div>
      </div>
    </div>
  );
}

/* ─────────────────────────────────────────────────────────
   Sheets dispatcher
   ───────────────────────────────────────────────────────── */
function Sheets({ sheet, sheetData, state, dispatch }) {
  if (!sheet) return null;

  if (sheet === 'privacy')   return <PrivacySheet dispatch={dispatch}/>;
  if (sheet === 'terms')     return <TermsSheet dispatch={dispatch}/>;
  if (sheet === 'editSpace') return <EditSpaceSheet data={sheetData} state={state} dispatch={dispatch}/>;

  switch (sheet) {
    case 'logMeal':          return <LogMealSheet          data={sheetData}  state={state} dispatch={dispatch}/>;
    case 'logSleep':         return <LogSleepSheet                           dispatch={dispatch}/>;
    case 'addHabit':         return <AddHabitSheet                           dispatch={dispatch}/>;
    case 'addAssignment':    return <AddAssignmentSheet     state={state}    dispatch={dispatch}/>;
    case 'addExam':          return <AddExamSheet           state={state}    dispatch={dispatch}/>;
    case 'studyPlan':        return <StudyPlanSheet         data={sheetData} dispatch={dispatch}/>;
    case 'practiceQs':       return <PracticeQsSheet        data={sheetData} dispatch={dispatch}/>;
    case 'scanBarcode':      return <ScanBarcodeSheet       data={sheetData} dispatch={dispatch}/>;
    case 'addCustomExercise':return <AddCustomExerciseSheet data={sheetData} dispatch={dispatch}/>;
    case 'swapExercise':     return <SwapExerciseSheet      data={sheetData} dispatch={dispatch}/>;
    case 'saveMeal':         return <SaveMealSheet          data={sheetData} dispatch={dispatch}/>;
    case 'editAssignment':   return <EditAssignmentSheet    data={sheetData} state={state} dispatch={dispatch}/>;
    case 'personaPicker':    return <PersonaPickerSheet                      state={state} dispatch={dispatch}/>;
    default:                 return null;
  }
}

export { Sheets, parseMealText as elosParseMealText };
