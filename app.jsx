import React from 'react'
import ElosStorage from './storage.js'
import { StatusBar, NavBar, Ring, SegCtrl, TabBar, BottomSheet, Toast } from './shell.jsx'
import { Today } from './screens/today.jsx'
import { Train } from './screens/train.jsx'
import { Eat } from './screens/eat.jsx'
import { Plan } from './screens/plan.jsx'
import { Me } from './screens/me.jsx'
import { ActiveSession } from './screens/active_session.jsx'
import { Sheets } from './sheets.jsx'
import { Onboarding } from './onboarding.jsx'
import { ErrorBoundary } from './error_boundary.jsx'
import {
  PreferencesScreen, CanvasScreen, TrainingProfileScreen,
  NutritionGoalsScreen, SpacesScreen, AboutScreen, WorkoutHistoryScreen,
} from './settings_screens.jsx'
const { useReducer, useEffect, useRef } = React;

/* ── Initial state ──────────────────────────────── */
const TODAY_KEY = (() => {
  const d = new Date();
  return d.getFullYear() + '-' + String(d.getMonth()+1).padStart(2,'0') + '-' + String(d.getDate()).padStart(2,'0');
})();

const DEFAULT_STATE = {
  /* Transient UI state — NOT persisted */
  tab: 'today',
  pushed: null,
  sheet: null,
  sheetData: null,
  toast: null,

  /* Persisted */
  theme: 'dark',
  onboarded: false,

  profile: {
    name: 'Frank Aguilar',
    initials: 'FA',
    subtitle: 'Sophomore · UHS · ELOS Pro',
    email: '',
  },

  preferences: {
    units: 'imperial',           // 'imperial' | 'metric'
    weekStartsOn: 1,             // 0=Sun 1=Mon
    notifications: false,
    reduceMotion: false,
  },

  trainingProfile: {
    program: 'Push/Pull/Legs',
    daysPerWeek: 5,
    bodyweight: 165,
    experience: 'Intermediate',
  },

  nutritionGoals: {
    calories: 2950,
    protein: 200,
    carbs: 320,
    fat: 90,
    hydrationOz: 128,
  },

  habits: [
    { k:'read',    l:'Read 20 min',      streak:24, done:false, cat:'Learning',  color:'var(--m-assign)' },
    { k:'protein', l:'Hit protein',      streak:41, done:false, cat:'Nutrition', color:'var(--m-nutri)'  },
    { k:'hydrate', l:'128 oz water',     streak:9,  done:false, cat:'Recovery',  color:'var(--m-health)' },
    { k:'journal', l:'Journal',          streak:14, done:false, cat:'Mindset',   color:'var(--m-assign)' },
    { k:'lift',    l:'Train today',      streak:6,  done:false, cat:'Fitness',   color:'var(--m-gym)'    },
    { k:'phone',   l:'No phone 10PM',    streak:3,  done:false, cat:'Mindset',   color:'var(--m-sched)'  },
  ],

  meals: {
    breakfast: [
      {n:'Greek yogurt 1 cup', kcal:210, p:22, c:14, f:6},
      {n:'Blueberries',        kcal:85,  p:1,  c:21, f:0},
    ],
    lunch: [
      {n:'Chicken breast 8oz', kcal:340, p:62, c:0,  f:8},
      {n:'White rice 1.5 cup', kcal:310, p:6,  c:68, f:1},
      {n:'Broccoli',           kcal:55,  p:4,  c:11, f:0},
    ],
    dinner: [],
    snacks: [
      {n:'Protein bar',        kcal:220, p:20, c:22, f:7},
    ],
  },
  calGoal: 2950,

  savedMeals: [
    { id:'sm1', l:'Yogurt parfait',  cal:340, items:[{n:'Greek yogurt',kcal:210,p:22,c:14,f:6},{n:'Granola',kcal:130,p:3,c:21,f:5}] },
    { id:'sm2', l:'Chicken & rice',  cal:680, items:[{n:'Chicken breast 8oz',kcal:340,p:62,c:0,f:8},{n:'White rice 1.5 cup',kcal:310,p:6,c:68,f:1},{n:'Broccoli',kcal:55,p:4,c:11,f:0}] },
    { id:'sm3', l:'Post-workout shake', cal:280, items:[{n:'Whey protein',kcal:120,p:24,c:3,f:1},{n:'Banana',kcal:105,p:1,c:27,f:0},{n:'Milk 1/2 cup',kcal:75,p:4,c:6,f:4}] },
    { id:'sm4', l:'Eggs & toast',    cal:420, items:[{n:'Eggs ×3',kcal:210,p:18,c:0,f:15},{n:'Wheat toast ×2',kcal:160,p:6,c:28,f:2},{n:'Butter',kcal:50,p:0,c:0,f:6}] },
  ],

  planTab: 'schedule',
  planDay: 2,

  assignments: [
    { id:1, l:'Lit Analysis Essay',  cls:'AP English', due:'Tomorrow 11:59 PM', done:false, urgent:true  },
    { id:2, l:'Physics Lab Report',  cls:'AP Physics',  due:'Friday',           done:false, urgent:false },
    { id:3, l:'DBQ Outline',         cls:'AP USH',      due:'Sunday',           done:false, urgent:false },
    { id:4, l:'Chem Lab Writeup',    cls:'AP Chem',     due:'Monday',           done:true,  urgent:false },
    { id:5, l:'Calc Problem Set 8',  cls:'AP Calc',     due:'Next Wed',         done:false, urgent:false },
  ],

  exams: [
    { id:1, l:'AP Physics Unit 4',   cls:'AP Physics', date:'2026-05-12' },
    { id:2, l:'AP Calc BC Exam',     cls:'AP Calc',    date:'2026-05-16' },
    { id:3, l:'AP English Essay',    cls:'AP English', date:'2026-05-21' },
  ],

  sleepLog: [
    { date:'Apr 23', bed:'10:45 PM', wake:'6:15 AM', dur:7.5, quality:4 },
    { date:'Apr 22', bed:'11:00 PM', wake:'6:30 AM', dur:7.5, quality:3 },
    { date:'Apr 21', bed:'10:30 PM', wake:'6:00 AM', dur:7.5, quality:5 },
  ],
  hydration: 72,
  hydGoal: 128,
  lastHydrationReset: TODAY_KEY,

  workoutHistory: [],
  spaces: [],
  personaMode: 'peak',
  recommendedWeights: {},
  scheduleCompleted: {},
  scheduleCompletedDay: TODAY_KEY,
};

/* Hydrate from localStorage once at startup. */
function hydrateInitialState() {
  const stored = ElosStorage.load() || null;
  const merged = { ...DEFAULT_STATE };
  if (stored) {
    for (const k of Object.keys(stored)) {
      if (stored[k] !== undefined) merged[k] = stored[k];
    }
  }
  /* Daily reset for hydration so the goal restarts each day. */
  if (merged.lastHydrationReset !== TODAY_KEY) {
    merged.hydration = 0;
    merged.lastHydrationReset = TODAY_KEY;
  }
  /* Daily reset for schedule completions */
  if (merged.scheduleCompletedDay !== TODAY_KEY) {
    merged.scheduleCompleted = {};
    merged.scheduleCompletedDay = TODAY_KEY;
  }
  /* Ensure transient fields are clean. */
  merged.tab = 'today';
  merged.pushed = null;
  merged.sheet = null;
  merged.sheetData = null;
  merged.toast = null;
  return merged;
}

/* ── Reducer ─────────────────────────────────────── */
function reducer(state, action) {
  switch (action.type) {
    case 'SET_TAB':
      return { ...state, tab: action.tab, pushed: null, sheet: null };
    case 'PUSH_SCREEN':
      return { ...state, pushed: action.screen, pushedData: action.data || null, sheet: null };
    case 'POP_SCREEN':
      return { ...state, pushed: null, pushedData: null };
    case 'OPEN_SHEET':
      return { ...state, sheet: action.sheet, sheetData: action.data || null };
    case 'CLOSE_SHEET':
      return { ...state, sheet: null, sheetData: null };
    case 'SET_THEME':
      return { ...state, theme: action.theme };
    case 'SET_PROFILE':
      return { ...state, profile: { ...state.profile, ...action.profile } };
    case 'SET_PREFERENCES':
      return { ...state, preferences: { ...state.preferences, ...action.preferences } };
    case 'SET_TRAINING_PROFILE':
      return { ...state, trainingProfile: { ...state.trainingProfile, ...action.profile } };
    case 'SET_NUTRITION_GOALS': {
      const ng = { ...state.nutritionGoals, ...action.goals };
      return { ...state, nutritionGoals: ng, calGoal: ng.calories ?? state.calGoal, hydGoal: ng.hydrationOz ?? state.hydGoal };
    }
    case 'COMPLETE_ONBOARDING':
      return { ...state, onboarded: true };
    case 'SET_PLAN_TAB':
      return { ...state, planTab: action.tab };
    case 'SET_PLAN_DAY':
      return { ...state, planDay: action.day };
    case 'TOGGLE_HABIT': {
      const hab = state.habits.find(h => h.k === action.k);
      const nowDone = hab ? !hab.done : false;
      return {
        ...state,
        habits: state.habits.map(h =>
          h.k === action.k ? { ...h, done: !h.done, streak: !h.done ? h.streak + 1 : Math.max(0, h.streak - 1) } : h
        ),
        toast: { id: Date.now(), msg: nowDone ? `${hab?.l || 'Habit'} done ✓` : `${hab?.l || 'Habit'} unchecked` },
      };
    }
    case 'ADD_HABIT':
      return { ...state, habits: [...state.habits, action.habit] };
    case 'DELETE_HABIT':
      return { ...state, habits: state.habits.filter(h => h.k !== action.k) };
    case 'TOGGLE_ASSIGNMENT':
      return {
        ...state,
        assignments: state.assignments.map(a => a.id === action.id ? { ...a, done: !a.done } : a),
      };
    case 'ADD_ASSIGNMENT':
      return { ...state, assignments: [...state.assignments, action.assignment], toast: { id: Date.now(), msg: 'Assignment added ✓' } };
    case 'DELETE_ASSIGNMENT':
      return { ...state, assignments: state.assignments.filter(a => a.id !== action.id) };
    case 'ADD_EXAM':
      return { ...state, exams: [...state.exams, action.exam], toast: { id: Date.now(), msg: 'Exam added ✓' } };
    case 'DELETE_EXAM':
      return { ...state, exams: state.exams.filter(e => e.id !== action.id) };
    case 'ADD_HYDRATION':
      return { ...state, hydration: Math.min(state.hydGoal, state.hydration + action.oz), lastHydrationReset: TODAY_KEY, toast: { id: Date.now(), msg: `+${action.oz} oz logged` } };
    case 'RESET_HYDRATION':
      return { ...state, hydration: 0, lastHydrationReset: TODAY_KEY };
    case 'TOGGLE_SCHEDULE_BLOCK': {
      const sc = { ...(state.scheduleCompleted || {}) };
      sc[action.key] = !sc[action.key];
      return { ...state, scheduleCompleted: sc, scheduleCompletedDay: TODAY_KEY };
    }
    case 'LOG_SLEEP':
      return { ...state, sleepLog: [action.entry, ...state.sleepLog], sheet: null, toast: { id: Date.now(), msg: `Sleep logged — ${action.entry.dur}h ✓` } };
    case 'ADD_MEAL_ITEM': {
      const meals = { ...state.meals };
      meals[action.meal] = [...(meals[action.meal] || []), action.item];
      return { ...state, meals, sheet: null, toast: { id: Date.now(), msg: `${action.item.n} logged ✓` } };
    }
    case 'DELETE_MEAL_ITEM': {
      const meals = { ...state.meals };
      meals[action.meal] = (meals[action.meal] || []).filter((_, i) => i !== action.index);
      return { ...state, meals };
    }
    case 'CLEAR_TODAY_MEALS':
      return { ...state, meals: { breakfast: [], lunch: [], dinner: [], snacks: [] } };
    case 'ADD_SAVED_MEAL':
      return { ...state, savedMeals: [...(state.savedMeals||[]), action.meal] };
    case 'DELETE_SAVED_MEAL':
      return { ...state, savedMeals: (state.savedMeals||[]).filter(m => m.id !== action.id) };
    case 'LOG_WORKOUT': {
      const recW = { ...(state.recommendedWeights || {}) };
      for (const ex of (action.workout.exercises || [])) {
        const rated = (ex.sets || []).filter(s => s.difficulty && (s.weight || 0) > 0);
        if (!rated.length) continue;
        const last = rated[rated.length - 1];
        const w = last.weight || 0;
        if (last.difficulty === 'easy') recW[ex.name] = w + 10;
        if (last.difficulty === 'good') recW[ex.name] = w + 5;
        if (last.difficulty === 'hard') recW[ex.name] = Math.max(w - 10, 5);
      }
      return { ...state, workoutHistory: [action.workout, ...(state.workoutHistory||[])].slice(0, 50), recommendedWeights: recW, pushed: null, pushedData: null, toast: { id: Date.now(), msg: 'Workout saved ✓' } };
    }
    case 'SET_PERSONA':
      return { ...state, personaMode: action.mode };
    case 'ADD_SPACE':
      return { ...state, spaces: [...(state.spaces||[]), action.space] };
    case 'UPDATE_SPACE':
      return { ...state, spaces: (state.spaces||[]).map(s => s.id === action.id ? { ...s, ...action.patch } : s) };
    case 'DELETE_SPACE':
      return { ...state, spaces: (state.spaces||[]).filter(s => s.id !== action.id) };
    case 'IMPORT_STATE':
      return { ...state, ...action.state, tab: state.tab, pushed: null, sheet: null, sheetData: null };
    case 'DISMISS_TOAST':
      return { ...state, toast: null };
    case 'RESET_ALL':
      return { ...DEFAULT_STATE, onboarded: false, tab: 'today' };
    default:
      return state;
  }
}

/* ── App ─────────────────────────────────────────── */
function App() {
  const [state, dispatch] = useReducer(reducer, null, hydrateInitialState);
  const saver = useRef(null);

  /* Lazy-init the debounced saver */
  if (!saver.current) {
    saver.current = ElosStorage.debouncedSave(300);
  }

  /* Persist state on every change (transient UI fields are filtered inside storage.js) */
  useEffect(() => {
    if (saver.current) saver.current(state);
  }, [state]);

  /* Apply theme */
  useEffect(() => {
    document.documentElement.setAttribute('data-theme', state.theme);
  }, [state.theme]);

  /* Reduce-motion accessibility */
  useEffect(() => {
    document.documentElement.dataset.reduceMotion = state.preferences?.reduceMotion ? '1' : '0';
  }, [state.preferences?.reduceMotion]);

  const toggleTheme = () => dispatch({ type: 'SET_THEME', theme: state.theme === 'light' ? 'dark' : 'light' });

  /* Active screen */
  const Screen = () => {
    switch (state.tab) {
      case 'today': return <Today state={state} dispatch={dispatch} />;
      case 'train': return <Train state={state} dispatch={dispatch} />;
      case 'eat':   return <Eat   state={state} dispatch={dispatch} />;
      case 'plan':  return <Plan  state={state} dispatch={dispatch} />;
      case 'me':    return <Me    state={state} dispatch={dispatch} />;
      default:      return <Today state={state} dispatch={dispatch} />;
    }
  };

  /* Onboarding gate */
  if (!state.onboarded && typeof Onboarding === 'function') {
    return (
      <div className="phone-wrap">
        <div className="ios-app">
          <Onboarding state={state} dispatch={dispatch}/>
        </div>
      </div>
    );
  }

  const RootBoundary = typeof ErrorBoundary === 'function' ? ErrorBoundary : (({ children }) => children);

  return (
    <RootBoundary>
      <div className="phone-wrap">
        <div className="ios-app">
          <StatusBar theme={state.theme} onToggleTheme={toggleTheme}/>

          <div style={{ flex: 1, position: 'relative', overflow: 'hidden', display: 'flex', flexDirection: 'column' }}>
            <Screen key={state.tab}/>

            {state.pushed === 'activeSession' && (
              <ActiveSession state={state} dispatch={dispatch}/>
            )}
            {state.pushed === 'preferences'    && <div className="push-screen"><PreferencesScreen     state={state} dispatch={dispatch}/></div>}
            {state.pushed === 'canvas'         && <div className="push-screen"><CanvasScreen          state={state} dispatch={dispatch}/></div>}
            {state.pushed === 'trainingProfile'&& <div className="push-screen"><TrainingProfileScreen state={state} dispatch={dispatch}/></div>}
            {state.pushed === 'nutritionGoals' && <div className="push-screen"><NutritionGoalsScreen  state={state} dispatch={dispatch}/></div>}
            {state.pushed === 'spaces'         && <div className="push-screen"><SpacesScreen          state={state} dispatch={dispatch}/></div>}
            {state.pushed === 'about'          && <div className="push-screen"><AboutScreen           state={state} dispatch={dispatch}/></div>}
            {state.pushed === 'workoutHistory' && <div className="push-screen"><WorkoutHistoryScreen  state={state} dispatch={dispatch}/></div>}

            {state.sheet && (
              <Sheets sheet={state.sheet} sheetData={state.sheetData} state={state} dispatch={dispatch}/>
            )}
          </div>

          <Toast toast={state.toast} dispatch={dispatch}/>
          <TabBar tab={state.tab} dispatch={dispatch}/>
        </div>
      </div>
    </RootBoundary>
  );
}

export default App;
