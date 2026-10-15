// =============================================================================
// NETTOYAGE DES VENTES DE TEST (15/10/2026) — identifiées par notes 'test'
// ou numéros POS-2026-000093…098 (audit). Jamais de ventes réelles.
//
//   node scripts/cleanup_test_sales.mjs          analyse seule (dry-run)
//   node scripts/cleanup_test_sales.mjs --yes    exécute (backup JSON d'abord)
//
// Par vente : compensation stock (adjustment +qté) → suppression des
// mouvements, paiements, puis ventes (sale_items/receipts en CASCADE).
// Sauvegarde JSON complète locale : backend/backups/ (gitignoré).
// =============================================================================
import { Client } from "pg";
import "dotenv/config";
import { writeFileSync, mkdirSync } from "node:fs";
import { join, dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const EXEC = process.argv.includes("--yes");
const url = (process.env.DATABASE_URL ?? "").replace(/[?&]sslmode=[^&]*/g, "");
const db = new Client({ connectionString: url, ssl: { rejectUnauthorized: false } });
await db.connect();

const TEST_NUMBERS = [
  "POS-2026-000093", "POS-2026-000094", "POS-2026-000095",
  "POS-2026-000096", "POS-2026-000097", "POS-2026-000098",
];

try {
  const sales = await db.query(
    `select id, pharmacy_id, branch_id, user_id, number, sale_date, subtotal, discount_total,
            tax_total, total, payment_method, client_sale_id, cash_session_id, notes, created_at
     from sales
     where notes ilike '%test%' or number = any($1)
     order by created_at`,
    [TEST_NUMBERS],
  );
  console.log(`VENTES DE TEST IDENTIFIEES : ${sales.rowCount}`);
  for (const s of sales.rows)
    console.log(`  ${s.number} total=${s.total} notes=${JSON.stringify(s.notes)}`);
  if (!sales.rowCount) { console.log("Rien à nettoyer."); process.exit(0); }

  const ids = sales.rows.map((s) => s.id);

  const items = await db.query(
    `select * from sale_items where sale_id = any($1) order by sale_id`, [ids],
  );
  const pays = await db.query(
    `select * from payments where sale_id = any($1) order by sale_id`, [ids],
  );
  const moves = await db.query(
    `select * from stock_movements where reference_type='sale' and reference_id = any($1)
     order by created_at`, [ids],
  );
  const combos = await db.query(
    `select distinct branch_id, medication_id, lot_id from stock_movements
     where reference_type='sale' and reference_id = any($1)`, [ids],
  );
  const balBefore = await db.query(
    `select branch_id, medication_id, lot_id, quantity from stock_balances
     where (branch_id, medication_id, lot_id) in (
       select branch_id, medication_id, lot_id from stock_movements
       where reference_type='sale' and reference_id = any($1))
     order by medication_id, lot_id`, [ids],
  );
  console.log(`Lignes: sale_items=${items.rowCount} payments=${pays.rowCount} mouvements=${moves.rowCount}`);

  const affected = await db.query(
    `select number, medication_id, quantity, lot_id from sales s
     join sale_items si on si.sale_id = s.id where s.id = any($1)`, [ids],
  );
  console.log("PRODUITS CONCERNES :");
  for (const a of affected.rows)
    console.log(`  ${a.number} : med=${a.medication_id} qte=${a.quantity} lot=${a.lot_id}`);

  if (!EXEC) {
    console.log("\nDRY-RUN — relancer avec --yes pour exécuter (backup JSON inclus).");
    process.exit(0);
  }

  // 1) Backup JSON complet avant suppression
  const backupDir = resolve(
    process.env.BACKUP_DIR || join(dirname(fileURLToPath(import.meta.url)), "..", "backups"),
  );
  mkdirSync(backupDir, { recursive: true });
  const bfile = join(backupDir, `test-sales-cleanup-${Date.now()}.json`);
  writeFileSync(bfile, JSON.stringify({
    exported_at: new Date().toISOString(),
    sales: sales.rows, sale_items: items.rows, payments: pays.rows,
    stock_movements: moves.rows, balances_before: balBefore.rows,
  }, null, 2));
  console.log(`\nBackup JSON : ${bfile}`);

  // 2) Transaction : compensation + suppressions
  await db.query("BEGIN");
  try {
    let comp = 0;
    for (const m of moves.rows) {
      await db.query(
        `insert into stock_movements
           (pharmacy_id, branch_id, medication_id, lot_id, movement_type, quantity,
            unit_cost, reference_type, reference_id, notes, user_id)
         values ($1,$2,$3,$4,'adjustment', $5, $6, 'test_cleanup', NULL,
                 $7, $8)`,
        [
          m.pharmacy_id, m.branch_id, m.medication_id, m.lot_id,
          Math.abs(Number(m.quantity)), m.unit_cost,
          `Nettoyage ventes de test (${m.reference_id}) — compensation du mouvement de vente`,
          m.user_id,
        ],
      );
      comp++;
    }
    const delMoves = await db.query(
      `delete from stock_movements where reference_type='sale' and reference_id = any($1)`, [ids],
    );
    const delPays = await db.query(
      `delete from payments where sale_id = any($1)`, [ids],
    );
    const delSales = await db.query(
      `delete from sales where id = any($1)`, [ids],
    );
    await db.query("COMMIT");
    console.log(`COMMIT : compensations=${comp} mouvements supprimes=${delMoves.rowCount} paiements=${delPays.rowCount} ventes=${delSales.rowCount}`);
  } catch (e) {
    await db.query("ROLLBACK");
    console.error("ROLLBACK :", e.message);
    process.exit(1);
  }

  // 3) Contrôles post-nettoyage
  const left = await db.query(
    `select count(*)::int as n from sales where notes ilike '%test%' or number = any($1)`,
    [TEST_NUMBERS],
  );
  const orphItems = await db.query(
    `select count(*)::int as n from sale_items where sale_id not in (select id from sales)`,
  );
  const orphPays = await db.query(
    `select count(*)::int as n from payments where sale_id is not null and sale_id not in (select id from sales)`,
  );
  const balAfter = await db.query(
    `select branch_id, medication_id, lot_id, quantity from stock_balances
     where (branch_id, medication_id, lot_id) in (
       select branch_id, medication_id, lot_id from stock_movements
       where movement_type='adjustment' and reference_type='test_cleanup')
     order by medication_id, lot_id`,
  );
  const neg = await db.query(
    `select count(*)::int as n from stock_balances where quantity < 0`,
  );
  console.log(`POST : ventes test restantes=${left.rows[0].n} | orphelins items=${orphItems.rows[0].n} payments=${orphPays.rows[0].n} | soldes negatifs=${neg.rows[0].n}`);
  console.log("SOLDES APRES compensation :");
  for (const b of balAfter.rows) {
    const before = balBefore.rows.find(
      (x) => x.medication_id === b.medication_id && x.lot_id === b.lot_id && x.branch_id === b.branch_id,
    );
    console.log(`  med=${b.medication_id} lot=${b.lot_id} avant=${before?.quantity} apres=${b.quantity}`);
  }
} finally {
  await db.end();
}
