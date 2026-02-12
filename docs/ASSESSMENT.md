# Emoji Battle Assessment

Build the game logic for the Emoji Battle backend. The API surface is wired, but the service layer is intentionally stubbed with TODOs in `src/services/matchService.ts`.

## Game rules
- The emoji win matrix is in `rules.json` and is loaded by the server at startup.
- A match progresses in rounds. Each round collects picks from both players, then determines a winner (or tie).
- Apply the win matrix per round and update match state accordingly.
  - Use `rules.json` to determine the winning emoji.
  - If both picks are the same, the round is a tie.

![Emoji Battle rules diagram](emoji-battle-rules.png)

## Required endpoints
- `POST /matches`: create a new match and return initial state.
- `POST /matches/:id/join`: second player joins an existing match.
- `POST /matches/:id/pick`: player submits a pick for the current round.
  - Requires `Idempotency-Key` header. Duplicate keys must be safe and return the same result.
- `GET /matches/:id`: fetch current match state.
- `GET /debug/errors`: protected by `X-Debug-Key`, returns recent error logs.
- `GET /debug/events?matchId=...`: optional debug endpoint listing recent events.

## Service layer
Implement your logic in the service layer:
- `MatchService.createMatch`
- `MatchService.joinMatch`
- `MatchService.submitPick` (idempotent)
- `MatchService.getMatchState`
- `ErrorLogService.recordError` (already wired for unexpected errors)

## Data model expectations
- Use `Event` for append-only events. `eventId` must enforce idempotency.
- `MatchState` stores current state as JSON and a monotonic `version`.
- `ErrorLog` captures unexpected failures with request IDs.
  - Include `eventId` when a failure is tied to a specific pick.

## Reliability expectations
- Implement idempotency for picks using `Idempotency-Key`.
- Add retries/backoff for transient failures within your own code paths.
- Use structured logs (Fastify + pino are already set up).
  - We will test with duplicate `Idempotency-Key` values and with retries.

## Suggested state shape (flexible)
You can design your own state JSON, but ensure it can answer:
- current round number
- players and their picks
- scores or win history
- match status (waiting, in_progress, complete)
 - last processed `Idempotency-Key` (or equivalent idempotency tracking)

## Frontend expectations
- Implement a scoreboard and round history UI.
- Do not reveal the opponent's pick until both picks are submitted for the round.
- Poll `GET /matches/:id` while a match is active so the UI updates when the other player acts.

## Idempotency guidance
- A pick request with a previously used `Idempotency-Key` must not change state.
- Return the same response shape you returned for the first request.
- Store the key in a durable place (for example, as an `Event` record with `eventId = Idempotency-Key`).

## Notes
- `GET /health` returns the active Postgres schema name so you can verify environment isolation.
- Local development uses Docker Postgres via `docker-compose.yml`.
