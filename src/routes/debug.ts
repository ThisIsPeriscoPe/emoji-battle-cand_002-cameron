import { FastifyInstance } from "fastify";
import { prisma } from "../lib/db";
import { isProduction } from "../lib/env";

const DEFAULT_LIMIT = 25;

function requireDebugKey(
  header: string | string[] | undefined,
  isProduction: boolean
): void {
  const incoming = Array.isArray(header) ? header[0] : header;
  const expected = process.env.DEBUG_KEY;
  if (!expected && !isProduction) {
    return;
  }

  if (!expected || incoming !== expected) {
    const error = new Error("Unauthorized");
    (error as { statusCode?: number }).statusCode = 401;
    throw error;
  }
}

export async function registerDebugRoutes(server: FastifyInstance) {
  server.get("/debug/errors", async (request) => {
    requireDebugKey(request.headers["x-debug-key"], isProduction());
    const errors = await prisma.errorLog.findMany({
      orderBy: { createdAt: "desc" },
      take: DEFAULT_LIMIT
    });

    return { ok: true, errors };
  });

  server.get("/debug/events", async (request) => {
    requireDebugKey(request.headers["x-debug-key"], isProduction());
    const matchId = (request.query as { matchId?: string }).matchId;

    const events = await prisma.event.findMany({
      where: matchId ? { matchId } : undefined,
      orderBy: { createdAt: "desc" },
      take: DEFAULT_LIMIT
    });

    return { ok: true, events };
  });
}
