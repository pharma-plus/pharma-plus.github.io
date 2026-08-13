import jwt from 'jsonwebtoken';
import crypto from 'node:crypto';
import argon2 from 'argon2';
import { authenticator } from 'otplib';
import { config } from '../../config/index.js';
import { query, withTransaction } from '../../db/pool.js';
import { auditLog } from '../../middleware/audit.js';
import {
  AppError, UnauthorizedError, ForbiddenError, ConflictError,
} from '../../utils/errors.js';
import { sha256, sanitizeUser, uuid } from '../../utils/crypto.js';

const JWT_2FA_PURPOSE = 'pharma-2fa';

/** Émet la paire access (JWT) + refresh (opaque) et crée la session. */
async function createSession(client, user, device) {
  const sessionId = uuid();
  const tokenId = crypto.randomBytes(32).toString('hex');
  const accessTokenHash = sha256(tokenId);
  const accessToken = jwt.sign(
    {
      sub: user.id,
      sid: sessionId,
      tkh: tokenId,
      pharmacyId: user.pharmacy_id,
      isSuperAdmin: user.is_super_admin,
      branchId: user.branch_id,
      roleId: user.role_id,
    },
    config.jwt.secret,
    { issuer: config.jwt.issuer, expiresIn: config.jwt.accessTtl },
  );
  const refreshToken = crypto.randomBytes(48).toString('hex');
  const refreshTokenHash = sha256(refreshToken);
  const expiresAt = new Date(Date.now() + parseTtlMs(config.jwt.refreshTtl));

  await client.query(
    `INSERT INTO user_sessions
       (id, user_id, pharmacy_id, access_token_hash, refresh_token_hash,
        device_name, device_type, ip_address, user_agent, expires_at)
     VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10)`,
    [sessionId, user.id, user.pharmacy_id, accessTokenHash, refreshTokenHash,
     device?.name ?? null, device?.type ?? null, device?.ip ?? null,
     device?.userAgent ?? null, expiresAt],
  );

  return { accessToken, refreshToken, expiresAt };
}

function parseTtlMs(ttl) {
  const match = String(ttl).match(/^(\d+)([smhd])$/);
  if (!match) return 30 * 24 * 60 * 60 * 1000;
  const [, n, unit] = match;
  const mult = { s: 1e3, m: 60e3, h: 3600e3, d: 86400e3 };
  return Number(n) * mult[unit];
}

async function buildSessionToken(client, user, device) {
  return createSession(client, user, device);
}

export const authService = {
  /**
   * Connexion : vérifie identifiants, verrouillage, puis 2FA éventuelle.
   */
  async login(email, password, device) {
    const { rows } = await query(
      `SELECT u.*, r.code AS role_code, r.name AS role_name,
              p.name AS pharmacy_name, p.slug AS pharmacy_slug,
              p.status AS pharmacy_status
         FROM users u
         LEFT JOIN roles r ON r.id = u.role_id
         LEFT JOIN pharmacies p ON p.id = u.pharmacy_id
        WHERE lower(u.email) = lower($1)`,
      [email],
    );
    const user = rows[0];
    if (!user) {
      throw new UnauthorizedError('Identifiants incorrects');
    }

    if (user.pharmacy_id && ['suspended', 'deleted'].includes(user.pharmacy_status)) {
      throw new ForbiddenError('Pharmacie suspendue. Contactez l\'administrateur.');
    }

    if (user.status === 'locked' && user.locked_until && user.locked_until > new Date()) {
      throw new ForbiddenError('Compte verrouillé. Réessayez plus tard.');
    }

    const passwordOk = await argon2.verify(user.password_hash, password);
    if (!passwordOk) {
      await this.recordFailedAttempt(user.id);
      throw new UnauthorizedError('Identifiants incorrects');
    }

    await query('UPDATE users SET failed_attempts = 0, locked_until = NULL WHERE id = $1', [user.id]);

    if (user.two_factor_enabled) {
      const challenge = jwt.sign(
        { sub: user.id, purpose: JWT_2FA_PURPOSE, step: 'challenge' },
        config.jwt.secret,
        { issuer: config.jwt.issuer, expiresIn: '10m' },
      );
      return { requireTwoFactor: true, twoFactorToken: challenge };
    }

    await query('UPDATE users SET last_login_at = now() WHERE id = $1', [user.id]);
    await auditLog({
      pharmacyId: user.pharmacy_id, userId: user.id,
      action: 'login', module: 'auth', entity: 'user', entityId: user.id,
      ip: device?.ip, device: device?.userAgent,
    });

    const session = await withTransaction(user.pharmacy_id, (client) =>
      createSession(client, user, device));

    return {
      user: sanitizeUser(user),
      pharmacy: { id: user.pharmacy_id, name: user.pharmacy_name, slug: user.pharmacy_slug },
      role: { code: user.role_code, name: user.role_name },
      ...session,
    };
  },

  async recordFailedAttempt(userId) {
    await query(
      `UPDATE users
          SET failed_attempts = failed_attempts + 1,
              locked_until = CASE
                WHEN failed_attempts + 1 >= $2 THEN now() + ($3 * interval '1 minute')
                ELSE locked_until END
        WHERE id = $1`,
      [userId, config.security.maxLoginAttempts, config.security.lockoutMinutes],
    );
  },

  /**
   * Valide le code 2FA (TOTP) et crée la session complète.
   */
  async verifyTwoFactor(twoFactorToken, code, device) {
    let payload;
    try {
      payload = jwt.verify(twoFactorToken, config.jwt.secret, { issuer: config.jwt.issuer });
    } catch {
      throw new UnauthorizedError('Jeton 2FA invalide ou expiré');
    }
    if (payload.purpose !== JWT_2FA_PURPOSE) throw new UnauthorizedError('Jeton 2FA invalide');

    const { rows } = await query('SELECT * FROM users WHERE id = $1', [payload.sub]);
    const user = rows[0];
    if (!user || !user.two_factor_secret) throw new UnauthorizedError('2FA non configurée');

    const valid = authenticator.verify({ token: String(code), secret: user.two_factor_secret });
    if (!valid) throw new UnauthorizedError('Code 2FA incorrect');

    await query('UPDATE users SET last_login_at = now() WHERE id = $1', [user.id]);
    await auditLog({
      pharmacyId: user.pharmacy_id, userId: user.id,
      action: 'login_2fa', module: 'auth', entity: 'user', entityId: user.id,
      ip: device?.ip, device: device?.userAgent,
    });

    const session = await withTransaction(user.pharmacy_id, (client) =>
      createSession(client, user, device));
    return { user: sanitizeUser(user), ...session };
  },

  /**
   * Rafraîchit les jetons (rotation). Détecte la réutilisation d'un
   * refresh token déjà consommé → révoque toutes les sessions.
   */
  async refresh(refreshToken, device) {
    const hash = sha256(refreshToken);
    const { rows } = await query(
      `SELECT s.id AS session_id, s.revoked_at, s.expires_at, s.user_id, s.pharmacy_id,
              u.status AS user_status, u.is_super_admin
         FROM user_sessions s
         JOIN users u ON u.id = s.user_id
        WHERE s.refresh_token_hash = $1`,
      [hash],
    );
    const session = rows[0];
    if (!session) throw new UnauthorizedError('Jeton de rafraîchissement invalide');

    if (session.revoked_at) {
      // Rejeu détecté → révocation de toutes les sessions de l'utilisateur
      await query('UPDATE user_sessions SET revoked_at = now() WHERE user_id = $1', [session.user_id]);
      throw new UnauthorizedError('Jeton réutilisé — toutes les sessions ont été révoquées');
    }
    if (session.expires_at < new Date()) throw new UnauthorizedError('Session expirée');
    if (session.user_status !== 'active') throw new ForbiddenError('Compte inactif');

    const { rows: users } = await query(
      `SELECT * FROM users WHERE id = $1`, [session.user_id],
    );
    const user = users[0];

    const newTokens = await withTransaction(session.pharmacy_id, async (client) => {
      await client.query('UPDATE user_sessions SET revoked_at = now() WHERE id = $1', [session.session_id]);
      return createSession(client, user, device);
    });

    return newTokens;
  },

  async logout(sessionId) {
    await query('UPDATE user_sessions SET revoked_at = now() WHERE id = $1', [sessionId]);
  },

  async revokeAll(userId) {
    await query('UPDATE user_sessions SET revoked_at = now() WHERE user_id = $1', [userId]);
  },

  async changePassword(userId, currentPassword, newPassword) {
    const { rows } = await query('SELECT * FROM users WHERE id = $1', [userId]);
    const user = rows[0];
    if (!user) throw new UnauthorizedError();

    const ok = await argon2.verify(user.password_hash, currentPassword);
    if (!ok) throw new AppError('Mot de passe actuel incorrect', 400, 'BAD_PASSWORD');

    const hash = await argon2.hash(newPassword, { type: argon2.argon2id });
    await query(
      'UPDATE users SET password_hash = $1, must_change_password = false WHERE id = $2',
      [hash, userId],
    );
    await auditLog({
      pharmacyId: user.pharmacy_id, userId,
      action: 'change_password', module: 'auth', entity: 'user', entityId: userId,
    });
  },

  async setupTwoFactor(userId) {
    const { rows } = await query('SELECT * FROM users WHERE id = $1', [userId]);
    const user = rows[0];
    if (!user) throw new UnauthorizedError();

    const secret = authenticator.generateSecret();
    await query('UPDATE users SET two_factor_secret = $1, two_factor_enabled = false WHERE id = $2',
      [secret, userId]);

    const otpauth = authenticator.keyuri(user.email || user.first_name, config.otp.issuer, secret);
    return { secret, otpauth, backupCodes: null };
  },

  async confirmTwoFactor(userId, code) {
    const { rows } = await query('SELECT two_factor_secret FROM users WHERE id = $1', [userId]);
    const secret = rows[0]?.two_factor_secret;
    if (!secret) throw new AppError('2FA non initialisée', 400, 'BAD_REQUEST');
    const valid = authenticator.verify({ token: String(code), secret });
    if (!valid) throw new AppError('Code 2FA incorrect', 400, 'BAD_CODE');
    await query('UPDATE users SET two_factor_enabled = true WHERE id = $1', [userId]);
  },

  async disableTwoFactor(userId, code) {
    const { rows } = await query('SELECT two_factor_secret FROM users WHERE id = $1', [userId]);
    const secret = rows[0]?.two_factor_secret;
    if (!secret) return;
    const valid = authenticator.verify({ token: String(code), secret });
    if (!valid) throw new AppError('Code 2FA incorrect', 400, 'BAD_CODE');
    await query(
      'UPDATE users SET two_factor_enabled = false, two_factor_secret = NULL WHERE id = $1',
      [userId],
    );
  },

  async me(userId) {
    const { rows } = await query(
      `SELECT u.id, u.first_name, u.last_name, u.email, u.phone, u.photo_url,
              u.status, u.must_change_password, u.two_factor_enabled, u.branch_id,
              u.pharmacy_id, u.role_id, r.name AS role_name, r.code AS role_code,
              p.name AS pharmacy_name, p.slug AS pharmacy_slug, p.colors, p.currency,
              b.name AS branch_name
         FROM users u
         LEFT JOIN roles r ON r.id = u.role_id
         LEFT JOIN pharmacies p ON p.id = u.pharmacy_id
         LEFT JOIN branches b ON b.id = u.branch_id
        WHERE u.id = $1`,
      [userId],
    );
    const user = rows[0];
    if (!user) throw new UnauthorizedError();

    const perms = await query(
      `SELECT rp.permission_code FROM role_permissions rp WHERE rp.role_id = $1`,
      [user.role_id],
    );
    user.permissions = perms.rows.map((r) => r.permission_code);
    return user;
  },
};
