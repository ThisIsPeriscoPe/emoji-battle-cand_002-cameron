import { FastifyInstance } from "fastify";
import { z } from "zod";
import { MatchService } from "../services/matchService";

const createMatchSchema = z.object({
  playerId: z.string().min(1)
});

const joinMatchSchema = z.object({
  playerId: z.string().min(1)
});

const pickEmojiSchema = z.object({
  playerId: z.string().min(1),
  emoji: z.string().min(1)
});

function normalizeBody(body: unknown) {
  if (typeof body === "string") {
    try {
      return JSON.parse(body);
    } catch {
      throw Object.assign(new Error("Invalid JSON body"), { statusCode: 400 });
    }
  }
  return body;
}

export async function registerMatchRoutes(server: FastifyInstance) {
  server.post("/matches", async (request, reply) => {
    const body = createMatchSchema.parse(normalizeBody(request.body));
    const result = await MatchService.createMatch({
      playerId: body.playerId,
      requestId: request.requestId
    });

    reply.status(201).send(result);
  });

  server.post("/matches/:id/join", async (request, reply) => {
    const body = joinMatchSchema.parse(normalizeBody(request.body));
    const params = request.params as { id: string };
    const result = await MatchService.joinMatch({
      matchId: params.id,
      playerId: body.playerId,
      requestId: request.requestId
    });

    reply.send(result);
  });

  server.post("/matches/:id/pick", async (request, reply) => {
    const idempotencyKey = request.headers["idempotency-key"];
    const normalizedKey = Array.isArray(idempotencyKey)
      ? idempotencyKey[0]
      : idempotencyKey;
    const params = request.params as { id: string };

    if (!normalizedKey) {
      reply.status(400).send({
        ok: false,
        error: "Missing Idempotency-Key header"
      });
      return;
    }

    const body = pickEmojiSchema.parse(normalizeBody(request.body));
    const result = await MatchService.submitPick({
      matchId: params.id,
      playerId: body.playerId,
      emoji: body.emoji,
      requestId: request.requestId,
      idempotencyKey: normalizedKey
    });

    reply.send(result);
  });

  server.get("/matches/:id", async (request, reply) => {
    const params = request.params as { id: string };
    const result = await MatchService.getMatchState({
      matchId: params.id,
      requestId: request.requestId
    });

    reply.send(result);
  });
}
