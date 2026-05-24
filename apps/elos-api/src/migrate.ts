import { readFileSync, readdirSync } from "fs";
import { join } from "path";
import { pool } from "./db";

const migrationsDir = join(__dirname, "..", "migrations");

async function migrate() {
  const client = await pool.connect();
  try {
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
      await client.query("BEGIN");
      await client.query(sql);
      await client.query(
        "INSERT INTO schema_migrations (filename) VALUES ($1)",
        [file]
      );
      await client.query("COMMIT");
      console.log(`Applied: ${file}`);
    }
    console.log("Migrations complete.");
  } catch (err) {
    await client.query("ROLLBACK");
    throw err;
  } finally {
    client.release();
    await pool.end();
  }
}

migrate().catch((err) => {
  console.error(err);
  process.exit(1);
});
