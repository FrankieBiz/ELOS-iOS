function TabBar({ activeTab, dispatch }) {
  const tabs = [
    { id: 'today', label: 'Today',  icon: TodayIcon },
    { id: 'train', label: 'Train',  icon: TrainIcon },
    { id: 'eat',   label: 'Eat',    icon: EatIcon   },
    { id: 'plan',  label: 'Plan',   icon: PlanIcon  },
    { id: 'me',    label: 'Me',     icon: MeIcon    },
  ];

  return (
    <div className="tab-bar">
      {tabs.map(t => (
        <button
          key={t.id}
          className={`tab-item${activeTab === t.id ? ' active' : ''}`}
          onClick={() => dispatch({ type: AT.TAB_CHANGE, tab: t.id })}
        >
          <t.icon active={activeTab === t.id} />
          <span className="tab-label">{t.label}</span>
        </button>
      ))}
    </div>
  );
}

function TodayIcon({ active }) {
  return (
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={active ? 2.5 : 1.8} strokeLinecap="round">
      <rect x="3" y="4" width="18" height="18" rx="3" />
      <line x1="3" y1="9" x2="21" y2="9" />
      <line x1="8" y1="2" x2="8" y2="6" />
      <line x1="16" y1="2" x2="16" y2="6" />
      {active && <rect x="7" y="13" width="3" height="3" rx="0.5" fill="currentColor" stroke="none" />}
    </svg>
  );
}

function TrainIcon({ active }) {
  return (
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={active ? 2.5 : 1.8} strokeLinecap="round">
      <line x1="6" y1="12" x2="18" y2="12" />
      <circle cx="3.5" cy="12" r="1.5" />
      <circle cx="20.5" cy="12" r="1.5" />
      <line x1="8" y1="8" x2="8" y2="16" strokeWidth={active ? 3 : 2.5} />
      <line x1="16" y1="8" x2="16" y2="16" strokeWidth={active ? 3 : 2.5} />
    </svg>
  );
}

function EatIcon({ active }) {
  return (
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={active ? 2.5 : 1.8} strokeLinecap="round">
      <path d="M12 2C8.13 2 5 5.13 5 9c0 2.38 1.19 4.47 3 5.74V17a2 2 0 002 2h4a2 2 0 002-2v-2.26C17.81 13.47 19 11.38 19 9c0-3.87-3.13-7-7-7z" />
      {active && <line x1="12" y1="9" x2="12" y2="14" />}
    </svg>
  );
}

function PlanIcon({ active }) {
  return (
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={active ? 2.5 : 1.8} strokeLinecap="round">
      <path d="M9 5H7a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2V7a2 2 0 00-2-2h-2" />
      <rect x="9" y="3" width="6" height="4" rx="1" />
      <line x1="9" y1="12" x2="15" y2="12" />
      <line x1="9" y1="16" x2="13" y2="16" />
    </svg>
  );
}

function MeIcon({ active }) {
  return (
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={active ? 2.5 : 1.8} strokeLinecap="round">
      <circle cx="12" cy="8" r="4" />
      <path d="M4 20c0-4 3.58-7 8-7s8 3 8 7" />
    </svg>
  );
}
