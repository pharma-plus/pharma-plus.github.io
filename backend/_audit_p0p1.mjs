import { Client } from "pg";
import "dotenv/config";
const url = (process.env.DATABASE_URL ?? "").replace(/[?&]sslmode=[^&]*/g, "");
const db = new Client({ connectionString: url, ssl: { rejectUnauthorized: false } });
await db.connect();
const one = async (q, p = []) => (await db.query(q, p)).rows;
try {
  // 1. MATRICE RBAC (codes sensibles par role)
  const roles = await one("select id, code, name from roles order by id");
  const rp = await one("select role_id, permission_code from role_permissions");
  console.log("== RBAC (sensibles) ==");
  for (const r of roles) {
    const codes = rp.filter(x => x.role_id === r.id).map(x => x.permission_code);
    const sens = codes.filter(c => /^(users|backups|settings|employees):(create|edit|delete|approve)$/.test(c));
    console.log(` ${r.code}: ${codes.length} perms | sensibles: ${sens.join(",") || "-"}`);
  }
  // 2. PIN : format des hashes + presence clair
  const pins = await one("select email, pin_hash from users where pin_hash is not null");
  const fmt = pins.map(p => ({ email: p.email, f: p.pin_hash.slice(0, 7), len: p.pin_hash.length, ok: p.pin_hash.startsWith("$argon2") }));
  console.log("== PIN hashes (" + pins.length + ") ==");
  fmt.forEach(f => console.log(" " + f.email + " prefix=" + f.f + " len=" + f.len + " argon2=" + f.ok));
  const cleartext = pins.filter(p => /^\d{4,6}$/.test(p.pin_hash));
  console.log(" PIN en clair: " + cleartext.length);
  // 3. VENTES TEST identifiables (preuves fiables, lecture seule)
  const sales = await one(`select s.id, s.number, s.total, s.sale_type, s.created_at, u.email,
    (select count(*)::int from sale_items si where si.sale_id = s.id) as lignes
    from sales s left join users u on u.id = s.user_id
    order by s.created_at desc limit 25`);
  console.log("== 25 dernieres ventes ==");
  sales.forEach(s => console.log(" " + s.number + " total=" + s.total + " type=" + s.sale_type + " " + String(s.created_at).slice(0, 16) + " by=" + (s.email ?? "?") + " lignes=" + s.lignes));
  // 4. COHERENCE: total vs lignes vs paiements (TOUTES les ventes)
  const inc = await one(`select s.id, s.number, s.total,
    coalesce((select sum(quantity*unit_price) from sale_items si where si.sale_id=s.id),0) as somme_lignes,
    coalesce((select sum(amount) from payments p where p.sale_id=s.id),0) as somme_paye
    from sales s`);
  const bad = inc.filter(r => Math.abs(Number(r.total) - Number(r.somme_lignes)) > 0.01);
  const badPay = inc.filter(r => Math.abs(Number(r.somme_paye) - Number(r.total)) > 0.01);
  console.log("== COHERENCE ==");
  console.log(" ventes=" + inc.length + " total!=somme_lignes=" + bad.length + " paiements!=total=" + badPay.length);
  bad.slice(0, 5).forEach(b => console.log("  LIGNE " + b.number + " total=" + b.total + " lignes=" + b.somme_lignes));
  badPay.slice(0, 8).forEach(b => console.log("  PAY " + b.number + " total=" + b.total + " paye=" + b.somme_paye));
  // 5. STOCK negatif / coherence balances vs mouvements
  const neg = await one("select count(*)::int n from stock_balances where quantity < 0");
  console.log("== STOCK == balances negatives: " + neg[0].n);
  // 6. FK cassees
  const orph = await one(`select
    (select count(*)::int from sale_items si left join sales s on s.id=si.sale_id where s.id is null) as si_s,
    (select count(*)::int from payments p left join sales s on s.id=p.sale_id where s.id is null) as pay_s,
    (select count(*)::int from stock_movements m left join medications md on md.id=m.medication_id where md.id is null) as mv_med,
    (select count(*)::int from sales s left join users u on u.id=s.user_id where u.id is null) as s_u`);
  console.log("== FK orphelins == sale_items->sales:" + orph[0].si_s + " payments->sales:" + orph[0].pay_s + " movements->med:" + orph[0].mv_med + " sales->users:" + orph[0].s_u);
  // 7. Comptes actifs sans role / inactifs avec sessions actives
  const norole = await one("select count(*)::int n from users where role_id is null and status='active'");
  const sess = await one("select count(*)::int n from user_sessions us join users u on u.id=us.user_id where us.revoked_at is null and us.expires_at > now() and u.status <> 'active'");
  console.log("== COMPTES == actifs sans role: " + norole[0].n + " | sessions actives de comptes non-actifs: " + sess[0].n);
  const sessDetail = await one("select u.email, u.status, count(*)::int n from user_sessions us join users u on u.id=us.user_id where us.revoked_at is null and us.expires_at > now() and u.status <> 'active' group by u.email, u.status");
  sessDetail.forEach(s => console.log("  " + s.email + " status=" + s.status + " sessions=" + s.n));
} finally { await db.end(); }