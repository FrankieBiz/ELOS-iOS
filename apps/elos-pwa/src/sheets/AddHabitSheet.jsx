function AddHabitSheet({ dispatch }) {
  const { useState } = React;
  const [name, setName] = useState('');
  const [icon, setIcon] = useState('⭐');
  const [targetDays, setTargetDays] = useState(7);

  const icons = ['⭐', '💪', '🏃', '📚', '🧘', '🚿', '✍️', '🎯', '🥗', '💤', '🎵', '🧠', '🌿', '🏋️', '🚴', '🧗', '🏊', '🎸'];

  function confirm() {
    if (!name.trim()) return;
    dispatch({ type: AT.HABIT_ADD, habit: { name: name.trim(), icon, targetDays } });
  }

  return (
    <div>
      <div style={{ fontSize: 17, fontWeight: 800, color: 'var(--text)', marginBottom: 20 }}>New Habit</div>

      {/* Icon picker */}
      <div style={{ marginBottom: 20 }}>
        <div style={{ fontSize: 10, fontWeight: 600, letterSpacing: 1, textTransform: 'uppercase', color: 'var(--text-2)', marginBottom: 10 }}>
          Icon
        </div>
        <div style={{ display: 'flex', flexWrap: 'wrap', gap: 8 }}>
          {icons.map(ic => (
            <button
              key={ic}
              onClick={() => setIcon(ic)}
              style={{
                width: 42, height: 42,
                borderRadius: 10,
                background: icon === ic ? 'var(--tint)' : 'var(--bg-input)',
                fontSize: 20,
                transition: 'all 0.15s',
                border: 'none',
              }}
            >
              {ic}
            </button>
          ))}
        </div>
      </div>

      {/* Name */}
      <div style={{ marginBottom: 20 }}>
        <div style={{ fontSize: 10, fontWeight: 600, letterSpacing: 1, textTransform: 'uppercase', color: 'var(--text-2)', marginBottom: 8 }}>
          Habit Name
        </div>
        <input
          className="input-field"
          placeholder="e.g. Morning Run"
          value={name}
          onChange={e => setName(e.target.value)}
          style={{ fontSize: 17, fontWeight: 700 }}
        />
      </div>

      {/* Target days */}
      <div style={{ marginBottom: 28 }}>
        <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: 10 }}>
          <div style={{ fontSize: 10, fontWeight: 600, letterSpacing: 1, textTransform: 'uppercase', color: 'var(--text-2)' }}>
            Target Days / Week
          </div>
          <div style={{ fontSize: 14, fontWeight: 800, fontFamily: 'Geist Mono, monospace', color: 'var(--tint)' }}>
            {targetDays}×
          </div>
        </div>
        <div style={{ display: 'flex', gap: 6 }}>
          {[1, 2, 3, 4, 5, 6, 7].map(d => (
            <button
              key={d}
              onClick={() => setTargetDays(d)}
              style={{
                flex: 1,
                padding: '10px 0',
                borderRadius: 7,
                background: targetDays >= d ? 'var(--tint)' : 'var(--bg-input)',
                color: targetDays >= d ? '#000' : 'var(--text-2)',
                fontSize: 13,
                fontWeight: 800,
                transition: 'all 0.15s',
              }}
            >
              {d}
            </button>
          ))}
        </div>
      </div>

      <button
        className="btn-primary"
        onClick={confirm}
        disabled={!name.trim()}
        style={{ opacity: name.trim() ? 1 : 0.4 }}
      >
        {icon} Add Habit
      </button>
    </div>
  );
}
