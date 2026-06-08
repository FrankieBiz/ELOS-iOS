/** Narrow an Express query-string value to a string (or undefined for arrays/missing). */
export const qs = (v: unknown): string | undefined =>
  typeof v === "string" ? v : undefined;

/**
 * Parse a query value to an integer clamped to [min, max], falling back to `def`
 * for missing/non-numeric input. Prevents `Number("abc")` → NaN from reaching SQL
 * (which would otherwise surface as a 500 instead of a sane default).
 */
export const intParam = (v: unknown, def: number, min: number, max: number): number => {
  const n = typeof v === "string" || typeof v === "number" ? Number(v) : NaN;
  if (!Number.isFinite(n)) return def;
  return Math.min(Math.max(Math.trunc(n), min), max);
};
