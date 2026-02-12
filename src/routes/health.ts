import { FastifyInstance } from "fastify";
import { checkDatabase } from "../lib/db";
import { getGitSha, getSchemaName } from "../lib/env";

export async function registerHealthRoutes(server: FastifyInstance) {
  server.get("/health", async () => {
    const dbOk = await checkDatabase();
    return {
      ok: true,
      gitSha: getGitSha(),
      now: new Date().toISOString(),
      db: {
        ok: dbOk
      },
      schema: getSchemaName()
    };
  });
}
