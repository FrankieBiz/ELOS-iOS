// ─── Helpers ────────────────────────────────────────────────────────────────
function daysAgo(n) {
  const d = new Date();
  d.setDate(d.getDate() - n);
  return d.toISOString().split('T')[0];
}
function uid() { return Math.random().toString(36).slice(2, 9); }

// ─── Seed Data ───────────────────────────────────────────────────────────────
const INITIAL_STATE = {
  theme: 'dark',
  activeTab: 'today',
  activeSession: null,
  openSheet: null,

  // ── Habits ──────────────────────────────────────────────────────────────
  habits: [
    { id: 'h1', name: 'Morning Run', icon: '🏃', targetDays: 5, completedToday: true,  streakDays: 12 },
    { id: 'h2', name: 'Meditate',    icon: '🧘', targetDays: 7, completedToday: true,  streakDays: 31 },
    { id: 'h3', name: 'Read',        icon: '📚', targetDays: 7, completedToday: false, streakDays: 7  },
    { id: 'h4', name: 'Cold Shower', icon: '🚿', targetDays: 5, completedToday: false, streakDays: 4  },
    { id: 'h5', name: 'Journals',    icon: '✍️', targetDays: 7, completedToday: false, streakDays: 2  },
  ],

  // ── Workout Library ──────────────────────────────────────────────────────
  workoutLibrary: [
    {
      id: 'w1', name: 'Push Day',
      muscleGroups: ['chest', 'shoulders', 'triceps'],
      exercises: [
        { name: 'Bench Press',        sets: 4, reps: '5',   rpe: 8 },
        { name: 'Incline DB Press',   sets: 3, reps: '8',   rpe: 8 },
        { name: 'Overhead Press',     sets: 3, reps: '6',   rpe: 7 },
        { name: 'Lateral Raises',     sets: 4, reps: '12',  rpe: 8 },
        { name: 'Tricep Pushdowns',   sets: 3, reps: '12',  rpe: 7 },
      ],
    },
    {
      id: 'w2', name: 'Pull Day',
      muscleGroups: ['lats', 'biceps', 'traps'],
      exercises: [
        { name: 'Deadlift',           sets: 3, reps: '5',   rpe: 8 },
        { name: 'Pull-ups',           sets: 4, reps: '6',   rpe: 7 },
        { name: 'Barbell Row',        sets: 3, reps: '8',   rpe: 8 },
        { name: 'Face Pulls',         sets: 3, reps: '15',  rpe: 7 },
        { name: 'Hammer Curls',       sets: 3, reps: '10',  rpe: 8 },
      ],
    },
    {
      id: 'w3', name: 'Leg Day',
      muscleGroups: ['quads', 'hamstrings', 'glutes', 'calves'],
      exercises: [
        { name: 'Squat',              sets: 4, reps: '5',   rpe: 8 },
        { name: 'Romanian Deadlift',  sets: 3, reps: '8',   rpe: 7 },
        { name: 'Leg Press',          sets: 3, reps: '12',  rpe: 7 },
        { name: 'Leg Curl',           sets: 3, reps: '12',  rpe: 7 },
        { name: 'Calf Raises',        sets: 4, reps: '15',  rpe: 7 },
      ],
    },
    {
      id: 'w4', name: 'Upper Body',
      muscleGroups: ['chest', 'back', 'shoulders'],
      exercises: [
        { name: 'Bench Press',        sets: 4, reps: '6',   rpe: 8 },
        { name: 'Pull-ups',           sets: 4, reps: '6',   rpe: 8 },
        { name: 'Overhead Press',     sets: 3, reps: '8',   rpe: 7 },
        { name: 'DB Row',             sets: 3, reps: '10',  rpe: 7 },
      ],
    },
  ],

  // ── Workout History ──────────────────────────────────────────────────────
  workoutHistory: [
    {
      id: 'wh1', workoutId: 'w1', name: 'Push Day',
      date: daysAgo(1), durationMin: 62, totalVolumeKg: 5840,
    },
    {
      id: 'wh2', workoutId: 'w2', name: 'Pull Day',
      date: daysAgo(3), durationMin: 55, totalVolumeKg: 6200,
    },
    {
      id: 'wh3', workoutId: 'w3', name: 'Leg Day',
      date: daysAgo(5), durationMin: 70, totalVolumeKg: 8100,
    },
    {
      id: 'wh4', workoutId: 'w1', name: 'Push Day',
      date: daysAgo(8), durationMin: 58, totalVolumeKg: 5600,
    },
    {
      id: 'wh5', workoutId: 'w2', name: 'Pull Day',
      date: daysAgo(10), durationMin: 60, totalVolumeKg: 6050,
    },
  ],

  // ── Nutrition ────────────────────────────────────────────────────────────
  dailyMacroTarget: { kcal: 2800, protein: 200, carbs: 320, fat: 90 },
  mealLog: [
    { id: 'm1', name: 'Overnight Oats + Protein',    time: '07:30', kcal: 520, protein: 42, carbs: 58, fat: 12 },
    { id: 'm2', name: 'Chicken Rice & Veg',          time: '12:30', kcal: 680, protein: 52, carbs: 75, fat: 14 },
    { id: 'm3', name: 'Greek Yogurt + Almonds',      time: '15:00', kcal: 310, protein: 20, carbs: 22, fat: 14 },
  ],

  // ── Plan / School ────────────────────────────────────────────────────────
  assignments: [
    { id: 'a1', title: 'Data Structures Problem Set 3', course: 'CS 201',  dueDate: daysAgo(-2), done: false },
    { id: 'a2', title: 'Linear Algebra HW 5',           course: 'MATH 215', dueDate: daysAgo(-1), done: false },
    { id: 'a3', title: 'Essay Draft — Romanticism',     course: 'ENG 110',  dueDate: daysAgo(-4), done: false },
    { id: 'a4', title: 'Physics Lab Report',            course: 'PHYS 101', dueDate: daysAgo(-6), done: false },
    { id: 'a5', title: 'Research Proposal',             course: 'CS 201',   dueDate: daysAgo(-9), done: true  },
  ],
  exams: [
    { id: 'e1', title: 'Midterm Exam',  course: 'CS 201',  date: daysAgo(-7)  },
    { id: 'e2', title: 'Final Exam',    course: 'MATH 215', date: daysAgo(-21) },
  ],

  // ── Profile ──────────────────────────────────────────────────────────────
  profile: { name: 'Frank', avatar: 'F', weightKg: 82, heightCm: 180 },

  // ── Sleep Log (7 days) ───────────────────────────────────────────────────
  sleepLog: [
    { date: daysAgo(6), bedTime: '23:00', wakeTime: '07:00', quality: 4 },
    { date: daysAgo(5), bedTime: '23:30', wakeTime: '07:15', quality: 3 },
    { date: daysAgo(4), bedTime: '22:45', wakeTime: '06:45', quality: 5 },
    { date: daysAgo(3), bedTime: '00:00', wakeTime: '07:30', quality: 3 },
    { date: daysAgo(2), bedTime: '23:15', wakeTime: '07:00', quality: 4 },
    { date: daysAgo(1), bedTime: '22:30', wakeTime: '06:30', quality: 5 },
    { date: daysAgo(0), bedTime: '23:00', wakeTime: '07:00', quality: 4 },
  ],

  // ── Body Metrics (30 days) ───────────────────────────────────────────────
  bodyMetrics: Array.from({ length: 30 }, (_, i) => ({
    date: daysAgo(29 - i),
    weightKg: parseFloat((82 + Math.sin(i * 0.4) * 0.8 + (Math.random() - 0.5) * 0.4).toFixed(1)),
  })),
};

// ─── Action Types ─────────────────────────────────────────────────────────────
const AT = {
  TAB_CHANGE:           'TAB_CHANGE',
  THEME_TOGGLE:         'THEME_TOGGLE',
  SHEET_OPEN:           'SHEET_OPEN',
  SHEET_CLOSE:          'SHEET_CLOSE',
  HABIT_TOGGLE:         'HABIT_TOGGLE',
  HABIT_ADD:            'HABIT_ADD',
  MEAL_LOG:             'MEAL_LOG',
  MEAL_DELETE:          'MEAL_DELETE',
  SLEEP_LOG:            'SLEEP_LOG',
  ASSIGNMENT_TOGGLE:    'ASSIGNMENT_TOGGLE',
  SESSION_START:        'SESSION_START',
  SESSION_SET_UPDATE:   'SESSION_SET_UPDATE',
  SESSION_SET_COMPLETE: 'SESSION_SET_COMPLETE',
  SESSION_ADD_SET:      'SESSION_ADD_SET',
  SESSION_REST_START:   'SESSION_REST_START',
  SESSION_REST_SKIP:    'SESSION_REST_SKIP',
  SESSION_FINISH:       'SESSION_FINISH',
};

// ─── Build Session From Workout ───────────────────────────────────────────────
function buildSession(workout) {
  return {
    workoutId: workout.id,
    name: workout.name,
    startedAt: Date.now(),
    restEndsAt: null,
    exercises: workout.exercises.map(ex => ({
      name: ex.name,
      sets: Array.from({ length: ex.sets }, (_, i) => ({
        id: uid(),
        idx: i + 1,
        weight: '',
        reps: ex.reps,
        rpe: String(ex.rpe),
        done: false,
      })),
    })),
  };
}

// ─── Root Reducer ─────────────────────────────────────────────────────────────
function rootReducer(state, action) {
  switch (action.type) {
    case AT.TAB_CHANGE:
      return { ...state, activeTab: action.tab };

    case AT.THEME_TOGGLE:
      return { ...state, theme: state.theme === 'dark' ? 'light' : 'dark' };

    case AT.SHEET_OPEN:
      return { ...state, openSheet: action.sheet };

    case AT.SHEET_CLOSE:
      return { ...state, openSheet: null };

    case AT.HABIT_TOGGLE:
      return {
        ...state,
        habits: state.habits.map(h =>
          h.id === action.id
            ? { ...h, completedToday: !h.completedToday, streakDays: !h.completedToday ? h.streakDays + 1 : Math.max(0, h.streakDays - 1) }
            : h
        ),
      };

    case AT.HABIT_ADD:
      return { ...state, habits: [...state.habits, { ...action.habit, id: uid(), completedToday: false, streakDays: 0 }], openSheet: null };

    case AT.MEAL_LOG:
      return { ...state, mealLog: [...state.mealLog, { ...action.meal, id: uid() }], openSheet: null };

    case AT.MEAL_DELETE:
      return { ...state, mealLog: state.mealLog.filter(m => m.id !== action.id) };

    case AT.SLEEP_LOG:
      return {
        ...state,
        sleepLog: [action.entry, ...state.sleepLog.filter(s => s.date !== action.entry.date)].slice(0, 30),
        openSheet: null,
      };

    case AT.ASSIGNMENT_TOGGLE:
      return {
        ...state,
        assignments: state.assignments.map(a =>
          a.id === action.id ? { ...a, done: !a.done } : a
        ),
      };

    case AT.SESSION_START: {
      const workout = state.workoutLibrary.find(w => w.id === action.workoutId);
      if (!workout) return state;
      return { ...state, activeSession: buildSession(workout) };
    }

    case AT.SESSION_SET_UPDATE: {
      const { exIdx, setIdx, field, value } = action;
      const exercises = state.activeSession.exercises.map((ex, ei) =>
        ei !== exIdx ? ex : {
          ...ex,
          sets: ex.sets.map((s, si) => si !== setIdx ? s : { ...s, [field]: value }),
        }
      );
      return { ...state, activeSession: { ...state.activeSession, exercises } };
    }

    case AT.SESSION_SET_COMPLETE: {
      const { exIdx, setIdx } = action;
      const exercises = state.activeSession.exercises.map((ex, ei) =>
        ei !== exIdx ? ex : {
          ...ex,
          sets: ex.sets.map((s, si) => si !== setIdx ? s : { ...s, done: !s.done }),
        }
      );
      const restEndsAt = Date.now() + 120_000;
      return { ...state, activeSession: { ...state.activeSession, exercises, restEndsAt } };
    }

    case AT.SESSION_ADD_SET: {
      const { exIdx } = action;
      const exercises = state.activeSession.exercises.map((ex, ei) => {
        if (ei !== exIdx) return ex;
        const last = ex.sets[ex.sets.length - 1] || { weight: '', reps: '8', rpe: '7' };
        return { ...ex, sets: [...ex.sets, { id: uid(), idx: ex.sets.length + 1, weight: last.weight, reps: last.reps, rpe: last.rpe, done: false }] };
      });
      return { ...state, activeSession: { ...state.activeSession, exercises } };
    }

    case AT.SESSION_REST_SKIP:
      return { ...state, activeSession: { ...state.activeSession, restEndsAt: null } };

    case AT.SESSION_FINISH: {
      const s = state.activeSession;
      const durationMin = Math.round((Date.now() - s.startedAt) / 60_000);
      const completedSets = s.exercises.flatMap(ex => ex.sets.filter(set => set.done));
      const totalVolumeKg = completedSets.reduce((acc, set) => {
        const w = parseFloat(set.weight) || 0;
        const r = parseInt(set.reps) || 0;
        return acc + w * r;
      }, 0);
      const entry = {
        id: uid(),
        workoutId: s.workoutId,
        name: s.name,
        date: new Date().toISOString().split('T')[0],
        durationMin,
        totalVolumeKg: Math.round(totalVolumeKg),
      };
      return { ...state, activeSession: null, workoutHistory: [entry, ...state.workoutHistory] };
    }

    default:
      return state;
  }
}
