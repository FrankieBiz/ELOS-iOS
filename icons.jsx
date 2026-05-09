import React from 'react'
const Ic = ({ d, size=20, fill='none', stroke='currentColor', sw=1.7, children, style }) => (
  <svg width={size} height={size} viewBox="0 0 24 24" fill={fill} stroke={stroke}
       strokeWidth={sw} strokeLinecap="round" strokeLinejoin="round" style={style} aria-hidden>
    {d ? <path d={d}/> : children}
  </svg>
);
const I = {
  home:    p=><Ic {...p}><rect x="3" y="3" width="7" height="9" rx="1.5"/><rect x="14" y="3" width="7" height="5" rx="1.5"/><rect x="14" y="12" width="7" height="9" rx="1.5"/><rect x="3" y="16" width="7" height="5" rx="1.5"/></Ic>,
  dumbbell:p=><Ic {...p}><path d="M6.5 6.5v11M17.5 6.5v11M3 9v6M21 9v6M7 12h10"/></Ic>,
  fork:    p=><Ic {...p}><path d="M4 3v8a2 2 0 0 0 2 2h0v8M6 3v6M10 3v6M18 3c-1.5 0-3 1.5-3 4s1.5 4 3 4v9"/></Ic>,
  calendar:p=><Ic {...p}><rect x="3" y="5" width="18" height="16" rx="2"/><path d="M3 10h18M8 3v4M16 3v4"/></Ic>,
  person:  p=><Ic {...p}><circle cx="12" cy="8" r="4"/><path d="M5 20a7 7 0 0 1 14 0"/></Ic>,
  check:   p=><Ic {...p}><path d="M5 12l5 5L20 7"/></Ic>,
  plus:    p=><Ic {...p}><path d="M12 5v14M5 12h14"/></Ic>,
  chevronR:p=><Ic {...p}><path d="m9 6 6 6-6 6"/></Ic>,
  chevronL:p=><Ic {...p}><path d="m15 6-6 6 6 6"/></Ic>,
  chevronD:p=><Ic {...p}><path d="m6 9 6 6 6-6"/></Ic>,
  chevronU:p=><Ic {...p}><path d="m6 15 6-6 6 6"/></Ic>,
  x:       p=><Ic {...p}><path d="M6 6l12 12M18 6L6 18"/></Ic>,
  sun:     p=><Ic {...p}><circle cx="12" cy="12" r="4"/><path d="M12 2v2M12 20v2M4.93 4.93l1.41 1.41M17.66 17.66l1.41 1.41M2 12h2M20 12h2M4.93 19.07l1.41-1.41M17.66 6.34l1.41-1.41"/></Ic>,
  moon:    p=><Ic {...p}><path d="M21 12.8A8 8 0 0 1 11.2 3a8 8 0 1 0 9.8 9.8z"/></Ic>,
  play:    p=><Ic fill="currentColor" stroke="none" {...p}><path d="M7 4v16l13-8z"/></Ic>,
  pause:   p=><Ic fill="currentColor" stroke="none" {...p}><rect x="6" y="4" width="4" height="16" rx="1"/><rect x="14" y="4" width="4" height="16" rx="1"/></Ic>,
  stop:    p=><Ic fill="currentColor" stroke="none" {...p}><rect x="5" y="5" width="14" height="14" rx="2"/></Ic>,
  flame:   p=><Ic {...p}><path d="M12 3s-6 7-6 11a6 6 0 0 0 12 0c0-4-6-11-6-11z" fill="currentColor" stroke="none"/></Ic>,
  drop:    p=><Ic {...p}><path d="M12 3s-6 7-6 11a6 6 0 0 0 12 0c0-4-6-11-6-11z"/></Ic>,
  moon2:   p=><Ic {...p}><path d="M3 12h4l2-3 4 6 2-3h6"/></Ic>,
  clock:   p=><Ic {...p}><circle cx="12" cy="12" r="9"/><path d="M12 7v5l3 2"/></Ic>,
  book:    p=><Ic {...p}><path d="M4 4.5A1.5 1.5 0 0 1 5.5 3H19v15H5.5A1.5 1.5 0 0 0 4 19.5v-15zM4 19.5A1.5 1.5 0 0 0 5.5 21H19"/></Ic>,
  warn:    p=><Ic {...p}><path d="M12 3 2 20h20L12 3zM12 10v5M12 18h.01"/></Ic>,
  gear:    p=><Ic {...p}><circle cx="12" cy="12" r="3"/><path d="M19 12c0-.4 0-.8-.1-1.2l2-1.5-2-3.4-2.3 1a7 7 0 0 0-2-1.2l-.4-2.5h-4l-.4 2.5a7 7 0 0 0-2 1.2l-2.3-1-2 3.4 2 1.5C5 10.8 5 11.4 5 12s0 1.2.1 1.6l-2 1.5 2 3.4 2.3-1a7 7 0 0 0 2 1.2l.4 2.5h4l.4-2.5a7 7 0 0 0 2-1.2l2.3 1 2-3.4-2-1.5c.1-.4.1-.8.1-1.2z"/></Ic>,
  barcode: p=><Ic {...p}><path d="M3 7V5a2 2 0 0 1 2-2h2M17 3h2a2 2 0 0 1 2 2v2M21 17v2a2 2 0 0 1-2 2h-2M7 21H5a2 2 0 0 1-2-2v-2"/><rect x="7" y="7" width="3" height="10" rx="1"/><rect x="14" y="7" width="3" height="10" rx="1"/></Ic>,
  mic:     p=><Ic {...p}><rect x="9" y="2" width="6" height="11" rx="3"/><path d="M5 10a7 7 0 0 0 14 0M12 19v3M9 22h6"/></Ic>,
  trending:p=><Ic {...p}><path d="m3 17 6-6 4 4 8-8M15 7h6v6"/></Ic>,
  trash:   p=><Ic {...p}><path d="M3 6h18M8 6V4h8v2M19 6l-1 14a2 2 0 0 1-2 2H8a2 2 0 0 1-2-2L5 6"/></Ic>,
  note:    p=><Ic {...p}><path d="M14 3v4a1 1 0 0 0 1 1h4"/><path d="M17 21H7a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h7l5 5v11a2 2 0 0 1-2 2z"/></Ic>,
  arrow:   p=><Ic {...p}><path d="m12 19-7-7 7-7M5 12h14"/></Ic>,
  info:    p=><Ic {...p}><circle cx="12" cy="12" r="9"/><path d="M12 8v4M12 16h.01"/></Ic>,
  weight:  p=><Ic {...p}><circle cx="12" cy="5" r="2"/><path d="M3 10h18l-2 9H5l-2-9z"/><path d="M9 10V7a3 3 0 0 1 6 0v3"/></Ic>,
  swap:    p=><Ic {...p}><path d="M7 16V4m0 0L3 8m4-4 4 4M17 8v12m0 0 4-4m-4 4-4-4"/></Ic>,
};
export { I };
