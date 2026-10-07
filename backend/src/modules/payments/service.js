import { query } from '../../db/pool.js';
import { auditLog } from '../../middleware/audit.js';
import { NotFoundError, ConflictError, ValidationError } from '../../utils/errors.js';
import { salesService } from '../sales/service.js';
import { paginate } from '../../utils/response.js';

/**
 * Paiements : lecture, suivi et remboursement.
 * L'enregistrement d'un paiement délègue à salesService.recordPayment
 * (logique existante : crédit client + facture) pour ne jamais dupliquer
 * la règle métier.
 */
export const paymentsService = {
  async listPayments(pharmacyId, { page = 1, limit = 20, saleId, method, status } = {}) {
    const pg = paginate(page, limit);
    const where = ['p.pharmacy_id = $1'];
    const params = [pharmacyId];
    let i = 2;
    if (saleId) { where.push(`p.sale_id = $${i}`); params.push(saleId); i++; }
    if (method) { where.push(`p.method = $${i}`); params.push(method); i++; }
    if (status) { where.push(`p.status = $${i}`); params.push(status); i++; }
    const count = await query(
      `SELECT count(*)::int AS total FROM payments p WHERE ${where.join(' AND ')}`,
      params,
    );
    const { rows } = await query(
      `SELECT p.*, u.first_name AS received_by_first_name, u.last_name AS received_by_last_name,
              s.number AS sale_number
         FROM payments p
         LEFT JOIN users u ON u.id = p.received_by
         LEFT JOIN sales s ON s.id = p.sale_id
        WHERE ${where.join(' AND ')}
        ORDER BY p.received_at DESC
        LIMIT $${i} OFFSET $${i + 1}`,
      [...params, pg.limit, pg.offset],
    );
    return { items: rows, meta: { ...pg, total: count.rows[0].total } };
  },

  async recordPayment(pharmacyId, data, actor) {
    if (!Number(data.amount) || Number(data.amount) <= 0) {
      throw new ValidationError([{ field: 'amount', message: 'Montant invalide' }]);
    }
    if (data.saleId) {
      const { rows: sales } = await query(
        'SELECT id FROM sales WHERE id = $1 AND pharmacy_id = $2',
        [data.saleId, pharmacyId],
      );
      if (!sales[0]) throw new NotFoundError('Vente introuvable');
    }
    const payment = await salesService.recordPayment(pharmacyId, data, actor);
    await auditLog({
      pharmacyId, userId: actor?.id, action: 'create', module: 'payments',
      entity: 'payment', entityId: payment.id,
      newValues: { saleId: data.saleId ?? null, method: data.method, amount: data.amount },
    });
    return payment;
  },

  async getPayment(pharmacyId, id) {
    const { rows } = await query(
      `SELECT p.*, s.number AS sale_number
         FROM payments p LEFT JOIN sales s ON s.id = p.sale_id
        WHERE p.id = $1 AND p.pharmacy_id = $2`,
      [id, pharmacyId],
    );
    if (!rows[0]) throw new NotFoundError('Paiement introuvable');
    return rows[0];
  },

  async refundPayment(pharmacyId, id, amount, reason, actor) {
    const payment = await this.getPayment(pharmacyId, id);
    if (payment.status === 'refunded') throw new ConflictError('Paiement déjà remboursé');
    if (payment.status !== 'completed') {
      throw new ConflictError('Seul un paiement complété peut être remboursé');
    }
    if (Number(amount) > Number(payment.amount)) {
      throw new ConflictError('Le montant remboursé dépasse le paiement d\'origine');
    }

    const { rows } = await query(
      `UPDATE payments SET status = 'refunded' WHERE id = $1 AND pharmacy_id = $2 RETURNING *`,
      [id, pharmacyId],
    );
    await auditLog({
      pharmacyId, userId: actor?.id, action: 'refund', module: 'payments',
      entity: 'payment', entityId: id,
      oldValues: { status: payment.status, amount: payment.amount },
      newValues: { status: 'refunded', refundedAmount: amount, reason: reason ?? null },
    });
    return { ...rows[0], refundedAmount: Number(amount), reason: reason ?? null };
  },
};
