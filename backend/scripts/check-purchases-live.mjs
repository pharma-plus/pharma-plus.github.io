/**
 * Validation live du module purchases contre la vraie base (Supabase) :
 * le VRAI service est ex├®cut├® (createOrder ÔåÆ status ÔåÆ r├®ceptions ÔåÆ listes)
 * dans une transaction annul├®e (ROLLBACK) ÔÇö aucune donn├®e persist├®e.
 * Le flux complet tourne dans une transaction courte ; en cas de coupure
 * r├®seau transitoire du pooler, l'essai est relanc├® (3 max).
 *
 *   node --experimental-test-module-mocks --test scripts/check-purchases-live.mjs
 */
import { test, mock } from 'node:test';
import assert from 'node:assert/strict';
import pg from 'pg';
import 'dotenv/config';

// M├¬me logique que src/db/pool.js : `sslmode=require` dans l'URL ├®craserait
// l'option ssl explicite (pg r├®cent le traite comme verify-full) ÔåÆ on le
// retire et on passe rejectUnauthorized:false ├á la main.
const rawUrl = process.env.DATABASE_URL ?? '';
const sslConfig = /(sslmode=require|supabase|amazonaws|\.rds\.)/i.test(rawUrl)
  ? { rejectUnauthorized: false }
  : undefined;
let connectionString = rawUrl;
if (sslConfig) {
  const u = new URL(rawUrl);
  u.searchParams.delete('sslmode');
  connectionString = u.toString();
}

// Pool mock├® : toutes les requ├¬tes passent par le client de la tentative
// en cours (mutable pour permettre les relances).
let active = null;
const run = (text, params) => active.query(text, params);

mock.module(new URL('../src/db/pool.js', import.meta.url).href, {
  exports: {
    pool: { query: run, connect: async () => ({ query: run, release: () => {} }), on: () => {}, end: async () => {} },
    query: run,
    withTenant: async (_pharmacyId, fn) => fn(active),
    // S├®mantique transactionnelle fid├¿le : en cas d'├®chec de fn, seules les
    // ├®critures internes sont annul├®es (SAVEPOINT), pas la transaction externe.
    withTransaction: async (_pharmacyId, fn) => {
      await active.query('SAVEPOINT pmg_service_sp');
      try {
        const result = await fn(active);
        await active.query('RELEASE SAVEPOINT pmg_service_sp');
        return result;
      } catch (err) {
        await active.query('ROLLBACK TO SAVEPOINT pmg_service_sp');
        throw err;
      }
    },
  },
});

const { purchasesService } = await import('../src/modules/purchases/service.js');

async function seedTestData(c) {
  const ph = await c.query(
    'SELECT p.id, (SELECT b.id FROM branches b WHERE b.pharmacy_id = p.id LIMIT 1) AS branch_id FROM pharmacies p ORDER BY p.created_at NULLS LAST LIMIT 1',
  );
  if (!ph.rows[0]?.branch_id) throw new Error('Aucune pharmacie/succursale en base pour le test');
  const pharmacyId = ph.rows[0].id;
  const branchId = ph.rows[0].branch_id;

  const sup = await c.query(
    "INSERT INTO suppliers (id, pharmacy_id, name) VALUES (gen_random_uuid(), $1, 'TEST-FOURNISSEUR-LIVE') RETURNING id",
    [pharmacyId],
  );
  const med = await c.query(
    "INSERT INTO medications (id, pharmacy_id, name, price_sale, reorder_level) VALUES (gen_random_uuid(), $1, 'TEST-PRODUIT-LIVE', 25, 5) RETURNING id",
    [pharmacyId],
  );
  return { pharmacyId, branchId, supplierId: sup.rows[0].id, medicationId: med.rows[0].id };
}

test('flux achats complet sur la vraie base (transaction annul├®e)', async () => {
  let lastErr;
  for (let attempt = 1; attempt <= 3; attempt++) {
    const c = new pg.Client({ connectionString, ssl: sslConfig, keepAlive: true });
    try {
      await c.connect();
      await c.query('BEGIN');
      active = c;

      const { pharmacyId, branchId, supplierId, medicationId } = await seedTestData(c);

      // 1) Cr├®ation de la commande (draft)
      const order = await purchasesService.createOrder(
        pharmacyId,
        {
          branchId,
          supplierId,
          items: [{ medication_id: medicationId, quantity: 10, unit_cost: 12.5, tva_rate: 20, discount: 0 }],
        },
        { id: null },
      );
      const orderId = order.id;
      assert.ok(orderId, 'un id de commande est renvoy├®');
      assert.equal(order.status, 'draft');
      assert.equal(order.items.length, 1);
      assert.equal(Number(order.items[0].quantity_ordered), 10);
      assert.equal(Number(order.items[0].quantity_received), 0);
      assert.equal(Number(order.total), 150, `order re├ºu : ${JSON.stringify(order)}`); // 10 ├ù 12,5 ├ù 1,2

      // 2) Passage en "sent"
      const sent = await purchasesService.updateStatus(pharmacyId, orderId, 'sent', { id: null });
      assert.equal(sent.status, 'sent');

      // 3) R├®ception partielle (4/10) : lot + mouvement + trigger stock
      const partial = await purchasesService.receiveOrder(
        pharmacyId,
        {
          orderId,
          branchId,
          items: [{ medication_id: medicationId, quantity: 4, lot_number: 'LOT-LIVE-1', expiry_date: '2027-06-30' }],
        },
        { id: null },
      );
      assert.equal(partial.order_status, 'partial');

      const items = (await run('SELECT quantity_received FROM purchase_order_items WHERE purchase_order_id = $1', [orderId])).rows;
      assert.equal(Number(items[0].quantity_received), 4);

      const sb = (await run(
        'SELECT quantity FROM stock_balances WHERE pharmacy_id = $1 AND medication_id = $2',
        [pharmacyId, medicationId],
      )).rows;
      assert.equal(sb.length, 1, 'le trigger a cr├®├® la ligne de stock');
      assert.equal(Number(sb[0].quantity), 4);

      const lot = (await run(
        "SELECT cost_price FROM lots WHERE pharmacy_id = $1 AND lot_number = 'LOT-LIVE-1'",
        [pharmacyId],
      )).rows[0];
      assert.equal(Number(lot.cost_price), 12.5);

      const mv = (await run(
        "SELECT count(*)::int AS n FROM stock_movements WHERE pharmacy_id = $1 AND medication_id = $2 AND movement_type = 'purchase_receipt'",
        [pharmacyId, medicationId],
      )).rows[0];
      assert.equal(mv.n, 1);

      // 4) R├®ception compl├®mentaire (6/10) ÔåÆ statut received
      const done = await purchasesService.receiveOrder(
        pharmacyId,
        {
          orderId,
          branchId,
          items: [{ medication_id: medicationId, quantity: 6, lot_number: 'LOT-LIVE-2', expiry_date: '2027-09-30' }],
        },
        { id: null },
      );
      assert.equal(done.order_status, 'received');

      const total = (await run(
        'SELECT sum(quantity) AS q FROM stock_balances WHERE pharmacy_id = $1 AND medication_id = $2',
        [pharmacyId, medicationId],
      )).rows[0];
      assert.equal(Number(total.q), 10);

      // 5) Sur-r├®ception refus├®e
      await assert.rejects(
        () => purchasesService.receiveOrder(
          pharmacyId,
          { orderId, branchId, items: [{ medication_id: medicationId, quantity: 1, lot_number: 'LOT-LIVE-3', expiry_date: '2027-09-30' }] },
          { id: null },
        ),
        (err) => err.code === 'OVER_RECEIPT',
      );

      // 6) Lectures coh├®rentes
      const list = await purchasesService.listOrders(pharmacyId, { status: 'received' });
      assert.ok(list.items.some((o) => o.id === orderId));

      const receptions = await purchasesService.listReceptions(pharmacyId, { orderId });
      assert.equal(receptions.items.length, 2);

      const detail = await purchasesService.getOrder(pharmacyId, orderId);
      assert.equal(detail.status, 'received');
      assert.equal(detail.receptions.length, 2);

      await c.query('ROLLBACK');
      await c.end();
      console.log('\nTransaction annul├®e : aucune donn├®e persist├®e.');
      return;
    } catch (err) {
      try { await c.query('ROLLBACK'); } catch { /* connexion d├®j├á morte */ }
      try { await c.end(); } catch { /* idem */ }
      lastErr = err;
      if (attempt >= 3) throw err;
      console.log(`\ntentative ${attempt} ├®chou├®e (${err.code ?? err.message}) ÔÇö nouvel essaiÔÇª`);
      await new Promise((r) => setTimeout(r, 1500));
    }
  }
  throw lastErr;
});
