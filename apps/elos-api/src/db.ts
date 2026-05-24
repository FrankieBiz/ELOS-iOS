import { Pool } from "pg";

// Used for workouts and other direct SQL queries.
// In production, use the Supabase Transaction Mode pooler URL as DATABASE_URL.
export const pool = new Pool(
  process.env.DATABASE_URL
    ? { connectionString: process.env.DATABASE_URL }
    : {
        host:     process.env.DB_HOST     ?? "localhost",
        port:     Number(process.env.DB_PORT ?? 5432),
        database: process.env.DB_NAME     ?? "elos",
        user:     process.env.DB_USER     ?? "elos",
        password: process.env.DB_PASSWORD ?? "elos",
      }
);
