import Fastify from "fastify";
import cors from "@fastify/cors";
import { randomUUID } from "crypto";
import { ZodError } from "zod";
import { loadRules } from "./lib/rules";
import { registerHealthRoutes } from "./routes/health";
import { registerMatchRoutes } from "./routes/matches";
import { registerDebugRoutes } from "./routes/debug";
import { ErrorLogService } from "./services/errorLogService";

declare module "fastify" {
  interface FastifyRequest {
    requestId: string;
  }
  interface FastifyInstance {
    rules: {
      emojis: string[];
      winsAgainst: Record<string, string[]>;
    };
  }
}

export function buildServer() {
  const server = Fastify({
    logger: true
  });

  server.register(cors, {
    origin: true
  });

  const rules = loadRules();
  server.decorate("rules", rules);

  server.addHook("onRequest", async (request, reply) => {
    const header = request.headers["x-request-id"];
    const incomingId = Array.isArray(header) ? header[0] : header;
    const requestId = incomingId || randomUUID();
    request.requestId = requestId;
    reply.header("X-Request-Id", requestId);
  });

  server.setErrorHandler(async (error, request, reply) => {
    request.log.error({ err: error }, "Request failed");

    try {
      const matchId =
        typeof request.params === "object" &&
        request.params !== null &&
        "id" in request.params
          ? String((request.params as { id?: string }).id)
          : null;

      await ErrorLogService.recordError({
        requestId: request.requestId ?? randomUUID(),
        matchId,
        message: error.message,
        details: {
          stack: error.stack,
          route: request.routerPath
        }
      });
    } catch (logError) {
      request.log.error({ err: logError }, "Failed to write error log");
    }

    const statusCode =
      error instanceof ZodError
        ? 400
        : (error as { statusCode?: number }).statusCode ?? 500;
    reply.status(statusCode).send({
      ok: false,
      error: error.message
    });
  });

  server.register(registerHealthRoutes);
  server.register(registerMatchRoutes);
  server.register(registerDebugRoutes);

  return server;
}
