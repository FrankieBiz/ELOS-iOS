// Gym-slang / Elos catalog name (normalized) -> source dataset name (normalized).
// Normalized = lowercase, punctuation stripped, whitespace collapsed (see matcher.normalize).
export const NAME_ALIASES: Record<string, string> = {
  "pec deck": "butterfly",
  "pec deck fly": "butterfly",
  "machine chest fly": "butterfly",
  "reverse pec deck": "reverse machine flyes",
  "lying leg curl": "lying leg curls",
  "leg extension": "leg extensions",
  "lat pulldown": "wide grip lat pulldown",
  "seated cable row": "seated cable rows",
  "hip abduction machine": "thigh abductor",
  "hip adduction machine": "thigh adductor",
  // Elos catalog name variants vs source dataset name variants
  "barbell back squat": "barbell squat",
  "conventional deadlift": "barbell deadlift",
  "barbell bench press": "barbell bench press medium grip",
  "barbell overhead press": "barbell shoulder press",
  "pull up": "pullups",
  // Enrich existing catalog machine rows in place (avoids gap-fill duplicates).
  "pec deck machine": "butterfly",
  "hip abductor machine": "thigh abductor",
  "hip adductor machine": "thigh adductor",
  "hack squat machine": "hack squat",
  "machine preacher curl": "machine preacher curls",
  "machine tricep extension": "machine triceps extension",
  "machine shoulder press": "machine shoulder military press",
  "standing calf raise": "standing calf raises",
  "donkey calf raise": "donkey calf raises",
  "leg curl": "lying leg curls",
  "tricep pushdown": "triceps pushdown",
  "incline chest press machine": "leverage incline chest press",
  "seated chest press machine": "leverage chest press",
};

export interface GapFill {
  sourceName: string;
  elosName: string;
  primaryMuscle: string;
  secondaryMuscles: string[];
  equipment: string;
  movementPattern: string;
}
// Curated INSERTs for machines the source dataset covers but the Elos catalog
// lacks entirely. Empty because every previously-considered gap-fill concept
// already exists as an Elos catalog row and is now enriched in place via
// NAME_ALIASES (Pec Deck / Reverse Pec Deck were seeded in migration 016;
// Hip Abductor/Adductor Machine are the real catalog rows). Inserting them here
// would create near-duplicate concepts.
export const MACHINE_GAP_FILLS: GapFill[] = [];

export const MUSCLE_MAP: Record<string, string> = {
  abdominals: "core", abductors: "glutes", adductors: "adductors", biceps: "biceps",
  calves: "calves", chest: "chest", forearms: "forearms", glutes: "glutes",
  hamstrings: "hamstrings", lats: "lats", "lower back": "lower_back",
  "middle back": "back", neck: "neck", quadriceps: "quads", shoulders: "front_delts",
  traps: "traps", triceps: "triceps",
};
