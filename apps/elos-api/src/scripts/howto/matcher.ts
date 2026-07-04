export interface SourceExercise {
  id: string; name: string; instructions: string[]; images: string[];
  primaryMuscles: string[]; secondaryMuscles: string[];
  equipment: string | null; force: string | null; mechanic: string | null; category: string;
}
export interface CatalogExercise { name: string; movement_pattern: string; }
export interface Enriched {
  elosName: string; sourceName: string; instructions: string[];
  imageKey: string; imagePath: string; derivedMovementPattern: string;
}
/** lowercase, replace non-alphanumeric with space, collapse whitespace. */
export function normalize(s: string): string {
  return s.toLowerCase().replace(/[^a-z0-9]+/g, " ").trim().replace(/\s+/g, " ");
}
/** Derive an Elos movement_pattern from the source's force/mechanic/name. */
export function deriveMovementPattern(ex: SourceExercise): string {
  const n = normalize(ex.name);
  if (/\bsquat\b/.test(n)) return "squat";
  if (/\b(deadlift|romanian|rdl|hip thrust|good morning|hyperextension)\b/.test(n)) return "hinge";
  if (ex.mechanic === "isolation") return "isolation";
  if (ex.force === "push") return "push";
  if (ex.force === "pull") return "pull";
  return "isolation";
}
/** Conservative: exact-normalized name OR alias-map hit only. No fuzzy matching. */
export function matchCatalog(
  catalog: CatalogExercise[], source: SourceExercise[],
  aliases: Record<string, string>, _muscleMap: Record<string, string>
): { enriched: Enriched[]; unmatched: string[] } {
  const byNorm = new Map<string, SourceExercise>();
  for (const s of source) {
    const key = normalize(s.name);
    if (!byNorm.has(key)) byNorm.set(key, s);
  }
  const enriched: Enriched[] = [];
  const unmatched: string[] = [];
  for (const c of catalog) {
    const cn = normalize(c.name);
    const target = aliases[cn] ?? cn;
    const src = byNorm.get(target);
    if (!src || src.instructions.length === 0) { unmatched.push(c.name); continue; }
    enriched.push({
      elosName: c.name, sourceName: src.name, instructions: src.instructions,
      imageKey: src.id, imagePath: src.images[0] ?? "", derivedMovementPattern: deriveMovementPattern(src),
    });
  }
  return { enriched, unmatched };
}
