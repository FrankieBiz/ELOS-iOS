# Skill: elos-backend-endpoint

## Purpose
Add or modify API endpoints in apps/elos-api and keep shared types in sync.

## Steps
1. Read apps/elos-api/src/index.ts to understand current routes.
2. Create/update route files under apps/elos-api/src/routes/.
3. Create/update service functions under apps/elos-api/src/services/.
4. Update packages/elos-shared types if table shapes change.
5. Add minimal tests if test files exist.

## Constraints
- Use Express + TypeScript strict mode.
- Keep logic in services, not route handlers.
- Do not change iOS code.
