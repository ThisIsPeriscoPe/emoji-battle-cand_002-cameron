import fs from "fs";
import path from "path";

type Rules = {
  emojis: string[];
  winsAgainst: Record<string, string[]>;
};

let cachedRules: Rules | null = null;

export function loadRules(): Rules {
  if (cachedRules) {
    return cachedRules;
  }

  const rulesPath = path.join(process.cwd(), "rules.json");
  const file = fs.readFileSync(rulesPath, "utf-8");
  const parsed = JSON.parse(file) as Rules;

  cachedRules = parsed;
  return parsed;
}
