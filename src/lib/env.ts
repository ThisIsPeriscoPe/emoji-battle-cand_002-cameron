const DEFAULT_SCHEMA = "public";

function requireEnv(key: string): string {
  const value = process.env[key];
  if (!value) {
    throw new Error(`Missing required env var: ${key}`);
  }
  return value;
}

export function getSchemaName(): string {
  const rawUrl = requireEnv("DATABASE_URL");
  const parsedUrl = new URL(rawUrl);
  const explicitSchema = process.env.DB_SCHEMA;
  const urlSchema = parsedUrl.searchParams.get("schema");

  return explicitSchema ?? urlSchema ?? DEFAULT_SCHEMA;
}

export function getDatabaseUrl(): string {
  const rawUrl = requireEnv("DATABASE_URL");
  const parsedUrl = new URL(rawUrl);
  const schema = getSchemaName();

  parsedUrl.searchParams.set("schema", schema);
  return parsedUrl.toString();
}

export function getGitSha(): string {
  return process.env.GIT_SHA ?? "dev";
}

export function isProduction(): boolean {
  return process.env.NODE_ENV === "production";
}
