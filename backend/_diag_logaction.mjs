// Diagnostic : quels appels _logAction(sb, pid, { existent et dans quelles routes.
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";

const p = fileURLToPath(
  new URL("../supabase/functions/pharma-api/index.ts", import.meta.url),
);
const edge = readFileSync(p, "utf8");

const re = /_logAction\(sb, pid, \{/g;
let m;
let n = 0;
while ((m = re.exec(edge))) {
  n++;
  const line = edge.slice(0, m.index).split("\n").length;
  const ctx = edge.slice(Math.max(0, m.index - 2500), m.index);
  const routes = [...ctx.matchAll(/path === "([^"]+)"/g)].map((r) => r[1]);
  const methods = [...ctx.matchAll(/method === "([A-Z]+)"/g)].map((r) => r[1]);
  console.log(
    `#${n} L${line} route="${routes.at(-1) ?? "?"}" method="${methods.at(-1) ?? "?"}"`,
  );
}
console.log(`total=${n}`);
