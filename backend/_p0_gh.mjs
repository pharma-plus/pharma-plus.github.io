import { execSync } from "node:child_process";
// 1. le mot de passe ACTUEL est-il dans l'historique git ? (compteur uniquement)
import { readFileSync } from "node:fs";
const repo = "C:\\Users\\Merouan\\Documents\\Default Project\\pharma-maroc-gold";
const raw = readFileSync("C:\\Users\\Merouan\\PHARMA+_mot_de_passe_admin_A_CHANGER.txt", "utf8");
const lines = raw.split(/\r?\n/); const sep = lines.findIndex((l) => l.startsWith("===="));
const cur = lines.slice(sep + 1).find((l) => l.trim().length > 0) ?? "";
let n = -1;
try { const out = execSync(`git log --all --oneline -S "${cur.replace(/[$]/g, "\\$")}"`, { cwd: repo, encoding: "utf8", maxBuffer: 8 * 1024 * 1024 }); n = out.split("\n").filter(l => l.trim()).length; } catch (e) { n = -2; }
console.log("occurrences_mdp_actuel_dans_historique=" + n + " (-2=erreur commande)");
// 2. GitHub Actions : runs backup-nightly (PAT en memoire, jamais affiche)
import { execSync as ex2 } from "node:child_process";
const fill = ex2("git credential fill", { input: "protocol=https\nhost=github.com\n\n", encoding: "utf8", cwd: repo, env: { ...process.env, GIT_TERMINAL_PROMPT: "0", GCM_INTERACTIVE: "never" } });
const pass = (fill.split("\n").find(l => l.startsWith("password=")) ?? "").slice(9);
const user = (fill.split("\n").find(l => l.startsWith("username=")) ?? "").slice(9);
if (!pass) { console.log("gh_api=credential_absent"); process.exit(0); }
const auth = "Basic " + Buffer.from(user + ":" + pass).toString("base64");
const r = await fetch("https://api.github.com/repos/pharma-plus/pharma-plus.github.io/actions/workflows/backup-nightly.yml/runs?per_page=8", { headers: { authorization: auth, accept: "application/vnd.github+json", "user-agent": "pharma-audit" } });
const j = await r.json().catch(() => ({}));
console.log("gh_api=" + r.status + " runs=" + (j.workflow_runs?.length ?? "?"));
for (const run of (j.workflow_runs ?? [])) {
  const concl = String(run.conclusion ?? run.status);
  const title = String(run.display_title ?? "").slice(0, 40);
  console.log("  run " + run.run_number + " " + run.created_at + " " + concl + " (" + title + ")");
}