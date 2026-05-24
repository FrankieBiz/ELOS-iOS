function PlanScreen({ state, dispatch }) {
  const { useState } = React;
  const { assignments, exams } = state;
  const [subTab, setSubTab] = useState('assignments');

  const today = new Date();
  function daysUntil(dateStr) {
    const d = new Date(dateStr + 'T12:00:00');
    return Math.round((d - today) / 86_400_000);
  }
  function formatDate(dateStr) {
    const d = new Date(dateStr + 'T12:00:00');
    return d.toLocaleDateString('en-US', { month: 'short', day: 'numeric' });
  }

  const pending = assignments.filter(a => !a.done);
  const done = assignments.filter(a => a.done);

  return (
    <div>
      {/* Sub-tabs */}
      <div style={{ display: 'flex', borderBottom: '0.5px solid var(--sep)', paddingTop: 4 }}>
        {[['assignments', 'Assignments'], ['exams', 'Exams']].map(([id, label]) => (
          <button
            key={id}
            onClick={() => setSubTab(id)}
            style={{
              flex: 1,
              padding: '12px 0',
              fontSize: 13,
              fontWeight: 700,
              color: subTab === id ? 'var(--text)' : 'var(--text-2)',
              borderBottom: subTab === id ? '2px solid var(--m-plan)' : '2px solid transparent',
              transition: 'all 0.15s',
            }}
          >
            {label}
          </button>
        ))}
      </div>

      {/* Assignments */}
      {subTab === 'assignments' && (
        <div style={{ paddingBottom: 16 }}>
          {/* Summary strip */}
          <div className="stat-strip">
            <div className="stat-cell">
              <span className="stat-value mono" style={{ color: 'var(--m-plan)' }}>{pending.length}</span>
              <span className="stat-label">Pending</span>
            </div>
            <div className="stat-cell">
              <span className="stat-value mono">{done.length}</span>
              <span className="stat-label">Done</span>
            </div>
            <div className="stat-cell">
              <span className="stat-value mono">
                {pending.filter(a => daysUntil(a.dueDate) <= 2).length}
              </span>
              <span className="stat-label">Due Soon</span>
            </div>
          </div>

          <div className="section-title">Pending</div>
          {pending.length === 0 ? (
            <div style={{ padding: '20px 20px', textAlign: 'center', color: 'var(--text-2)', fontSize: 14 }}>
              All caught up! 🎉
            </div>
          ) : (
            <div style={{ margin: '0 16px', background: 'var(--bg-card)', borderRadius: 12, overflow: 'hidden' }}>
              {pending.map((a, i) => {
                const days = daysUntil(a.dueDate);
                const urgent = days <= 1;
                const soon = days <= 3;
                return (
                  <div key={a.id}>
                    <div
                      style={{ display: 'flex', alignItems: 'center', padding: '13px 16px', gap: 12 }}
                      onClick={() => dispatch({ type: AT.ASSIGNMENT_TOGGLE, id: a.id })}
                    >
                      <div style={{
                        width: 22, height: 22,
                        borderRadius: 6,
                        border: `2px solid ${urgent ? 'var(--danger)' : soon ? 'var(--warning)' : 'var(--text-3)'}`,
                        flexShrink: 0,
                        display: 'flex', alignItems: 'center', justifyContent: 'center',
                      }} />
                      <div style={{ flex: 1 }}>
                        <div style={{ fontSize: 14, fontWeight: 700, color: 'var(--text)', marginBottom: 2 }}>{a.title}</div>
                        <div style={{ fontSize: 12, color: 'var(--text-2)' }}>{a.course}</div>
                      </div>
                      <div style={{ textAlign: 'right', flexShrink: 0 }}>
                        <div style={{ fontSize: 12, fontWeight: 700, fontFamily: 'Geist Mono, monospace', color: urgent ? 'var(--danger)' : soon ? 'var(--warning)' : 'var(--text-2)' }}>
                          {days === 0 ? 'Today' : days < 0 ? `${Math.abs(days)}d late` : `${days}d`}
                        </div>
                        <div style={{ fontSize: 10, color: 'var(--text-3)' }}>{formatDate(a.dueDate)}</div>
                      </div>
                    </div>
                    {i < pending.length - 1 && <div className="sep-indent" />}
                  </div>
                );
              })}
            </div>
          )}

          {done.length > 0 && (
            <>
              <div className="section-title">Completed</div>
              <div style={{ margin: '0 16px', background: 'var(--bg-card)', borderRadius: 12, overflow: 'hidden' }}>
                {done.map((a, i) => (
                  <div key={a.id}>
                    <div
                      style={{ display: 'flex', alignItems: 'center', padding: '13px 16px', gap: 12, opacity: 0.5 }}
                      onClick={() => dispatch({ type: AT.ASSIGNMENT_TOGGLE, id: a.id })}
                    >
                      <div style={{
                        width: 22, height: 22, borderRadius: 6,
                        background: 'var(--m-habits)',
                        display: 'flex', alignItems: 'center', justifyContent: 'center',
                        flexShrink: 0,
                      }}>
                        <span style={{ fontSize: 13, color: '#000', fontWeight: 900 }}>✓</span>
                      </div>
                      <div style={{ flex: 1 }}>
                        <div style={{ fontSize: 14, fontWeight: 600, color: 'var(--text)', textDecoration: 'line-through' }}>{a.title}</div>
                        <div style={{ fontSize: 12, color: 'var(--text-2)' }}>{a.course}</div>
                      </div>
                    </div>
                    {i < done.length - 1 && <div className="sep-indent" />}
                  </div>
                ))}
              </div>
            </>
          )}
        </div>
      )}

      {/* Exams */}
      {subTab === 'exams' && (
        <div style={{ paddingBottom: 16 }}>
          <div className="section-title">Upcoming Exams</div>
          <div style={{ margin: '0 16px', display: 'flex', flexDirection: 'column', gap: 10 }}>
            {exams.map(exam => {
              const days = daysUntil(exam.date);
              const urgent = days <= 5;
              return (
                <div key={exam.id} style={{ background: 'var(--bg-card)', borderRadius: 12, overflow: 'hidden', display: 'flex' }}>
                  <div style={{ width: 4, background: urgent ? 'var(--danger)' : 'var(--m-plan)', flexShrink: 0 }} />
                  <div style={{ padding: '16px', flex: 1 }}>
                    <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: 4 }}>
                      <div>
                        <div style={{ fontSize: 16, fontWeight: 800, color: 'var(--text)' }}>{exam.title}</div>
                        <div style={{ fontSize: 13, color: 'var(--text-2)', marginTop: 2 }}>{exam.course}</div>
                      </div>
                      <div style={{ textAlign: 'right' }}>
                        <div style={{ fontSize: 24, fontWeight: 900, fontFamily: 'Geist Mono, monospace', color: urgent ? 'var(--danger)' : 'var(--m-plan)' }}>
                          {Math.abs(days)}
                        </div>
                        <div style={{ fontSize: 10, color: 'var(--text-2)', letterSpacing: 1 }}>
                          {days < 0 ? 'DAYS AGO' : 'DAYS LEFT'}
                        </div>
                      </div>
                    </div>
                    <div style={{ marginTop: 10 }}>
                      <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: 4 }}>
                        <span style={{ fontSize: 11, color: 'var(--text-2)', letterSpacing: 1, textTransform: 'uppercase' }}>Prep Progress</span>
                        <span style={{ fontSize: 11, color: 'var(--text-2)', fontFamily: 'Geist Mono, monospace' }}>0%</span>
                      </div>
                      <div className="progress-bar">
                        <div className="progress-fill" style={{ width: '0%', background: urgent ? 'var(--danger)' : 'var(--m-plan)' }} />
                      </div>
                    </div>
                    <div style={{ fontSize: 12, color: 'var(--text-3)', marginTop: 8 }}>{formatDate(exam.date)}</div>
                  </div>
                </div>
              );
            })}
          </div>
        </div>
      )}
    </div>
  );
}
