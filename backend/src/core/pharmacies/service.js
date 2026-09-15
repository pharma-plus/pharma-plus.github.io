import argon2 from 'argon2';
import { query, withTransaction } from '../../db/pool.js';
import { auditLog } from '../../middleware/audit.js';
import {
  NotFoundError, ConflictError, AppError,
} from '../../utils/errors.js';
import { uuid, sanitizeUser } from '../../utils/crypto.js';
import { paginate } from '../../utils/response.js';

const SYSTEM_ROLE_IDS = {
  super_admin: '00000000-0000-0000-0000-000000000001',
  pharmacy_admin: '00000000-0000-0000-0000-000000000002',
};

const DEFAULT_SETTINGS = {
  receipt: { width: 80, show_logo: true, footer: '', include_tva: true },
  alerts: { low_stock: true, expiry_days: 90 },
  pos: { require_pin_for_refund: true, receipt_copy: 1 },
  inventory: { expiry_warning_days: 90 },
};

export const pharmaciesService = {
  /**
   * Provisionnement d'une pharmacie (Super Administrateur) :
   * pharmacie + licence + succursale principale + clonage des rôles
   * système + compte administrateur initial.
   */
  async create(data, actor) {
    const pharmacyId = uuid();
    const branchId = uuid();
    const adminRoleId = uuid();

    const { user, pharmacy, license } = await withTransaction(null, async (client) => {
      const existing = await client.query('SELECT id FROM pharmacies WHERE slug = $1', [data.slug]);
      if (existing.rows[0]) throw new ConflictError('Ce slug est déjà utilisé');

      await client.query(
        `INSERT INTO pharmacies (id, slug, name, legal_name, address, city, phone,
                                 whatsapp, email, website, currency, languages, default_lang,
                                 timezone, colors, settings, status)
         VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16,$17)`,
        [pharmacyId, data.slug, data.name, data.legal_name ?? null, data.address ?? null,
         data.city ?? null, data.phone ?? null, data.whatsapp ?? null, data.email ?? null,
         data.website ?? null, data.currency ?? 'MAD',
         data.languages ?? ['fr', 'ar', 'en'], data.default_lang ?? 'fr',
         data.timezone ?? 'Africa/Casablanca',
         JSON.stringify(data.colors ?? {}), JSON.stringify(DEFAULT_SETTINGS),
         data.status ?? 'active'],
      );

      const expiry = data.license_duration_months
        ? new Date(Date.now() + data.license_duration_months * 30 * 24 * 3600 * 1000)
        : new Date(Date.now() + 30 * 24 * 3600 * 1000);

      await client.query(
        `INSERT INTO licenses (id, pharmacy_id, type, status, billing_cycle,
                               activation_date, expiry_date, max_users, max_branches, modules)
         VALUES (gen_random_uuid(), $1, $2, 'active', $3, now(), $4, $5, $6, $7)`,
        [pharmacyId, data.license_type ?? 'trial', data.billing_cycle ?? 'monthly',
         expiry, data.max_users ?? 1, data.max_branches ?? 1, JSON.stringify(data.modules ?? {})],
      );

      await client.query(
        `INSERT INTO branches (id, pharmacy_id, name, code, address, city, phone, is_main)
         VALUES ($1,$2,$3,$4,$5,$6,$7, true)`,
        [branchId, pharmacyId, `${data.name} - Siège`, data.branch_code ?? 'BR-001',
         data.address ?? null, data.city ?? null, data.phone ?? null],
      );

      // Clonage des rôles système pour la pharmacie
      const clonedRoles = await client.query(
        `INSERT INTO roles (id, pharmacy_id, name, code, is_system)
         SELECT gen_random_uuid(), $1, name, code, is_system
           FROM roles WHERE pharmacy_id IS NULL
         RETURNING id, code`,
        [pharmacyId],
      );
      const roleByCode = {};
      for (const r of clonedRoles.rows) roleByCode[r.code] = r.id;

      // Copie des permissions des rôles système vers les clones
      await client.query(
        `INSERT INTO role_permissions (role_id, permission_code)
         SELECT cr.id, rp.permission_code
           FROM roles gr
           JOIN roles cr ON cr.pharmacy_id = $1 AND cr.code = gr.code
           JOIN role_permissions rp ON rp.role_id = gr.id
          WHERE gr.pharmacy_id IS NULL`,
        [pharmacyId],
      );

      // Compte administrateur
      const adminRoleId = roleByCode.pharmacy_admin || (await client.query(
        'SELECT id FROM roles WHERE pharmacy_id = $1 AND code = $2', [pharmacyId, 'pharmacy_admin'],
      )).rows[0].id;

      const passwordHash = await argon2.hash(data.admin_password || 'Admin123!', { type: argon2.argon2id });
      const adminId = uuid();
      await client.query(
        `INSERT INTO users (id, pharmacy_id, branch_id, role_id, first_name, last_name,
                            email, phone, password_hash, must_change_password)
         VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9, true)`,
        [adminId, pharmacyId, branchId, adminRoleId,
         data.admin_first_name ?? 'Administrateur', data.admin_last_name ?? 'Pharmacie',
         data.admin_email, data.admin_phone ?? null, passwordHash],
      );

      return {
        pharmacy: { id: pharmacyId, name: data.name, slug: data.slug },
        license: { type: data.license_type ?? 'trial', expiry },
        user: { id: adminId, email: data.admin_email },
      };
    });

    await auditLog({
      pharmacyId, userId: actor?.id, action: 'create', module: 'pharmacies',
      entity: 'pharmacy', entityId: pharmacyId, newValues: pharmacy,
    });

    return { pharmacy, license, user };
  },

  async list({ page = 1, limit = 20, q, status }) {
    const pg = paginate(page, limit);
    const where = ['1=1'];
    const params = [];
    let i = 1;
    if (q) { where.push(`(name ILIKE $${i} OR slug ILIKE $${i})`); params.push(`%${q}%`); i++; }
    if (status) { where.push(`status = $${i}`); params.push(status); i++; }

    const count = await query(`SELECT count(*)::int AS total FROM pharmacies WHERE ${where.join(' AND ')}`, params);
    const { rows } = await query(
      `SELECT p.id, p.slug, p.name, p.city, p.status, p.currency, p.created_at,
              (SELECT count(*)::int FROM branches b WHERE b.pharmacy_id = p.id) AS nb_branches,
              (SELECT count(*)::int FROM users u WHERE u.pharmacy_id = p.id) AS nb_users,
              l.type AS license_type, l.status AS license_status, l.expiry_date
         FROM pharmacies p
         LEFT JOIN LATERAL (
           SELECT type, status, expiry_date FROM licenses
            WHERE pharmacy_id = p.id ORDER BY created_at DESC LIMIT 1
         ) l ON true
        WHERE ${where.join(' AND ')}
        ORDER BY p.created_at DESC
        LIMIT $${i} OFFSET $${i + 1}`,
      [...params, pg.limit, pg.offset],
    );
    return { items: rows, meta: { ...pg, total: count.rows[0].total } };
  },

  async get(id) {
    const { rows } = await query(
      `SELECT p.*,
              (SELECT count(*)::int FROM branches b WHERE b.pharmacy_id = p.id) AS nb_branches,
              (SELECT count(*)::int FROM users u WHERE u.pharmacy_id = p.id) AS nb_users
         FROM pharmacies p WHERE p.id = $1`,
      [id],
    );
    if (!rows[0]) throw new NotFoundError('Pharmacie introuvable');
    return rows[0];
  },

  /** Mise à jour des paramètres & personnalisation (par la pharmacie elle-même). */
  async updateSettings(pharmacyId, data, actor) {
    const fields = [];
    const params = [pharmacyId];
    let i = 2;
    const map = {
      name: 'name', legal_name: 'legal_name', logo_url: 'logo_url', icon_url: 'icon_url',
      banner_url: 'banner_url', colors: 'colors', address: 'address', city: 'city',
      phone: 'phone', whatsapp: 'whatsapp', email: 'email', website: 'website',
      currency: 'currency', languages: 'languages', default_lang: 'default_lang',
      timezone: 'timezone',
    };
    const oldValues = {};
    for (const [key, value] of Object.entries(data)) {
      if (!(key in map) || value === undefined) continue;
      fields.push(`${map[key]} = $${i}`);
      params.push(typeof value === 'object' && value !== null ? JSON.stringify(value) : value);
      oldValues[key] = undefined;
      i++;
    }
    if (data.settings && typeof data.settings === 'object') {
      // Merge profond pour les settings JSONB
      const merged = await query(
        `UPDATE pharmacies
            SET settings = settings || $2::jsonb
          WHERE id = $1
         RETURNING settings`,
        [pharmacyId, JSON.stringify(data.settings)],
      );
      return merged.rows[0];
    }
    if (!fields.length) return this.get(pharmacyId);

    await query(`UPDATE pharmacies SET ${fields.join(', ')} WHERE id = $1`, params);
    await auditLog({
      pharmacyId, userId: actor?.id, action: 'edit', module: 'pharmacies',
      entity: 'pharmacy', entityId: pharmacyId, newValues: data,
    });
    return this.get(pharmacyId);
  },

  async setStatus(id, status, actor) {
    const pharmacy = await this.get(id);
    await query('UPDATE pharmacies SET status = $1 WHERE id = $2', [status, id]);
    if (status === 'suspended' || status === 'deleted') {
      await query('UPDATE user_sessions SET revoked_at = now() WHERE pharmacy_id = $1', [id]);
    }
    await auditLog({
      pharmacyId: id, userId: actor?.id, action: 'status_change', module: 'pharmacies',
      entity: 'pharmacy', entityId: id, oldValues: { status: pharmacy.status }, newValues: { status },
    });
  },

  /** Statistiques d'un tenant (Super Admin). */
  async tenantStats(id) {
    const [pharmacy, branches, users, medications, sales, revenue, purchases, license] = await Promise.all([
      this.get(id),
      query('SELECT count(*)::int AS total FROM branches WHERE pharmacy_id = $1', [id]),
      query('SELECT count(*)::int AS total FROM users WHERE pharmacy_id = $1', [id]),
      query('SELECT count(*)::int AS total FROM medications WHERE pharmacy_id = $1', [id]),
      query(`SELECT count(*)::int AS total,
                    count(*) FILTER (WHERE created_at >= now() - interval '30 days')::int AS last_30d
               FROM sales WHERE pharmacy_id = $1 AND status = 'completed'`, [id]),
      query(`SELECT COALESCE(sum(total), 0)::numeric(14,2) AS total,
                    COALESCE(sum(total) FILTER (WHERE created_at >= now() - interval '30 days'), 0)::numeric(14,2) AS last_30d
               FROM sales WHERE pharmacy_id = $1 AND status = 'completed'`, [id]),
      query(`SELECT count(*)::int AS total,
                    COALESCE(sum(total), 0)::numeric(14,2) AS total_amount
               FROM purchase_orders WHERE pharmacy_id = $1`, [id]),
      query(`SELECT type, status, billing_cycle, activation_date, expiry_date,
                    max_users, max_branches, modules
               FROM licenses WHERE pharmacy_id = $1 ORDER BY created_at DESC LIMIT 1`, [id]),
    ]);
    return {
      pharmacy,
      branches: branches.rows[0].total,
      users: users.rows[0].total,
      medications: medications.rows[0].total,
      sales: sales.rows[0],
      revenue: revenue.rows[0],
      purchases: purchases.rows[0],
      license: license.rows[0] ?? null,
    };
  },

  async globalStats() {
    const [pharmacies, activeLicenses, users, sales, revenue] = await Promise.all([
      query('SELECT count(*)::int AS total, count(*) FILTER (WHERE status = \'active\')::int AS active FROM pharmacies'),
      query('SELECT count(*)::int AS active FROM licenses WHERE status = \'active\' AND expiry_date >= now()'),
      query('SELECT count(*)::int AS total FROM users'),
      query('SELECT count(*)::int AS total FROM sales WHERE status = \'completed\''),
      query('SELECT COALESCE(sum(total), 0)::numeric(14,2) AS total FROM sales WHERE status = \'completed\''),
    ]);
    return {
      pharmacies: pharmacies.rows[0],
      activeLicenses: activeLicenses.rows[0].active,
      users: users.rows[0].total,
      sales: sales.rows[0].total,
      revenue: revenue.rows[0].total,
    };
  },
};
