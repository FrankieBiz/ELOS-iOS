function MeScreen({ state, dispatch }) {
  const { profile, sleepLog, bodyMetrics, theme } = state;

  function sleepHours(entry) {
    const [bh, bm] = entry.bedTime.split(':').map(Number);
    const [wh, wm] = entry.wakeTime.split(':').map(Number);
    let hours = (wh + wm / 60) - (bh + bm / 60);
    if (hours < 0) hours += 24;
    return parseFloat(hours.toFixed(1));
  }

  const avgSleep = sleepLog.length
    ? (sleepLog.reduce((a, s) => a + sleepHours(s), 0) / sleepLog.length).toFixed(1)
    : '—';

  const latest = bodyMetrics[bodyMetrics.length - 1];
  const weekMetrics = bodyMetrics.slice(-7);
  const weightRange = weekMetrics.length > 0
    ? { min: Math.min(...weekMetrics.map(m => m.weightKg)), max: Math.max(...weekMetrics.map(m => m.weightKg)) }
    : { min: 0, max: 100 };

  const svgW = 320, svgH = 70;
  const padX = 12, padY = 8;
  function toX(i) { return padX + (i / (weekMetrics.length - 1 || 1)) * (svgW - padX * 2); }
  function toY(v) { return svgH - padY - ((v - weightRange.min) / (weightRange.max - weightRange.min || 1)) * (svgH - padY * 2); }

  const polyline = weekMetrics.map((m, i) => `${toX(i)},${toY(m.weightKg)}`).join(' ');

  return (
    <div style={{ paddingBottom: 8 }}>
      {/* Profile Card */}
      <div style={{ padding: '20px 16px 0' }}>
        <div style={{
          background: 'var(--bg-card)',
          borderRadius: 16,
          padding: '20px 20px',
          display: 'flex',
          alignItems: 'center',
          gap: 16,
        }}>
          <div style={{
            width: 60, height: 60,
            borderRadius: '50%',
            background: 'var(--tint)',
            display: 'flex', alignItems: 'center', justifyContent: 'center',
            fontSize: 26, fontWeight: 900, color: '#000',
          }}>
            {profile.avatar}
          </div>
          <div style={{ flex: 1 }}>
            <div style={{ fontSize: 22, fontWeight: 900, color: 'var(--text)' }}>{profile.name}</div>
            <div style={{ display: 'flex', gap: 16, marginTop: 6 }}>
              <div>
                <span style={{ fontSize: 16, fontWeight: 800, fontFamily: 'Geist Mono, monospace', color: 'var(--text)' }}>{profile.weightKg}</span>
                <span style={{ fontSize: 11, color: 'var(--text-2)', marginLeft: 2 }}>kg</span>
              </div>
              <div>
                <span style={{ fontSize: 16, fontWeight: 800, fontFamily: 'Geist Mono, monospace', color: 'var(--text)' }}>{profile.heightCm}</span>
                <span style={{ fontSize: 11, color: 'var(--text-2)', marginLeft: 2 }}>cm</span>
              </div>
            </div>
          </div>
          <button
            onClick={() => dispatch({ type: AT.THEME_TOGGLE })}
            style={{
              width: 40, height: 40,
              borderRadius: '50%',
              background: 'var(--bg-input)',
              display: 'flex', alignItems: 'center', justifyContent: 'center',
              fontSize: 18,
            }}
          >
            {theme === 'dark' ? '☀️' : '🌙'}
          </button>
        </div>
      </div>

      {/* Body Weight Chart */}
      <div className="section-title" style={{ marginTop: 16 }}>Body Weight (7d)</div>
      <div style={{ margin: '0 16px', background: 'var(--bg-card)', borderRadius: 12, padding: '16px' }}>
        <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: 12 }}>
          <div>
            <span style={{ fontSize: 24, fontWeight: 900, fontFamily: 'Geist Mono, monospace', color: 'var(--text)' }}>
              {latest ? latest.weightKg : '—'}
            </span>
            <span style={{ fontSize: 13, color: 'var(--text-2)', marginLeft: 4 }}>kg</span>
          </div>
          <div style={{ textAlign: 'right' }}>
            <div style={{ fontSize: 11, color: 'var(--text-2)', letterSpacing: 1, textTransform: 'uppercase' }}>7d range</div>
            <div style={{ fontSize: 13, fontFamily: 'Geist Mono, monospace', color: 'var(--text)' }}>
              {weightRange.min.toFixed(1)} – {weightRange.max.toFixed(1)}
            </div>
          </div>
        </div>
        {weekMetrics.length > 1 && (
          <svg width="100%" viewBox={`0 0 ${svgW} ${svgH}`} style={{ overflow: 'visible' }}>
            <polyline
              points={polyline}
              fill="none"
              stroke="var(--tint)"
              strokeWidth="2"
              strokeLinejoin="round"
              strokeLinecap="round"
            />
            {weekMetrics.map((m, i) => (
              <circle key={i} cx={toX(i)} cy={toY(m.weightKg)} r="3" fill="var(--tint)" />
            ))}
          </svg>
        )}
      </div>

      {/* Sleep */}
      <div className="section-title" style={{ marginTop: 16 }}>Sleep (7d)</div>
      <div style={{ margin: '0 16px', background: 'var(--bg-card)', borderRadius: 12, overflow: 'hidden' }}>
        <div style={{ padding: '16px', borderBottom: '0.5px solid var(--sep)' }}>
          <div style={{ display: 'flex', gap: 20 }}>
            <div>
              <div style={{ fontSize: 26, fontWeight: 900, fontFamily: 'Geist Mono, monospace', color: 'var(--text)' }}>{avgSleep}h</div>
              <div style={{ fontSize: 10, color: 'var(--text-2)', letterSpacing: 1, textTransform: 'uppercase' }}>Avg Sleep</div>
            </div>
            <div style={{ flex: 1, display: 'flex', alignItems: 'flex-end', gap: 4 }}>
              {sleepLog.slice(-7).map((s, i) => {
                const h = sleepHours(s);
                const pct = Math.min(h / 10, 1);
                return (
                  <div key={i} style={{ flex: 1, display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 4 }}>
                    <div style={{
                      height: `${pct * 48}px`,
                      background: h >= 7 ? 'var(--m-sleep)' : h >= 6 ? 'var(--warning)' : 'var(--danger)',
                      borderRadius: 3,
                      minHeight: 4,
                      width: '100%',
                    }} />
                    <div style={{ fontSize: 8, color: 'var(--text-3)' }}>
                      {new Date(s.date + 'T12:00:00').toLocaleDateString('en-US', { weekday: 'narrow' })}
                    </div>
                  </div>
                );
              })}
            </div>
          </div>
        </div>
        {sleepLog.slice(0, 4).map((s, i) => (
          <div key={s.date}>
            <div style={{ display: 'flex', alignItems: 'center', padding: '12px 16px', gap: 12 }}>
              <div style={{ fontSize: 13, color: 'var(--text-2)', width: 60, flexShrink: 0 }}>
                {new Date(s.date + 'T12:00:00').toLocaleDateString('en-US', { month: 'short', day: 'numeric' })}
              </div>
              <div style={{ flex: 1, display: 'flex', gap: 8, fontSize: 12 }}>
                <span style={{ color: 'var(--text-2)' }}>🌙 {s.bedTime}</span>
                <span style={{ color: 'var(--text-3)' }}>→</span>
                <span style={{ color: 'var(--text-2)' }}>☀️ {s.wakeTime}</span>
              </div>
              <div style={{ fontSize: 14, fontWeight: 800, fontFamily: 'Geist Mono, monospace', color: 'var(--m-sleep)' }}>
                {sleepHours(s)}h
              </div>
            </div>
            {i < 3 && <div className="sep-indent" />}
          </div>
        ))}
      </div>

      {/* Quick actions */}
      <div style={{ padding: '16px 16px 0', display: 'flex', gap: 10 }}>
        <button
          className="btn-secondary"
          style={{ flex: 1 }}
          onClick={() => dispatch({ type: AT.SHEET_OPEN, sheet: 'logSleep' })}
        >
          Log Sleep
        </button>
      </div>

      <div style={{ height: 24 }} />
    </div>
  );
}
