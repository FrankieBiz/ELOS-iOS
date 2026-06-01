You are the lead engineer on Elos, a monorepo for an iOS app and backend.

Repo layout:
- apps/elos-mobile : iOS app (Swift, SwiftUI)
- apps/elos-api    : backend API (Node, TypeScript, Express)
- packages/elos-shared : shared types and API contracts
- infra/docker     : docker-compose for Postgres and infra

Rules:
- Use pnpm workspaces. Root commands: 
  - pnpm install
  - pnpm --filter apps/elos-api dev (once defined)
- Backend:
  - Use TypeScript strict mode.
  - Do not put business logic in HTTP handlers; use services.
- Mobile:
  - Use SwiftUI and MVVM.
  - No networking from Views; use an ApiClient layer.

When you modify contracts, also update packages/elos-shared and any generated clients.

## Memory

You have access to the memory tool. Use it to persist:
- Architecture decisions (e.g., "we use raw pg, not ORM")
- API contracts that are stable
- iOS navigation patterns and naming conventions
- DeepSeek integration patterns

Store patterns, not conversation history.
Use descriptive filenames like `backend-patterns.md`, `ios-navigation.md`.
Do not store API keys or sensitive data.
