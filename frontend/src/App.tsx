import { useMemo, useState } from "react";
import {
  createMatch,
  getHealth,
  getMatchState,
  joinMatch,
  submitPick
} from "./api";

const emojis = ["🪨", "📄", "✂️", "🦎", "🖖"];

function generateKey() {
  return `${Date.now()}-${Math.random().toString(16).slice(2)}`;
}

export function App() {
  const [playerId, setPlayerId] = useState("player-1");
  const [matchId, setMatchId] = useState("");
  const [emoji, setEmoji] = useState(emojis[0]);
  const [output, setOutput] = useState<Record<string, unknown> | null>(null);
  const [error, setError] = useState<string | null>(null);

  const idempotencyKey = useMemo(() => generateKey(), []);

  async function run(action: () => Promise<Record<string, unknown>>) {
    setError(null);
    try {
      const result = await action();
      setOutput(result);
    } catch (err) {
      setOutput(null);
      setError(err instanceof Error ? err.message : "Unknown error");
    }
  }

  return (
    <div style={{ fontFamily: "sans-serif", padding: 24 }}>
      <h1>Emoji Battle</h1>
      <p>Quick test UI for the assessment API.</p>

      <section style={{ marginBottom: 16 }}>
        <label style={{ display: "block", marginBottom: 8 }}>
          Player ID
        </label>
        <input
          value={playerId}
          onChange={(event) => setPlayerId(event.target.value)}
        />
      </section>

      <section style={{ marginBottom: 16 }}>
        <label style={{ display: "block", marginBottom: 8 }}>
          Match ID
        </label>
        <input
          value={matchId}
          onChange={(event) => setMatchId(event.target.value)}
        />
      </section>

      <section style={{ marginBottom: 16 }}>
        <label style={{ display: "block", marginBottom: 8 }}>
          Pick
        </label>
        <select value={emoji} onChange={(event) => setEmoji(event.target.value)}>
          {emojis.map((item) => (
            <option key={item} value={item}>
              {item}
            </option>
          ))}
        </select>
      </section>

      <div style={{ display: "flex", gap: 12, flexWrap: "wrap" }}>
        <button onClick={() => run(() => getHealth())}>Health</button>
        <button
          onClick={() =>
            run(async () => {
              const result = await createMatch(playerId);
              if (result.matchId) {
                setMatchId(result.matchId);
              }
              return result;
            })
          }
        >
          Create Match
        </button>
        <button
          onClick={() => run(() => joinMatch(matchId, playerId))}
          disabled={!matchId}
        >
          Join Match
        </button>
        <button
          onClick={() =>
            run(() =>
              submitPick(matchId, playerId, emoji, idempotencyKey)
            )
          }
          disabled={!matchId}
        >
          Submit Pick
        </button>
        <button
          onClick={() => run(() => getMatchState(matchId))}
          disabled={!matchId}
        >
          Get Match
        </button>
      </div>

      {error && (
        <pre
          style={{
            marginTop: 16,
            padding: 12,
            background: "#ffe3e3",
            color: "#b00020"
          }}
        >
          {error}
        </pre>
      )}

      {output && (
        <pre
          style={{
            marginTop: 16,
            padding: 12,
            background: "#f4f4f4"
          }}
        >
          {JSON.stringify(output, null, 2)}
        </pre>
      )}
    </div>
  );
}
