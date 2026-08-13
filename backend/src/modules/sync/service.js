import { query } from '../../db/pool.js';
import { auditLog } from '../../middleware/audit.js';
import { NotFoundError } from '../../utils/errors.js';

/**
 * Synchronisation hors-ligne : l'app mobile conserve un journal local
 * (SQLite) et synchronise par entité via une révision incrémentale.
 */
export const syncService = {
  /** Révision la plus récente par entité (état du serveur). */
  async serverState(pharmacyId) {
    const { rows } = await query(
      `SELECT entity, last_revision, COALESCE(finished_at, started_at) AS updated_at
         FROM sync_operations
        WHERE pharmacy_id = $1 ORDER BY entity`,
      [pharmacyId],
    );
    return rows;
  },

  /** Enregistre l'état de synchronisation d'un appareil. */
  async push(pharmacyId, data, actor) {
    const { rows } = await query(
      `INSERT INTO sync_operations (pharmacy_id, device_id, entity, last_revision, status, error, started_at, finished_at)
       VALUES ($1,$2,$3,$4,$5,$6,now(), CASE WHEN $5 = 'success' THEN now() ELSE NULL END)
       ON CONFLICT (device_id, entity)
       DO UPDATE SET last_revision = GREATEST(sync_operations.last_revision, EXCLUDED.last_revision),
                     status = EXCLUDED.status,
                     error = EXCLUDED.error,
                     started_at = now(),
                     finished_at = CASE WHEN EXCLUDED.status = 'success' THEN now() ELSE sync_operations.finished_at END
       RETURNING *`,
      [pharmacyId, data.deviceId, data.entity, data.lastRevision ?? 0, data.status ?? 'success', data.error ?? null],
    );
    await auditLog({ pharmacyId, userId: actor?.id, action: 'sync', module: 'sync', entity: 'sync_operation', entityId: rows[0].id, newValues: { deviceId: data.deviceId, entity: data.entity } });
    return rows[0];
  },

  /**
   * Récupère les modifications depuis une révision.
   * Le delta incrémental s'appuie sur la colonne `revision` (catalogue).
   */
  async pull(pharmacyId, entity, { sinceRevision = 0, limit = 500 }) {
    const deltaEntities = ['medications'];
    if (!deltaEntities.includes(entity)) {
      throw new NotFoundError(`Entité non synchronisable en delta : ${entity}`);
    }
    const { rows } = await query(
      `SELECT * FROM ${entity}
        WHERE pharmacy_id = $1 AND revision > $2
        ORDER BY revision LIMIT $3`,
      [pharmacyId, sinceRevision, limit],
    );
    const { rows: maxRow } = await query(
      `SELECT COALESCE(max(revision), 0)::bigint AS max_revision FROM ${entity} WHERE pharmacy_id = $1`,
      [pharmacyId],
    );
    return {
      entity,
      sinceRevision,
      maxRevision: maxRow[0].max_revision,
      hasMore: rows.length === limit,
      rows,
    };
  },
};
