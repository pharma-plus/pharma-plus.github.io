// Réparation ciblée du double-encodage (UTF-8 → cp1252 → UTF-8).
// N'agit QUE sur les séquences suspectes, préserve le reste du fichier.
//   node _fix_mojibake.mjs           → dry-run (liste + aperçu)
//   node _fix_mojibake.mjs --apply   → écrit les fichiers contenant au moins 1 séquence
import { readFileSync, writeFileSync } from "node:fs";
import { globSync } from "node:fs";
import { join } from "node:path";
import { fileURLToPath } from "node:url";

const apply = process.argv.includes("--apply");
const root = fileURLToPath(new URL("../frontend/lib", import.meta.url));

// cp1252 étendu 0x80-0x9F → Unicode (inversé pour reconstruire les octets).
const CP_EXT = new Map([
  [0x20ac,0x80],[0x201a,0x82],[0x0192,0x83],[0x201e,0x84],[0x2026,0x85],
  [0x2020,0x86],[0x2021,0x87],[0x02c6,0x88],[0x2030,0x89],[0x0160,0x8a],
  [0x2039,0x8b],[0x0152,0x8c],[0x017d,0x8e],[0x2018,0x91],[0x2019,0x92],
  [0x201c,0x93],[0x201d,0x94],[0x2022,0x95],[0x2013,0x96],[0x2014,0x97],
  [0x02dc,0x98],[0x2122,0x99],[0x0161,0x9a],[0x203a,0x9b],[0x0153,0x9c],
  [0x017e,0x9e],[0x0178,0x9f],
]);

// Retourne l'octet cp1252 pour un char cp1252 (Latin-1 + étendu), ou null.
const cpByte = (ch) => {
  const c = ch.codePointAt(0);
  if (c >= 0xa0 && c <= 0xff) return c;
  return CP_EXT.get(c) ?? null;
};

// Répare U+00C3/U+00C2 suivi d'un bloc cp1252, et les triples â€X.
function repair(s) {
  let out = "";
  let n = 0;
  for (let i = 0; i < s.length; ) {
    const c = s.codePointAt(i);
    const two = s.slice(i, i + 2);
    const three = s.slice(i, i + 3);
    // Cas 1 : â€ + X (3 chars) → octets E2 / 80 / X
    if (
      c === 0xe2 &&
      s.codePointAt(i + 1) === 0x20ac &&
      i + 2 < s.length &&
      cpByte(s[i + 2]) !== null &&
      s[i + 2].codePointAt(0) >= 0x80 &&
      s[i + 2].codePointAt(0) < 0xa0
    ) {
      const b = cpByte(s[i + 2]);
      const bytes = Uint8Array.of(0xe2, 0x80, b);
      const dec = new TextDecoder("utf-8", { fatal: false }).decode(bytes);
      if (!dec.includes("\uFFFD")) {
        out += dec;
        n++;
        i += 3;
        continue;
      }
    }
    // Cas 2 : C3/C2 + suiveur latin1 → 2 octets UTF-8
    if (
      (c === 0xc3 || c === 0xc2) &&
      i + 1 < s.length &&
      s.codePointAt(i + 1) >= 0xa0 &&
      s.codePointAt(i + 1) <= 0xff
    ) {
      const b1 = c;
      const b2 = s.codePointAt(i + 1);
      const bytes = Uint8Array.of(b1, b2);
      const dec = new TextDecoder("utf-8", { fatal: false }).decode(bytes);
      // Un caractère non-remplacement ET non-ASCII => réparation validée.
      if (!dec.includes("\uFFFD") && dec.codePointAt(0) > 0x7f) {
        out += dec;
        n++;
        i += 2;
        continue;
      }
    }
    out += s[i];
    i += 1;
  }
  return { out, n };
}

const files = globSync("**/*.dart", { cwd: root, recursive: true });
let totalSeq = 0;
const touched = [];
for (const rel of files) {
  const p = join(root, rel);
  const s = readFileSync(p, "utf8");
  const { out, n } = repair(s);
  if (n === 0) continue;
  totalSeq += n;
  touched.push(`${rel} (${n} seq)`);
  if (apply && out !== s) writeFileSync(p, out, "utf8");
  if (!apply) {
    // Aperçu des 3 premières réparations.
    let shown = 0;
    const origLines = s.split("\n");
    const newLines = out.split("\n");
    for (let i = 0; i < origLines.length && shown < 3; i++) {
      if (origLines[i] !== newLines[i]) {
        console.log(`  ~ ${rel}:${i + 1}`);
        console.log(`      avant: ${origLines[i].trim().slice(0, 90)}`);
        console.log(`      apres: ${newLines[i].trim().slice(0, 90)}`);
        shown++;
      }
    }
  }
}
console.log(`\n${apply ? "RÉPARÉ" : "CANDIDAT"}: ${touched.length} fichiers, ${totalSeq} séquences`);
for (const t of touched) console.log(`  - ${t}`);
