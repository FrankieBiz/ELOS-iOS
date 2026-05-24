function TodayScreen({ state, dispatch }) {
  const { habits, workoutHistory, mealLog, dailyMacroTarget, workoutLibrary } = state;

  const completedHabits = habits.filter(h => h.completedToday).length;
  const habitProgress = habits.length > 0 ? completedHabits / habits.length : 0;

  const todayKcal = mealLog.reduce((a, m) => a + m.kcal, 0);
  const todayProtein = mealLog.reduce((a, m) => a + m.protein, 0);

  const lastWorkout = workoutHistory[0];
  const nextWorkout = workoutLibrary[0];

  const hour = new Date().getHours();
  const greeting = hour < 12 ? 'Good Morning' : hour < 17 ? 'Good Afternoon' : 'Good Evening';

  const today = new Date().toLocaleDateString('en-US', { weekday: 'long', month: 'long', day: 'numeric' });

  return (
    <div style={{ paddingBottom: 8 }}>
      {/* Header */}
      <div style={{ padding: '24px 20px 8px' }}>
        <div className="label" style={{ marginBottom: 4 }}>{today}</div>
        <div style={{ fontSize: 34, fontWeight: 900, color: 'var(--text)', lineHeight: 1.1 }}>
          {greeting},<br />{state.profile.name}.
        </div>
      </div>

      {/* Stats Strip */}
      <div className="stat-strip" style={{ marginTop: 20 }}>
        <div className="stat-cell">
          <span className="stat-value mono">{lastWorkout ? `${lastWorkout.durationMin}m` : '—'}</span>
          <span className="stat-label">Last Session</span>
        </div>
        <div className="stat-cell">
          <span className="stat-value mono">{todayKcal}</span>
          <span className="stat-label">Calories</span>
        </div>
        <div className="stat-cell">
          <span className="stat-value mono">{completedHabits}/{habits.length}</span>
          <span className="stat-label">Habits</span>
        </div>
      </div>

      {/* Habits */}
      <div className="section-title">Habits</div>
      <div style={{ padding: '0 16px' }}>
        <div style={{ display: 'flex', gap: 12, marginBottom: 4 }}>
          <RingChart size={72} strokeWidth={7} progress={habitProgress} color="var(--m-habits)">
            <span style={{ fontSize: 16, fontWeight: 800, color: 'var(--text)' }}>{completedHabits}</span>
          </RingChart>
          <div style={{ flex: 1, display: 'flex', flexWrap: 'wrap', gap: 8, alignContent: 'center' }}>
            {habits.map(h => (
              <button
                key={h.id}
                onClick={() => dispatch({ type: AT.HABIT_TOGGLE, id: h.id })}
                style={{
                  display: 'flex',
                  alignItems: 'center',
                  gap: 6,
                  padding: '6px 12px',
                  borderRadius: 20,
                  background: h.completedToday ? 'var(--m-habits)' : 'var(--bg-input)',
                  color: h.completedToday ? '#000' : 'var(--text-2)',
                  fontSize: 12,
                  fontWeight: 700,
                  transition: 'all 0.2s',
                }}
              >
                <span>{h.icon}</span>
                <span>{h.name}</span>
                {h.streakDays > 0 && (
                  <span style={{ fontSize: 10, opacity: 0.7 }}>{h.streakDays}🔥</span>
                )}
              </button>
            ))}
          </div>
        </div>
      </div>

      {/* Nutrition Summary */}
      <div className="section-title" style={{ marginTop: 8 }}>Nutrition Today</div>
      <div style={{ padding: '0 16px', display: 'flex', gap: 10 }}>
        {[
          { label: 'Kcal',    val: todayKcal,                        tgt: dailyMacroTarget.kcal,    color: 'var(--m-eat)' },
          { label: 'Protein', val: todayProtein,                     tgt: dailyMacroTarget.protein, color: 'var(--tint)'  },
          { label: 'Carbs',   val: mealLog.reduce((a,m)=>a+m.carbs,0), tgt: dailyMacroTarget.carbs,   color: 'var(--m-plan)' },
          { label: 'Fat',     val: mealLog.reduce((a,m)=>a+m.fat,0),   tgt: dailyMacroTarget.fat,     color: 'var(--m-sleep)' },
        ].map(m => (
          <div key={m.label} style={{ flex: 1, textAlign: 'center' }}>
            <RingChart size={52} strokeWidth={5} progress={m.val / m.tgt} color={m.color}>
              <span style={{ fontSize: 9, fontWeight: 700, fontFamily: 'Geist Mono, monospace', color: 'var(--text)' }}>
                {m.val}
              </span>
            </RingChart>
            <div style={{ fontSize: 9, fontWeight: 600, letterSpacing: 1, textTransform: 'uppercase', color: 'var(--text-2)', marginTop: 4 }}>
              {m.label}
            </div>
          </div>
        ))}
      </div>

      {/* Next Workout */}
      {nextWorkout && (
        <>
          <div className="section-title" style={{ marginTop: 8 }}>Next Workout</div>
          <div style={{ margin: '0 16px' }}>
            <div style={{
              background: 'var(--bg-card)',
              borderRadius: 12,
              overflow: 'hidden',
              display: 'flex',
            }}>
              <div style={{ width: 3, background: 'var(--tint)', flexShrink: 0 }} />
              <div style={{ padding: '16px 16px 16px 14px', flex: 1 }}>
                <div style={{ fontSize: 17, fontWeight: 800, color: 'var(--text)', marginBottom: 6 }}>{nextWorkout.name}</div>
                <div style={{ fontSize: 12, color: 'var(--text-2)', marginBottom: 12 }}>
                  {nextWorkout.exercises.length} exercises · {nextWorkout.exercises.reduce((a, e) => a + e.sets, 0)} sets
                </div>
                <div style={{ display: 'flex', flexDirection: 'column', gap: 4, marginBottom: 14 }}>
                  {nextWorkout.exercises.slice(0, 3).map((ex, i) => (
                    <div key={i} style={{ fontSize: 13, color: 'var(--text)', display: 'flex', justifyContent: 'space-between' }}>
                      <span>{ex.name}</span>
                      <span style={{ color: 'var(--text-2)', fontFamily: 'Geist Mono, monospace', fontSize: 12 }}>
                        {ex.sets}×{ex.reps} @{ex.rpe}
                      </span>
                    </div>
                  ))}
                  {nextWorkout.exercises.length > 3 && (
                    <div style={{ fontSize: 12, color: 'var(--text-3)' }}>
                      +{nextWorkout.exercises.length - 3} more
                    </div>
                  )}
                </div>
                <button
                  className="btn-primary"
                  onClick={() => dispatch({ type: AT.SESSION_START, workoutId: nextWorkout.id })}
                >
                  Start Workout
                </button>
              </div>
            </div>
          </div>
        </>
      )}

      {/* Quick Actions */}
      <div className="section-title" style={{ marginTop: 16 }}>Quick Add</div>
      <div style={{ padding: '0 16px', display: 'flex', gap: 10 }}>
        {[
          { label: '+ Meal',   sheet: 'logMeal',  color: 'var(--m-eat)'   },
          { label: '+ Sleep',  sheet: 'logSleep', color: 'var(--m-sleep)' },
          { label: '+ Habit',  sheet: 'addHabit', color: 'var(--m-habits)'},
        ].map(a => (
          <button
            key={a.sheet}
            onClick={() => dispatch({ type: AT.SHEET_OPEN, sheet: a.sheet })}
            style={{
              flex: 1,
              background: 'var(--bg-card)',
              border: `1px solid ${a.color}30`,
              borderRadius: 10,
              padding: '12px 0',
              fontSize: 13,
              fontWeight: 700,
              color: a.color,
            }}
          >
            {a.label}
          </button>
        ))}
      </div>

      <div style={{ height: 24 }} />
    </div>
  );
}
