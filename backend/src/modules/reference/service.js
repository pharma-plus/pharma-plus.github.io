import fs from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { query, withTransaction } from '../../db/pool.js';
import { auditLog } from '../../middleware/audit.js';
import { NotFoundError, ConflictError } from '../../utils/errors.js';
import { uuid } from '../../utils/crypto.js';
import { paginate } from '../../utils/response.js';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const DATA_FILE = path.join(__dirname, 'reference_data.json');

const PRODUCT_SELECT = `
  SELECT p.id, p.category_code, p.name, p.dci, p.substance_active, p.dosage, p.form,
         p.presentation, p.laboratory, p.therapeutic_class, p.commercial_status,
         p.amm_number, p.code_produit, p.barcode_ean13, p.qr_code, p.ppv, p.ph, p.pfht,
         p.tva_rate, p.rcp_url, p.notice_url, p.source, p.source_updated_at, p.updated_at,
         c.name_fr AS category_name, c.icon AS category_icon, c.color AS category_color`;

const PRODUCT_JOIN = `
  LEFT JOIN reference_categories c ON c.code = p.category_code`;

async function loadSnapshot() {
  const raw = await fs.readFile(DATA_FILE, 'utf8');
  return JSON.parse(raw);
}

export const referenceService = {
  // ---------------- Catégories ----------------
  async categories() {
    const { rows } = await query(
      `SELECT c.code, c.name_fr, c.name_ar, c.name_en, c.icon, c.color, c.sort_order,
              (SELECT count(*)::int FROM reference_products p
                WHERE p.category_code = c.code AND p.commercial_status = 'commercialise') AS nb_products
         FROM reference_categories c
        ORDER BY c.sort_order, c.name_fr`,
    );
    return rows;
  },

  // ---------------- Produits de référence ----------------
  async products({ page = 1, limit = 20, q, category, status, commercialStatus } = {}) {
    const pg = paginate(page, limit);
    const where = [];
    const params = [];
    let i = 1;

    if (q) {
      where.push(`(p.name ILIKE $${i} OR p.dci ILIKE $${i} OR p.barcode_ean13 = $${i} OR p.laboratory ILIKE $${i})`);
      params.push(`%${q}%`);
      i++;
    }
    if (category) { where.push(`p.category_code = $${i}`); params.push(category); i++; }
    if (status) { where.push(`p.commercial_status = $${i}`); params.push(status); i++; }

    const whereSql = where.length ? `WHERE ${where.join(' AND ')}` : '';
    const { rows: countRows } = await query(
      `SELECT count(*)::int AS total FROM reference_products p ${whereSql}`, params,
    );
    const { rows } = await query(
      `${PRODUCT_SELECT} FROM reference_products p ${PRODUCT_JOIN} ${whereSql}
        ORDER BY p.name LIMIT $${i} OFFSET $${i + 1}`,
      [...params, pg.limit, pg.offset],
    );
    return { items: rows, meta: { ...pg, total: countRows[0].total } };
  },

  async getProduct(id) {
    const { rows } = await query(
      `${PRODUCT_SELECT} FROM reference_products p ${PRODUCT_JOIN} WHERE p.id = $1`, [id],
    );
    if (!rows[0]) throw new NotFoundError('Produit de référence introuvable');
    return rows[0];
  },

  // ---------------- Synchronisation ----------------
  async syncStatus() {
    const [run, total] = await Promise.all([
      query(
        `SELECT id, source, started_at, finished_at, status, new_count, modified_count,
                price_changed_count, status_changed_count, removed_count, notes
           FROM reference_sync_runs ORDER BY started_at DESC LIMIT 1`,
      ),
      query(`SELECT count(*)::int AS total FROM reference_products`),
    ]);
    const last = run.rows[0] ?? null;
    const updatedAt = last?.finished_at ?? null;
    return { last_run: last, total: total.rows[0].total, updated_at: updatedAt };
  },

  async syncHistory({ limit = 20 } = {}) {
    const { rows } = await query(
      `SELECT id, source, started_at, finished_at, status, new_count, modified_count,
              price_changed_count, status_changed_count, removed_count, notes
         FROM reference_sync_runs ORDER BY started_at DESC LIMIT $1`,
      [limit],
    );
    return rows;
  },

  async updates({ limit = 30, type } = {}) {
    const where = type ? 'WHERE change_type = $2' : '';
    const params = type ? [limit, type] : [limit];
    const { rows } = await query(
      `SELECT u.id, u.barcode, u.name, u.change_type, u.fields, u.created_at, u.sync_run_id,
              u.product_id, r.source
         FROM reference_product_updates u
         LEFT JOIN reference_sync_runs r ON r.id = u.sync_run_id
         ${where}
        ORDER BY u.created_at DESC LIMIT $1`,
      params,
    );
    return rows;
  },

  /**
   * Synchronise la base de référence à partir du fichier officiel fourni.
   * Ne supprime jamais de données : les retraits sont journalisés uniquement.
   */
  async runSync(actor) {
    const snapshot = await loadSnapshot();
    const { source } = snapshot;

    const runId = uuid();
    await query(
      `INSERT INTO reference_sync_runs (id, source, status)
       VALUES ($1, $2, 'running')`,
      [runId, source],
    );

    const counters = { new: 0, modified: 0, price: 0, status: 0, removed: 0 };
    const barcodes = new Set(snapshot.products.map((p) => p.barcode_ean13).filter(Boolean));

    try {
      await withTransaction(null, async (client) => {
        for (const item of snapshot.products) {
          const existing = await client.query(
            `SELECT id, ppv, ph, pfht, commercial_status, source
               FROM reference_products WHERE barcode_ean13 = $1`,
            [item.barcode_ean13],
          );

          const row = existing.rows[0];
          const fields = {};

          if (!row) {
            await client.query(
              `INSERT INTO reference_products
                 (id, category_code, name, dci, substance_active, dosage, form, presentation,
                  laboratory, therapeutic_class, commercial_status, amm_number, code_produit,
                  barcode_ean13, qr_code, ppv, ph, pfht, tva_rate, rcp_url, notice_url,
                  source, source_updated_at)
               VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16,$17,$18,$19,$20,$21,$22,$23)`,
              [uuid(), item.category_code ?? null, item.name, item.dci ?? null,
               item.substance_active ?? null, item.dosage ?? null, item.form ?? null,
               item.presentation ?? null, item.laboratory ?? null, item.therapeutic_class ?? null,
               item.commercial_status ?? 'commercialise', item.amm_number ?? null,
               item.code_produit ?? null, item.barcode_ean13 ?? null, item.qr_code ?? null,
               item.ppv ?? null, item.ph ?? null, item.pfht ?? null, item.tva_rate ?? 20,
               item.rcp_url ?? null, item.notice_url ?? null, source, snapshot.updated_at ?? null],
            );
            await client.query(
              `INSERT INTO reference_product_updates (sync_run_id, product_id, barcode, name, change_type, fields)
               VALUES ($1,$2,$3,$4,'new','{}')`,
              [runId, null, item.barcode_ean13 ?? null, item.name],
            );
            counters.new++;
            continue;
          }

          const changes = {};
          if (Number(row.ppv) !== Number(item.ppv ?? row.ppv)) {
            changes.ppv = { old: row.ppv, new: item.ppv };
            fields.ppv = item.ppv;
          }
          if (Number(row.ph) !== Number(item.ph ?? row.ph)) {
            changes.ph = { old: row.ph, new: item.ph };
            fields.ph = item.ph;
          }
          if (Number(row.pfht) !== Number(item.pfht ?? row.pfht)) {
            changes.pfht = { old: row.pfht, new: item.pfht };
            fields.pfht = item.pfht;
          }
          const priceChanged = Object.keys(changes).length > 0;

          let statusChanged = false;
          if (row.commercial_status !== (item.commercial_status ?? row.commercial_status)) {
            statusChanged = true;
            changes.commercial_status = { old: row.commercial_status, new: item.commercial_status };
          }

          if (priceChanged || statusChanged) {
            await client.query(
              `UPDATE reference_products
                  SET ppv = COALESCE($1, ppv), ph = COALESCE($2, ph), pfht = COALESCE($3, pfht),
                      commercial_status = COALESCE($4, commercial_status), source = $5,
                      source_updated_at = $6, updated_at = now()
                WHERE id = $7`,
              [fields.ppv ?? null, fields.ph ?? null, fields.pfht ?? null,
               item.commercial_status ?? null, source, snapshot.updated_at ?? null, row.id],
            );
            const types = [];
            if (priceChanged) types.push('price_changed');
            if (statusChanged) types.push('status_changed');
            for (const t of types) {
              await client.query(
                `INSERT INTO reference_product_updates (sync_run_id, product_id, barcode, name, change_type, fields)
                 VALUES ($1,$2,$3,$4,$5,$6)`,
                [runId, row.id, item.barcode_ean13 ?? null, item.name, t, JSON.stringify(changes)],
              );
            }
            if (priceChanged) counters.price++;
            if (statusChanged) counters.status++;
            counters.modified++;
          }
        }

        // Produits de la même source absents du nouveau fichier (retraits signalés)
        if (barcodes.size > 0) {
          const { rows: removedRows } = await client.query(
            `SELECT id, barcode_ean13, name FROM reference_products
              WHERE source = $1 AND barcode_ean13 IS NOT NULL AND barcode_ean13 <> ALL($2::text[])`,
            [source, [...barcodes]],
          );
          for (const r of removedRows) {
            await client.query(
              `INSERT INTO reference_product_updates (sync_run_id, product_id, barcode, name, change_type, fields)
               VALUES ($1,$2,$3,$4,'removed','{}')`,
              [runId, r.id, r.barcode_ean13, r.name],
            );
            counters.removed++;
          }
        }

        await client.query(
          `UPDATE reference_sync_runs
              SET status = 'completed', finished_at = now(),
                  new_count = $1, modified_count = $2, price_changed_count = $3,
                  status_changed_count = $4, removed_count = $5
            WHERE id = $6`,
          [counters.new, counters.modified, counters.price, counters.status, counters.removed, runId],
        );
      });

      await auditLog({
        pharmacyId: actor?.pharmacyId ?? null,
        userId: actor?.id,
        action: 'sync', module: 'reference', entity: 'reference_sync_run', entityId: runId,
        newValues: { source, counters },
      });
      return this.syncStatus();
    } catch (err) {
      await query(
        `UPDATE reference_sync_runs SET status = 'failed', finished_at = now(), notes = $1 WHERE id = $2`,
        [String(err?.message ?? err).slice(0, 500), runId],
      );
      throw err;
    }
  },

  // ---------------- Import vers le catalogue de la pharmacie ----------------
  async importToCatalog(pharmacyId, productId, { priceSale, pricePurchase, reorderLevel = 10, minStock = 5 }, actor) {
    const product = await this.getProduct(productId);
    if (product.commercial_status !== 'commercialise') {
      throw new ConflictError(`Produit non commercialisable : ${product.commercial_status}`);
    }

    const existing = await query(
      `SELECT id FROM medications WHERE pharmacy_id = $1 AND barcode_ean13 = $2`,
      [pharmacyId, product.barcode_ean13],
    );
    if (existing.rows[0]) {
      throw new ConflictError(`Ce produit existe déjà dans votre catalogue (${product.name})`);
    }

    const id = uuid();
    const pricePur = pricePurchase ?? product.pfht ?? 0;
    const priceSel = priceSale ?? product.ppv ?? pricePur * 1.3;
    const margin = pricePur > 0 ? ((priceSel - pricePur) / pricePur) * 100 : 0;

    await query(
      `INSERT INTO medications (id, pharmacy_id, category_id, family_id, laboratory_id,
                                name, dci, generic_name, dosage, form, presentation,
                                barcode_ean13, price_purchase, price_sale, tva_rate, margin,
                                prescription_required, reorder_level, min_stock, status, is_public)
       VALUES ($1,$2,NULL,NULL,NULL,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,false,$14,$15,'available',false)`,
      [id, pharmacyId, product.name, product.dci ?? null, product.substance_active ?? null,
       product.dosage ?? null, product.form ?? null, product.presentation ?? null,
       product.barcode_ean13 ?? null, pricePur, priceSel, product.tva_rate ?? 20,
       Math.round(margin * 100) / 100, reorderLevel ?? 10, minStock ?? 5],
    );

    // Le laboratoire : réutiliser ou créer
    if (product.laboratory) {
      const lab = await query(
        `SELECT id FROM laboratories WHERE pharmacy_id = $1 AND name = $2 LIMIT 1`,
        [pharmacyId, product.laboratory],
      );
      const labId = lab.rows[0]?.id ?? null;
      if (labId) {
        await query(`UPDATE medications SET laboratory_id = $1 WHERE id = $2`, [labId, id]);
      } else {
        const newLabId = uuid();
        await query(
          `INSERT INTO laboratories (id, pharmacy_id, name) VALUES ($1,$2,$3)`,
          [newLabId, pharmacyId, product.laboratory],
        );
        await query(`UPDATE medications SET laboratory_id = $1 WHERE id = $2`, [newLabId, id]);
      }
    }

    await auditLog({
      pharmacyId, userId: actor?.id,
      action: 'create', module: 'reference', entity: 'medication', entityId: id,
      newValues: { name: product.name, barcode: product.barcode_ean13, importedFrom: product.source },
    });
    return { id, name: product.name, barcode: product.barcode_ean13 };
  },
};
