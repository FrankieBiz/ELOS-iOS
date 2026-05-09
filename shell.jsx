import React from 'react'
import { I } from './icons.jsx'
const { useState: uS, useEffect: uE, useMemo: uM, useCallback: uC } = React;

function StatusBar({ theme, onToggleTheme }) {
  const [time, setTime] = uS(() => new Date().toLocaleTimeString('en-US',{hour:'numeric',minute:'2-digit'}));
  uE(() => {
    const id = setInterval(() => setTime(new Date().toLocaleTimeString('en-US',{hour:'numeric',minute:'2-digit'})), 30000);
    return () => clearInterval(id);
  }, []);
  return (
    <div className="status-bar">
      <span className="mono" style={{fontSize:15,fontWeight:600}}>{time}</span>
      <div className="status-icons">
        <button className="icon-btn muted" style={{width:36,height:36,borderRadius:8}} onClick={onToggleTheme}>
          {theme==='light' ? <I.moon size={16}/> : <I.sun size={16}/>}
        </button>
        {/* signal bars */}
        <svg width="17" height="12" viewBox="0 0 17 12" fill="var(--ink-3)"><rect x="0" y="6" width="3" height="6" rx="1"/><rect x="4.5" y="4" width="3" height="8" rx="1"/><rect x="9" y="2" width="3" height="10" rx="1"/><rect x="13.5" y="0" width="3" height="12" rx="1"/></svg>
        {/* wifi */}
        <svg width="16" height="12" viewBox="0 0 24 18" fill="none" stroke="var(--ink-3)" strokeWidth="2" strokeLinecap="round"><path d="M12 16h.01M4.5 9.5a10.6 10.6 0 0 1 15 0M1 6a15 15 0 0 1 22 0M8 13a5.3 5.3 0 0 1 8 0"/></svg>
        {/* battery */}
        <svg width="25" height="12" viewBox="0 0 25 12"><rect x="0" y="0.5" width="22" height="11" rx="3" fill="none" stroke="var(--ink-3)" strokeWidth="1"/><path d="M23 4v4a2 2 0 0 0 0-4z" fill="var(--ink-3)"/><rect x="2" y="2" width="16" height="8" rx="2" fill="var(--ink)"/></svg>
      </div>
    </div>
  );
}

function NavBar({ title, left, right }) {
  return (
    <div className="nav-bar">
      <div className="nav-left">{left}</div>
      <div className="nav-title">{title}</div>
      <div className="nav-right">{right}</div>
    </div>
  );
}

function Ring({ value, max=100, size=80, stroke=8, color='var(--tint)', children }) {
  const r = (size - stroke) / 2;
  const C = 2 * Math.PI * r;
  const off = C - Math.min(1, value / max) * C;
  return (
    <div className="ring" style={{width:size,height:size}}>
      <svg width={size} height={size}>
        <circle cx={size/2} cy={size/2} r={r} className="r-track" strokeWidth={stroke}/>
        <circle cx={size/2} cy={size/2} r={r} className="r-fill" strokeWidth={stroke}
                strokeDasharray={C} strokeDashoffset={off} style={{stroke:color}}/>
      </svg>
      <div className="r-center">{children}</div>
    </div>
  );
}

function SegCtrl({ tabs, active, onChange }) {
  return (
    <div className="seg-ctrl">
      {tabs.map(t => (
        <button key={t.k} className={`seg-btn${active===t.k?' on':''}`} onClick={() => onChange(t.k)}>
          {t.l}
        </button>
      ))}
    </div>
  );
}

function TabBar({ tab, dispatch }) {
  const tabs = [
    { k:'today', l:'Today', icon: I.home },
    { k:'train', l:'Train', icon: I.dumbbell },
    { k:'eat',   l:'Eat',   icon: I.fork },
    { k:'plan',  l:'Plan',  icon: I.calendar },
    { k:'me',    l:'Me',    icon: I.person },
  ];
  return (
    <div className="tab-bar">
      {tabs.map(t => {
        const Ico = t.icon;
        return (
          <button key={t.k} className={`tab-btn${tab===t.k?' active':''}`}
                  onClick={() => dispatch({type:'SET_TAB',tab:t.k})}>
            <Ico size={22} sw={tab===t.k ? 2.2 : 1.7}/>
            <span>{t.l}</span>
          </button>
        );
      })}
    </div>
  );
}

function BottomSheet({ id, title, children, dispatch, action, actionLabel, actionColor }) {
  return (
    <div className="sheet-backdrop" onClick={e => { if(e.target===e.currentTarget) dispatch({type:'CLOSE_SHEET'}); }}>
      <div className="sheet">
        <div className="sheet-handle"/>
        <div className="sheet-header">
          <button className="nav-btn" onClick={() => dispatch({type:'CLOSE_SHEET'})}>Cancel</button>
          <div className="sheet-title">{title}</div>
          {action
            ? <button className="nav-btn" style={{color: actionColor||'var(--tint)',fontWeight:600}} onClick={action}>{actionLabel||'Done'}</button>
            : <div style={{width:70}}/>
          }
        </div>
        <div className="sheet-body">{children}</div>
      </div>
    </div>
  );
}

function Toast({ toast, dispatch }) {
  uE(() => {
    if (!toast) return;
    const timer = setTimeout(() => dispatch({ type: 'DISMISS_TOAST' }), 2400);
    return () => clearTimeout(timer);
  }, [toast?.id]);

  if (!toast) return null;
  return (
    <div style={{
      position: 'absolute', bottom: 72, left: 0, right: 0,
      display: 'flex', justifyContent: 'center',
      pointerEvents: 'none', zIndex: 999,
    }}>
      <div style={{
        background: 'var(--ink)',
        color: 'var(--bg)',
        padding: '10px 16px',
        borderRadius: 6,
        fontSize: 11,
        fontWeight: 700,
        letterSpacing: '0.1em',
        textTransform: 'uppercase',
        animation: 'toast-in 0.18s ease',
        maxWidth: '85%',
      }}>
        {toast.msg}
      </div>
    </div>
  );
}

export { StatusBar, NavBar, Ring, SegCtrl, TabBar, BottomSheet, Toast };
