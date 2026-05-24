function TrainScreen({ state, dispatch }) {
  const { useState } = React;
  const { workoutLibrary, workoutHistory } = state;
  const [subTab, setSubTab] = useState('library'); // 'library' | 'history' | 'muscles'
  const [muscleFilter, setMuscleFilter] = useState(null);

  const filtered = muscleFilter
    ? workoutLibrary.filter(w => w.muscleGroups.includes(muscleFilter))
    : workoutLibrary;

  // Aggregate muscle intensity from history
  const muscleCount = {};
  workoutHistory.forEach(session => {
    const workout = workoutLibrary.find(w => w.id === session.workoutId);
    if (workout) workout.muscleGroups.forEach(m => { muscleCount[m] = (muscleCount[m] || 0) + 1; });
  });
  const maxCount = Math.max(...Object.values(muscleCount), 1);
  const intensity = Object.fromEntries(Object.entries(muscleCount).map(([k, v]) => [k, v / maxCount]));
  const activeMuscles = Object.keys(muscleCount);

  function formatDate(dateStr) {
    const d = new Date(dateStr + 'T12:00:00');
    return d.toLocaleDateString('en-US', { month: 'short', day: 'numeric' });
  }

  return (
    <div>
      {/* Sub-tab bar */}
      <div style={{ display: 'flex', borderBottom: '0.5px solid var(--sep)', paddingTop: 4 }}>
        {[['library', 'Library'], ['history', 'History'], ['muscles', 'Muscles']].map(([id, label]) => (
          <button
            key={id}
            onClick={() => setSubTab(id)}
            style={{
              flex: 1,
              padding: '12px 0',
              fontSize: 13,
              fontWeight: 700,
              color: subTab === id ? 'var(--text)' : 'var(--text-2)',
              borderBottom: subTab === id ? '2px solid var(--tint)' : '2px solid transparent',
              transition: 'all 0.15s',
              letterSpacing: 0.5,
            }}
          >
            {label}
          </button>
        ))}
      </div>

      {/* Library */}
      {subTab === 'library' && (
        <div style={{ paddingBottom: 8 }}>
          <div className="section-title">Workout Programs</div>
          <div style={{ display: 'flex', flexDirection: 'column', gap: 10, padding: '0 16px' }}>
            {filtered.map(workout => (
              <div key={workout.id} style={{ background: 'var(--bg-card)', borderRadius: 12, overflow: 'hidden' }}>
                <div style={{ display: 'flex' }}>
                  <div style={{ width: 3, background: 'var(--tint)', flexShrink: 0 }} />
                  <div style={{ padding: '14px 16px 14px 14px', flex: 1 }}>
                    <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: 6 }}>
                      <span style={{ fontSize: 17, fontWeight: 800, color: 'var(--text)' }}>{workout.name}</span>
                      <span style={{ fontSize: 11, color: 'var(--text-2)', fontFamily: 'Geist Mono, monospace' }}>
                        {workout.exercises.length} ex
                      </span>
                    </div>
                    <div style={{ display: 'flex', gap: 6, marginBottom: 12, flexWrap: 'wrap' }}>
                      {workout.muscleGroups.map(m => (
                        <span key={m} className="chip" style={{ color: 'var(--tint)', background: 'rgba(168,255,62,0.1)' }}>
                          {m}
                        </span>
                      ))}
                    </div>
                    <div style={{ display: 'flex', flexDirection: 'column', gap: 3, marginBottom: 14 }}>
                      {workout.exercises.map((ex, i) => (
                        <div key={i} style={{ display: 'flex', justifyContent: 'space-between', fontSize: 13 }}>
                          <span style={{ color: 'var(--text)' }}>{ex.name}</span>
                          <span style={{ color: 'var(--text-2)', fontFamily: 'Geist Mono, monospace', fontSize: 12 }}>
                            {ex.sets}×{ex.reps}
                          </span>
                        </div>
                      ))}
                    </div>
                    <button
                      className="btn-primary"
                      style={{ padding: '11px 16px' }}
                      onClick={() => dispatch({ type: AT.SESSION_START, workoutId: workout.id })}
                    >
                      Start
                    </button>
                  </div>
                </div>
              </div>
            ))}
          </div>
          <div style={{ height: 16 }} />
        </div>
      )}

      {/* History */}
      {subTab === 'history' && (
        <div>
          <div className="section-title">Recent Sessions</div>
          <div style={{ margin: '0 16px', background: 'var(--bg-card)', borderRadius: 12, overflow: 'hidden' }}>
            {workoutHistory.length === 0 ? (
              <div style={{ padding: 32, textAlign: 'center', color: 'var(--text-2)', fontSize: 14 }}>
                No sessions yet. Start your first workout!
              </div>
            ) : workoutHistory.map((session, i) => (
              <div key={session.id}>
                <div style={{ display: 'flex', alignItems: 'center', padding: '14px 16px', gap: 14 }}>
                  <div style={{
                    width: 38, height: 38,
                    borderRadius: 10,
                    background: 'rgba(168,255,62,0.1)',
                    display: 'flex', alignItems: 'center', justifyContent: 'center',
                    fontSize: 18,
                  }}>💪</div>
                  <div style={{ flex: 1 }}>
                    <div style={{ fontSize: 15, fontWeight: 700, color: 'var(--text)', marginBottom: 2 }}>{session.name}</div>
                    <div style={{ fontSize: 12, color: 'var(--text-2)' }}>
                      {formatDate(session.date)} · {session.durationMin}m
                    </div>
                  </div>
                  <div style={{ textAlign: 'right' }}>
                    <div style={{ fontSize: 14, fontWeight: 700, fontFamily: 'Geist Mono, monospace', color: 'var(--text)' }}>
                      {(session.totalVolumeKg / 1000).toFixed(1)}t
                    </div>
                    <div style={{ fontSize: 10, color: 'var(--text-2)', letterSpacing: 1, textTransform: 'uppercase' }}>volume</div>
                  </div>
                </div>
                {i < workoutHistory.length - 1 && <div className="sep-indent" />}
              </div>
            ))}
          </div>
          <div style={{ height: 16 }} />
        </div>
      )}

      {/* Muscles */}
      {subTab === 'muscles' && (
        <div style={{ paddingBottom: 16 }}>
          <div className="section-title">Muscle Heatmap</div>
          <div style={{ padding: '0 16px 16px', textAlign: 'center' }}>
            <div style={{ fontSize: 12, color: 'var(--text-2)', marginBottom: 16 }}>
              Based on your last {workoutHistory.length} sessions. Tap a muscle to filter workouts.
            </div>
            <MuscleBody
              activeMuscles={activeMuscles}
              intensity={intensity}
              onMuscleClick={(m) => setMuscleFilter(muscleFilter === m ? null : m)}
            />
            {muscleFilter && (
              <div style={{ marginTop: 12 }}>
                <span
                  style={{
                    display: 'inline-flex', alignItems: 'center', gap: 6,
                    background: 'rgba(168,255,62,0.15)',
                    color: 'var(--tint)',
                    borderRadius: 20, padding: '6px 14px', fontSize: 13, fontWeight: 700,
                  }}
                >
                  {muscleFilter}
                  <button onClick={() => setMuscleFilter(null)} style={{ color: 'var(--tint)', fontSize: 14 }}>✕</button>
                </span>
              </div>
            )}
          </div>

          {muscleFilter && (
            <>
              <div className="section-title">Filtered Workouts</div>
              <div style={{ display: 'flex', flexDirection: 'column', gap: 8, padding: '0 16px' }}>
                {filtered.map(w => (
                  <div key={w.id} style={{ background: 'var(--bg-card)', borderRadius: 10, padding: '14px 16px' }}>
                    <div style={{ fontSize: 15, fontWeight: 700, color: 'var(--text)', marginBottom: 4 }}>{w.name}</div>
                    <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                      <span style={{ fontSize: 12, color: 'var(--text-2)' }}>{w.exercises.length} exercises</span>
                      <button className="btn-tint" style={{ padding: '7px 14px', fontSize: 12 }}
                        onClick={() => dispatch({ type: AT.SESSION_START, workoutId: w.id })}>
                        Start
                      </button>
                    </div>
                  </div>
                ))}
              </div>
            </>
          )}
        </div>
      )}
    </div>
  );
}
