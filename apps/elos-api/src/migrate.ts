import "dotenv/config";
import { readFileSync, readdirSync } from "fs";
import { join } from "path";
import type { Pool } from "pg";

const migrationsDir = join(__dirname, "..", "migrations");

// Serializes concurrent runners (e.g. two instances booting at once) so a
// migration is never applied twice. Arbitrary app-unique lock id.
const MIGRATION_LOCK_ID = 727_001;

/**
 * Apply any unapplied migrations/*.sql in order, tracked in schema_migrations.
 * Runs at server boot (fail-fast: a failed migration must stop the deploy)
 * and via `npm run migrate`.
 */
export async function runMigrations(db: Pool): Promise<void> {
  const client = await db.connect();
  try {
    await client.query("SELECT pg_advisory_lock($1)", [MIGRATION_LOCK_ID]);
    await client.query(`
      CREATE TABLE IF NOT EXISTS schema_migrations (
        filename TEXT PRIMARY KEY,
        applied_at TIMESTAMPTZ NOT NULL DEFAULT now()
      )
    `);

    const applied = await client.query<{ filename: string }>(
      "SELECT filename FROM schema_migrations ORDER BY filename"
    );
    const appliedSet = new Set(applied.rows.map((r) => r.filename));

    const files = readdirSync(migrationsDir)
      .filter((f) => f.endsWith(".sql"))
      .sort();

    for (const file of files) {
      if (appliedSet.has(file)) continue;
      const sql = readFileSync(join(migrationsDir, file), "utf8");
      console.log(`Applying migration: ${file}`);
      try {
        await client.query("BEGIN");
        await client.query(sql);
        await client.query(
          "INSERT INTO schema_migrations (filename) VALUES ($1)",
          [file]
        );
        await client.query("COMMIT");
      } catch (err) {
        await client.query("ROLLBACK");
        throw err;
      }
      console.log(`Applied: ${file}`);
    }
    console.log("Migrations complete.");
  } finally {
    await client.query("SELECT pg_advisory_unlock($1)", [MIGRATION_LOCK_ID]);
    client.release();
  }
}

// CLI entry point: `npm run migrate`
if (require.main === module) {
  // Deferred so importing runMigrations never constructs the pool as a side effect.
  // eslint-disable-next-line @typescript-eslint/no-var-requires
  const { pool } = require("./db") as typeof import("./db");
  runMigrations(pool)
    .then(() => pool.end())
    .catch((err) => {
      console.error(err);
      process.exit(1);
    });
}
