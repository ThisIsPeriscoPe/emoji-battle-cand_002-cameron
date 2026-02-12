# Emoji Battle Assessment Template

Backend template for a technical assessment. The API is wired and the data model is in place; candidates implement the core game logic in the service layer.

## What you get
- Node 20 + TypeScript + Fastify + Prisma
- Postgres with schema isolation (`DB_SCHEMA` or `?schema=...`)
- Structured logging (pino)
- Debug endpoints with optional auth in dev
- Render blueprint for deployment

## Quick start (local)
```bash
bash scripts/setup-local.sh
npm run dev
```

## Frontend (optional)
The repo includes a small React app under `frontend/` to exercise the API.

```bash
cd frontend
npm install
npm run dev
```

Set `VITE_API_BASE` in `frontend/.env` if your API is not on `http://localhost:3000`.

## Environment variables
- `DATABASE_URL` (required): Postgres connection string. Supports `?schema=...`.
- `DB_SCHEMA` (optional): Overrides schema from `DATABASE_URL`.
- `DEBUG_KEY` (optional in dev, required in prod): Header auth for `/debug/*`.
- `GIT_SHA` (optional): Reported by `/health`. Defaults to `dev`.
- `PORT` (optional): Defaults to `3000`.

## Endpoints
- `GET /health` -> `{ ok, gitSha, now, db: { ok }, schema }`
- `POST /matches`
- `POST /matches/:id/join`
- `POST /matches/:id/pick` (requires `Idempotency-Key`)
- `GET /matches/:id`
- `GET /debug/errors` (requires `X-Debug-Key` in prod)
- `GET /debug/events?matchId=...` (requires `X-Debug-Key` in prod)

## Where to implement logic
Service layer stubs live in:
- `src/services/matchService.ts`
- `src/services/errorLogService.ts`

## Deployment (Render)
- Build: `npm ci && npm run build`
- Start: `npm run start`
- Pre-deploy migration: `npx prisma migrate deploy`
- Health check: `/health`

See `docs/DEPLOYMENT.md` for more details.
