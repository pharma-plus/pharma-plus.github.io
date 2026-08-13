import { query } from '../../db/pool.js';
import { auditLog } from '../../middleware/audit.js';
import { NotFoundError } from '../../utils/errors.js';
import { uuid } from '../../utils/crypto.js';
import { paginate } from '../../utils/response.js';

export const prescriptionsService = {
  async list(pharmacyId, { page = 1, limit = 20, status, q, from, to }) {
    const pg = paginate(page, limit);
    const where = ['p.pharmacy_id = $1'];
    const params = [pharmacyId];
    let i = 2;
    if (status) { where.push(`p.status = $${i}`); params.push(status); i++; }
    if (q) { where.push(`(p.patient_name ILIKE $${i} OR p.doctor_name ILIKE $${i})`); params.push(`%${q}%`); i++; }
    if (from) { where.push(`p.created_at >= $${i}`); params.push(from); i++; }
    if (to) { where.push(`p.created_at < $${i}`); params.push(to); i++; }

    const count = await query(`SELECT count(*)::int AS total FROM prescriptions p WHERE ${where.join(' AND ')}`, params);
    const { rows } = await query(
      `SELECT p.id, p.customer_id, c.name AS customer_name,
              p.patient_name, p.doctor_name, p.source, p.file_url, p.status, p.notes, p.filled_at,
              p.created_by, p.created_at,
              (SELECT COALESCE(sum(pi.quantity), 0)::numeric(12,3) FROM prescription_items pi
                WHERE pi.prescription_id = p.id) AS total_qty,
              (SELECT count(*)::int FROM prescription_items pi
                WHERE pi.prescription_id = p.id AND NOT pi.is_dispensed) AS pending_items
         FROM prescriptions p
         LEFT JOIN customers c ON c.id = p.customer_id
        WHERE ${where.join(' AND ')}
        ORDER BY p.created_at DESC
        LIMIT $${i} OFFSET $${i + 1}`,
      [...params, pg.limit, pg.offset],
    );
    return { items: rows, meta: { ...pg, total: count.rows[0].total } };
  },

  async get(pharmacyId, id) {
    const { rows } = await query(
      `SELECT p.*, c.name AS customer_name,
              u.first_name AS created_by_first, u.last_name AS created_by_last
         FROM prescriptions p
         LEFT JOIN customers c ON c.id = p.customer_id
         LEFT JOIN users u ON u.id = p.created_by
        WHERE p.id = $1 AND p.pharmacy_id = $2`,
      [id, pharmacyId],
    );
    if (!rows[0]) throw new NotFoundError('Ordonnance introuvable');
    const prescription = rows[0];

    const { rows: items } = await query(
      `SELECT pi.id, pi.medication_id, m.name AS medication_name, m.dosage AS medication_dosage,
              pi.dosage, pi.frequency, pi.duration, pi.quantity, pi.is_dispensed, pi.notes,
              (SELECT COALESCE(SUM(CASE WHEN l.expiry_date < CURRENT_DATE THEN b.quantity ELSE 0 END), 0)
                 FROM stock_balances b
                 JOIN lots l ON l.id = b.lot_id
                WHERE b.medication_id = pi.medication_id AND b.pharmacy_id = $2) AS expired_qty
         FROM prescription_items pi
         LEFT JOIN medications m ON m.id = pi.medication_id
        WHERE pi.prescription_id = $1
        ORDER BY pi.created_at DESC`,
      [id, pharmacyId],
    );
    return { ...prescription, items };
  },

  async create(pharmacyId, data, actor) {
    const id = uuid();
    await query(
      `INSERT INTO prescriptions (id, pharmacy_id, customer_id, patient_name, doctor_name,
                                  source, file_url, status, notes, created_by)
       VALUES ($1,$2,$3,$4,$5,$6,$7,'received',$8,$9)`,
      [id, pharmacyId, data.customerId ?? null, data.patientName ?? null,
       data.doctorName ?? null, data.source ?? 'manual', data.fileUrl ?? null,
       data.notes ?? null, actor?.id],
    );
    await this.replaceItems(pharmacyId, id, data.items || []);
    await auditLog({ pharmacyId, userId: actor?.id, action: 'create', module: 'prescriptions', entity: 'prescription', entityId: id, newValues: { patientName: data.patientName } });
    return this.get(pharmacyId, id);
  },

  async update(pharmacyId, id, data, actor) {
    await this.get(pharmacyId, id);
    const fields = [];
    const params = [id, pharmacyId];
    let i = 3;
    const map = {
      customerId: 'customer_id', patientName: 'patient_name', doctorName: 'doctor_name',
      fileUrl: 'file_url', notes: 'notes',
    };
    for (const [key, value] of Object.entries(data)) {
      if (!(key in map) || value === undefined) continue;
      fields.push(`${map[key]} = $${i}`);
      params.push(value);
      i++;
    }
    if (fields.length) {
      await query(`UPDATE prescriptions SET ${fields.join(', ')}, updated_at = now() WHERE id = $1 AND pharmacy_id = $2`, params);
    }
    if (data.items) await this.replaceItems(pharmacyId, id, data.items);
    await auditLog({ pharmacyId, userId: actor?.id, action: 'edit', module: 'prescriptions', entity: 'prescription', entityId: id, newValues: data });
    return this.get(pharmacyId, id);
  },

  async replaceItems(pharmacyId, prescriptionId, items) {
    await query('DELETE FROM prescription_items WHERE prescription_id = $1', [prescriptionId]);
    for (const item of items) {
      await query(
        `INSERT INTO prescription_items (id, pharmacy_id, prescription_id, medication_id, dosage, frequency,
                                          duration, quantity, is_dispensed, notes)
         VALUES (gen_random_uuid(),$1,$2,$3,$4,$5,$6,$7,$8,$9)`,
        [pharmacyId, prescriptionId, item.medicationId ?? null, item.dosage ?? null,
         item.frequency ?? null, item.duration ?? null, item.quantity ?? 0,
         item.isDispensed ?? false, item.notes ?? null],
      );
    }
  },

  async markDispensed(pharmacyId, id, itemIds, actor) {
    const prescription = await this.get(pharmacyId, id);
    const ids = Array.isArray(itemIds) && itemIds.length ? itemIds : prescription.items.map((it) => it.id);
    await query(
      `UPDATE prescription_items SET is_dispensed = true
        WHERE prescription_id = $1 AND id = ANY($2::uuid[])`,
      [id, ids],
    );
    const { rows } = await query(
      `SELECT count(*)::int AS total, count(*) FILTER (WHERE NOT is_dispensed)::int AS pending
         FROM prescription_items WHERE prescription_id = $1`,
      [id],
    );
    let newStatus = prescription.status;
    if (rows[0].pending === 0 && newStatus === 'received') newStatus = 'filled';
    await query('UPDATE prescriptions SET status = $1, filled_at = now() WHERE id = $2', [newStatus, id]);
    await auditLog({ pharmacyId, userId: actor?.id, action: 'edit', module: 'prescriptions', entity: 'prescription', entityId: id, newValues: { status: newStatus, itemIds: ids } });
    return this.get(pharmacyId, id);
  },

  async updateStatus(pharmacyId, id, status, actor) {
    const prescription = await this.get(pharmacyId, id);
    const allowed = ['received', 'processing', 'filled', 'rejected', 'archived'];
    if (!allowed.includes(status)) throw new NotFoundError('Statut invalide');
    await query(
      `UPDATE prescriptions SET status = $1,
              filled_at = CASE WHEN $1 = 'filled' THEN now() ELSE filled_at END,
              updated_at = now()
        WHERE id = $2 AND pharmacy_id = $3`,
      [status, id, pharmacyId],
    );
    await auditLog({ pharmacyId, userId: actor?.id, action: 'edit', module: 'prescriptions', entity: 'prescription', entityId: id, oldValues: { status: prescription.status }, newValues: { status } });
    return this.get(pharmacyId, id);
  },

  async remove(pharmacyId, id, actor) {
    const existing = await this.get(pharmacyId, id);
    await query('DELETE FROM prescriptions WHERE id = $1 AND pharmacy_id = $2', [id, pharmacyId]);
    await auditLog({ pharmacyId, userId: actor?.id, action: 'delete', module: 'prescriptions', entity: 'prescription', entityId: id, newValues: { patientName: existing.patient_name } });
  },
};
