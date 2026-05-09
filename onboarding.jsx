import React from 'react'
import { I } from './icons.jsx'
const { useState: uS_ob } = React;

function Onboarding({ state, dispatch }) {
  const [step, setStep] = uS_ob(0);
  const [name, setName] = uS_ob(state.profile?.name === 'Frank Aguilar' ? '' : (state.profile?.name || ''));
  const [units, setUnits] = uS_ob(state.preferences?.units || 'imperial');
  const [calories, setCalories] = uS_ob(state.nutritionGoals?.calories || 2950);
  const [protein, setProtein] = uS_ob(state.nutritionGoals?.protein || 200);
  const [hydration, setHydration] = uS_ob(state.nutritionGoals?.hydrationOz || 128);
  const [program, setProgram] = uS_ob(state.trainingProfile?.program || 'Push/Pull/Legs');
  const [agreed, setAgreed] = uS_ob(false);

  const STEPS = ['welcome', 'name', 'units', 'goals', 'training', 'consent'];
  const total = STEPS.length;

  const next = () => setStep(s => Math.min(total - 1, s + 1));
  const back = () => setStep(s => Math.max(0, s - 1));

  const finish = () => {
    const initials = (name.trim().split(/\s+/).map(p => p[0]).join('').slice(0,2).toUpperCase()) || 'EL';
    dispatch({ type: 'SET_PROFILE', profile: { name: name.trim() || 'Athlete', initials } });
    dispatch({ type: 'SET_PREFERENCES', preferences: { units } });
    dispatch({ type: 'SET_NUTRITION_GOALS', goals: { calories: Number(calories)||2950, protein: Number(protein)||200, hydrationOz: Number(hydration)||128 } });
    dispatch({ type: 'SET_TRAINING_PROFILE', profile: { program } });
    dispatch({ type: 'COMPLETE_ONBOARDING' });
  };

  const StepDots = () => (
    <div style={{display:'flex',gap:6,justifyContent:'center',marginTop:16}}>
      {STEPS.map((_, i) => (
        <div key={i} style={{width:6,height:6,borderRadius:3,background:i===step?'var(--tint)':'var(--sep-strong)'}}/>
      ))}
    </div>
  );

  const cur = STEPS[step];

  return (
    <div className="screen-area" style={{paddingTop:40}}>
      {cur !== 'welcome' && (
        <div style={{padding:'8px 16px'}}>
          <button className="nav-btn" onClick={back} style={{padding:0}}>‹ Back</button>
        </div>
      )}

      <div style={{padding:'24px 24px 0',flex:1,display:'flex',flexDirection:'column'}}>

        {cur === 'welcome' && (
          <div style={{marginTop:40}}>
            <div className="eyebrow" style={{marginBottom:16}}>v1.0 · Daily Performance OS</div>
            <div style={{fontSize:56,fontWeight:800,letterSpacing:'-0.045em',marginBottom:8,lineHeight:0.95,color:'var(--ink)'}}>ELOS.</div>
            <div style={{fontSize:18,color:'var(--ink-3)',lineHeight:1.35,marginBottom:36,letterSpacing:'-0.01em'}}>
              Habits, training, nutrition, schedule and recovery — engineered into one daily ritual.
            </div>
            <div style={{borderTop:'1px solid var(--sep)'}}>
              {[
                ['Train', 'Programs, sets, PRs, volume.'],
                ['Eat', 'Macros, barcode, AI parser.'],
                ['Plan', 'Classes, assignments, exams.'],
                ['Recover', 'Sleep, hydration, habits.'],
              ].map(([t,d],i) => (
                <div key={i} style={{display:'flex',alignItems:'baseline',gap:14,padding:'14px 0',borderBottom:'1px solid var(--sep)'}}>
                  <div className="eyebrow" style={{minWidth:64,color:'var(--tint)'}}>0{i+1}</div>
                  <div style={{flex:1}}>
                    <div style={{fontSize:18,fontWeight:700,letterSpacing:'-0.015em'}}>{t}</div>
                    <div style={{fontSize:13,color:'var(--ink-3)',marginTop:2}}>{d}</div>
                  </div>
                </div>
              ))}
            </div>
          </div>
        )}

        {cur === 'name' && (
          <div>
            <div style={{fontSize:34,fontWeight:800,letterSpacing:'-0.035em',marginBottom:8,lineHeight:1.05}}>What should we call you?</div>
            <div style={{fontSize:14,color:'var(--ink-3)',marginBottom:24}}>Everything stays on your device — no account needed.</div>
            <input value={name} onChange={e=>setName(e.target.value)} placeholder="Your name"
                   autoFocus
                   style={{width:'100%',padding:'14px 16px',fontSize:18,border:'1px solid var(--sep)',background:'var(--bg-card)',
                           color:'var(--ink)',borderRadius:12,outline:'none',marginBottom:20}}/>
          </div>
        )}

        {cur === 'units' && (
          <div>
            <div style={{fontSize:34,fontWeight:800,letterSpacing:'-0.035em',marginBottom:8,lineHeight:1.05}}>Pick your units</div>
            <div style={{fontSize:14,color:'var(--ink-3)',marginBottom:24}}>Used across nutrition, training and hydration.</div>
            {[['imperial','Imperial','lb · oz · °F'], ['metric','Metric','kg · ml · °C']].map(([k,l,d]) => (
              <button key={k} onClick={()=>setUnits(k)}
                      style={{display:'block',width:'100%',padding:'16px',marginBottom:12,
                              background:units===k?'var(--tint-soft)':'var(--bg-card)',
                              border:`2px solid ${units===k?'var(--tint)':'var(--sep)'}`,
                              borderRadius:12,textAlign:'left',color:'var(--ink)',cursor:'pointer'}}>
                <div style={{fontSize:17,fontWeight:600}}>{l}</div>
                <div style={{fontSize:13,color:'var(--ink-3)',marginTop:4}}>{d}</div>
              </button>
            ))}
          </div>
        )}

        {cur === 'goals' && (
          <div>
            <div style={{fontSize:34,fontWeight:800,letterSpacing:'-0.035em',marginBottom:8,lineHeight:1.05}}>Daily nutrition goals</div>
            <div style={{fontSize:14,color:'var(--ink-3)',marginBottom:24}}>You can change these any time in Settings.</div>
            {[
              ['Calories', calories, setCalories, 'kcal', 1200, 5000, 50],
              ['Protein',  protein,  setProtein,  'g',     50, 400,  5],
              ['Hydration',hydration,setHydration,'oz',    32, 256,  4],
            ].map(([label,val,set,unit,min,max,step]) => (
              <div key={label} style={{marginBottom:18}}>
                <div style={{display:'flex',justifyContent:'space-between',marginBottom:8}}>
                  <span style={{fontSize:15,fontWeight:600}}>{label}</span>
                  <span className="mono" style={{fontSize:15,color:'var(--tint)'}}>{val} {unit}</span>
                </div>
                <input type="range" min={min} max={max} step={step} value={val}
                       onChange={e=>set(Number(e.target.value))}
                       style={{width:'100%',accentColor:'var(--tint)'}}/>
              </div>
            ))}
          </div>
        )}

        {cur === 'training' && (
          <div>
            <div style={{fontSize:34,fontWeight:800,letterSpacing:'-0.035em',marginBottom:8,lineHeight:1.05}}>Training program</div>
            <div style={{fontSize:14,color:'var(--ink-3)',marginBottom:24}}>Pick what fits your week.</div>
            {['Push/Pull/Legs','Upper/Lower','Full Body','Bro Split','Custom'].map(p => (
              <button key={p} onClick={()=>setProgram(p)}
                      style={{display:'block',width:'100%',padding:'14px 16px',marginBottom:10,
                              background:program===p?'var(--tint-soft)':'var(--bg-card)',
                              border:`2px solid ${program===p?'var(--tint)':'var(--sep)'}`,
                              borderRadius:12,textAlign:'left',color:'var(--ink)',cursor:'pointer',fontSize:16,fontWeight:500}}>
                {p}
              </button>
            ))}
          </div>
        )}

        {cur === 'consent' && (
          <div>
            <div style={{fontSize:34,fontWeight:800,letterSpacing:'-0.035em',marginBottom:8,lineHeight:1.05}}>One last thing</div>
            <div style={{fontSize:14,color:'var(--ink-3)',marginBottom:18}}>
              ELOS stores everything locally on this device. Your data never leaves your phone.
            </div>
            <label style={{display:'flex',gap:10,padding:14,background:'var(--bg-card)',border:'1px solid var(--sep)',borderRadius:12,marginBottom:14,cursor:'pointer'}}>
              <input type="checkbox" checked={agreed} onChange={e=>setAgreed(e.target.checked)} style={{marginTop:2,accentColor:'var(--tint)'}}/>
              <span style={{fontSize:14,lineHeight:1.4}}>
                I have read and agree to the <button onClick={()=>dispatch({type:'OPEN_SHEET',sheet:'privacy'})} style={{color:'var(--tint)',background:'none',border:'none',padding:0,cursor:'pointer',font:'inherit'}}>Privacy Policy</button> and <button onClick={()=>dispatch({type:'OPEN_SHEET',sheet:'terms'})} style={{color:'var(--tint)',background:'none',border:'none',padding:0,cursor:'pointer',font:'inherit'}}>Terms</button>.
              </span>
            </label>
          </div>
        )}

        <StepDots/>
      </div>

      <div style={{padding:'16px 24px 32px'}}>
        {cur === 'consent'
          ? <button className="btn-primary" disabled={!agreed} onClick={finish}
                    style={{opacity:agreed?1:0.4}}>Get started</button>
          : <button className="btn-primary"
                    disabled={cur==='name' && !name.trim()}
                    onClick={next}
                    style={{opacity:(cur==='name' && !name.trim())?0.4:1}}>
              {cur==='welcome' ? 'Begin' : 'Continue'}
            </button>}
      </div>
    </div>
  );
}

export { Onboarding };
