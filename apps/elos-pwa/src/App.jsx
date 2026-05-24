function App() {
  const { useReducer, useEffect } = React;
  const [state, dispatch] = useReducer(rootReducer, INITIAL_STATE);

  // Sync theme to DOM
  useEffect(() => {
    document.documentElement.setAttribute('data-theme', state.theme);
  }, [state.theme]);

  const { activeTab, activeSession, openSheet } = state;

  function renderScreen() {
    switch (activeTab) {
      case 'today': return <TodayScreen state={state} dispatch={dispatch} />;
      case 'train': return <TrainScreen state={state} dispatch={dispatch} />;
      case 'eat':   return <EatScreen state={state} dispatch={dispatch} />;
      case 'plan':  return <PlanScreen state={state} dispatch={dispatch} />;
      case 'me':    return <MeScreen state={state} dispatch={dispatch} />;
      default:      return <TodayScreen state={state} dispatch={dispatch} />;
    }
  }

  function renderSheet() {
    if (!openSheet) return null;
    const close = () => dispatch({ type: AT.SHEET_CLOSE });
    let content;
    switch (openSheet) {
      case 'logMeal':  content = <LogMealSheet dispatch={dispatch} />; break;
      case 'logSleep': content = <LogSleepSheet dispatch={dispatch} />; break;
      case 'addHabit': content = <AddHabitSheet dispatch={dispatch} />; break;
      default: return null;
    }
    return <BottomSheet onClose={close}>{content}</BottomSheet>;
  }

  return (
    <div className="phone-frame" data-theme={state.theme}>
      <div className="app-shell">
        {/* Main screen area */}
        <div className="screen-area">
          {renderScreen()}
        </div>

        {/* Tab bar (hidden during active session) */}
        {!activeSession && (
          <TabBar activeTab={activeTab} dispatch={dispatch} />
        )}

        {/* Active session pushed layer */}
        {activeSession && (
          <ActiveSessionScreen session={activeSession} dispatch={dispatch} />
        )}

        {/* Bottom sheets */}
        {renderSheet()}
      </div>
    </div>
  );
}
