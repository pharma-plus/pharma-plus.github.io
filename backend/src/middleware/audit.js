import { pool } from '../db/pool.js';

/**
 * Journalisation d'audit (append-only).
 * Peut être utilisée comme middleware ou appelée directement.
 */
export async function auditLog({
  pharmacyId = null,
  userId = null,
  action,
  module,
  entity = null,
  entityId = null,
  oldValues = null,
  newValues = null,
  ip = null,
  device = null,
}) {
  try {
    await pool.query(
      `INSERT INTO audit_logs
        (pharmacy_id, user_id, action, module, entity, entity_id, old_values, new_values, ip_address, device)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10)`,
      [pharmacyId, userId, action, module, entity, entityId,
       oldValues ? JSON.stringify(oldValues) : null,
       newValues ? JSON.stringify(newValues) : null, ip, device],
    );
  } catch (err) {
    // L'audit ne doit jamais faire échouer l'opération principale.
    console.error('[audit] écriture impossible', err.message);
  }
}

/** Usine : crée un logger lié à la requête courante. */
export function auditLogger(req) {
  return (payload) => auditLog({
    pharmacyId: req.user?.pharmacyId ?? null,
    userId: req.user?.id ?? null,
    ip: req.ip,
    device: req.headers['user-agent'] ?? null,
    ...payload,
  });
}
