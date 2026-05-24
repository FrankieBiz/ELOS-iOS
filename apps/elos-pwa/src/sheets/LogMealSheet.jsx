function LogMealSheet({ dispatch }) {
  const { useState } = React;
  const [text, setText] = useState('');
  const [parsed, setParsed] = useState(null);
  const [parsing, setParsing] = useState(false);
  const [error, setError] = useState('');

  // Manual fallback state
  const [manual, setManual] = useState({ name: '', kcal: '', protein: '', carbs: '', fat: '' });
  const [mode, setMode] = useState('ai'); // 'ai' | 'manual'

  async function parse() {
    if (!text.trim()) return;
    setParsing(true);
    setError('');
    try {
      if (typeof window.claude === 'undefined' || !window.claude.complete) {
        throw new Error('no_claude');
      }
      const prompt = `Parse this meal description into macros. Reply ONLY with valid JSON, no markdown, no explanation:
"${text}"

JSON schema: {"name": string, "kcal": number, "protein": number, "carbs": number, "fat": number}
All numbers are integers. Estimate reasonably. If unsure, estimate conservatively.`;
      const result = await window.claude.complete(prompt);
      const json = JSON.parse(result.trim());
      setParsed(json);
    } catch (e) {
      if (e.message === 'no_claude') {
        setMode('manual');
        setManual(m => ({ ...m, name: text }));
      } else {
        setError('Could not parse. Try the manual form below.');
        setMode('manual');
        setManual(m => ({ ...m, name: text }));
      }
    } finally {
      setParsing(false);
    }
  }

  function confirmAI() {
    const now = new Date();
    const time = `${String(now.getHours()).padStart(2,'0')}:${String(now.getMinutes()).padStart(2,'0')}`;
    dispatch({ type: AT.MEAL_LOG, meal: { ...parsed, time } });
  }

  function confirmManual() {
    const now = new Date();
    const time = `${String(now.getHours()).padStart(2,'0')}:${String(now.getMinutes()).padStart(2,'0')}`;
    dispatch({
      type: AT.MEAL_LOG,
      meal: {
        name: manual.name || 'Meal',
        time,
        kcal: parseInt(manual.kcal) || 0,
        protein: parseInt(manual.protein) || 0,
        carbs: parseInt(manual.carbs) || 0,
        fat: parseInt(manual.fat) || 0,
      },
    });
  }

  function ManualField({ label, field, unit }) {
    return (
      <div style={{ flex: 1 }}>
        <div style={{ fontSize: 10, fontWeight: 600, letterSpacing: 1, textTransform: 'uppercase', color: 'var(--text-2)', marginBottom: 6 }}>
          {label}
        </div>
        <div style={{ display: 'flex', alignItems: 'center', gap: 4, background: 'var(--bg-input)', borderRadius: 8, padding: '10px 10px' }}>
          <input
            type="number"
            inputMode="numeric"
            placeholder="0"
            value={manual[field]}
            onChange={e => setManual(m => ({ ...m, [field]: e.target.value }))}
            style={{ width: '100%', background: 'none', color: 'var(--text)', fontSize: 18, fontWeight: 700, fontFamily: 'Geist Mono, monospace', textAlign: 'center' }}
          />
          {unit && <span style={{ fontSize: 10, color: 'var(--text-3)', flexShrink: 0 }}>{unit}</span>}
        </div>
      </div>
    );
  }

  return (
    <div>
      <div style={{ fontSize: 17, fontWeight: 800, color: 'var(--text)', marginBottom: 16 }}>Log Meal</div>

      {mode === 'ai' && !parsed && (
        <>
          <div style={{ fontSize: 13, color: 'var(--text-2)', marginBottom: 10 }}>
            Describe what you ate — the AI will estimate the macros.
          </div>
          <textarea
            value={text}
            onChange={e => setText(e.target.value)}
            placeholder="e.g. 2 scrambled eggs, oatmeal with banana, black coffee"
            rows={3}
            style={{
              width: '100%',
              background: 'var(--bg-input)',
              color: 'var(--text)',
              borderRadius: 10,
              padding: '12px 14px',
              fontSize: 14,
              resize: 'none',
              lineHeight: 1.5,
            }}
          />
          {error && <div style={{ fontSize: 12, color: 'var(--danger)', marginTop: 8 }}>{error}</div>}
          <div style={{ display: 'flex', gap: 10, marginTop: 14 }}>
            <button className="btn-primary" onClick={parse} disabled={!text.trim() || parsing} style={{ flex: 1 }}>
              {parsing ? 'Parsing…' : '✦ Parse with AI'}
            </button>
            <button className="btn-secondary" onClick={() => setMode('manual')} style={{ flex: 0.6 }}>
              Manual
            </button>
          </div>
        </>
      )}

      {mode === 'ai' && parsed && (
        <div>
          <div style={{ background: 'var(--bg-input)', borderRadius: 12, padding: '16px', marginBottom: 16 }}>
            <div style={{ fontSize: 15, fontWeight: 800, color: 'var(--text)', marginBottom: 12 }}>{parsed.name}</div>
            <div style={{ display: 'flex', gap: 10 }}>
              {[['kcal', 'Kcal', 'var(--m-eat)'], ['protein', 'Protein', 'var(--tint)'], ['carbs', 'Carbs', 'var(--m-plan)'], ['fat', 'Fat', 'var(--m-sleep)']].map(([k, l, c]) => (
                <div key={k} style={{ flex: 1, textAlign: 'center', background: 'var(--bg-card)', borderRadius: 8, padding: '10px 4px' }}>
                  <div style={{ fontSize: 18, fontWeight: 900, fontFamily: 'Geist Mono, monospace', color: c }}>{parsed[k]}</div>
                  <div style={{ fontSize: 9, letterSpacing: 1, textTransform: 'uppercase', color: 'var(--text-2)', marginTop: 2 }}>{l}</div>
                </div>
              ))}
            </div>
          </div>
          <div style={{ display: 'flex', gap: 10 }}>
            <button className="btn-primary" onClick={confirmAI} style={{ flex: 1 }}>Add to Log</button>
            <button className="btn-secondary" onClick={() => setParsed(null)} style={{ flex: 0.5 }}>Edit</button>
          </div>
        </div>
      )}

      {mode === 'manual' && (
        <div>
          <div style={{ marginBottom: 14 }}>
            <div style={{ fontSize: 10, fontWeight: 600, letterSpacing: 1, textTransform: 'uppercase', color: 'var(--text-2)', marginBottom: 6 }}>
              Meal Name
            </div>
            <input
              className="input-field"
              placeholder="Meal name"
              value={manual.name}
              onChange={e => setManual(m => ({ ...m, name: e.target.value }))}
            />
          </div>
          <div style={{ display: 'flex', gap: 8, marginBottom: 16 }}>
            <ManualField label="Kcal" field="kcal" />
            <ManualField label="Protein" field="protein" unit="g" />
            <ManualField label="Carbs" field="carbs" unit="g" />
            <ManualField label="Fat" field="fat" unit="g" />
          </div>
          <div style={{ display: 'flex', gap: 10 }}>
            <button className="btn-primary" onClick={confirmManual} style={{ flex: 1 }}>Add to Log</button>
            <button className="btn-secondary" onClick={() => setMode('ai')} style={{ flex: 0.5 }}>AI Mode</button>
          </div>
        </div>
      )}
    </div>
  );
}
