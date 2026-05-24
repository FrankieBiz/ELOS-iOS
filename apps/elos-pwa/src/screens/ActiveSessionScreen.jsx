function ActiveSessionScreen({ session, dispatch }) {
  const { useState, useEffect, useRef } = React;
  const [elapsed, setElapsed] = useState(0);
  const [restRemaining, setRestRemaining] = useState(null);

  // Elapsed timer
  useEffect(() => {
    const id = setInterval(() => {
      setElapsed(Math.floor((Date.now() - session.startedAt) / 1000));
    }, 1000);
    return () => clearInterval(id);
  }, [session.startedAt]);

  // Rest timer
  useEffect(() => {
    if (!session.restEndsAt) { setRestRemaining(null); return; }
    const tick = () => {
      const rem = Math.max(0, Math.ceil((session.restEndsAt - Date.now()) / 1000));
      setRestRemaining(rem);
      if (rem === 0) dispatch({ type: AT.SESSION_REST_SKIP });
    };
    tick();
    const id = setInterval(tick, 250);
    return () => clearInterval(id);
  }, [session.restEndsAt]);

  function fmtTime(s) {
    const m = Math.floor(s / 60);
    const sec = s % 60;
    return `${String(m).padStart(2, '0')}:${String(sec).padStart(2, '0')}`;
  }

  const totalSets = session.exercises.reduce((a, ex) => a + ex.sets.length, 0);
  const doneSets = session.exercises.reduce((a, ex) => a + ex.sets.filter(s => s.done).length, 0);

  return (
    <div className="session-layer">
      {/* Header */}
      <div style={{
        padding: '16px 20px 12px',
        borderBottom: '0.5px solid var(--sep)',
        display: 'flex',
        alignItems: 'center',
        gap: 12,
        background: 'var(--bg)',
        flexShrink: 0,
      }}>
        <div style={{ flex: 1 }}>
          <div style={{ fontSize: 11, fontWeight: 700, letterSpacing: 2, textTransform: 'uppercase', color: 'var(--text-2)' }}>
            WORKOUT
          </div>
          <div style={{ fontSize: 18, fontWeight: 900, color: 'var(--text)' }}>{session.name}</div>
        </div>
        <div style={{ textAlign: 'center' }}>
          <div style={{ fontSize: 20, fontWeight: 800, fontFamily: 'Geist Mono, monospace', color: 'var(--tint)' }}>
            {fmtTime(elapsed)}
          </div>
          <div style={{ fontSize: 9, letterSpacing: 1, textTransform: 'uppercase', color: 'var(--text-2)' }}>elapsed</div>
        </div>
        <button
          onClick={() => dispatch({ type: AT.SESSION_FINISH })}
          style={{
            background: 'var(--text)',
            color: 'var(--bg)',
            borderRadius: 20,
            padding: '9px 18px',
            fontSize: 14,
            fontWeight: 800,
          }}
        >
          Finish
        </button>
      </div>

      {/* Progress strip */}
      <div style={{ padding: '0 20px', flexShrink: 0 }}>
        <div style={{ display: 'flex', justifyContent: 'space-between', padding: '10px 0 6px' }}>
          <span style={{ fontSize: 11, color: 'var(--text-2)', letterSpacing: 1, textTransform: 'uppercase' }}>
            Sets: {doneSets}/{totalSets}
          </span>
          <span style={{ fontSize: 11, color: 'var(--text-2)', fontFamily: 'Geist Mono, monospace' }}>
            {Math.round(doneSets / totalSets * 100)}%
          </span>
        </div>
        <div className="progress-bar">
          <div
            className="progress-fill"
            style={{
              width: `${totalSets > 0 ? doneSets / totalSets * 100 : 0}%`,
              background: 'var(--tint)',
            }}
          />
        </div>
      </div>

      {/* Exercise list */}
      <div style={{ flex: 1, overflowY: 'auto', WebkitOverflowScrolling: 'touch', padding: '8px 0 24px' }}>
        {session.exercises.map((ex, exIdx) => (
          <div key={exIdx} style={{ marginBottom: 16 }}>
            {/* Exercise header */}
            <div style={{ padding: '10px 20px 8px' }}>
              <div style={{ fontSize: 16, fontWeight: 800, color: 'var(--text)' }}>{ex.name}</div>
            </div>

            {/* Column header */}
            <div style={{
              display: 'flex',
              alignItems: 'center',
              padding: '0 20px 6px',
              gap: 8,
            }}>
              <div style={{ width: 28, fontSize: 9, fontWeight: 700, letterSpacing: 1, textTransform: 'uppercase', color: 'var(--text-3)', textAlign: 'center' }}>SET</div>
              <div style={{ flex: 1.2, fontSize: 9, fontWeight: 700, letterSpacing: 1, textTransform: 'uppercase', color: 'var(--text-3)', textAlign: 'center' }}>KG</div>
              <div style={{ flex: 1, fontSize: 9, fontWeight: 700, letterSpacing: 1, textTransform: 'uppercase', color: 'var(--text-3)', textAlign: 'center' }}>REPS</div>
              <div style={{ flex: 0.8, fontSize: 9, fontWeight: 700, letterSpacing: 1, textTransform: 'uppercase', color: 'var(--text-3)', textAlign: 'center' }}>RPE</div>
              <div style={{ width: 36 }} />
            </div>

            {/* Sets */}
            {ex.sets.map((set, setIdx) => (
              <SetRow
                key={set.id}
                set={set}
                setIdx={setIdx}
                exIdx={exIdx}
                dispatch={dispatch}
              />
            ))}

            {/* Add set */}
            <button
              onClick={() => dispatch({ type: AT.SESSION_ADD_SET, exIdx })}
              style={{
                display: 'block',
                width: 'calc(100% - 40px)',
                margin: '8px 20px 0',
                padding: '10px',
                background: 'var(--bg-input)',
                borderRadius: 8,
                fontSize: 13,
                fontWeight: 700,
                color: 'var(--text-2)',
                letterSpacing: 0.5,
              }}
            >
              + Add Set
            </button>

            <div className="sep" style={{ marginTop: 16 }} />
          </div>
        ))}

        {/* Discard */}
        <div style={{ padding: '0 20px' }}>
          <button
            className="btn-ghost"
            style={{ width: '100%', color: 'var(--danger)', fontSize: 14, padding: '12px 0', fontWeight: 600 }}
            onClick={() => dispatch({ type: AT.SESSION_FINISH })}
          >
            Discard Workout
          </button>
        </div>
      </div>

      {/* Rest Timer Overlay */}
      {restRemaining !== null && restRemaining > 0 && (
        <div className="rest-overlay">
          <div style={{ fontSize: 11, fontWeight: 700, letterSpacing: 2, textTransform: 'uppercase', color: 'var(--text-2)' }}>
            REST
          </div>
          <div style={{ fontSize: 72, fontWeight: 900, fontFamily: 'Geist Mono, monospace', color: 'var(--text)', lineHeight: 1 }}>
            {fmtTime(restRemaining)}
          </div>
          <div style={{ width: 200 }}>
            <div className="progress-bar" style={{ height: 3 }}>
              <div
                className="progress-fill"
                style={{
                  width: `${100 - (restRemaining / 120) * 100}%`,
                  background: 'var(--tint)',
                }}
              />
            </div>
          </div>
          <button
            className="btn-ghost"
            onClick={() => dispatch({ type: AT.SESSION_REST_SKIP })}
            style={{ fontSize: 15, color: 'var(--text-2)', fontWeight: 600 }}
          >
            Skip Rest
          </button>
        </div>
      )}
    </div>
  );
}

function SetRow({ set, setIdx, exIdx, dispatch }) {
  function update(field, value) {
    dispatch({ type: AT.SESSION_SET_UPDATE, exIdx, setIdx, field, value });
  }

  return (
    <div style={{
      display: 'flex',
      alignItems: 'center',
      padding: '6px 20px',
      gap: 8,
      background: set.done ? 'rgba(168,255,62,0.04)' : 'transparent',
      transition: 'background 0.2s',
    }}>
      <div style={{
        width: 28, textAlign: 'center',
        fontSize: 13, fontWeight: 700, fontFamily: 'Geist Mono, monospace',
        color: set.done ? 'var(--text-3)' : 'var(--text-2)',
      }}>
        {setIdx + 1}
      </div>

      <input
        className="input-mono"
        style={{ flex: 1.2, color: set.done ? 'var(--text-3)' : 'var(--text)' }}
        type="number"
        inputMode="decimal"
        placeholder="0"
        value={set.weight}
        onChange={e => update('weight', e.target.value)}
      />

      <input
        className="input-mono"
        style={{ flex: 1, color: set.done ? 'var(--text-3)' : 'var(--text)' }}
        type="number"
        inputMode="numeric"
        placeholder="0"
        value={set.reps}
        onChange={e => update('reps', e.target.value)}
      />

      <input
        className="input-mono"
        style={{ flex: 0.8, color: set.done ? 'var(--text-3)' : 'var(--text)' }}
        type="number"
        inputMode="numeric"
        min="1"
        max="10"
        placeholder="—"
        value={set.rpe}
        onChange={e => update('rpe', e.target.value)}
      />

      <button
        style={{
          width: 36, height: 36,
          borderRadius: '50%',
          background: set.done ? 'var(--tint)' : 'var(--bg-input)',
          display: 'flex', alignItems: 'center', justifyContent: 'center',
          fontSize: 16,
          flexShrink: 0,
          transition: 'all 0.15s',
        }}
        onClick={() => dispatch({ type: AT.SESSION_SET_COMPLETE, exIdx, setIdx })}
      >
        {set.done ? <span style={{ color: '#000', fontWeight: 900 }}>✓</span> : <span style={{ color: 'var(--text-3)' }}>○</span>}
      </button>
    </div>
  );
}
