// Extrait la page officielle grossistes-repartiteurs de medicament.ma
// et genere un CSV pour data/imports/import_suppliers.mjs (source verifiable).
import fs from "node:fs";

const URL = "https://medicament.ma/grossistes-repartiteurs/";
const res = await fetch(URL, { headers: { "user-agent": "Mozilla/5.0 (PHARMA+ import outil)" } });
if (!res.ok) { console.error("HTTP", res.status); process.exit(1); }
const html = await res.text();
fs.writeFileSync("reports/imports/grossistes_medicament_ma_source.html", html, "utf8");

// Corps de la liste : entre le h3 (2e occurrence du titre) et le footer
const body = html
  .replace(/<script[\s\S]*?<\/script>/gi, " ")
  .replace(/<style[\s\S]*?<\/style>/gi, " ")
  .replace(/<[^>]+>/g, "\n")
  .replace(/&nbsp;/g, " ").replace(/&#8217;|&rsquo;/g, "'").replace(/&amp;/g, "&");
const t1 = body.toUpperCase().indexOf("GROSSISTES REPARTITEURS");
const start = body.toUpperCase().indexOf("GROSSISTES REPARTITEURS", t1 + 1);
const end = body.indexOf("Derni", start);
const section = body.slice(start, end > 0 ? end : start + 20000);

const lines = section.split(/\r?\n/).map((l) => l.replace(/\s+/g, " ").trim()).filter(Boolean);
const entries = [];
let cur = null;
const isName = (l) => /^(SOCI[OE]T[EA]?\.?\s|SOICETE\s|SOPHACENTRE\b|U\.P\.M\.|U\.G\.|SOCIETE\s)/i.test(l) && !/^TEL|^FAX|^LOT|^ZONE|^N°|^RUE|^KM|^B\.P|^QUART|^DAR|^RESID|^HAY|^1 |^100|^130|^15 |^21 |^26,|^299|^30 |^33|^43|^69|^76|^82|^303/i.test(l);
for (const l of lines) {
  if (l.toUpperCase() === "GROSSISTES REPARTITEURS") continue;
  if (/^(Navigation|Accueil|Professionnels|Liens|Organismes|medicament\.ma ©)/i.test(l)) break;
  if (isName(l)) {
    if (cur) entries.push(cur);
    cur = { name: l.replace(/^SOICETE\s+/i, "SOCIETE ").replace(/\s+/g, " ").trim(), addr: [], tel: "", fax: "" };
    continue;
  }
  if (!cur) continue;
  const tel = l.match(/TEL[^0-9]*(.+)$/i);
  const fax = l.match(/F[AI]X[^0-9]*(.+)$/i);
  if (tel) cur.tel = tel[1].replace(/[^0-9.+/ ]/g, "").trim();
  else if (fax) cur.fax = fax[1].replace(/[^0-9.+/ ]/g, "").trim();
  else if (/^(B\.?P\.?|LOT|ZONE|RUE|BD |BLD|QUART|N°|KM |ROUTE|RESID|HAY|DAR|IMM|AV |Boulevard)/i.test(l) || /^[0-9]/.test(l) || /^[A-ZÀ-Ý\s'-]{3,}$/.test(l)) cur.addr.push(l);
  else if (cur.tel === "" && /^[0-9.+/ ]{8,}$/.test(l)) cur.tel = l;
}
if (cur) entries.push(cur);

const esc = (s) => `"${String(s ?? "").replace(/"/g, '""')}"`;
const rows = ["name,phone,address,city,type,status,notes"];
const cities = /CASABLANCA|TANGER|AGADIR|FES|RABAT|MARRAKECH|OUJDA|SALE|TETOUAN|KENITRA|MEKNES|SAFI|LARACHE|BENI MELLAL|NADOR|MOHAMADIA|AIT MELLOUL|DHEIRA|BERKANE|TAZA|SIDI MOUMENE/i;
for (const e of entries) {
  const addr = e.addr.join(", ");
  const cityM = addr.match(cities);
  const city = cityM ? cityM[0].toUpperCase() : "";
  const notes = `Source: medicament.ma/grossistes-repartiteurs (recupere le ${new Date().toISOString().slice(0, 10)})${e.fax ? " | fax " + e.fax : ""} — a verifier avant usage commercial`;
  rows.push([esc(e.name), esc(e.phone || e.tel), esc(addr), esc(city), '"grossiste"', '"active"', esc(notes)].join(","));
}
fs.writeFileSync("data/imports/suppliers/grossistes_medicament_ma.csv", rows.join("\n") + "\n", "utf8");
console.log("ENTRIES:", entries.length);
console.log(entries.slice(0, 5).map((e) => `${e.name} | tel=${e.tel} | addr=${e.addr.join(" / ")}`).join("\n"));
