function LogSleepSheet({ dispatch }) {
  const { useState } = React;
  const [bedTime, setBedTime] = useState('23:00');
  const [wakeTime, setWakeTime] = useState('07:00');
  const [quality, setQuality] = useState(4);

  function sleepHours() {
    const [bh, bm] = bedTime.split(':').map(Number);
    const [wh, wm] = wakeTime.split(':').map(Number);
    let h = (wh + wm / 60) - (bh + bm / 60);
    if (h < 0) h += 24;
    return parseFloat(h.toFixed(1));
  }

  function confirm() {
    const today = new Date().toISOString().split('T')[0];
    dispatch({ type: AT.SLEEP_LOG, entry: { date: today, bedTime, wakeTime, quality } });
  }

  const hours = sleepHours();
  const qualityLabels = { 1: 'Terrible', 2: 'Poor', 3: 'OK', 4: 'Good', 5: 'Great' };
  const qualityColors = { 1: 'var(--danger)', 2: 'var(--warning)', 3: 'var(--text-2)', 4: 'var(--m-sleep)', 5: 'var(--tint)' };

  return (
    <div>
      <div style={{ fontSize: 17, fontWeight: 800, color: 'var(--text)', marginBottom: 20 }}>Log Sleep</div>

      <div style={{ display: 'flex', gap: 14, marginBottom: 20 }}>
        <div style={{ flex: 1 }}>
          <div style={{ fontSize: 10, fontWeight: 600, letterSpacing: 1, textTransform: 'uppercase', color: 'var(--text-2)', marginBottom: 8 }}>
            🌙 Bed Time
          </div>
          <input
            type="time"
            value={bedTime}
            onChange={e => setBedTime(e.target.value)}
            style={{
              width: '100%',
              background: 'var(--bg-input)',
              color: 'var(--text)',
              borderRadius: 10,
              padding: '14px 14px',
              fontSize: 22,
              fontWeight: 800,
              fontFamily: 'Geist Mono, monospace',
            }}
          />
        </div>
        <div style={{ flex: 1 }}>
          <div style={{ fontSize: 10, fontWeight: 600, letterSpacing: 1, textTransform: 'uppercase', color: 'var(--text-2)', marginBottom: 8 }}>
            ☀️ Wake Time
          </div>
          <input
            type="time"
            value={wakeTime}
            onChange={e => setWakeTime(e.target.value)}
            style={{
              width: '100%',
              background: 'var(--bg-input)',
              color: 'var(--text)',
              borderRadius: 10,
              padding: '14px 14px',
              fontSize: 22,
              fontWeight: 800,
              fontFamily: 'Geist Mono, monospace',
            }}
          />
        </div>
      </div>

      {/* Hours summary */}
      <div style={{
        background: 'var(--bg-input)',
        borderRadius: 10,
        padding: '16px',
        textAlign: 'center',
        marginBottom: 20,
      }}>
        <div style={{ fontSize: 40, fontWeight: 900, fontFamily: 'Geist Mono, monospace', color: hours >= 7 ? 'var(--m-sleep)' : hours >= 6 ? 'var(--warning)' : 'var(--danger)' }}>
          {hours}h
        </div>
        <div style={{ fontSize: 12, color: 'var(--text-2)' }}>
          {hours >= 8 ? 'Excellent sleep' : hours >= 7 ? 'Good sleep' : hours >= 6 ? 'Slightly short' : 'Not enough sleep'}
        </div>
      </div>

      {/* Quality */}
      <div style={{ marginBottom: 24 }}>
        <div style={{ fontSize: 10, fontWeight: 600, letterSpacing: 1, textTransform: 'uppercase', color: 'var(--text-2)', marginBottom: 12 }}>
          Sleep Quality — {qualityLabels[quality]}
        </div>
        <div style={{ display: 'flex', gap: 8 }}>
          {[1, 2, 3, 4, 5].map(q => (
            <button
              key={q}
              onClick={() => setQuality(q)}
              style={{
                flex: 1,
                padding: '12px 0',
                borderRadius: 8,
                background: quality === q ? qualityColors[q] : 'var(--bg-input)',
                color: quality === q ? (q >= 4 ? '#000' : '#fff') : 'var(--text-2)',
                fontSize: 18,
                fontWeight: 900,
                transition: 'all 0.15s',
              }}
            >
              {q}
            </button>
          ))}
        </div>
      </div>

      <button className="btn-primary" onClick={confirm}>
        Save Sleep Entry
      </button>
    </div>
  );
}
