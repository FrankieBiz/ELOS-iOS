// activeMuscles: string[] — muscle keys to highlight
// intensity: Record<string, 0-1> — optional per-muscle opacity
function MuscleBody({ activeMuscles = [], intensity = {}, onMuscleClick }) {
  const active = new Set(activeMuscles.map(m => m.toLowerCase()));

  function muscleFill(key) {
    if (!active.has(key)) return 'var(--text-3)';
    const alpha = intensity[key] != null ? 0.4 + intensity[key] * 0.6 : 1;
    return `rgba(168, 255, 62, ${alpha})`;
  }

  function mp(key, d) {
    return (
      <path
        key={key}
        d={d}
        fill={muscleFill(key)}
        onClick={() => onMuscleClick && onMuscleClick(key)}
        style={{ cursor: onMuscleClick ? 'pointer' : 'default', transition: 'fill 0.2s' }}
      />
    );
  }

  return (
    <div className="muscle-body-wrap">
      {/* Anterior (front) */}
      <div className="muscle-figure">
        <svg viewBox="0 0 100 220" xmlns="http://www.w3.org/2000/svg">
          {/* Head */}
          <ellipse cx="50" cy="14" rx="11" ry="13" fill="var(--text-3)" opacity="0.4" />
          {/* Neck */}
          <rect x="45" y="26" width="10" height="7" rx="2" fill="var(--text-3)" opacity="0.3" />
          {/* Chest */}
          {mp('chest', 'M30,34 Q35,50 50,52 Q65,50 70,34 Q60,32 50,33 Q40,32 30,34Z')}
          {/* Shoulders */}
          {mp('shoulders', 'M24,34 Q18,38 17,46 Q22,50 27,46 Q29,40 30,34Z')}
          {mp('shoulders', 'M76,34 Q82,38 83,46 Q78,50 73,46 Q71,40 70,34Z')}
          {/* Abs */}
          {mp('abs', 'M38,52 L38,82 Q44,85 50,85 Q56,85 62,82 L62,52 Q56,55 50,55 Q44,55 38,52Z')}
          {/* Obliques */}
          {mp('abs', 'M30,56 L38,56 L38,78 L29,74Z')}
          {mp('abs', 'M70,56 L62,56 L62,78 L71,74Z')}
          {/* Biceps */}
          {mp('biceps', 'M17,47 Q12,54 13,64 Q18,66 22,62 Q24,54 27,47Z')}
          {mp('biceps', 'M83,47 Q88,54 87,64 Q82,66 78,62 Q76,54 73,47Z')}
          {/* Forearms */}
          {mp('forearms', 'M13,65 Q10,76 11,88 L18,88 Q20,76 22,63Z')}
          {mp('forearms', 'M87,65 Q90,76 89,88 L82,88 Q80,76 78,63Z')}
          {/* Quads */}
          {mp('quads', 'M33,88 Q26,110 28,132 Q34,136 40,132 Q43,110 42,88Z')}
          {mp('quads', 'M67,88 Q74,110 72,132 Q66,136 60,132 Q57,110 58,88Z')}
          {mp('quads', 'M42,88 L58,88 Q57,112 50,118 Q43,112 42,88Z')}
          {/* Calves */}
          {mp('calves', 'M29,136 Q26,154 28,172 L38,172 Q38,154 38,136Z')}
          {mp('calves', 'M71,136 Q74,154 72,172 L62,172 Q62,154 62,136Z')}
          {/* Feet */}
          <ellipse cx="33" cy="175" rx="9" ry="4" fill="var(--text-3)" opacity="0.3" />
          <ellipse cx="67" cy="175" rx="9" ry="4" fill="var(--text-3)" opacity="0.3" />
        </svg>
      </div>
      {/* Posterior (back) */}
      <div className="muscle-figure">
        <svg viewBox="0 0 100 220" xmlns="http://www.w3.org/2000/svg">
          {/* Head back */}
          <ellipse cx="50" cy="14" rx="11" ry="13" fill="var(--text-3)" opacity="0.4" />
          {/* Neck */}
          <rect x="45" y="26" width="10" height="7" rx="2" fill="var(--text-3)" opacity="0.3" />
          {/* Traps */}
          {mp('traps', 'M30,30 Q40,35 50,33 Q60,35 70,30 Q60,26 50,26 Q40,26 30,30Z')}
          {/* Rear Delts */}
          {mp('shoulders', 'M22,35 Q17,40 17,48 Q23,52 28,47 Q29,40 30,34Z')}
          {mp('shoulders', 'M78,35 Q83,40 83,48 Q77,52 72,47 Q71,40 70,34Z')}
          {/* Lats */}
          {mp('lats', 'M28,46 Q22,60 26,76 Q32,80 38,75 Q40,60 38,48Z')}
          {mp('lats', 'M72,46 Q78,60 74,76 Q68,80 62,75 Q60,60 62,48Z')}
          {/* Lower Back */}
          {mp('lats', 'M38,52 L62,52 L62,80 Q56,84 50,84 Q44,84 38,80Z')}
          {/* Triceps */}
          {mp('triceps', 'M17,48 Q11,56 12,66 L19,65 Q22,56 23,48Z')}
          {mp('triceps', 'M83,48 Q89,56 88,66 L81,65 Q78,56 77,48Z')}
          {/* Forearms back */}
          {mp('forearms', 'M12,67 Q9,78 10,88 L18,88 Q19,78 19,66Z')}
          {mp('forearms', 'M88,67 Q91,78 90,88 L82,88 Q81,78 81,66Z')}
          {/* Glutes */}
          {mp('glutes', 'M33,84 Q28,98 32,110 Q40,114 50,113 Q60,114 68,110 Q72,98 67,84 Q60,86 50,86 Q40,86 33,84Z')}
          {/* Hamstrings */}
          {mp('hamstrings', 'M32,112 Q28,130 30,148 Q36,152 40,148 Q42,132 40,112Z')}
          {mp('hamstrings', 'M68,112 Q72,130 70,148 Q64,152 60,148 Q58,132 60,112Z')}
          {mp('hamstrings', 'M40,112 Q44,132 50,136 Q56,132 60,112Z')}
          {/* Calves back */}
          {mp('calves', 'M30,150 Q28,162 29,172 L39,172 Q40,162 40,150Z')}
          {mp('calves', 'M70,150 Q72,162 71,172 L61,172 Q60,162 60,150Z')}
          {/* Feet */}
          <ellipse cx="34" cy="175" rx="9" ry="4" fill="var(--text-3)" opacity="0.3" />
          <ellipse cx="66" cy="175" rx="9" ry="4" fill="var(--text-3)" opacity="0.3" />
        </svg>
      </div>
    </div>
  );
}
