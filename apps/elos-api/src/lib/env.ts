const REQUIRED_VARS = [
  "SUPABASE_URL",
  "SUPABASE_SERVICE_ROLE_KEY",
  "DEEPSEEK_API_KEY",
] as const;

export function assertRequiredEnv(): void {
  const missing = REQUIRED_VARS.filter((name) => !process.env[name]);
  const hasDb =
    !!process.env.DATABASE_URL ||
    (!!process.env.DB_HOST && !!process.env.DB_NAME);
  if (!hasDb) missing.push("DATABASE_URL" as never);

  if (missing.length > 0) {
    // eslint-disable-next-line no-console
    console.error(
      `Missing required environment variables: ${missing.join(", ")}\n` +
        `See apps/elos-api/.env.example for the full list.`
    );
    process.exit(1);
  }
}
