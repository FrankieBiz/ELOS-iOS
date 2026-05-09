/* ELOS local persistence */
const KEY = 'elos.state.v1';
const SCHEMA_VERSION = 1;

const PERSIST_FIELDS = [
  'theme',
  'habits',
  'meals',
  'calGoal',
  'planTab',
  'planDay',
  'assignments',
  'exams',
  'sleepLog',
  'hydration',
  'hydGoal',
  'profile',
  'preferences',
  'savedMeals',
  'trainingProfile',
  'nutritionGoals',
  'spaces',
  'workoutHistory',
  'onboarded',
  'lastHydrationReset',
  'scheduleCompleted',
  'scheduleCompletedDay',
];

function load() {
  try {
    const raw = localStorage.getItem(KEY);
    if (!raw) return null;
    const data = JSON.parse(raw);
    if (data._v !== SCHEMA_VERSION) return migrate(data);
    delete data._v;
    return data;
  } catch (e) {
    console.warn('[ELOS] storage.load failed:', e);
    return null;
  }
}

function save(state) {
  try {
    const out = { _v: SCHEMA_VERSION };
    for (const k of PERSIST_FIELDS) {
      if (state[k] !== undefined) out[k] = state[k];
    }
    localStorage.setItem(KEY, JSON.stringify(out));
    return true;
  } catch (e) {
    console.warn('[ELOS] storage.save failed:', e);
    return false;
  }
}

function migrate(data) {
  delete data._v;
  return data;
}

function clearAll() {
  try {
    localStorage.removeItem(KEY);
    return true;
  } catch (e) { return false; }
}

function exportJSON() {
  const data = load() || {};
  return JSON.stringify({ exported: new Date().toISOString(), version: SCHEMA_VERSION, data }, null, 2);
}

function importJSON(text) {
  try {
    const parsed = JSON.parse(text);
    if (!parsed || typeof parsed !== 'object') throw new Error('invalid file');
    const data = parsed.data || parsed;
    const out = { _v: SCHEMA_VERSION };
    for (const k of PERSIST_FIELDS) if (data[k] !== undefined) out[k] = data[k];
    localStorage.setItem(KEY, JSON.stringify(out));
    return true;
  } catch (e) {
    console.warn('[ELOS] import failed:', e);
    return false;
  }
}

function debouncedSave(delay = 350) {
  let t = null;
  let lastState = null;
  return function (state) {
    lastState = state;
    if (t) clearTimeout(t);
    t = setTimeout(() => {
      save(lastState);
      t = null;
    }, delay);
  };
}

const ElosStorage = {
  load, save, clearAll, exportJSON, importJSON,
  debouncedSave,
  SCHEMA_VERSION,
  PERSIST_FIELDS,
};
export default ElosStorage;
