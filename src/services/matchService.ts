class NotImplementedError extends Error {
  statusCode = 501;
}

function notImplemented(step: string): never {
  throw new NotImplementedError(`TODO: ${step}`);
}

export class MatchService {
  static async createMatch(input: { playerId: string; requestId: string }) {
    void input;
    notImplemented(
      "create match, persist MatchState, and emit initial Event"
    );
  }

  static async joinMatch(input: {
    matchId: string;
    playerId: string;
    requestId: string;
  }) {
    void input;
    notImplemented(
      "load MatchState, add player, persist new state, emit Event"
    );
  }

  static async submitPick(input: {
    matchId: string;
    playerId: string;
    emoji: string;
    requestId: string;
    idempotencyKey: string;
  }) {
    void input;
    notImplemented(
      "enforce idempotency, apply pick, persist state, emit Event"
    );
  }

  static async getMatchState(input: {
    matchId: string;
    requestId: string;
  }) {
    void input;
    notImplemented("load MatchState and return to client");
  }
}
