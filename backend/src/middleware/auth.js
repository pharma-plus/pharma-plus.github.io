import jwt from 'jsonwebtoken';
import { config } from '../config/index.js';
import { pool } from '../db/pool.js';
import { UnauthorizedError, ForbiddenError } from '../utils/errors.js';
import { sha256 } from '../utils/crypto.js';

/** Récupère les permissions de l'utilisateur (depuis son rôle). */
async function loadPermissions(userId) {
  const { rows } = await pool.query(
    `SELECT DISTINCT rp.permission_code
       FROM role_permissions rp
       JOIN users u ON u.role_id = rp.role_id
      WHERE u.id = $1`,
    [userId],
  );
  return new Set(rows.map((r) => r.permission_code));
}

/**
 * Middleware d'authentification : vérifie le JWT, charge la session et
 * l'utilisateur, et configure le contexte tenant (RLS) pour la requête.
 */
export async function requireAuth(req, _res, next) {
  try {
    const header = req.headers.authorization || '';
    const token = header.startsWith('Bearer ') ? header.slice(7) : null;
    if (!token) throw new UnauthorizedError('Jeton manquant');

    let payload;
    try {
      payload = jwt.verify(token, config.jwt.secret, { issuer: config.jwt.issuer });
    } catch {
      throw new UnauthorizedError('Jeton invalide ou expiré');
    }

    const { rows } = await pool.query(
      `SELECT s.id AS session_id, s.revoked_at, s.expires_at,
              u.id AS user_id, u.pharmacy_id, u.branch_id, u.role_id,
              u.status AS user_status, u.is_super_admin, u.first_name, u.last_name
         FROM user_sessions s
         JOIN users u ON u.id = s.user_id
        WHERE s.id = $1 AND s.access_token_hash = $2`,
      [payload.sid, sha256(payload.tkh)],
    );

    const session = rows[0];
    if (!session || session.revoked_at) throw new UnauthorizedError('Session invalide');
    if (session.expires_at < new Date()) throw new UnauthorizedError('Session expirée');
    if (session.user_status !== 'active') throw new ForbiddenError('Compte inactif ou verrouillé');

    // Vérifie que la licence de la pharmacie est active (sauf super admin)
    if (!session.is_super_admin && session.pharmacy_id) {
      const lic = await pool.query(
        `SELECT 1 FROM licenses
          WHERE pharmacy_id = $1 AND status = 'active'
            AND activation_date <= now() AND expiry_date >= now()
          LIMIT 1`,
        [session.pharmacy_id],
      );
      if (lic.rowCount === 0) {
        throw new ForbiddenError('Licence expirée ou suspendue. Contactez votre administrateur.');
      }
    }

    // Contexte tenant pour RLS
    if (session.pharmacy_id) {
      await pool.query("SELECT set_config('app.pharmacy_id', $1, true)", [session.pharmacy_id]);
    }

    const permissions = await loadPermissions(session.user_id);

    req.user = {
      id: session.user_id,
      pharmacyId: session.pharmacy_id,
      branchId: session.branch_id,
      roleId: session.role_id,
      isSuperAdmin: session.is_super_admin,
      firstName: session.first_name,
      lastName: session.last_name,
      sessionId: session.session_id,
      permissions,
      ip: req.ip,
    };
    req.sessionId = session.session_id;

    // Mise à jour légère de l'activité
    pool.query('UPDATE user_sessions SET last_used_at = now() WHERE id = $1', [session.session_id])
      .catch(() => {});

    next();
  } catch (err) {
    next(err);
  }
}

/** Accès réservé au Super Administrateur (portail éditeur). */
export function requireSuperAdmin(req, _res, next) {
  if (!req.user?.isSuperAdmin) {
    return next(new ForbiddenError('Accès réservé au Super Administrateur'));
  }
  next();
}

/**
 * Contrôle des permissions (RBAC). Exemple : requirePerm('sales:create').
 * Accepte une liste : requirePerm(['sales:create', 'sales:edit']).
 */
export function requirePerm(perms) {
  const allowed = Array.isArray(perms) ? perms : [perms];
  return (req, _res, next) => {
    if (!req.user) return next(new UnauthorizedError());
    if (req.user.isSuperAdmin) return next();
    const granted = allowed.some((p) => req.user.permissions.has(p));
    if (!granted) return next(new ForbiddenError(`Permission requise : ${allowed.join(' ou ')}`));
    next();
  };
}
