## Deploy & DB

### Local development
- Start Postgres with `docker-compose.yml`.
- Run migrations with `npx prisma migrate dev`.
- Use `scripts/setup-local.sh` to do both plus install deps.
  - `.env.example` defaults to `DB_SCHEMA=candidate_local` so each dev can stay isolated.

### Production (Render)
- Render runs `npx prisma migrate deploy` via `preDeployCommand`.
- Candidates do NOT need Render access.
- Verify a deployment via `GET /health`, which returns:
  - `gitSha` (from `GIT_SHA`)
  - `schema` (active Postgres schema)
  - `db.ok` (connectivity check)

### Schema isolation
- The active Postgres schema is selected from `DATABASE_URL?schema=...` or `DB_SCHEMA`.
- `/health` returns the active schema name so you can confirm isolation.
