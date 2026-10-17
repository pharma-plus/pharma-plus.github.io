// Buckets storage + policies + ventes de test (colonnes sales en vrai).
import { Client } from "pg";
import "dotenv/config";

const url = (process.env.DATABASE_URL ?? "").replace(/[?&]sslmode=[^&]*/g, "");
const db = new Client({ connectionString: url, ssl: { rejectUnauthorized: false } });
await db.connect();
try {
  const b = await db.query("select name, public from storage.buckets order by name");
  console.log("BUCKETS :", b.rows.map((r) => `${r.name}${r.public ? "(public)" : ""}`).join(", ") || "(aucun)");

  const pol = await db.query(
    `select policyname, cmd, qual from pg_policies where schemaname='storage' limit 20`,
  );
  console.log(`POLICIES storage = ${pol.rowCount}`);
  for (const p of pol.rows) console.log(`  ${p.policyname} [${p.cmd}]`);

  const cols = await db.query(
    `select column_name from information_schema.columns where table_name='sales' order by ordinal_position`,
  );
  console.log("COLONNES sales :", cols.rows.map((r) => r.column_name).join(", "));

  const sales = await db.query(
    `select id, number, notes, total, created_at,
            (select count(*) from sale_items si where si.sale_id = s.id)::int as items,
            (select count(*) from payments p where p.sale_id = s.id)::int as pays
     from sales s
     where s.notes ilike '%test%' or s.number in
       ('POS-2026-000093','POS-2026-000094','POS-2026-000095','POS-2026-000096','POS-2026-000097','POS-2026-000098')
     order by s.created_at`,
  ).catch(async (e) => {
    console.log("retry sans colonne number :", e.message);
    return db.query(
      `select id, null::text as number, notes, total, created_at,
              (select count(*) from sale_items si where si.sale_id = s.id)::int as items,
              (select count(*) from payments p where p.sale_id = s.id)::int as pays
       from sales s where s.notes ilike '%test%' order by s.created_at`,
    );
  });
  console.log(`VENTES DE TEST = ${sales.rowCount}`);
  for (const s of sales.rows)
    console.log(`  ${s.number ?? s.id} total=${s.total} items=${s.items} pays=${s.pays} notes=${JSON.stringify(s.notes)} ${s.created_at?.toISOString?.()}`);

  const allSales = await db.query(
    `select count(*)::int as n, min(created_at) as mn, max(created_at) as mx from sales`,
  );
  console.log("VENTES totales =", allSales.rows[0].n, "depuis", allSales.rows[0].mn?.toISOString?.());
} finally {
  await db.end();
}
