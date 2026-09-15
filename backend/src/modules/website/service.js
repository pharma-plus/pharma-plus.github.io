import { query } from '../../db/pool.js';
import { auditLog } from '../../middleware/audit.js';
import { NotFoundError } from '../../utils/errors.js';
import { paginate } from '../../utils/response.js';

export const websiteService = {
  /**
   * Site public de la pharmacie (aucune authentification).
   * Résout la pharmacie via son slug et renvoie le contenu publié.
   */
  async publicSite(slug) {
    const { rows: pharmacy } = await query(
      `SELECT id, slug, name, logo_url, icon_url, banner_url, colors, address, city,
              phone, whatsapp, email, website, currency, languages, default_lang, timezone
         FROM pharmacies WHERE slug = $1 AND status = 'active'`,
      [slug],
    );
    if (!pharmacy[0]) throw new NotFoundError('Site introuvable');
    const pharmacyId = pharmacy[0].id;

    const [settings, medications, branches, categories, posts] = await Promise.all([
      query('SELECT * FROM website_settings WHERE pharmacy_id = $1', [pharmacyId]),
      query(
        `SELECT m.id, m.name, m.dci, m.dosage, m.form, m.presentation, m.photo_url, m.price_sale,
                m.barcode_ean13, m.is_public,
                (SELECT COALESCE(SUM(sb.quantity), 0)::numeric(12,3) FROM stock_balances sb
                  WHERE sb.medication_id = m.id AND sb.pharmacy_id = $1) AS stock
           FROM medications m WHERE m.pharmacy_id = $1 AND m.is_public AND m.status = 'available'
          ORDER BY m.name`, [pharmacyId]),
      query('SELECT id, name, address, city, phone, whatsapp FROM branches WHERE pharmacy_id = $1 ORDER BY name', [pharmacyId]),
      query(
        `SELECT id, name, slug FROM blog_categories WHERE pharmacy_id = $1 ORDER BY name`,
        [pharmacyId]),
      query(
        `SELECT p.id, p.title, p.slug, p.excerpt, p.image_url, p.published_at,
                c.name AS category_name
           FROM blog_posts p LEFT JOIN blog_categories c ON c.id = p.category_id
          WHERE p.pharmacy_id = $1 AND p.is_published AND p.published_at <= now()
          ORDER BY p.published_at DESC LIMIT 50`,
        [pharmacyId]),
    ]);

    return {
      pharmacy: pharmacy[0],
      settings: settings.rows[0] ?? null,
      medications: medications.rows,
      branches: branches.rows,
      blog: { categories: categories.rows, posts: posts.rows },
    };
  },

  /** Page publique d'un article de blog. */
  async publicPost(slug, postSlug) {
    const { rows: pharmacy } = await query('SELECT id FROM pharmacies WHERE slug = $1 AND status = $2', [slug, 'active']);
    if (!pharmacy[0]) throw new NotFoundError('Site introuvable');
    const { rows } = await query(
      `SELECT p.id, p.title, p.slug, p.excerpt, p.content, p.image_url, p.seo, p.published_at,
              c.name AS category_name
         FROM blog_posts p LEFT JOIN blog_categories c ON c.id = p.category_id
        WHERE p.pharmacy_id = $1 AND p.slug = $2 AND p.is_published AND p.published_at <= now()`,
      [pharmacy[0].id, postSlug],
    );
    if (!rows[0]) throw new NotFoundError('Article introuvable');
    return rows[0];
  },

  // ---- Réglages (authentifié) ----
  async getSettings(pharmacyId) {
    const { rows } = await query(
      `SELECT ws.* FROM website_settings ws WHERE ws.pharmacy_id = $1`,
      [pharmacyId],
    );
    if (!rows[0]) {
      await query(
        `INSERT INTO website_settings (pharmacy_id) VALUES ($1) ON CONFLICT (pharmacy_id) DO NOTHING`,
        [pharmacyId],
      );
      return { pharmacy_id: pharmacyId };
    }
    return rows[0];
  },

  async saveSettings(pharmacyId, data, actor) {
    const fields = [];
    const params = [pharmacyId];
    let i = 2;
    const map = {
      heroTitle: 'hero_title', heroSubtitle: 'hero_subtitle', about: 'about',
      services: 'services', photos: 'photos', videoUrl: 'video_url', social: 'social',
      openingHours: 'opening_hours', customCss: 'custom_css',
    };
    for (const [key, value] of Object.entries(data)) {
      if (!(key in map) || value === undefined) continue;
      fields.push(`${map[key]} = $${i}`);
      params.push(typeof value === 'string' ? value : JSON.stringify(value));
      i++;
    }
    fields.push(`updated_at = now()`);
    await query(
      `INSERT INTO website_settings (pharmacy_id) VALUES ($1)
       ON CONFLICT (pharmacy_id) DO UPDATE SET ${fields.join(', ')}`,
      params,
    );
    await auditLog({ pharmacyId, userId: actor?.id, action: 'edit', module: 'website', entity: 'website_settings', entityId: pharmacyId, newValues: data });
    return this.getSettings(pharmacyId);
  },

  // ---- Blog ----
  async listCategories(pharmacyId) {
    const { rows } = await query(
      'SELECT id, name, slug FROM blog_categories WHERE pharmacy_id = $1 ORDER BY name',
      [pharmacyId],
    );
    return rows;
  },

  async createCategory(pharmacyId, data, actor) {
    const { rows } = await query(
      `INSERT INTO blog_categories (pharmacy_id, name, slug)
       VALUES ($1,$2,$3) RETURNING id, name, slug`,
      [pharmacyId, data.name, data.slug || slugify(data.name)],
    );
    await auditLog({ pharmacyId, userId: actor?.id, action: 'create', module: 'website', entity: 'blog_category', entityId: rows[0].id, newValues: { name: data.name } });
    return rows[0];
  },

  async listPosts(pharmacyId, { page = 1, limit = 20, isPublished }) {
    const pg = paginate(page, limit);
    const where = ['p.pharmacy_id = $1'];
    const params = [pharmacyId];
    let i = 2;
    if (isPublished !== undefined) { where.push(`p.is_published = $${i}`); params.push(isPublished === 'true' || isPublished === true); i++; }
    const count = await query(`SELECT count(*)::int AS total FROM blog_posts p WHERE ${where.join(' AND ')}`, params);
    const { rows } = await query(
      `SELECT p.id, p.title, p.slug, p.excerpt, p.image_url, p.is_published, p.published_at,
              p.created_at, c.name AS category_name
         FROM blog_posts p LEFT JOIN blog_categories c ON c.id = p.category_id
        WHERE ${where.join(' AND ')}
        ORDER BY p.created_at DESC LIMIT $${i} OFFSET $${i + 1}`,
      [...params, pg.limit, pg.offset],
    );
    return { items: rows, meta: { ...pg, total: count.rows[0].total } };
  },

  async createPost(pharmacyId, data, actor) {
    const { rows } = await query(
      `INSERT INTO blog_posts (pharmacy_id, category_id, title, slug, excerpt, content, image_url,
                               is_published, seo, published_at)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,
               CASE WHEN $8 THEN now() ELSE NULL END)
       RETURNING *`,
      [pharmacyId, data.categoryId ?? null, data.title, data.slug || slugify(data.title),
       data.excerpt ?? null, data.content, data.imageUrl ?? null,
       data.isPublished ?? false, data.seo ? JSON.stringify(data.seo) : null],
    );
    await auditLog({ pharmacyId, userId: actor?.id, action: 'create', module: 'website', entity: 'blog_post', entityId: rows[0].id, newValues: { title: data.title } });
    return rows[0];
  },

  async updatePost(pharmacyId, id, data, actor) {
    const fields = [];
    const params = [id, pharmacyId];
    let i = 3;
    const map = {
      categoryId: 'category_id', title: 'title', slug: 'slug', excerpt: 'excerpt',
      content: 'content', imageUrl: 'image_url', seo: 'seo',
    };
    for (const [key, value] of Object.entries(data)) {
      if (!(key in map) || value === undefined) continue;
      fields.push(`${map[key]} = $${i}`);
      params.push(value);
      i++;
    }
    if (data.isPublished !== undefined) {
      fields.push(`is_published = $${i}`, `published_at = CASE WHEN $${i} THEN now() ELSE published_at END`);
      params.push(data.isPublished);
      i++;
    }
    if (fields.length) {
      fields.push('updated_at = now()');
      await query(`UPDATE blog_posts SET ${fields.join(', ')} WHERE id = $1 AND pharmacy_id = $2`, params);
    }
    const { rows } = await query(
      'SELECT * FROM blog_posts WHERE id = $1 AND pharmacy_id = $2',
      [id, pharmacyId],
    );
    if (!rows[0]) throw new NotFoundError('Article introuvable');
    await auditLog({ pharmacyId, userId: actor?.id, action: 'edit', module: 'website', entity: 'blog_post', entityId: id, newValues: data });
    return rows[0];
  },

  async removePost(pharmacyId, id, actor) {
    const { rows } = await query(
      'DELETE FROM blog_posts WHERE id = $1 AND pharmacy_id = $2 RETURNING id',
      [id, pharmacyId],
    );
    if (!rows[0]) throw new NotFoundError('Article introuvable');
    await auditLog({ pharmacyId, userId: actor?.id, action: 'delete', module: 'website', entity: 'blog_post', entityId: id });
  },
};

export function slugify(text) {
  return text
    .toLowerCase()
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '');
}
