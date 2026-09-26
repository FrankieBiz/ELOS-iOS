# Skill: elos-db-migration

## Purpose
Add or modify Postgres tables and keep the API in sync.

## Steps
1. Read current schema/migrations in apps/elos-api/.
2. Write SQL migration to create/alter tables.
3. Update service and route files.
4. Update packages/elos-shared types if shapes change.

## Constraints
- Postgres: localhost:5432, user elos, password elos, db elos.
- Prefer additive migrations; do not drop data.
