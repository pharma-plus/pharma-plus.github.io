import { Router } from 'express';
import Joi from 'joi';
import { validate } from '../../middleware/validate.js';
import { requireAuth, requirePerm, requireSuperAdmin } from '../../middleware/auth.js';
import { wrap } from '../../middleware/error.js';
import { ok } from '../../utils/response.js';
import { query } from '../../db/pool.js';
import { paginate } from '../../utils/response.js';

const router = Router();
router.use(requireAuth);

const listSchema = Joi.object({
  page: Joi.number().integer().min(1).default(1),
  limit: Joi.number().integer().min(1).max(200).default(20),
  module: Joi.string(),
  action: Joi.string(),
  entity: Joi.string(),
  entityId: Joi.string(),
  userId: Joi.string().uuid(),
  from: Joi.date().iso(),
  to: Joi.date().iso(),
});

// Journal d'audit (lecture seule, append-only) pour une pharmacie
router.get('/', requirePerm('audit:view'), validate({ query: listSchema }),
  wrap(async (req, res) => {
    const pg = paginate(req.query.page, req.query.limit);
    const where = ['a.pharmacy_id = $1'];
    const params = [req.user.pharmacyId];
    let i = 2;
    const { module: mod, action, entity, entityId, userId, from, to } = req.query;

    if (mod) { where.push(`a.module = $${i}`); params.push(mod); i++; }
    if (action) { where.push(`a.action = $${i}`); params.push(action); i++; }
    if (entity) { where.push(`a.entity = $${i}`); params.push(entity); i++; }
    if (entityId) { where.push(`a.entity_id = $${i}`); params.push(entityId); i++; }
    if (userId) { where.push(`a.user_id = $${i}`); params.push(userId); i++; }
    if (from) { where.push(`a.created_at >= $${i}`); params.push(from); i++; }
    if (to) { where.push(`a.created_at <= $${i}`); params.push(to); i++; }

    const count = await query(`SELECT count(*)::int AS total FROM audit_logs a WHERE ${where.join(' AND ')}`, params);
    const { rows } = await query(
      `SELECT a.id, a.action, a.module, a.entity, a.entity_id, a.old_values, a.new_values,
              a.ip_address, a.device, a.created_at,
              u.first_name, u.last_name, u.email
         FROM audit_logs a
         LEFT JOIN users u ON u.id = a.user_id
        WHERE ${where.join(' AND ')}
        ORDER BY a.created_at DESC
        LIMIT $${i} OFFSET $${i + 1}`,
      [...params, pg.limit, pg.offset],
    );
    return ok(res, rows, { ...pg, total: count.rows[0].total });
  }));

// Historique d'une entité précise
router.get('/entity/:entity/:entityId', requirePerm('audit:view'), validate({ query: listSchema }),
  wrap(async (req, res) => {
    const pg = paginate(req.query.page, req.query.limit);
    const { rows } = await query(
      `SELECT a.id, a.action, a.module, a.entity, a.entity_id, a.old_values, a.new_values,
              a.ip_address, a.device, a.created_at,
              u.first_name, u.last_name, u.email
         FROM audit_logs a
         LEFT JOIN users u ON u.id = a.user_id
        WHERE a.pharmacy_id = $1 AND a.entity = $2 AND a.entity_id = $3
        ORDER BY a.created_at DESC
        LIMIT $${4} OFFSET $${5}`,
      [req.user.pharmacyId, req.params.entity, req.params.entityId, pg.limit, pg.offset],
    );
    return ok(res, rows, { ...pg, total: rows.length });
  }));

// Résumé des actions par module
router.get('/stats', requirePerm('audit:view'),
  wrap(async (req, res) => {
    const { rows } = await query(
      `SELECT module, action, count(*)::int AS total,
              max(created_at) AS last_at
         FROM audit_logs
        WHERE pharmacy_id = $1
        GROUP BY module, action
        ORDER BY total DESC LIMIT 100`,
      [req.user.pharmacyId],
    );
    return ok(res, rows);
  }));

// Super Admin : audit global (toutes pharmacies)
router.get('/global', requireSuperAdmin, validate({ query: listSchema }),
  wrap(async (req, res) => {
    const pg = paginate(req.query.page, req.query.limit);
    const where = ['1=1'];
    const params = [];
    let i = 1;
    const { module: mod, action, from, to } = req.query;
    if (mod) { where.push(`module = $${i}`); params.push(mod); i++; }
    if (action) { where.push(`action = $${i}`); params.push(action); i++; }
    if (from) { where.push(`created_at >= $${i}`); params.push(from); i++; }
    if (to) { where.push(`created_at <= $${i}`); params.push(to); i++; }

    const count = await query(`SELECT count(*)::int AS total FROM audit_logs WHERE ${where.join(' AND ')}`, params);
    const { rows } = await query(
      `SELECT a.*, p.name AS pharmacy_name
         FROM audit_logs a
         LEFT JOIN pharmacies p ON p.id = a.pharmacy_id
        WHERE ${where.join(' AND ')}
        ORDER BY a.created_at DESC
        LIMIT $${i} OFFSET $${i + 1}`,
      [...params, pg.limit, pg.offset],
    );
    return ok(res, rows, { ...pg, total: count.rows[0].total });
  }));

export const auditRouter = router;
