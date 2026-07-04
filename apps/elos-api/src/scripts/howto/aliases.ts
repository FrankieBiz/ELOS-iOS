// Gym-slang / Elos catalog name (normalized) -> source dataset name (normalized).
// Normalized = lowercase, punctuation stripped, whitespace collapsed (see matcher.normalize).
export const NAME_ALIASES: Record<string, string> = {
  "pec deck": "butterfly",
  "pec deck fly": "butterfly",
  "machine chest fly": "butterfly",
  "reverse pec deck": "reverse machine flyes",
  "seated leg curl": "seated leg curl",
  "lying leg curl": "lying leg curls",
  "leg extension": "leg extensions",
  "lat pulldown": "wide grip lat pulldown",
  "seated cable row": "seated cable rows",
  "hip abduction machine": "thigh abductor",
  "hip adduction machine": "thigh adductor",
};

export interface GapFill {
  sourceName: string;
  elosName: string;
  primaryMuscle: string;
  secondaryMuscles: string[];
  equipment: string;
  movementPattern: string;
}
export const MACHINE_GAP_FILLS: GapFill[] = [
  { sourceName: "Butterfly", elosName: "Pec Deck", primaryMuscle: "chest", secondaryMuscles: ["front_delts"], equipment: "machine", movementPattern: "isolation" },
  { sourceName: "Reverse Machine Flyes", elosName: "Reverse Pec Deck", primaryMuscle: "rear_delts", secondaryMuscles: ["traps"], equipment: "machine", movementPattern: "isolation" },
  { sourceName: "Thigh Abductor", elosName: "Hip Abduction Machine", primaryMuscle: "glutes", secondaryMuscles: [], equipment: "machine", movementPattern: "isolation" },
  { sourceName: "Thigh Adductor", elosName: "Hip Adduction Machine", primaryMuscle: "adductors", secondaryMuscles: [], equipment: "machine", movementPattern: "isolation" },
];

export const MUSCLE_MAP: Record<string, string> = {
  abdominals: "core", abductors: "glutes", adductors: "adductors", biceps: "biceps",
  calves: "calves", chest: "chest", forearms: "forearms", glutes: "glutes",
  hamstrings: "hamstrings", lats: "lats", "lower back": "lower_back",
  "middle back": "back", neck: "neck", quadriceps: "quads", shoulders: "front_delts",
  traps: "traps", triceps: "triceps",
};
