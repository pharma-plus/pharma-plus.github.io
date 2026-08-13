import { query, withTransaction } from '../../db/pool.js';
import { auditLog } from '../../middleware/audit.js';
import { NotFoundError, ConflictError, ValidationError } from '../../utils/errors.js';
import { uuid } from '../../utils/crypto.js';
import { paginate } from '../../utils/response.js';

const MEDICATION_SELECT = `
  SELECT m.id, m.name, m.dci, m.generic_name, m.dosage, m.form, m.presentation,
         m.photo_url, m.leaflet_url, m.barcode_ean13, m.price_purchase, m.price_sale,
         m.tva_rate, m.margin, m.prescription_required, m.storage_conditions,
         m.storage_temp_min, m.storage_temp_max, m.reorder_level, m.min_stock,
         m.shelf_location, m.status, m.is_public, m.is_parapharmacie, m.created_at, m.updated_at,
         c.name AS category_name, c.id AS category_id,
         f.name AS family_name, f.id AS family_id,
         l.name AS laboratory_name, l.id AS laboratory_id`;

const MEDICATION_JOINS = `
         LEFT JOIN categories c ON c.id = m.category_id
         LEFT JOIN therapeutic_families f ON f.id = m.family_id
         LEFT JOIN laboratories l ON l.id = m.laboratory_id`;

export const catalogService = {
  // ---------------- Catégories ----------------
  // ---------------- Familles thérapeutiques ----------------
  async listFamilies(pharmacyId) {
    const { rows } = await query(
      `SELECT f.*, (SELECT count(*)::int FROM medications m WHERE m.family_id = f.id) AS nb_medications
         FROM therapeutic_families f WHERE f.pharmacy_id = $1 ORDER BY f.name`, [pharmacyId],
    );
    return rows;
  },

  async createFamily(pharmacyId, data, actor) {
    const id = uuid();
    await query(
      `INSERT INTO therapeutic_families (id, pharmacy_id, code, name)
       VALUES ($1,$2,$3,$4)`,
      [id, pharmacyId, data.code, data.name],
    );
    await auditLog({ pharmacyId, userId: actor?.id, action: 'create', module: 'catalog', entity: 'family', entityId: id, newValues: data });
    return { id, ...data };
  },

  async updateFamily(pharmacyId, id, data, actor) {
    const { rows } = await query(
      `UPDATE therapeutic_families SET code=COALESCE($1,code), name=COALESCE($2,name)
        WHERE id=$3 AND pharmacy_id=$4 RETURNING *`,
      [data.code, data.name, id, pharmacyId],
    );
    if (!rows[0]) throw new NotFoundError('Famille thérapeutique introuvable');
    await auditLog({ pharmacyId, userId: actor?.id, action: 'edit', module: 'catalog', entity: 'family', entityId: id, newValues: data });
    return rows[0];
  },

  async deleteFamily(pharmacyId, id, actor) {
    const { rows } = await query(
      `DELETE FROM therapeutic_families WHERE id=$1 AND pharmacy_id=$2 RETURNING id`, [id, pharmacyId],
    );
    if (!rows[0]) throw new NotFoundError('Famille thérapeutique introuvable');
    await auditLog({ pharmacyId, userId: actor?.id, action: 'delete', module: 'catalog', entity: 'family', entityId: id });
  },

  // ---------------- Équivalents thérapeutiques ----------------
  async listEquivalents(pharmacyId, medicationId) {
    await this.getMedication(pharmacyId, medicationId);
    const { rows } = await query(
      `SELECT me.equivalent_id AS id, m.name, m.dosage, m.form, m.price_sale
         FROM medication_equivalents me
         JOIN medications m ON m.id = me.equivalent_id
        WHERE me.medication_id = $1 AND m.pharmacy_id = $2
        ORDER BY m.name`,
      [medicationId, pharmacyId],
    );
    return rows;
  },

  async addEquivalent(pharmacyId, medicationId, equivalentId, actor) {
    await this.getMedication(pharmacyId, medicationId);
    await this.getMedication(pharmacyId, equivalentId);
    if (medicationId === equivalentId) {
      throw new ValidationError([{ field: 'equivalentId', message: 'Un médicament ne peut pas être son propre équivalent' }]);
    }
    await query(
      `INSERT INTO medication_equivalents (medication_id, equivalent_id)
       VALUES ($1,$2) ON CONFLICT DO NOTHING`,
      [medicationId, equivalentId],
    );
    await auditLog({ pharmacyId, userId: actor?.id, action: 'create', module: 'catalog', entity: 'medication_equivalent', entityId: medicationId, newValues: { equivalentId } });
    return { medication_id: medicationId, equivalent_id: equivalentId };
  },

  async listCategories(pharmacyId) {
    const { rows } = await query(
      `WITH RECURSIVE tree AS (
         SELECT id, parent_id, name, icon, color, 0 AS depth FROM categories
          WHERE pharmacy_id = $1 AND parent_id IS NULL
         UNION ALL
         SELECT c.id, c.parent_id, c.name, c.icon, c.color, t.depth + 1
           FROM categories c JOIN tree t ON t.id = c.parent_id
          WHERE c.pharmacy_id = $1
       )
       SELECT * FROM tree ORDER BY depth, name`,
      [pharmacyId],
    );
    return rows;
  },

  async createCategory(pharmacyId, data, actor) {
    const id = uuid();
    await query(
      `INSERT INTO categories (id, pharmacy_id, parent_id, name, description, icon, color)
       VALUES ($1,$2,$3,$4,$5,$6,$7)`,
      [id, pharmacyId, data.parent_id ?? null, data.name, data.description ?? null,
       data.icon ?? null, data.color ?? null],
    );
    await auditLog({ pharmacyId, userId: actor?.id, action: 'create', module: 'catalog', entity: 'category', entityId: id, newValues: data });
    return { id, ...data };
  },

  async updateCategory(pharmacyId, id, data, actor) {
    const { rows } = await query(
      `UPDATE categories SET name=COALESCE($1,name), description=COALESCE($2,description),
              icon=COALESCE($3,icon), color=COALESCE($4,color), parent_id=COALESCE($5,parent_id)
        WHERE id=$6 AND pharmacy_id=$7 RETURNING *`,
      [data.name, data.description, data.icon, data.color, data.parent_id ?? undefined, id, pharmacyId],
    );
    if (!rows[0]) throw new NotFoundError('Catégorie introuvable');
    await auditLog({ pharmacyId, userId: actor?.id, action: 'edit', module: 'catalog', entity: 'category', entityId: id, newValues: data });
    return rows[0];
  },

  async deleteCategory(pharmacyId, id, actor) {
    const { rows } = await query(
      `DELETE FROM categories WHERE id=$1 AND pharmacy_id=$2 RETURNING id`, [id, pharmacyId],
    );
    if (!rows[0]) throw new NotFoundError('Catégorie introuvable');
    await auditLog({ pharmacyId, userId: actor?.id, action: 'delete', module: 'catalog', entity: 'category', entityId: id });
  },

  // ---------------- Laboratoires ----------------
  async listLaboratories(pharmacyId) {
    const { rows } = await query(
      `SELECT l.*, (SELECT count(*)::int FROM medications m WHERE m.laboratory_id = l.id) AS nb_medications
         FROM laboratories l WHERE l.pharmacy_id = $1 ORDER BY l.name`, [pharmacyId],
    );
    return rows;
  },

  async createLaboratory(pharmacyId, data, actor) {
    const id = uuid();
    await query(
      `INSERT INTO laboratories (id, pharmacy_id, name, country, phone, email)
       VALUES ($1,$2,$3,$4,$5,$6)`,
      [id, pharmacyId, data.name, data.country ?? null, data.phone ?? null, data.email ?? null],
    );
    await auditLog({ pharmacyId, userId: actor?.id, action: 'create', module: 'catalog', entity: 'laboratory', entityId: id, newValues: data });
    return { id, ...data };
  },

  async updateLaboratory(pharmacyId, id, data, actor) {
    const { rows } = await query(
      `UPDATE laboratories SET name=COALESCE($1,name), country=COALESCE($2,country),
              phone=COALESCE($3,phone), email=COALESCE($4,email)
        WHERE id=$5 AND pharmacy_id=$6 RETURNING *`,
      [data.name, data.country, data.phone, data.email, id, pharmacyId],
    );
    if (!rows[0]) throw new NotFoundError('Laboratoire introuvable');
    await auditLog({ pharmacyId, userId: actor?.id, action: 'edit', module: 'catalog', entity: 'laboratory', entityId: id, newValues: data });
    return rows[0];
  },

  async deleteLaboratory(pharmacyId, id, actor) {
    const { rows } = await query(
      `DELETE FROM laboratories WHERE id=$1 AND pharmacy_id=$2 RETURNING id`, [id, pharmacyId],
    );
    if (!rows[0]) throw new NotFoundError('Laboratoire introuvable');
    await auditLog({ pharmacyId, userId: actor?.id, action: 'delete', module: 'catalog', entity: 'laboratory', entityId: id });
  },

  // ---------------- Médicaments ----------------
  async listMedications(pharmacyId, { page = 1, limit = 20, q, categoryId, familyId, laboratoryId, status, branchId, lowStock, expiring, is_parapharmacie: isParapharmacie }) {
    const pg = paginate(page, limit);
    const where = ['m.pharmacy_id = $1'];
    const params = [pharmacyId];
    let i = 2;

    if (q) {
      where.push(`(m.search @@ websearch_to_tsquery('simple', $${i})
                   OR m.name ILIKE $${i} OR m.barcode_ean13 = $${i})`);
      params.push(q);
      i++;
    }
    if (categoryId) { where.push(`m.category_id = $${i}`); params.push(categoryId); i++; }
    if (familyId) { where.push(`m.family_id = $${i}`); params.push(familyId); i++; }
    if (laboratoryId) { where.push(`m.laboratory_id = $${i}`); params.push(laboratoryId); i++; }
    if (status) { where.push(`m.status = $${i}`); params.push(status); i++; }
    if (typeof isParapharmacie === 'boolean') {
      where.push(`m.is_parapharmacie = $${i}`);
      params.push(isParapharmacie);
      i++;
    }

    const stockJoin = branchId
      ? `LEFT JOIN (
           SELECT medication_id, COALESCE(sum(quantity - reserved_quantity), 0) AS stock_available
             FROM stock_balances WHERE branch_id = $${i} GROUP BY medication_id
         ) sb ON sb.medication_id = m.id`
      : `LEFT JOIN (
           SELECT medication_id, COALESCE(sum(quantity - reserved_quantity), 0) AS stock_available
             FROM stock_balances GROUP BY medication_id
         ) sb ON sb.medication_id = m.id`;
    if (branchId) i++;
    if (lowStock) {
      where.push(`COALESCE(sb.stock_available, 0) <= m.reorder_level`);
    }

    const countWhere = where.filter((w) => !w.includes('sb.stock_available'));
    const count = await query(
      `SELECT count(DISTINCT m.id)::int AS total FROM medications m WHERE ${countWhere.join(' AND ')}`,
      params,
    );

    const { rows } = await query(
      `${MEDICATION_SELECT},
              COALESCE(sb.stock_available, 0) AS stock_available
         FROM medications m
         ${MEDICATION_JOINS}
         ${stockJoin}
        WHERE ${where.join(' AND ')}
        ORDER BY m.name
        LIMIT $${i} OFFSET $${i + 1}`,
      [...params, pg.limit, pg.offset],
    );

    return { items: rows, meta: { ...pg, total: count.rows[0].total } };
  },

  async getMedication(pharmacyId, id, branchId = null) {
    const params = [id, pharmacyId];
    const branchWhere = branchId ? ' AND sb.branch_id = $3' : '';
    if (branchId) params.push(branchId);
    const stockJoin = `LEFT JOIN (
         SELECT sb.medication_id, COALESCE(sum(sb.quantity - sb.reserved_quantity), 0) AS stock_available,
                min(l.expiry_date) FILTER (WHERE sb.quantity > 0) AS next_expiry,
                sum(sb.quantity) FILTER (WHERE sb.quantity > 0 AND l.expiry_date < now()) AS expired_qty
           FROM stock_balances sb JOIN lots l ON l.id = sb.lot_id
          WHERE sb.pharmacy_id = $2${branchWhere}
          GROUP BY sb.medication_id
       ) sb ON sb.medication_id = m.id`;

    const { rows } = await query(
      `${MEDICATION_SELECT},
              COALESCE(sb.stock_available, 0) AS stock_available,
              sb.next_expiry, COALESCE(sb.expired_qty, 0) AS expired_qty
         FROM medications m ${MEDICATION_JOINS} ${stockJoin}
        WHERE m.id = $1 AND m.pharmacy_id = $2`,
      params,
    );
    if (!rows[0]) throw new NotFoundError('Médicament introuvable');

    const [equivalents, suppliers] = await Promise.all([
      query(
        `SELECT m.id, m.name, m.dosage, m.form, m.price_sale
           FROM medication_equivalents me
           JOIN medications m ON m.id = me.equivalent_id
          WHERE me.medication_id = $1 AND m.pharmacy_id = $2`,
        [id, pharmacyId],
      ),
      query(
        `SELECT ms.supplier_id, s.name, ms.reference, ms.price, ms.is_primary
           FROM medication_suppliers ms JOIN suppliers s ON s.id = ms.supplier_id
          WHERE ms.medication_id = $1 AND ms.pharmacy_id = $2`,
        [id, pharmacyId],
      ),
    ]);
    return { ...rows[0], equivalents: equivalents.rows, suppliers: suppliers.rows };
  },

  async findBarcode(pharmacyId, barcode) {
    const { rows } = await query(
      `${MEDICATION_SELECT} FROM medications m
        WHERE m.barcode_ean13 = $1 AND m.pharmacy_id = $2 LIMIT 1`,
      [barcode, pharmacyId],
    );
    return rows[0] ?? null;
  },

  async createMedication(pharmacyId, data, actor) {
    const id = uuid();
    const margin = data.margin ?? (
      data.price_purchase > 0 && data.price_sale > 0
        ? ((data.price_sale - data.price_purchase) / data.price_purchase) * 100
        : 0
    );
    await query(
      `INSERT INTO medications (id, pharmacy_id, category_id, family_id, laboratory_id,
                                name, dci, generic_name, dosage, form, presentation,
                                photo_url, leaflet_url, barcode_ean13, price_purchase,
                                price_sale, tva_rate, margin, prescription_required,
                                storage_conditions, storage_temp_min, storage_temp_max,
                                reorder_level, min_stock, shelf_location, status, is_public,
                                is_parapharmacie)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16,$17,$18,$19,$20,$21,$22,$23,$24,$25,$26,$27,$28)`,
      [id, pharmacyId, data.category_id ?? null, data.family_id ?? null, data.laboratory_id ?? null,
       data.name, data.dci ?? null, data.generic_name ?? null, data.dosage ?? null,
       data.form ?? null, data.presentation ?? null, data.photo_url ?? null,
       data.leaflet_url ?? null, data.barcode_ean13 ?? null, data.price_purchase ?? 0,
       data.price_sale ?? 0, data.tva_rate ?? 20, Math.round(margin * 100) / 100,
       data.prescription_required ?? false, data.storage_conditions ?? null,
       data.storage_temp_min ?? null, data.storage_temp_max ?? null,
       data.reorder_level ?? 0, data.min_stock ?? 0, data.shelf_location ?? null,
       data.status ?? 'available', data.is_public ?? false, data.is_parapharmacie ?? false],
    );
    await this.createMedicationRelations(pharmacyId, id, data, actor);
    await auditLog({ pharmacyId, userId: actor?.id, action: 'create', module: 'catalog', entity: 'medication', entityId: id, newValues: { name: data.name, barcode: data.barcode_ean13 } });
    return this.getMedication(pharmacyId, id);
  },

  async createMedicationRelations(pharmacyId, id, data, actor) {
    if (data.equivalents?.length) {
      for (const eq of data.equivalents) {
        await query(
          `INSERT INTO medication_equivalents (medication_id, equivalent_id)
           SELECT $1, m.id FROM medications m WHERE m.id = $2 AND m.pharmacy_id = $3
           ON CONFLICT DO NOTHING`,
          [id, eq, pharmacyId],
        );
      }
    }
    if (data.suppliers?.length) {
      for (const s of data.suppliers) {
        await query(
          `INSERT INTO medication_suppliers (pharmacy_id, medication_id, supplier_id, reference, price, is_primary)
           VALUES ($1,$2,$3,$4,$5,$6) ON CONFLICT DO NOTHING`,
          [pharmacyId, id, s.supplier_id, s.reference ?? null, s.price ?? 0, s.is_primary ?? false],
        );
      }
    }
  },

  async updateMedication(pharmacyId, id, data, actor) {
    const existing = await this.getMedication(pharmacyId, id);
    const fields = [];
    const params = [id, pharmacyId];
    let i = 3;
    const map = {
      category_id: 'category_id', family_id: 'family_id', laboratory_id: 'laboratory_id',
      name: 'name', dci: 'dci', generic_name: 'generic_name', dosage: 'dosage', form: 'form',
      presentation: 'presentation', photo_url: 'photo_url', leaflet_url: 'leaflet_url',
      barcode_ean13: 'barcode_ean13', price_purchase: 'price_purchase', price_sale: 'price_sale',
      tva_rate: 'tva_rate', margin: 'margin', prescription_required: 'prescription_required',
      storage_conditions: 'storage_conditions', storage_temp_min: 'storage_temp_min',
      storage_temp_max: 'storage_temp_max', reorder_level: 'reorder_level', min_stock: 'min_stock',
      shelf_location: 'shelf_location', status: 'status', is_public: 'is_public',
    };
    for (const [key, value] of Object.entries(data)) {
      if (!(key in map) || value === undefined) continue;
      fields.push(`${map[key]} = $${i}`);
      params.push(value);
      i++;
    }
    if (fields.length) {
      await query(`UPDATE medications SET ${fields.join(', ')} WHERE id = $1 AND pharmacy_id = $2`, params);
    }
    if (data.equivalents || data.suppliers) {
      await query('DELETE FROM medication_equivalents WHERE medication_id = $1', [id]);
      await query('DELETE FROM medication_suppliers WHERE medication_id = $1', [id]);
      await this.createMedicationRelations(pharmacyId, id, data, actor);
    }
    await auditLog({ pharmacyId, userId: actor?.id, action: 'edit', module: 'catalog', entity: 'medication', entityId: id, oldValues: { name: existing.name }, newValues: data });
    return this.getMedication(pharmacyId, id);
  },

  async deleteMedication(pharmacyId, id, actor) {
    const { rows } = await query(
      `DELETE FROM medications WHERE id=$1 AND pharmacy_id=$2 RETURNING id`, [id, pharmacyId],
    );
    if (!rows[0]) throw new NotFoundError('Médicament introuvable');
    await auditLog({ pharmacyId, userId: actor?.id, action: 'delete', module: 'catalog', entity: 'medication', entityId: id });
  },

  async bulkCreate(pharmacyId, items, actor) {
    const results = [];
    for (const item of items) {
      results.push(await this.createMedication(pharmacyId, item, actor));
    }
    return results;
  },
};
