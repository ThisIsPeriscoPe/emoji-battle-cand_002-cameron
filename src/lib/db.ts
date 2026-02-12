import { PrismaClient } from "@prisma/client";
import { getDatabaseUrl } from "./env";

export const prisma = new PrismaClient({
  datasources: {
    db: {
      url: getDatabaseUrl()
    }
  }
});

export async function checkDatabase(): Promise<boolean> {
  try {
    await prisma.$queryRaw`SELECT 1`;
    return true;
  } catch {
    return false;
  }
}
