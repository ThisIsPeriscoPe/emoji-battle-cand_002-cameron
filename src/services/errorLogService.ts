import { prisma } from "../lib/db";
import { getSchemaName } from "../lib/env";

export class ErrorLogService {
  static async recordError(input: {
    requestId: string;
    matchId: string | null;
    eventId?: string | null;
    message: string;
    details?: Record<string, unknown>;
  }): Promise<void> {
    const { requestId, matchId, eventId, message, details } = input;

    await prisma.errorLog.create({
      data: {
        requestId,
        matchId,
        eventId: eventId ?? null,
        message,
        details: {
          ...details,
          schema: getSchemaName()
        }
      }
    });
  }
}
