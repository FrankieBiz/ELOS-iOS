-- The legacy custom-auth `users` table (002) is dead: nothing ever inserts into
-- it, so every FK pointing at it rejects the first write for a real (Supabase)
-- user — profiles, splits, feed posts and community splits all fail with FK
-- violations. Rows key off the Supabase user UUID directly; drop the dead FKs.
-- Conditional + idempotent: safe on databases where the table or FKs are absent
-- (e.g. production, where profiles references auth.users instead).
DO $$
DECLARE c RECORD;
BEGIN
  IF to_regclass('public.users') IS NOT NULL THEN
    FOR c IN
      SELECT conname, conrelid::regclass::text AS tbl
      FROM pg_constraint
      WHERE contype = 'f' AND confrelid = 'public.users'::regclass
    LOOP
      EXECUTE format('ALTER TABLE %s DROP CONSTRAINT %I', c.tbl, c.conname);
    END LOOP;
  END IF;
END $$;
