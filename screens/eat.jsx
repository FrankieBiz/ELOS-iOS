import React from 'react'
import { I } from '../icons.jsx'
import { Ring } from '../shell.jsx'
import { elosParseMealText } from '../sheets.jsx'
const { useState: uS_e } = React;

function MacroBar({ label, val, goal }) {
  const over = val > goal;
  const pct = Math.min(100, val/goal*100);
  return (
    <div style={{flex:1,minWidth:0}}>
      <div style={{display:'flex',justifyContent:'space-between',alignItems:'baseline',marginBottom:6}}>
        <span className="eyebrow">{label}</span>
        <span className="mono tabular" style={{fontSize:13,fontWeight:700,color: over ? 'var(--warn)' : 'var(--ink)'}}>{val}<span style={{fontSize:10,color:'var(--ink-3)',marginLeft:1}}>g</span></span>
      </div>
      <div className="prog"><div className="fill" style={{width:`${pct}%`,background: over ? 'var(--warn)' : 'var(--tint)'}}/></div>
    </div>
  );
}

function CalHeader({ meals, calGoal, nutritionGoals, dispatch }) {
  const macrosGoal = {
    p: nutritionGoals?.protein  || 220,
    c: nutritionGoals?.carbs    || 360,
    f: nutritionGoals?.fat      || 95,
  };
  const allItems = Object.values(meals).flat();
  const cal  = allItems.reduce((s,m) => s+m.kcal, 0);
  const p    = allItems.reduce((s,m) => s+m.p,    0);
  const c    = allItems.reduce((s,m) => s+m.c,    0);
  const f    = allItems.reduce((s,m) => s+m.f,    0);
  const remaining = calGoal - cal;
  const over = remaining < 0;
  return (
    <div style={{margin:'0 16px 14px',padding:'18px 18px 16px',borderTop:'1px solid var(--sep)',borderBottom:'1px solid var(--sep)',background:'var(--bg-card)'}}>
      <div style={{display:'flex',alignItems:'baseline',justifyContent:'space-between',marginBottom:14}}>
        <div>
          <div className="eyebrow">{over ? 'Over by' : 'Remaining'}</div>
          <div className="mono tabular" style={{fontSize:42,fontWeight:800,letterSpacing:'-0.035em',lineHeight:1,color: over ? 'var(--warn)' : 'var(--ink)',marginTop:4}}>
            {Math.abs(remaining).toLocaleString()}
          </div>
          <div className="eyebrow" style={{marginTop:6}}>kcal · {cal.toLocaleString()} of {calGoal.toLocaleString()}</div>
        </div>
        <div style={{textAlign:'right'}}>
          <div className="eyebrow">Goal</div>
          <div className="mono tabular" style={{fontSize:18,fontWeight:700,letterSpacing:'-0.02em',color:'var(--ink-3)',marginTop:4}}>
            {calGoal.toLocaleString()}
          </div>
        </div>
      </div>
      <div style={{display:'flex',gap:14,paddingTop:12,borderTop:'1px solid var(--sep)'}}>
        <MacroBar label="Protein" val={p} goal={macrosGoal.p}/>
        <MacroBar label="Carbs"   val={c} goal={macrosGoal.c}/>
        <MacroBar label="Fat"     val={f} goal={macrosGoal.f}/>
      </div>
    </div>
  );
}

function MealSection({ title, mealKey, items, dispatch }) {
  const [open, setOpen] = uS_e(mealKey==='breakfast'||mealKey==='lunch');
  const total = items.reduce((s,i) => s+i.kcal, 0);
  return (
    <div className="card" style={{marginBottom:10}}>
      <div className="cell tappable" onClick={() => setOpen(v=>!v)}>
        <div className="cell-label" style={{fontWeight:600}}>{title}</div>
        <div className="cell-detail mono">{total} kcal</div>
        <button className="icon-btn muted" style={{width:36,height:36}}
                onClick={e => { e.stopPropagation(); dispatch({type:'OPEN_SHEET',sheet:'logMeal',data:{mealKey,title}}); }}>
          <I.plus size={18}/>
        </button>
        {open ? <I.chevronU size={16} stroke="var(--ink-4)"/> : <I.chevronD size={16} stroke="var(--ink-4)"/>}
      </div>
      {open && (
        <div>
          {items.length === 0 && (
            <div style={{padding:'12px 16px',color:'var(--ink-4)',fontSize:14}}>
              No items logged yet. Tap + to add food.
            </div>
          )}
          {items.map((it,i) => (
            <div key={i} className="cell" style={{paddingLeft:20}}>
              <div className="cell-label" style={{fontSize:14}}>{it.n}</div>
              <div className="cell-detail mono" style={{fontSize:12}}>{it.p}p/{it.c}c/{it.f}f</div>
              <div className="cell-value" style={{fontSize:14,minWidth:52,textAlign:'right'}}>{it.kcal}</div>
              <button className="icon-btn muted" style={{width:28,height:28,flexShrink:0}}
                      onClick={e => { e.stopPropagation(); dispatch({type:'DELETE_MEAL_ITEM',meal:mealKey,index:i}); }}>
                <I.x size={14}/>
              </button>
            </div>
          ))}
          <div className="cell tappable" style={{paddingLeft:20}}
               onClick={() => dispatch({type:'OPEN_SHEET',sheet:'logMeal',data:{mealKey,title}})}>
            <I.plus size={16} stroke="var(--tint)"/>
            <div className="cell-label" style={{fontSize:14,color:'var(--tint)'}}>Add food</div>
          </div>
        </div>
      )}
    </div>
  );
}

function AiParser({ dispatch }) {
  const [text, setText] = uS_e('');
  const [result, setResult] = uS_e(null);

  const parse = () => {
    if (!text.trim()) return;
    const parsed = elosParseMealText(text);
    setResult(parsed);
  };

  const logIt = () => {
    if (!result) return;
    dispatch({type:'ADD_MEAL_ITEM', meal:'snacks', item:{n:result.n, kcal:result.kcal, p:result.p, c:result.c, f:result.f}});
    setText(''); setResult(null);
  };

  return (
    <div className="card" style={{margin:'0 16px'}}>
      <div className="cell">
        <I.mic size={18} stroke="var(--tint)"/>
        <div className="cell-label" style={{fontWeight:600}}>Quick describe</div>
      </div>
      <div style={{padding:'0 16px 14px'}}>
        <div className="food-input-row">
          <input value={text} onChange={e=>setText(e.target.value)}
                 placeholder="e.g. 2 eggs, oatmeal, banana"
                 onKeyDown={e=>e.key==='Enter'&&parse()}
                 autoCorrect="off" enterKeyHint="go"
                 style={{fontSize:16}}/>
          {text && (
            <button className="btn-primary xs" onClick={parse} style={{flexShrink:0}}>
              Parse
            </button>
          )}
        </div>
        {result && (
          <div style={{marginTop:10,padding:'10px 12px',background:'var(--bg-input)',borderRadius:10}}>
            <div style={{fontWeight:500,marginBottom:4}}>{result.n}</div>
            <div style={{display:'flex',justifyContent:'space-between',alignItems:'center'}}>
              <span className="small muted mono">{result.kcal} kcal · P{result.p} C{result.c} F{result.f}</span>
              <button className="btn-primary xs" style={{marginLeft:10}} onClick={logIt}>Log it</button>
            </div>
          </div>
        )}
      </div>
    </div>
  );
}

function QuickLog({ state, dispatch }) {
  const savedMeals = state.savedMeals || [];
  return (
    <div className="card" style={{margin:'0 16px'}}>
      <div className="cell">
        <I.note size={18} stroke="var(--tint)"/>
        <div className="cell-label" style={{fontWeight:600}}>Saved meals</div>
      </div>
      {savedMeals.length === 0 && (
        <div style={{padding:'12px 16px',color:'var(--ink-4)',fontSize:14}}>
          No saved meals yet. Tap a meal item below × Save as quick meal to start.
        </div>
      )}
      {savedMeals.map((m) => (
        <div key={m.id} className="cell tappable"
             onClick={() => {
               (m.items || []).forEach(item =>
                 dispatch({type:'ADD_MEAL_ITEM', meal:'snacks', item})
               );
             }}>
          <div className="cell-label" style={{fontSize:15}}>{m.l}</div>
          <div className="cell-detail mono">{m.cal} kcal</div>
          <div className="cell-chevron"><I.plus size={16} stroke="var(--tint)"/></div>
          <button className="icon-btn muted" style={{width:28,height:28,flexShrink:0}}
                  onClick={e => { e.stopPropagation(); dispatch({type:'DELETE_SAVED_MEAL', id:m.id}); }}>
            <I.x size={14}/>
          </button>
        </div>
      ))}
    </div>
  );
}

function Eat({ state, dispatch }) {
  return (
    <div className="screen-area enter">
      <div className="nav-bar">
        <div className="nav-title">NUTRITION</div>
        <div className="nav-right">
          <button className="icon-btn muted"
                  onClick={() => dispatch({type:'OPEN_SHEET', sheet:'scanBarcode', data:{mealKey:'snacks', title:'Snack'}})}>
            <I.barcode size={20}/>
          </button>
          <button className="icon-btn" onClick={() => dispatch({type:'OPEN_SHEET',sheet:'logMeal',data:{mealKey:'snacks',title:'Snack'}})}>
            <I.plus size={20}/>
          </button>
        </div>
      </div>

      <CalHeader meals={state.meals} calGoal={state.calGoal} nutritionGoals={state.nutritionGoals} dispatch={dispatch}/>

      <div style={{padding:'0 16px'}}>
        {[
          ['breakfast','Breakfast'],
          ['lunch','Lunch'],
          ['dinner','Dinner'],
          ['snacks','Snacks'],
        ].map(([k,l]) => <MealSection key={k} title={l} mealKey={k} items={state.meals[k]} dispatch={dispatch}/>)}
      </div>

      <div className="section-header" style={{padding:'4px 20px 10px'}}>Quick & AI log</div>
      <QuickLog state={state} dispatch={dispatch}/>
      <div style={{height:14}}/>
      <AiParser dispatch={dispatch}/>
      <div style={{height:32}}/>
    </div>
  );
}

export { Eat };
