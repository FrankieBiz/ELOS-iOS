function EatScreen({ state, dispatch }) {
  const { mealLog, dailyMacroTarget } = state;

  const totals = mealLog.reduce(
    (acc, m) => ({ kcal: acc.kcal + m.kcal, protein: acc.protein + m.protein, carbs: acc.carbs + m.carbs, fat: acc.fat + m.fat }),
    { kcal: 0, protein: 0, carbs: 0, fat: 0 }
  );

  const macros = [
    { key: 'kcal',    label: 'Calories', unit: 'kcal', color: 'var(--m-eat)',   tgt: dailyMacroTarget.kcal    },
    { key: 'protein', label: 'Protein',  unit: 'g',    color: 'var(--tint)',    tgt: dailyMacroTarget.protein },
    { key: 'carbs',   label: 'Carbs',    unit: 'g',    color: 'var(--m-plan)',  tgt: dailyMacroTarget.carbs   },
    { key: 'fat',     label: 'Fat',      unit: 'g',    color: 'var(--m-sleep)', tgt: dailyMacroTarget.fat     },
  ];

  return (
    <div style={{ paddingBottom: 8 }}>
      {/* Macro Rings */}
      <div style={{ padding: '20px 16px 0' }}>
        <div style={{ display: 'flex', justifyContent: 'space-around', alignItems: 'center' }}>
          {/* Main kcal ring */}
          <RingChart size={100} strokeWidth={10} progress={totals.kcal / dailyMacroTarget.kcal} color="var(--m-eat)">
            <div style={{ textAlign: 'center' }}>
              <div style={{ fontSize: 20, fontWeight: 900, fontFamily: 'Geist Mono, monospace', color: 'var(--text)' }}>
                {totals.kcal}
              </div>
              <div style={{ fontSize: 9, fontWeight: 600, letterSpacing: 1, textTransform: 'uppercase', color: 'var(--text-2)' }}>
                kcal
              </div>
            </div>
          </RingChart>
          {/* Macro sub-rings */}
          <div style={{ display: 'flex', flexDirection: 'column', gap: 14 }}>
            {macros.slice(1).map(m => (
              <div key={m.key} style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
                <RingChart size={44} strokeWidth={5} progress={totals[m.key] / m.tgt} color={m.color}>
                  <span style={{ fontSize: 9, fontWeight: 700, fontFamily: 'Geist Mono, monospace', color: 'var(--text)' }}>
                    {totals[m.key]}
                  </span>
                </RingChart>
                <div>
                  <div style={{ fontSize: 11, fontWeight: 700, color: 'var(--text)' }}>{totals[m.key]}{m.unit}</div>
                  <div style={{ fontSize: 10, color: 'var(--text-2)' }}>of {m.tgt}{m.unit}</div>
                </div>
              </div>
            ))}
          </div>
        </div>

        {/* Remaining */}
        <div style={{ display: 'flex', gap: 8, marginTop: 16 }}>
          {macros.map(m => {
            const rem = m.tgt - totals[m.key];
            return (
              <div key={m.key} style={{ flex: 1, textAlign: 'center', background: 'var(--bg-card)', borderRadius: 8, padding: '10px 4px' }}>
                <div style={{ fontSize: 14, fontWeight: 800, fontFamily: 'Geist Mono, monospace', color: rem < 0 ? 'var(--danger)' : 'var(--text)' }}>
                  {Math.abs(rem)}
                </div>
                <div style={{ fontSize: 9, letterSpacing: 1, textTransform: 'uppercase', color: 'var(--text-2)', marginTop: 2 }}>
                  {rem < 0 ? 'over' : 'left'}
                </div>
                <div style={{ fontSize: 9, color: 'var(--text-3)' }}>{m.label}</div>
              </div>
            );
          })}
        </div>
      </div>

      {/* Add Meal CTA */}
      <div style={{ padding: '16px 16px 0' }}>
        <button
          className="btn-primary"
          onClick={() => dispatch({ type: AT.SHEET_OPEN, sheet: 'logMeal' })}
        >
          + Log Meal
        </button>
      </div>

      {/* Meal Log */}
      <div className="section-title" style={{ marginTop: 16 }}>Today's Meals</div>
      {mealLog.length === 0 ? (
        <div style={{ padding: '32px 20px', textAlign: 'center', color: 'var(--text-2)', fontSize: 14 }}>
          No meals logged yet. Tap "Log Meal" to get started.
        </div>
      ) : (
        <div style={{ margin: '0 16px', background: 'var(--bg-card)', borderRadius: 12, overflow: 'hidden' }}>
          {mealLog.map((meal, i) => (
            <div key={meal.id}>
              <div style={{ display: 'flex', alignItems: 'center', padding: '13px 16px', gap: 12 }}>
                <div style={{ flex: 1 }}>
                  <div style={{ fontSize: 15, fontWeight: 700, color: 'var(--text)', marginBottom: 3 }}>{meal.name}</div>
                  <div style={{ display: 'flex', gap: 10, fontSize: 12 }}>
                    <span style={{ color: 'var(--m-eat)', fontFamily: 'Geist Mono, monospace', fontWeight: 700 }}>{meal.kcal} kcal</span>
                    <span style={{ color: 'var(--text-2)' }}>P:{meal.protein}g</span>
                    <span style={{ color: 'var(--text-2)' }}>C:{meal.carbs}g</span>
                    <span style={{ color: 'var(--text-2)' }}>F:{meal.fat}g</span>
                  </div>
                </div>
                <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
                  <span style={{ fontSize: 11, color: 'var(--text-3)', fontFamily: 'Geist Mono, monospace' }}>{meal.time}</span>
                  <button
                    onClick={() => dispatch({ type: AT.MEAL_DELETE, id: meal.id })}
                    style={{ color: 'var(--text-3)', fontSize: 16, padding: 4 }}
                  >✕</button>
                </div>
              </div>
              {i < mealLog.length - 1 && <div className="sep-indent" />}
            </div>
          ))}
        </div>
      )}
      <div style={{ height: 16 }} />
    </div>
  );
}
