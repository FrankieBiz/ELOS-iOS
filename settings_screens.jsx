import React from 'react'
import { I } from './icons.jsx'
import ElosStorage from './storage.js'
const { useState: uS_set, useEffect: uE_set } = React;

/* ── Header used by every settings sub-screen ─────────────── */
function SubNav({ title, dispatch, right }) {
  return (
    <div className="nav-bar">
      <div className="nav-left">
        <button className="nav-btn" onClick={() => dispatch({ type: 'POP_SCREEN' })}>‹ Me</button>
      </div>
      <div className="nav-title">{title}</div>
      <div className="nav-right">{right}</div>
    </div>
  );
}

function Toggle({ checked, onChange }) {
  return (
    <button onClick={() => onChange(!checked)}
            aria-pressed={checked}
            style={{width:48,height:30,borderRadius:15,
                    background:checked?'var(--m-gym)':'var(--sep-strong)',
                    border:'none',position:'relative',cursor:'pointer',transition:'background .15s'}}>
      <div style={{width:26,height:26,borderRadius:13,background:'#fff',
                   position:'absolute',top:2,left:checked?20:2,
                   transition:'left .15s',boxShadow:'0 1px 3px rgba(0,0,0,.2)'}}/>
    </button>
  );
}

/* ── 1. Preferences ───────────────────────────────────────── */
function PreferencesScreen({ state, dispatch }) {
  const p = state.preferences || {};
  const set = (patch) => dispatch({ type: 'SET_PREFERENCES', preferences: patch });

  return (
    <div className="screen-area enter">
      <SubNav title="Preferences" dispatch={dispatch}/>
      <div style={{padding:'10px 16px'}}>
        <div className="section-header">Appearance</div>
        <div className="card" style={{marginBottom:14}}>
          <div className="cell">
            <div className="cell-label">Theme</div>
            <div style={{display:'flex',gap:6}}>
              {['light','dark'].map(t => (
                <button key={t} onClick={()=>dispatch({type:'SET_THEME',theme:t})}
                        className={`chip${state.theme===t?' active':''}`}>
                  {t==='light'?'Light':'Dark'}
                </button>
              ))}
            </div>
          </div>
          <div className="cell">
            <div className="cell-label">Reduce motion</div>
            <Toggle checked={!!p.reduceMotion} onChange={v=>set({reduceMotion:v})}/>
          </div>
        </div>

        <div className="section-header">Units & calendar</div>
        <div className="card" style={{marginBottom:14}}>
          <div className="cell">
            <div className="cell-label">Units</div>
            <div style={{display:'flex',gap:6}}>
              {['imperial','metric'].map(u => (
                <button key={u} onClick={()=>set({units:u})}
                        className={`chip${p.units===u?' active':''}`}>
                  {u==='imperial'?'Imperial':'Metric'}
                </button>
              ))}
            </div>
          </div>
          <div className="cell">
            <div className="cell-label">Week starts on</div>
            <div style={{display:'flex',gap:6}}>
              {[[0,'Sun'],[1,'Mon']].map(([v,l]) => (
                <button key={v} onClick={()=>set({weekStartsOn:v})}
                        className={`chip${p.weekStartsOn===v?' active':''}`}>{l}</button>
              ))}
            </div>
          </div>
        </div>

        <div className="section-header">Notifications</div>
        <div className="card" style={{marginBottom:14}}>
          <div className="cell">
            <div className="cell-label">Push reminders</div>
            <Toggle checked={!!p.notifications} onChange={async v => {
              if (v && 'Notification' in window) {
                try { const r = await Notification.requestPermission(); v = (r === 'granted'); } catch {}
              }
              set({ notifications: v });
            }}/>
          </div>
        </div>
      </div>
      <div style={{height:32}}/>
    </div>
  );
}

/* ── 2. Canvas LMS ────────────────────────────────────────── */
function CanvasScreen({ state, dispatch }) {
  const [domain, setDomain] = uS_set(state.canvas?.domain || '');
  const [token, setToken] = uS_set('');
  const [busy, setBusy] = uS_set(false);
  const [msg, setMsg] = uS_set('');

  const test = async () => {
    if (!domain.trim() || !token.trim()) { setMsg('Enter your Canvas domain and access token.'); return; }
    setBusy(true); setMsg('');
    try {
      const r = await fetch(`https://${domain.replace(/^https?:\/\//,'').replace(/\/$/,'')}/api/v1/users/self`, {
        headers: { authorization: `Bearer ${token}` }
      });
      if (!r.ok) throw new Error('HTTP ' + r.status);
      const u = await r.json();
      setMsg(`Connected as ${u.name || u.short_name || 'user'}.`);
    } catch (e) {
      setMsg('Could not connect. Check your domain & token.');
    } finally { setBusy(false); }
  };

  return (
    <div className="screen-area enter">
      <SubNav title="Canvas LMS" dispatch={dispatch}/>
      <div style={{padding:'10px 16px'}}>
        <div className="card" style={{marginBottom:14,padding:14}}>
          <div style={{fontSize:15,fontWeight:600,marginBottom:6}}>Sync your assignments</div>
          <div style={{fontSize:13,color:'var(--ink-3)',lineHeight:1.4}}>
            ELOS can pull your Canvas assignments and exam dates into your Plan. Generate a personal access token in Canvas → Account → Settings → New Access Token.
          </div>
        </div>

        <div className="section-header">Connection</div>
        <div className="card" style={{marginBottom:14}}>
          <div className="cell" style={{display:'flex'}}>
            <div className="cell-label" style={{flex:'0 0 90px'}}>Domain</div>
            <input value={domain} onChange={e=>setDomain(e.target.value)} placeholder="canvas.school.edu"
                   autoCorrect="off" autoCapitalize="none" spellCheck={false}
                   style={{flex:1,background:'none',border:'none',outline:'none',fontSize:15,color:'var(--ink)',fontFamily:'inherit'}}/>
          </div>
          <div className="cell" style={{display:'flex'}}>
            <div className="cell-label" style={{flex:'0 0 90px'}}>Token</div>
            <input value={token} onChange={e=>setToken(e.target.value)} type="password" placeholder="paste token"
                   autoCorrect="off" autoCapitalize="none" spellCheck={false}
                   style={{flex:1,background:'none',border:'none',outline:'none',fontSize:15,color:'var(--ink)',fontFamily:'inherit'}}/>
          </div>
        </div>

        <button className="btn-primary" disabled={busy} onClick={test} style={{marginBottom:10}}>
          {busy ? 'Connecting…' : 'Test connection'}
        </button>
        {msg && <div style={{fontSize:13,color:msg.startsWith('Connected')?'var(--m-gym)':'var(--bad)',padding:'4px 4px 12px'}}>{msg}</div>}

        <div style={{fontSize:12,color:'var(--ink-4)',padding:'4px 4px 0',lineHeight:1.4}}>
          We never see your token — it stays on your device and is sent directly to your school's Canvas server.
        </div>
      </div>
      <div style={{height:32}}/>
    </div>
  );
}

/* ── 3. Training profile ──────────────────────────────────── */
function TrainingProfileScreen({ state, dispatch }) {
  const tp = state.trainingProfile || {};
  const set = (patch) => dispatch({ type: 'SET_TRAINING_PROFILE', profile: patch });
  const [bw, setBw] = uS_set(String(tp.bodyweight || ''));

  return (
    <div className="screen-area enter">
      <SubNav title="Training profile" dispatch={dispatch}/>
      <div style={{padding:'10px 16px'}}>
        <div className="section-header">Program</div>
        <div className="card" style={{marginBottom:14}}>
          {['Push/Pull/Legs','Upper/Lower','Full Body','Bro Split','Custom'].map(p => (
            <div key={p} className="cell tappable" onClick={()=>set({program:p})}>
              <div className="cell-label">{p}</div>
              {tp.program===p && <I.check size={18} stroke="var(--tint)"/>}
            </div>
          ))}
        </div>

        <div className="section-header">Schedule</div>
        <div className="card" style={{marginBottom:14}}>
          <div className="cell">
            <div className="cell-label">Days per week</div>
            <div style={{display:'flex',gap:6}}>
              {[3,4,5,6].map(d => (
                <button key={d} onClick={()=>set({daysPerWeek:d})}
                        className={`chip${tp.daysPerWeek===d?' active':''}`}>{d}</button>
              ))}
            </div>
          </div>
          <div className="cell">
            <div className="cell-label">Experience</div>
            <div style={{display:'flex',gap:6}}>
              {['Beginner','Intermediate','Advanced'].map(e => (
                <button key={e} onClick={()=>set({experience:e})}
                        className={`chip${tp.experience===e?' active':''}`}>{e[0]+e.slice(1).toLowerCase()}</button>
              ))}
            </div>
          </div>
        </div>

        <div className="section-header">Body</div>
        <div className="card" style={{marginBottom:14}}>
          <div className="cell" style={{display:'flex'}}>
            <div className="cell-label" style={{flex:1}}>Bodyweight</div>
            <input type="number" value={bw} onChange={e=>{ setBw(e.target.value); set({bodyweight:Number(e.target.value)||0}); }}
                   style={{width:90,textAlign:'right',background:'none',border:'none',outline:'none',fontSize:17,color:'var(--ink)',fontFamily:'inherit'}}/>
            <div className="cell-detail" style={{marginLeft:6}}>{state.preferences?.units==='metric'?'kg':'lb'}</div>
          </div>
        </div>
      </div>
      <div style={{height:32}}/>
    </div>
  );
}

/* ── 4. Nutrition goals ───────────────────────────────────── */
function NutritionGoalsScreen({ state, dispatch }) {
  const ng = state.nutritionGoals || {};
  const set = (patch) => dispatch({ type: 'SET_NUTRITION_GOALS', goals: patch });
  const sliders = [
    ['calories', 'Calories', 'kcal', 1200, 5000, 50],
    ['protein',  'Protein',  'g',     50, 400,  5],
    ['carbs',    'Carbs',    'g',     50, 700, 10],
    ['fat',      'Fat',      'g',     20, 250,  5],
    ['hydrationOz','Hydration','oz',  32, 256,  4],
  ];
  return (
    <div className="screen-area enter">
      <SubNav title="Nutrition goals" dispatch={dispatch}/>
      <div style={{padding:'10px 16px'}}>
        <div className="section-header">Daily targets</div>
        <div className="card" style={{padding:'14px 16px',marginBottom:14}}>
          {sliders.map(([k,l,u,mn,mx,st]) => (
            <div key={k} style={{marginBottom:14}}>
              <div style={{display:'flex',justifyContent:'space-between',marginBottom:6}}>
                <span style={{fontSize:14,fontWeight:600}}>{l}</span>
                <span className="mono" style={{fontSize:14,color:'var(--tint)'}}>{ng[k]||0} {u}</span>
              </div>
              <input type="range" min={mn} max={mx} step={st} value={ng[k]||0}
                     onChange={e=>set({[k]:Number(e.target.value)})}
                     style={{width:'100%',accentColor:'var(--tint)'}}/>
            </div>
          ))}
        </div>
        <div style={{fontSize:12,color:'var(--ink-4)',padding:'4px 4px',lineHeight:1.4}}>
          Tip: protein ≈ 0.7–1g per lb of bodyweight. Carbs and fat fill the rest of your calorie target.
        </div>
      </div>
      <div style={{height:32}}/>
    </div>
  );
}

/* ── 5. Spaces & notes ────────────────────────────────────── */
function SpacesScreen({ state, dispatch }) {
  const spaces = state.spaces || [];
  const [draft, setDraft] = uS_set('');

  const add = () => {
    if (!draft.trim()) return;
    dispatch({ type: 'ADD_SPACE', space: { id: 's' + Date.now(), title: draft.trim(), body: '', updated: Date.now() } });
    setDraft('');
  };

  return (
    <div className="screen-area enter">
      <SubNav title="Spaces & notes" dispatch={dispatch}/>
      <div style={{padding:'10px 16px'}}>
        <div className="card" style={{marginBottom:14,padding:'10px 12px'}}>
          <div style={{display:'flex',gap:8,alignItems:'center'}}>
            <input value={draft} onChange={e=>setDraft(e.target.value)} placeholder="New space (e.g., AP Calc, Injury notes)…"
                   onKeyDown={e=>e.key==='Enter'&&add()}
                   style={{flex:1,padding:'10px 12px',background:'var(--bg-input)',border:'1px solid var(--sep)',
                           borderRadius:10,outline:'none',fontSize:15,color:'var(--ink)',fontFamily:'inherit'}}/>
            <button className="btn-primary xs" onClick={add} disabled={!draft.trim()}
                    style={{opacity:draft.trim()?1:0.4}}>Add</button>
          </div>
        </div>

        {spaces.length === 0 ? (
          <div style={{padding:32,textAlign:'center',color:'var(--ink-3)'}}>
            <I.note size={32} stroke="var(--ink-4)"/>
            <div style={{marginTop:10,fontSize:14}}>No spaces yet.</div>
            <div style={{fontSize:12,color:'var(--ink-4)',marginTop:4}}>Spaces are notebooks for classes, projects, and journals.</div>
          </div>
        ) : (
          <div className="card">
            {spaces.map(s => (
              <div key={s.id} className="cell tappable" onClick={()=>dispatch({type:'OPEN_SHEET',sheet:'editSpace',data:s})}>
                <I.note size={18} stroke="var(--m-assign)"/>
                <div style={{flex:1,minWidth:0}}>
                  <div className="cell-label" style={{fontWeight:600}}>{s.title}</div>
                  <div style={{fontSize:12,color:'var(--ink-4)',whiteSpace:'nowrap',overflow:'hidden',textOverflow:'ellipsis'}}>
                    {s.body ? s.body.slice(0,80) : 'Empty space'}
                  </div>
                </div>
                <I.chevronR size={16} stroke="var(--ink-4)"/>
              </div>
            ))}
          </div>
        )}
      </div>
      <div style={{height:32}}/>
    </div>
  );
}

/* ── 6. About ELOS ────────────────────────────────────────── */
function AboutScreen({ state, dispatch }) {
  const [busy, setBusy] = uS_set(false);

  const exportData = () => {
    const json = ElosStorage.exportJSON() || '{}';
    const blob = new Blob([json], { type: 'application/json' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url; a.download = `elos-backup-${new Date().toISOString().slice(0,10)}.json`;
    document.body.appendChild(a); a.click(); a.remove();
    URL.revokeObjectURL(url);
  };

  const importData = () => {
    const inp = document.createElement('input');
    inp.type = 'file'; inp.accept = 'application/json,.json';
    inp.onchange = async () => {
      const f = inp.files?.[0]; if (!f) return;
      const txt = await f.text();
      if (ElosStorage.importJSON(txt)) {
        if (confirm('Imported. Reload to apply?')) location.reload();
      } else {
        alert('Import failed — file is not a valid ELOS backup.');
      }
    };
    inp.click();
  };

  const installApp = async () => {
    const p = window.__elosInstallPrompt;
    if (!p) { alert('Install prompt is not available right now. On iOS: Share → Add to Home Screen.'); return; }
    setBusy(true);
    try { await p.prompt(); await p.userChoice; window.__elosInstallPrompt = null; }
    finally { setBusy(false); }
  };

  const erase = () => {
    if (!confirm('Erase ALL ELOS data on this device? This cannot be undone.')) return;
    ElosStorage.clearAll();
    location.reload();
  };

  return (
    <div className="screen-area enter">
      <SubNav title="About ELOS" dispatch={dispatch}/>
      <div style={{padding:'10px 16px'}}>
        <div style={{textAlign:'center',padding:'20px 0 24px'}}>
          <div style={{width:72,height:72,margin:'0 auto 12px',borderRadius:18,
                       background:'linear-gradient(135deg,#0A0A0A,#1F1F23)',display:'flex',alignItems:'center',justifyContent:'center',
                       color:'#fff',fontSize:36,fontWeight:700}}>E</div>
          <div style={{fontSize:22,fontWeight:700,letterSpacing:'-0.02em'}}>ELOS</div>
          <div style={{fontSize:13,color:'var(--ink-3)'}}>Version 1.0.0</div>
        </div>

        <div className="section-header">Data</div>
        <div className="card" style={{marginBottom:14}}>
          <div className="cell tappable" onClick={exportData}>
            <I.note size={18} stroke="var(--m-sched)"/>
            <div className="cell-label">Export my data</div>
            <I.chevronR size={16} stroke="var(--ink-4)"/>
          </div>
          <div className="cell tappable" onClick={importData}>
            <I.plus size={18} stroke="var(--m-gym)"/>
            <div className="cell-label">Import a backup</div>
            <I.chevronR size={16} stroke="var(--ink-4)"/>
          </div>
        </div>

        <div className="section-header">App</div>
        <div className="card" style={{marginBottom:14}}>
          <div className="cell tappable" onClick={installApp}>
            <I.dumbbell size={18} stroke="var(--m-gym)"/>
            <div className="cell-label">{busy ? 'Installing…' : 'Install ELOS'}</div>
            <I.chevronR size={16} stroke="var(--ink-4)"/>
          </div>
          <div className="cell tappable" onClick={()=>dispatch({type:'OPEN_SHEET',sheet:'privacy'})}>
            <I.info size={18} stroke="var(--ink-3)"/>
            <div className="cell-label">Privacy policy</div>
            <I.chevronR size={16} stroke="var(--ink-4)"/>
          </div>
          <div className="cell tappable" onClick={()=>dispatch({type:'OPEN_SHEET',sheet:'terms'})}>
            <I.info size={18} stroke="var(--ink-3)"/>
            <div className="cell-label">Terms of use</div>
            <I.chevronR size={16} stroke="var(--ink-4)"/>
          </div>
        </div>

        <div className="section-header">Danger zone</div>
        <div className="card" style={{marginBottom:14}}>
          <div className="cell tappable" onClick={erase}>
            <I.x size={18} stroke="var(--bad)"/>
            <div className="cell-label" style={{color:'var(--bad)'}}>Erase all data on this device</div>
          </div>
        </div>

        <div style={{fontSize:11,color:'var(--ink-4)',textAlign:'center',padding:'12px 0 24px',lineHeight:1.5}}>
          ELOS does not provide medical advice. Always consult a qualified professional for nutrition, training and health decisions.
        </div>
      </div>
      <div style={{height:24}}/>
    </div>
  );
}

/* ── Privacy + Terms (used as sheets) ────────────────────── */
const PRIVACY_TEXT = `**Privacy Policy** — last updated: 2026-04-28

ELOS stores your data on your device by default. We never read your habits, training, nutrition or schedule unless you explicitly turn on cloud sync.

**What stays on your device**
- Habit completions, training sessions, meals, sleep, hydration, schedules, assignments, exams, notes, settings.

**What we collect when cloud sync is on**
- An email address you provide.
- An encrypted backup of the data above, used only to sync between your devices.

**Third parties**
- Canvas LMS: if you connect Canvas, your access token is sent only to your school's Canvas server. We never see it.
- OpenFoodFacts: barcode lookups go directly to OpenFoodFacts. We do not log them.

**Children**
- ELOS is not directed at children under 13. If you are under 13, do not use the app.

**Your rights**
- Export, import or delete your data at any time from About → Data.
- Disable cloud sync to stop transferring data to our servers.

Contact: privacy@elos.app`;

const TERMS_TEXT = `**Terms of Use** — last updated: 2026-04-28

By using ELOS you agree to these terms. ELOS is provided for personal use, "as is", with no warranty of fitness for any particular purpose.

**No medical advice**
ELOS is a self-tracking tool. It does not diagnose, treat or prevent any condition. Always consult a qualified professional before changing your nutrition, training or recovery routines.

**Acceptable use**
You may not abuse the cloud-sync service, attempt to break its security, scrape user data, or use it to harm others.

**Account & content**
You own your data. We will return or delete it on request. We may suspend abusive accounts.

**Changes**
We may update these terms. Material changes will be announced in the app.

Contact: legal@elos.app`;

function MarkdownLite({ text }) {
  return (
    <div style={{fontSize:14,lineHeight:1.55,color:'var(--ink)',whiteSpace:'pre-wrap'}}>
      {text.split('\n').map((line,i) => {
        const m = line.match(/^\*\*(.+?)\*\*\s*(.*)$/);
        if (m) return <div key={i} style={{fontWeight:700,fontSize:15,marginTop:14,marginBottom:6}}>{m[1]}{m[2]?` ${m[2]}`:''}</div>;
        if (line.startsWith('- ')) return <div key={i} style={{paddingLeft:16,position:'relative',marginBottom:4}}><span style={{position:'absolute',left:4}}>·</span>{line.slice(2)}</div>;
        return <div key={i}>{line}</div>;
      })}
    </div>
  );
}

function PrivacySheet({ dispatch }) {
  return (
    <div className="sheet-backdrop" onClick={e => e.target===e.currentTarget && dispatch({type:'CLOSE_SHEET'})}>
      <div className="sheet" style={{maxHeight:'88%'}}>
        <div className="sheet-handle"/>
        <div className="sheet-header">
          <div style={{width:70}}/>
          <div className="sheet-title">Privacy Policy</div>
          <button className="nav-btn" onClick={() => dispatch({type:'CLOSE_SHEET'})}>Done</button>
        </div>
        <div className="sheet-body" style={{overflowY:'auto'}}>
          <MarkdownLite text={PRIVACY_TEXT}/>
        </div>
      </div>
    </div>
  );
}

function TermsSheet({ dispatch }) {
  return (
    <div className="sheet-backdrop" onClick={e => e.target===e.currentTarget && dispatch({type:'CLOSE_SHEET'})}>
      <div className="sheet" style={{maxHeight:'88%'}}>
        <div className="sheet-handle"/>
        <div className="sheet-header">
          <div style={{width:70}}/>
          <div className="sheet-title">Terms of Use</div>
          <button className="nav-btn" onClick={() => dispatch({type:'CLOSE_SHEET'})}>Done</button>
        </div>
        <div className="sheet-body" style={{overflowY:'auto'}}>
          <MarkdownLite text={TERMS_TEXT}/>
        </div>
      </div>
    </div>
  );
}

/* ── Edit space (note) sheet ──────────────────────────────── */
function EditSpaceSheet({ state, data, dispatch }) {
  const space = data;
  const [title, setTitle] = uS_set(space?.title || '');
  const [body, setBody]  = uS_set(space?.body || '');

  const save = () => {
    if (!space?.id) return;
    dispatch({ type:'UPDATE_SPACE', id: space.id, patch: { title: title.trim() || 'Untitled', body, updated: Date.now() } });
    dispatch({ type: 'CLOSE_SHEET' });
  };
  const del = () => {
    if (!space?.id) return;
    if (!confirm('Delete this space?')) return;
    dispatch({ type:'DELETE_SPACE', id: space.id });
    dispatch({ type:'CLOSE_SHEET' });
  };

  return (
    <div className="sheet-backdrop" onClick={e => e.target===e.currentTarget && dispatch({type:'CLOSE_SHEET'})}>
      <div className="sheet" style={{maxHeight:'90%'}}>
        <div className="sheet-handle"/>
        <div className="sheet-header">
          <button className="nav-btn" onClick={() => dispatch({type:'CLOSE_SHEET'})}>Cancel</button>
          <div className="sheet-title">Edit space</div>
          <button className="nav-btn" style={{fontWeight:600}} onClick={save}>Save</button>
        </div>
        <div className="sheet-body">
          <input value={title} onChange={e=>setTitle(e.target.value)} placeholder="Title"
                 style={{width:'100%',padding:'12px 14px',background:'var(--bg-card)',border:'1px solid var(--sep)',
                         borderRadius:10,fontSize:17,color:'var(--ink)',outline:'none',marginBottom:10,fontFamily:'inherit'}}/>
          <textarea value={body} onChange={e=>setBody(e.target.value)} placeholder="Notes…"
                    style={{width:'100%',minHeight:200,padding:'12px 14px',background:'var(--bg-card)',border:'1px solid var(--sep)',
                            borderRadius:10,fontSize:15,color:'var(--ink)',outline:'none',fontFamily:'inherit',resize:'vertical'}}/>
          <button className="btn-primary secondary" style={{marginTop:14,color:'var(--bad)'}} onClick={del}>Delete space</button>
        </div>
      </div>
    </div>
  );
}

/* ── 7. Workout History ───────────────────────────────── */
function WorkoutHistoryScreen({ state, dispatch }) {
  const history = state.workoutHistory || [];
  const [expanded, setExpanded] = uS_set(null);

  return (
    <div className="screen-area enter">
      <SubNav title="Workout History" dispatch={dispatch}/>
      <div style={{padding:'10px 16px'}}>
        {history.length === 0 ? (
          <div style={{display:'flex',flexDirection:'column',alignItems:'center',padding:'48px 16px',textAlign:'center'}}>
            <I.dumbbell size={40} stroke="var(--ink-4)"/>
            <div style={{marginTop:16,fontSize:16,fontWeight:700,color:'var(--ink)'}}>No workouts yet</div>
            <div style={{marginTop:6,fontSize:13,color:'var(--ink-3)',lineHeight:1.4}}>Complete a session from the Train tab to see your history here.</div>
            <button className="btn-primary" style={{marginTop:24,width:'auto',paddingLeft:24,paddingRight:24}}
                    onClick={() => { dispatch({type:'POP_SCREEN'}); dispatch({type:'SET_TAB',tab:'train'}); }}>
              <I.play size={16}/>
              Start a workout
            </button>
          </div>
        ) : (
          <>
            <div className="section-header" style={{padding:'0 4px 10px'}}>{history.length} session{history.length!==1?'s':''} logged</div>
            {history.map((w, i) => {
              const isOpen = expanded === i;
              const date = new Date(w.date);
              const dateStr = date.toLocaleDateString('en-US',{weekday:'short',month:'short',day:'numeric'});
              const timeStr = date.toLocaleTimeString('en-US',{hour:'numeric',minute:'2-digit'});
              const names = (w.exercises||[]).map(e=>e.name).slice(0,2).join(', ');
              return (
                <div key={i} className="exercise-block" style={{marginBottom:10,border:'1px solid var(--sep)'}}>
                  <div className="exercise-header" onClick={() => setExpanded(isOpen ? null : i)}>
                    <div style={{flex:1,minWidth:0}}>
                      <div className="eyebrow">{dateStr} · {timeStr}</div>
                      <div style={{fontSize:15,fontWeight:600,marginTop:3,overflow:'hidden',textOverflow:'ellipsis',whiteSpace:'nowrap'}}>
                        {names || 'Workout'}
                      </div>
                    </div>
                    <div style={{textAlign:'right',flexShrink:0,marginRight:8}}>
                      <div className="mono tabular" style={{fontSize:18,fontWeight:800,letterSpacing:'-0.02em',color:'var(--ink)'}}>{(w.totalVolume||0).toLocaleString()}<span className="eyebrow" style={{marginLeft:3}}>lb</span></div>
                      <div className="eyebrow" style={{marginTop:2}}>{w.totalSets} sets · {Math.round((w.durationSec||0)/60)} min</div>
                    </div>
                    {isOpen ? <I.chevronU size={16} stroke="var(--ink-4)"/> : <I.chevronD size={16} stroke="var(--ink-4)"/>}
                  </div>
                  {isOpen && (
                    <div>
                      <div style={{display:'grid',gridTemplateColumns:'repeat(3,1fr)',borderTop:'1px solid var(--sep)',borderBottom:'1px solid var(--sep)'}}>
                        {[
                          ['Duration', `${Math.round((w.durationSec||0)/60)} min`],
                          ['Sets', String(w.totalSets||0)],
                          ['Volume', `${Math.round((w.totalVolume||0)/1000)}k lb`],
                        ].map(([l,v],j) => (
                          <div key={j} style={{padding:'12px 0',textAlign:'center',borderLeft:j?'1px solid var(--sep)':'none'}}>
                            <div className="eyebrow">{l}</div>
                            <div className="mono tabular" style={{fontSize:18,fontWeight:800,marginTop:3,color:'var(--ink)',letterSpacing:'-0.02em'}}>{v}</div>
                          </div>
                        ))}
                      </div>
                      {(w.exercises||[]).map((ex,j) => {
                        const completedSets = (ex.sets||[]).filter(s => s.weight || s.reps);
                        return (
                          <div key={j} style={{padding:'12px 16px',borderTop:j>0?'1px solid var(--sep)':'none'}}>
                            <div style={{fontSize:14,fontWeight:600,color:'var(--ink)',marginBottom:6}}>{ex.name}</div>
                            <div style={{display:'flex',gap:4,flexWrap:'wrap'}}>
                              {completedSets.map((s,k) => (
                                <span key={k} className="chip" style={{background:'var(--bg-input)',fontSize:11,fontFamily:'ui-monospace,monospace'}}>
                                  {s.weight}×{s.reps}{s.rpe ? ` @${s.rpe}` : ''}
                                </span>
                              ))}
                              {completedSets.length === 0 && <span className="eyebrow">No sets logged</span>}
                            </div>
                          </div>
                        );
                      })}
                    </div>
                  )}
                </div>
              );
            })}
          </>
        )}
      </div>
      <div style={{height:32}}/>
    </div>
  );
}

export {
  PreferencesScreen, CanvasScreen, TrainingProfileScreen,
  NutritionGoalsScreen, SpacesScreen, AboutScreen,
  WorkoutHistoryScreen,
  PrivacySheet, TermsSheet, EditSpaceSheet,
};
