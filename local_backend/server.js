/// PHARMA+ LOCAL Backend Service
/// Backend local pour mode hors-ligne de PHARMA+.
/// Utilise SQLite (node:sqlite intégré à Node >= 22) comme base persistante.
/// Écoute sur http://127.0.0.1:4001
///
/// Contrats servis (alignés sur `frontend/test/local_backend_integration_test.dart`
/// et sur l'ApiClient Flutter : enveloppe { success, data } / { error: { code, message } }) :
///   GET  /api/v1/health
///   POST /api/v1/auth/login                      → { accessToken, refreshToken, user, pharmacy, role }
///   GET  /api/v1/auth/me                         → user confirmé par le serveur
///   GET  /api/v1/branches                        → liste des succursales (DB)
///   GET  /api/v1/catalog/medications?limit=…     → catalogue (DB)
///   GET  /api/v1/catalog/medications/stock        → stock (placeholder, préservé)
///   GET  /api/v1/customers?limit=…               → clients (DB)
///   GET  /api/v1/sales                           → ventes (DB)
///   POST /api/v1/sales (Idempotency-Key)         → vente idempotente (DB) ; 409 IDEMPOTENCY_CONFLICT

const express = require('express');
const cors = require('cors');
const crypto = require('node:crypto');
const { DatabaseSync } = require('node:sqlite');

const DB_PATH = './pharma-local.sqlite';
const PORT = 4001;

const app = express();
app.use(cors());
app.use(express.json());

const db = new DatabaseSync(DB_PATH);

const uuid = () => crypto.randomUUID();
const sha256 = (s) => crypto.createHash('sha256').update(s).digest('hex');
const randomSuffix = () => crypto.randomBytes(5).toString('hex').slice(0, 7);

/// Canonicalisation stable d'une charge utile (clés triées) pour le hash
/// idempotent — le même contenu doit produire exactement le même hash.
function canonical(x) {
  if (Array.isArray(x)) return '[' + x.map(canonical).join(',') + ']';
  if (x !== null && typeof x === 'object') {
    const keys = Object.keys(x).sort();
    return '{' + keys.map((k) => JSON.stringify(k) + ':' + canonical(x[k])).join(',') + '}';
  }
  return JSON.stringify(x);
}

const contentHashOf = (payload) =>
  sha256(canonical({
    pharmacyId: payload.pharmacyId ?? null,
    branchId: payload.branchId ?? null,
    clientSaleId: payload.clientSaleId ?? null,
    items: payload.items ?? [],
    payments: payload.payments ?? [],
  }));

/// Formatage du user pour les réponses (snake_case, contrat complet venant
/// de la table users — rien d'inventé).
function userPayload(u) {
  return {
    id: u.id,
    email: u.email,
    pharmacy_id: u.pharmacy_id,
    branch_id: u.branch_id,
    role_name: u.role_name,
    is_super_admin: !!Number(u.is_super_admin || 0),
    permissions: typeof u.permissions === 'string' ? JSON.parse(u.permissions) : (u.permissions ?? []),
    visible_modules:
      typeof u.visible_modules === 'string' ? JSON.parse(u.visible_modules) : (u.visible_modules ?? []),
    first_name: u.first_name,
    last_name: u.last_name,
    has_pin: !!Number(u.has_pin || 0),
  };
}

// ─── Santé ───────────────────────────────────────────────────────────────────
app.get('/api/v1/health', (req, res) => {
  res.json({ status: 'ok', version: '1.1.0', mode: 'local', db: DB_PATH });
});

// ─── Connexion ───────────────────────────────────────────────────────────────
// Mot de passe stocké en sha256 hex (ex. admin123 → 240be518…).
const tokens = new Map(); // token → userId (filtre in-memory, issu de login)

app.post('/api/v1/auth/login', (req, res) => {
  const { email, password } = req.body || {};
  if (!email || !password) {
    return res.status(400).json({ error: { code: 'INVALID_CREDENTIALS', message: 'Identifiants incorrects' } });
  }
  const u = db.prepare('SELECT * FROM users WHERE email = ?').get(String(email));
  if (!u || u.password_hash !== sha256(String(password))) {
    return res.status(401).json({ error: { code: 'INVALID_CREDENTIALS', message: 'Identifiants incorrects' } });
  }
  const token = 'local-' + uuid();
  tokens.set(token, u.id);
  const pharmacy = db.prepare('SELECT * FROM pharmacies WHERE id = ?').get(u.pharmacy_id) ?? null;
  res.json({
    success: true,
    data: {
      accessToken: token,
      refreshToken: token,
      user: userPayload(u),
      pharmacy: pharmacy ? { id: pharmacy.id, name: pharmacy.name, slug: pharmacy.slug } : { id: u.pharmacy_id },
      role: { name: u.role_name ?? null },
    },
  });
});

function currentUser(req) {
  const auth = req.headers['authorization'] ?? '';
  const m = /^Bearer\s+(.+)$/i.exec(auth);
  if (!m) return null;
  const uid = tokens.get(m[1].trim());
  if (!uid) return null;
  return db.prepare('SELECT * FROM users WHERE id = ?').get(uid);
}

// ─── Profil confirmé par le serveur ──────────────────────────────────────────
app.get('/api/v1/auth/me', (req, res) => {
  const u = currentUser(req);
  if (!u) return res.status(401).json({ error: { code: 'UNAUTHENTICATED', message: 'Session non valide' } });
  const pharmacy = db.prepare('SELECT * FROM pharmacies WHERE id = ?').get(u.pharmacy_id) ?? null;
  res.json({ success: true, data: userPayload(u), pharmacy });
});

// ─── Référentiels ────────────────────────────────────────────────────────────
app.get('/api/v1/branches', (req, res) => {
  const u = currentUser(req);
  if (!u) return res.status(401).json({ error: { code: 'UNAUTHENTICATED', message: 'Session non valide' } });
  const rows = db.prepare('SELECT * FROM branches WHERE pharmacy_id = ? ORDER BY created_at').all(u.pharmacy_id);
  res.json({ success: true, data: rows });
});

app.get('/api/v1/catalog/medications', (req, res) => {
  const u = currentUser(req);
  if (!u) return res.status(401).json({ error: { code: 'UNAUTHENTICATED', message: 'Session non valide' } });
  const limit = Math.min(parseInt(String(req.query.limit ?? '50'), 10) || 50, 500);
  const rows = db
    .prepare('SELECT * FROM medications WHERE pharmacy_id = ? ORDER BY created_at LIMIT ?')
    .all(u.pharmacy_id, limit);
  res.json({ success: true, data: rows });
});

// Stock des médicaments (route préservée : liste vide, assumée par le test existant)
app.get('/api/v1/catalog/medications/stock', (req, res) => res.json({ success: true, data: [] }));

app.get('/api/v1/customers', (req, res) => {
  const u = currentUser(req);
  if (!u) return res.status(401).json({ error: { code: 'UNAUTHENTICATED', message: 'Session non valide' } });
  const limit = Math.min(parseInt(String(req.query.limit ?? '50'), 10) || 50, 500);
  const rows = db
    .prepare('SELECT * FROM customers WHERE pharmacy_id = ? ORDER BY created_at LIMIT ?')
    .all(u.pharmacy_id, limit);
  res.json({ success: true, data: rows });
});

// ─── Ventes : lecture + création idempotente ────────────────────────────────
app.get('/api/v1/sales', (req, res) => {
  const u = currentUser(req);
  if (!u) return res.status(401).json({ error: { code: 'UNAUTHENTICATED', message: 'Session non valide' } });
  const limit = Math.min(parseInt(String(req.query.limit ?? '100'), 10) || 100, 500);
  const rows = db
    .prepare('SELECT * FROM sales WHERE pharmacy_id = ? ORDER BY created_at DESC LIMIT ?')
    .all(u.pharmacy_id, limit);
  res.json({ success: true, data: rows });
});

app.post('/api/v1/sales', (req, res) => {
  const u = currentUser(req);
  if (!u) return res.status(401).json({ error: { code: 'UNAUTHENTICATED', message: 'Session non valide' } });

  const body = req.body ?? {};
  const items = Array.isArray(body.items) ? body.items : [];
  const payments = Array.isArray(body.payments) ? body.payments : [];
  if (items.length === 0 || payments.length === 0) {
    return res.status(400).json({ error: { code: 'VALIDATION_ERROR', message: 'items et payments sont requis' } });
  }

  const clientSaleId = body.clientSaleId ?? null;
  const hash = contentHashOf({
    pharmacyId: body.pharmacyId,
    branchId: body.branchId,
    clientSaleId,
    items,
    payments,
  });

  // Idempotence : même clientSaleId + même contenu → même vente.
  if (clientSaleId) {
    const existing = db.prepare('SELECT * FROM sales WHERE pharmacy_id = ? AND client_sale_id = ?')
      .get(u.pharmacy_id, clientSaleId);
    if (existing) {
      if (existing.content_hash === hash) {
        return res.json({ success: true, data: existing });
      }
      return res.status(409).json({
        error: { code: 'IDEMPOTENCY_CONFLICT', message: 'Même clé de vente, contenu différent' },
      });
    }
  }

  // Totaux (tva par ligne, remise présence). Réplique les ventes existantes.
  let subtotal = 0, taxTotal = 0, costTotal = 0;
  for (const it of items) {
    const qty = Number(it.quantity ?? 0);
    const price = Number(it.unit_price ?? 0);
    const disc = Number(it.discount ?? 0);
    const lineNet = qty * price * (1 - disc);
    subtotal += lineNet;
    taxTotal += lineNet * (Number(it.tva_rate ?? 0) / 100);
    const med = db.prepare('SELECT price_purchase FROM medications WHERE id = ?').get(it.medication_id);
    costTotal += med ? qty * Number(med.price_purchase ?? 0) : 0;
  }
  const paid = payments.reduce((s, p) => s + Number(p.amount ?? 0), 0);
  const total = subtotal + taxTotal;

  const saleNumber = 'VTE-' + randomSuffix();
  const saleId = uuid();
  const saleDate = new Date().toISOString().slice(0, 10);

  db.exec('BEGIN');
  try {
    db.prepare(
      `INSERT INTO sales (id, pharmacy_id, branch_id, user_id, customer_id, number, sale_type, status,
        subtotal, discount_total, tax_total, total, cost_total, paid_amount, change_amount,
        payment_method, sale_date, payments, client_sale_id, content_hash, created_at)
       VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)`
    ).run(
      saleId, u.pharmacy_id, body.branchId ?? u.branch_id ?? null, u.id, body.customerId ?? null,
      saleNumber, body.saleType ?? 'pos', 'completed',
      subtotal, 0, taxTotal, total, costTotal, paid, Math.max(paid - total, 0),
      payments[0]?.method ?? 'cash', saleDate, JSON.stringify(payments), clientSaleId, hash,
      new Date().toISOString().slice(0, 19).replace('T', ' ')
    );
    for (const it of items) {
      const med = db.prepare('SELECT price_purchase FROM medications WHERE id = ?').get(it.medication_id);
      db.prepare(
        `INSERT INTO sale_items (id, pharmacy_id, sale_id, medication_id, quantity, unit_price,
          cost_price, tva_rate, discount) VALUES (?,?,?,?,?,?,?,?,?)`
      ).run(
        uuid(), u.pharmacy_id, saleId, it.medication_id, Number(it.quantity ?? 0),
        Number(it.unit_price ?? 0), med ? Number(med.price_purchase ?? 0) : 0,
        Number(it.tva_rate ?? 0), Number(it.discount ?? 0)
      );
      const sb = db
        .prepare('SELECT * FROM stock_balances WHERE pharmacy_id = ? AND medication_id = ? AND branch_id = ?')
        .get(u.pharmacy_id, it.medication_id, body.branchId ?? u.branch_id ?? null);
      if (sb) {
        db.prepare('UPDATE stock_balances SET quantity = ?, updated_at = ? WHERE id = ?')
          .run(Number(sb.quantity) - Number(it.quantity ?? 0),
               new Date().toISOString().slice(0, 19).replace('T', ' '), sb.id);
      }
    }
    for (const p of payments) {
      db.prepare('INSERT INTO payments (id, pharmacy_id, sale_id, method, amount) VALUES (?,?,?,?,?)')
        .run(uuid(), u.pharmacy_id, saleId, p.method ?? 'cash', Number(p.amount ?? 0));
    }
    db.exec('COMMIT');
  } catch (e) {
    db.exec('ROLLBACK');
    return res.status(500).json({ error: { code: 'INTERNAL_ERROR', message: e.message } });
  }

  const created = db.prepare('SELECT * FROM sales WHERE id = ?').get(saleId);
  res.status(201).json({ success: true, data: created });
});

app.listen(PORT, '127.0.0.1', () => {
  console.log(`PHARMA+ Local Backend démarré sur http://127.0.0.1:${PORT}`);
  console.log('Mode: LOCAL (base de données SQLite réelle, idempotence active)');
});
