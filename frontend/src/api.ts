const DEFAULT_API_BASE = "http://localhost:3000";

const apiBase =
  (import.meta as { env?: Record<string, string> }).env?.VITE_API_BASE ||
  DEFAULT_API_BASE;

export type MatchResponse = {
  ok: boolean;
  matchId: string;
  state: Record<string, unknown>;
};

async function request<T>(
  path: string,
  options: RequestInit = {}
): Promise<T> {
  const response = await fetch(`${apiBase}${path}`, {
    headers: {
      "Content-Type": "application/json",
      ...(options.headers ?? {})
    },
    ...options
  });

  if (!response.ok) {
    const text = await response.text();
    throw new Error(text || `Request failed with ${response.status}`);
  }

  return (await response.json()) as T;
}

export async function createMatch(playerId: string): Promise<MatchResponse> {
  return request("/matches", {
    method: "POST",
    body: JSON.stringify({ playerId })
  });
}

export async function joinMatch(
  matchId: string,
  playerId: string
): Promise<MatchResponse> {
  return request(`/matches/${matchId}/join`, {
    method: "POST",
    body: JSON.stringify({ playerId })
  });
}

export async function submitPick(
  matchId: string,
  playerId: string,
  emoji: string,
  idempotencyKey: string
): Promise<MatchResponse> {
  return request(`/matches/${matchId}/pick`, {
    method: "POST",
    headers: {
      "Idempotency-Key": idempotencyKey
    },
    body: JSON.stringify({ playerId, emoji })
  });
}

export async function getMatchState(matchId: string): Promise<MatchResponse> {
  return request(`/matches/${matchId}`);
}

export async function getHealth(): Promise<Record<string, unknown>> {
  return request("/health");
}
