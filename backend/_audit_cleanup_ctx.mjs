// Pharmacie du superadmin + job backup en attente + retours sur ventes test.
import { Client } from "pg";
import "dotenv/config";

const url = (process.env.DATABASE_URL ?? "").replace(/[?&]sslmode=[^&]*/g, "");
const db = new Client({ connectionString: url, ssl: { rejectUnauthorized: false } });
await db.connect();
try {
  const sa = await db.query(
    `select u.id, u.email, u.pharmacy_id, u.role_id, r.name as role_name
     from users u left join roles r on r.id = u.role_id
     where u.email = $1`,
    [process.env.SUPER_ADMIN_EMAIL],
  );
  console.log("SUPERADMIN:", JSON.stringify(sa.rows[0]));

  const job = await db.query(
    `select id, pharmacy_id, type, scope, status, created_at from backups order by created_at desc limit 5`,
  );
  console.log("BACKUPS :", JSON.stringify(job.rows, null, 1));

  const ret = await db.query(
    `select count(*)::int as n from sale_returns where sale_id in (
       select id from sales where notes ilike '%test%' or number in
       ('POS-2026-000093','POS-2026-000094','POS-2026-000095','POS-2026-000096','POS-2026-000097','POS-2026-000098'))`,
  );
  console.log("RETOURS sur ventes de test =", ret.rows[0].n);

  const refs = await db.query(
    `select reference_type, movement_type, count(*)::int as n
     from stock_movements group by 1,2 order by n desc`,
  );
  console.log("STOCK_MOVEMENTS refs :");
  for (const r of refs.rows) console.log(`  ref=${r.reference_type} type=${r.movement_type} n=${r.n}`);

  const testMoves = await db.query(
    `select sm.movement_type, sm.reference_type, sm.medication_id, sm.quantity, sm.lot_id, sm.branch_id, sm.pharmacy_id, sm.id
     from stock_movements sm
     where sm.reference_id in (select id from sales where notes ilike '%test%' or number in
       ('POS-2026-000093','POS-2026-000094','POS-2026-000095','POS-2026-000096','POS-2026-000097','POS-2026-000098'))
     order by sm.created_at`,
  );
  console.log("MOUVEMENTS des ventes de test =", testMoves.rowCount);
  for (const m of testMoves.rows)
    console.log(`  ${m.movement_type} ref=${m.reference_type} med=${m.medication_id} qty=${m.quantity} lot=${m.lot_id} br=${m.branch_id}`);
} finally {
  await db.end();
}
