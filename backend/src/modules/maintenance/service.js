import { query } from '../../db/pool.js';
import { auditLog } from '../../middleware/audit.js';
import { ValidationError, ForbiddenError } from '../../utils/errors.js';

/**
 * Maintenance : santé de l'instance + réinitialisations contrôlées.
 * Aucune réinitialisation « complète » n'est automatisée : elle exige
 * une intervention manuelle (protection anti-destruction volontaire),
 * exactement comme le comportement Edge existant.
 */
const LEVELS = ['test_sales', 'stock_zero'];

const count = async (table, pharmacyId) => {
  const { rows } = await query(
    `SELECT count(*)::int AS n FROM ${table} WHERE pharmacy_id = $1`,
    [pharmacyId],
  );
  return rows[0]?.n ?? 0;
};

export const maintenanceService = {
  async healthCheck(pharmacyId) {
    const [medications, sales, stockBalances, users, sessions, lastSale, licence] = await Promise.all([
      count('medications', pharmacyId),
      count('sales', pharmacyId),
      count('stock_balances', pharmacyId),
      count('users', pharmacyId),
      query(
        `SELECT count(*)::int AS n FROM user_sessions
          WHERE pharmacy_id = $1 AND revoked_at IS NULL AND expires_at > now()`,
        [pharmacyId],
      ),
      query(
        `SELECT number, created_at FROM sales
          WHERE pharmacy_id = $1 ORDER BY created_at DESC LIMIT 1`,
        [pharmacyId],
      ),
      query(
        `SELECT status, expiry_date FROM licenses
          WHERE pharmacy_id = $1 ORDER BY expiry_date DESC LIMIT 1`,
        [pharmacyId],
      ),
    ]);
    return {
      status: 'ok',
      pharmacyId,
      counts: {
        medications,
        sales,
        stockBalances,
        users,
        activeSessions: sessions.rows[0]?.n ?? 0,
      },
      lastSale: lastSale.rows[0] ?? null,
      license: licence.rows[0] ?? null,
      checkedAt: new Date().toISOString(),
    };
  },

  async resetDatabase(pharmacyId, body = {}, actor) {
    const level = String(body.level ?? '');
    const confirmation = String(body.confirmation ?? '');

    if (actor?.isSuperAdmin !== true && !actor?.permissions?.has?.('settings:edit')) {
      throw new ForbiddenError('Permission settings:edit requise');
    }
    if (confirmation !== 'REINITIALISER') {
      throw new ValidationError([
        { field: 'confirmation', message: 'Confirmation invalide (tapez REINITIALISER)' },
      ]);
    }
    if (!LEVELS.includes(level)) {
      throw new ValidationError([
        {
          field: 'level',
          message: 'Niveau non supporté. Réinitialisation complète : intervention manuelle requise (protection volontaire).',
        },
      ]);
    }

    if (level === 'test_sales') {
      // Supprime UNIQUEMENT les ventes marquées 'VENTE-TEST' en notes.
      const { rows: testSales } = await query(
        `SELECT id FROM sales WHERE pharmacy_id = $1 AND notes ILIKE 'VENTE-TEST%'`,
        [pharmacyId],
      );
      const ids = testSales.map((s) => s.id);
      if (ids.length) {
        await query('DELETE FROM stock_movements WHERE reference_id = ANY($1::uuid[])', [ids]);
        await query('DELETE FROM payments WHERE sale_id = ANY($1::uuid[])', [ids]);
        await query('DELETE FROM sales WHERE id = ANY($1::uuid[])', [ids]);
      }
      await auditLog({
        pharmacyId, userId: actor?.id, action: 'maintenance_reset_test_sales',
        module: 'maintenance', entity: 'sales', newValues: { deleted: ids.length },
      });
      return { level, deletedSales: ids.length };
    }

    // stock_zero : quantités à zéro SANS supprimer les références.
    const { rowCount } = await query(
      'UPDATE stock_balances SET quantity = 0 WHERE pharmacy_id = $1',
      [pharmacyId],
    );
    await auditLog({
      pharmacyId, userId: actor?.id, action: 'maintenance_reset_stock',
      module: 'maintenance', entity: 'stock_balances', newValues: { zeroed: rowCount },
    });
    return { level, zeroed: rowCount };
  },
};
