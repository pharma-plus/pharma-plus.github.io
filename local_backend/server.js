#!/usr/bin/env node
/**
 * PHARMA+ LOCAL Backend Service
 * ------------------------------
 * Backend local installable pour le mode hors-ligne de PHARMA+.
 * - Base SQLite persistante (fichier .sqlite, pas :memory:)
 * - Écoute sur http://127.0.0.1:4001 (préfixe /api/v1)
 * - Auth réelle (JWT, argon2id + fallback compat local)
 * - Routes : auth (login/me/refresh/logout), branches, customers,
 *   catalog/medications(+stock+barcode), sales (idempotent, transaction),
 *   inventory, health
 * - Idempotence ventes : clientSaleId + content_hash + advisory-like lock
 *   (sérialisation SQLite) + vérification hash
 * - Isolation pharmacies : chaque requête porte un pharmacy_id
 * - Scripts : `npm start` (serveur), `npm run setup` (initialise la base)
 */

process.title = 'pharma-local-backend';

const express = require('express');
const { DatabaseSync } = require('node:sqlite');
const crypto = require('node:crypto');
const jwt = require('jsonwebtoken');
const cors = require('cors');

const app = express();
const PORT = 4001;
const DB_PATH = process.env.PHARMA_LOCAL_DB || './pharma-local.sqlite';
const JWT_SECRET = process.env.PHARMA_LOCAL_JWT_SECRET || 'pharma-local-change-me';

const db = new DatabaseSync(DB_PATH);

// ---------------------------------------------------------------------------
// Initialisation / migrations de la base (persistente, additive)
// ---------------------------------------------------------------------------

function runMultiple(sql) {
  const statements = sql.split(';').map(s => s.trim()).filter(Boolean);
  statements.forEach(s => db.exec(s));
}

function initDb() {
  runMultiple(`
    PRAGMA journal_mode = WAL;
    PRAGMA foreign_keys = ON;

    CREATE TABLE IF NOT EXISTS pharmacies (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      slug TEXT UNIQUE NOT NULL,
      address TEXT,
      phone TEXT,
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP
    );

    CREATE TABLE IF NOT EXISTS branches (
      id TEXT PRIMARY KEY,
      pharmacy_id TEXT NOT NULL REFERENCES pharmacies(id),
      name TEXT NOT NULL,
      code TEXT,
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP
    );

    CREATE TABLE IF NOT EXISTS users (
      id TEXT PRIMARY KEY,
      pharmacy_id TEXT NOT NULL REFERENCES pharmacies(id),
      branch_id TEXT REFERENCES branches(id),
      email TEXT NOT NULL,
      password_hash TEXT NOT NULL,
      is_super_admin INTEGER DEFAULT 0,
      role_name TEXT DEFAULT 'employee',
      permissions TEXT DEFAULT '[]',
      visible_modules TEXT DEFAULT '[]',
      first_name TEXT,
      last_name TEXT,
      has_pin INTEGER DEFAULT 0,
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP
    );

    CREATE TABLE IF NOT EXISTS customers (
      id TEXT PRIMARY KEY,
      pharmacy_id TEXT NOT NULL REFERENCES pharmacies(id),
      name TEXT NOT NULL,
      email TEXT,
      phone TEXT,
      credit_limit REAL DEFAULT 0,
      credit_balance REAL DEFAULT 0,
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP
    );

    CREATE TABLE IF NOT EXISTS medications (
      id TEXT PRIMARY KEY,
      pharmacy_id TEXT REFERENCES pharmacies(id),
      name TEXT NOT NULL,
      dci TEXT,
      dosage TEXT,
      form TEXT,
      presentation TEXT,
      barcode_ean13 TEXT,
      price_sale REAL DEFAULT 0,
      price_purchase REAL DEFAULT 0,
      tva_rate REAL DEFAULT 20,
      status TEXT DEFAULT 'available',
      shelf_location TEXT,
      category_name TEXT,
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP
    );

    CREATE TABLE IF NOT EXISTS stock_balances (
      id TEXT PRIMARY KEY,
      pharmacy_id TEXT NOT NULL REFERENCES pharmacies(id),
      branch_id TEXT REFERENCES branches(id),
      medication_id TEXT NOT NULL REFERENCES medications(id),
      lot_id TEXT,
      quantity INTEGER DEFAULT 0,
      reserved_quantity INTEGER DEFAULT 0,
      updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
    );

    CREATE TABLE IF NOT EXISTS sales (
      id TEXT PRIMARY KEY,
      pharmacy_id TEXT NOT NULL REFERENCES pharmacies(id),
      branch_id TEXT REFERENCES branches(id),
      user_id TEXT REFERENCES users(id),
      customer_id TEXT REFERENCES customers(id),
      number TEXT NOT NULL,
      sale_type TEXT DEFAULT 'pos',
      status TEXT DEFAULT 'completed',
      subtotal REAL DEFAULT 0,
      discount_total REAL DEFAULT 0,
      tax_total REAL DEFAULT 0,
      total REAL DEFAULT 0,
      cost_total REAL DEFAULT 0,
      paid_amount REAL DEFAULT 0,
      change_amount REAL DEFAULT 0,
      payment_method TEXT,
      notes TEXT,
      prescription_id TEXT,
      sale_date DATETIME DEFAULT CURRENT_TIMESTAMP,
      payments TEXT DEFAULT '[]',
      client_sale_id TEXT,
      content_hash TEXT,
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP
    );

    CREATE INDEX IF NOT EXISTS idx_sales_pharmacy_client ON sales(pharmacy_id, client_sale_id) WHERE client_sale_id IS NOT NULL;
    CREATE UNIQUE INDEX IF NOT EXISTS ux_sales_client_hash ON sales(pharmacy_id, client_sale_id) WHERE client_sale_id IS NOT NULL;

    CREATE TABLE IF NOT EXISTS sale_items (
      id TEXT PRIMARY KEY,
      pharmacy_id TEXT NOT NULL REFERENCES pharmacies(id),
      sale_id TEXT NOT NULL REFERENCES sales(id),
      medication_id TEXT REFERENCES medications(id),
      lot_id TEXT,
      quantity INTEGER DEFAULT 0,
      unit_price REAL DEFAULT 0,
      cost_price REAL DEFAULT 0,
      tva_rate REAL DEFAULT 20,
      discount REAL DEFAULT 0
    );

    CREATE TABLE IF NOT EXISTS payments (
      id TEXT PRIMARY KEY,
      pharmacy_id TEXT NOT NULL REFERENCES pharmacies(id),
      sale_id TEXT NOT NULL REFERENCES sales(id),
      customer_id TEXT REFERENCES customers(id),
      method TEXT NOT NULL,
      amount REAL DEFAULT 0,
      reference TEXT,
      received_by TEXT REFERENCES users(id),
      received_at DATETIME DEFAULT CURRENT_TIMESTAMP
    );

    CREATE TABLE IF NOT EXISTS inventory_sessions (
      id TEXT PRIMARY KEY,
      pharmacy_id TEXT NOT NULL REFERENCES pharmacies(id),
      branch_id TEXT REFERENCES branches(id),
      user_id TEXT REFERENCES users(id),
      status TEXT DEFAULT 'open',
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
      closed_at DATETIME
    );

    CREATE TABLE IF NOT EXISTS sync_log (
      id TEXT PRIMARY KEY,
      pharmacy_id TEXT REFERENCES pharmacies(id),
      operation TEXT,
      path TEXT,
      status TEXT,
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP
    );
  `);

  // Semencement minimal si base vide (démarrage hors-ligne autonome)
  const count = db.prepare('SELECT COUNT(*) AS c FROM pharmacies').get().c;
  if (count === 0) {
    const phId = crypto.randomUUID();
    const brId = crypto.randomUUID();
    const usId = crypto.randomUUID();
    const pwHash = crypto.createHash('sha256').update('admin123').digest('hex');
    db.prepare('INSERT INTO pharmacies (id, name, slug) VALUES (?, ?, ?)').run(phId, 'PHARMA+ Démo', 'pharma-demo');
    db.prepare('INSERT INTO branches (id, pharmacy_id, name, code) VALUES (?, ?, ?, ?)').run(brId, phId, 'Officine', 'BR01');
    db.prepare('INSERT INTO users (id, pharmacy_id, branch_id, email, password_hash, is_super_admin, role_name, first_name, last_name, permissions, visible_modules) VALUES (?, ?, ?, ?, ?, 1, ?, ?, ?, ?, ?)')
      .run(usId, phId, brId, 'admin@pharma.local', pwHash, 'superadmin', 'Admin', 'Local', JSON.stringify(['sales:view','stock:view','customers:view','catalog:view','reports:view','settings:view','users:view','employees:view']), JSON.stringify(['sales','stock','customers','catalog','reports','settings','users','employees']));
    const meds = [
      ['m1', phId, 'Paracétamol 500', 'Paracétamol', '500 mg', 'comprimé', 'BLISTER', '3400936055410', 6.50, 2.10, 20, 'available', 'A1', 'Antalgique'],
      ['m2', phId, 'Ibuprofène 400', 'Ibuprofène', '400 mg', 'comprimé', 'BLISTER', '3400936055427', 8.90, 3.00, 20, 'available', 'A2', 'Antalgique'],
      ['m3', phId, 'Amoxicilline 500', 'Amoxicilline', '500 mg', 'gélule', 'BLISTER', '3400936055434', 12.00, 4.50, 20, 'available', 'B1', 'Antibiotique'],
    ];
    const insertMed = db.prepare('INSERT INTO medications (id, pharmacy_id, name, dci, dosage, form, presentation, barcode_ean13, price_sale, price_purchase, tva_rate, status, shelf_location, category_name) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?)');
    const insertStock = db.prepare('INSERT INTO stock_balances (id, pharmacy_id, branch_id, medication_id, quantity) VALUES (?,?,?,?,?)');
    meds.forEach(([id, pid, name, dci, dosage, form, pres, barcode, psale, ppur, tva, status, loc, cat]) => {
      insertMed.run(id, pid, name, dci, dosage, form, pres, barcode, psale, ppur, tva, status, loc, cat);
      insertStock.run(crypto.randomUUID(), pid, brId, id, Math.floor(Math.random() * 50) + 10);
    });
    console.log(`Base locale initialisée (pharmacie ${phId}, branche ${brId}, user ${usId})`);
  }
}

// ---------------------------------------------------------------------------
// Middleware
// ---------------------------------------------------------------------------

app.use(cors());
app.use(express.json({ limit: '2mb' }));
app.use(express.urlencoded({ extended: true }));

function requireAuth(req, res, next) {
  const auth = req.headers['authorization'];
  if (!auth || !auth.startsWith('Bearer ')) {
    return res.status(401).json({ error: 'Authentification requise', code: 'UNAUTHENTICATED' });
  }
  const token = auth.slice(7);
  let payload;
  try {
    payload = jwt.verify(token, JWT_SECRET);
  } catch (e) {
    return res.status(401).json({ error: 'Jeton invalide ou expiré', code: 'TOKEN_INVALID' });
  }
  req.user = payload;
  next();
}

function pharmacyOf(req) {
  return req.user && req.user.pharmacy_id ? req.user.pharmacy_id : null;
}

function userIdOf(req) {
  return req.user && req.user.id ? req.user.id : null;
}

// ---------------------------------------------------------------------------
// Helpers DB
// ---------------------------------------------------------------------------

function all(sql, params = []) {
  return db.prepare(sql).all(...params);
}
function get(sql, params = []) {
  return db.prepare(sql).get(...params);
}
function run(sql, params = []) {
  return db.prepare(sql).run(...params);
}

function nowIso() { return new Date().toISOString(); }
function uuid() { return crypto.randomUUID(); }

// Verrou sérialisé par (pharmacy_id, clientSaleId) — émule pg_advisory_xact_lock
// en attendant la transaction SQLite (verrou au niveau base, pas d’écriture concurrente).
const idemLocks = new Map();
function idemLock(pharmacyId, clientSaleId, fn) {
  const key = `${pharmacyId}:${clientSaleId}`;
  let prev = idemLocks.get(key);
  if (!prev) prev = Promise.resolve();
  const run = prev.then(fn);
  idemLocks.set(key, run);
  return run;
}

// ---------------------------------------------------------------------------
// Routes santé
// ---------------------------------------------------------------------------

app.get('/api/v1/health', (req, res) => {
  res.json({ status: 'ok', version: '1.0.0', mode: 'local', db: DB_PATH });
});

// ---------------------------------------------------------------------------
// Auth
// ---------------------------------------------------------------------------

function hashPassword(password) {
  // argon2id si disponible, sinon SHA-256 (compat locale hors-ligne)
  try {
    const argon2 = require('argon2');
    return argon2.hash(password, { type: argon2.argon2id, memoryCost: 65536, timeCost: 3, parallelism: 2 });
  } catch (_) {
    return Promise.resolve(crypto.createHash('sha256').update(password).digest('hex'));
  }
}
function verifyPassword(password, hash) {
  try {
    const argon2 = require('argon2');
    return argon2.verify(hash, password);
  } catch (_) {
    return Promise.resolve(crypto.createHash('sha256').update(password).digest('hex') === hash);
  }
}

app.post('/api/v1/auth/login', async (req, res) => {
  const { email, password } = req.body || {};
  if (!email || !password) {
    return res.status(400).json({ error: 'Email et mot de passe requis', code: 'VALIDATION_ERROR' });
  }
  const user = get('SELECT * FROM users WHERE email = ?', [email]);
  if (!user) {
    return res.status(401).json({ error: 'Identifiants incorrects', code: 'INVALID_CREDENTIALS' });
  }
  const ok = await verifyPassword(password, user.password_hash);
  if (!ok) {
    return res.status(401).json({ error: 'Identifiants incorrects', code: 'INVALID_CREDENTIALS' });
  }
  const token = jwt.sign({ id: user.id, email: user.email, pharmacy_id: user.pharmacy_id, branch_id: user.branch_id, is_super_admin: user.is_super_admin !== 0, role_name: user.role_name }, JWT_SECRET, { expiresIn: '24h' });
  const refresh = jwt.sign({ id: user.id, type: 'refresh' }, JWT_SECRET, { expiresIn: '7d' });
  res.json({
    success: true,
    data: {
      accessToken: token,
      refreshToken: refresh,
      user: {
        id: user.id, email: user.email, pharmacy_id: user.pharmacy_id, branch_id: user.branch_id,
        first_name: user.first_name, last_name: user.last_name, role_name: user.role_name,
        is_super_admin: user.is_super_admin !== 0,
        permissions: JSON.parse(user.permissions || '[]'),
        visible_modules: JSON.parse(user.visible_modules || '[]'),
        has_pin: user.has_pin !== 0,
      },
      pharmacy: { id: user.pharmacy_id },
      role: { name: user.role_name },
    },
  });
});

app.post('/api/v1/auth/refresh', async (req, res) => {
  const { refreshToken } = req.body || {};
  if (!refreshToken) return res.status(401).json({ error: 'Jeton de rafraîchissement requis', code: 'TOKEN_INVALID' });
  let payload;
  try {
    payload = jwt.verify(refreshToken, JWT_SECRET);
  } catch (e) {
    return res.status(401).json({ error: 'Jeton de rafraîchissement invalide', code: 'TOKEN_INVALID' });
  }
  if (payload.type !== 'refresh') return res.status(401).json({ error: 'Type de jeton invalide', code: 'TOKEN_INVALID' });
  const user = get('SELECT * FROM users WHERE id = ?', [payload.id]);
  if (!user) return res.status(401).json({ error: 'Utilisateur introuvable', code: 'USER_NOT_FOUND' });
  const token = jwt.sign({ id: user.id, email: user.email, pharmacy_id: user.pharmacy_id, branch_id: user.branch_id, is_super_admin: user.is_super_admin !== 0, role_name: user.role_name }, JWT_SECRET, { expiresIn: '24h' });
  const refresh = jwt.sign({ id: user.id, type: 'refresh' }, JWT_SECRET, { expiresIn: '7d' });
  res.json({
    success: true,
    data: {
      accessToken: token,
      refreshToken: refresh,
      user: {
        id: user.id, email: user.email, pharmacy_id: user.pharmacy_id, branch_id: user.branch_id,
        first_name: user.first_name, last_name: user.last_name, role_name: user.role_name,
        is_super_admin: user.is_super_admin !== 0,
        permissions: JSON.parse(user.permissions || '[]'),
        visible_modules: JSON.parse(user.visible_modules || '[]'),
        has_pin: user.has_pin !== 0,
      },
    },
  });
});

app.post('/api/v1/auth/logout', requireAuth, (req, res) => {
  res.json({ success: true });
});

app.get('/api/v1/auth/me', requireAuth, (req, res) => {
  const user = get('SELECT * FROM users WHERE id = ?', [req.user.id]);
  if (!user) return res.status(404).json({ error: 'Utilisateur introuvable', code: 'USER_NOT_FOUND' });
  res.json({
    success: true,
    data: {
      id: user.id, email: user.email, pharmacy_id: user.pharmacy_id, branch_id: user.branch_id,
      first_name: user.first_name, last_name: user.last_name, role_name: user.role_name,
      is_super_admin: user.is_super_admin !== 0,
      permissions: JSON.parse(user.permissions || '[]'),
      visible_modules: JSON.parse(user.visible_modules || '[]'),
      has_pin: user.has_pin !== 0,
    },
  });
});

// ---------------------------------------------------------------------------
// Référentiels (lecture, isolés par pharmacie)
// ---------------------------------------------------------------------------

app.get('/api/v1/branches', requireAuth, (req, res) => {
  const pid = pharmacyOf(req);
  const rows = all('SELECT * FROM branches WHERE pharmacy_id = ? ORDER BY name', [pid]);
  res.json({ success: true, data: rows });
});

app.get('/api/v1/customers', requireAuth, (req, res) => {
  const pid = pharmacyOf(req);
  const limit = Number(req.query.limit || 200);
  const rows = all('SELECT * FROM customers WHERE pharmacy_id = ? ORDER BY name LIMIT ?', [pid, limit]);
  res.json({ success: true, data: rows });
});

app.get('/api/v1/catalog/medications', requireAuth, (req, res) => {
  const pid = pharmacyOf(req);
  const limit = Number(req.query.limit || 60);
  const q = req.query.q;
  const form = req.query.form;
  let sql = 'SELECT * FROM medications WHERE pharmacy_id IS NULL OR pharmacy_id = ?';
  const params = [pid];
  if (q) { sql += ' AND (name LIKE ? OR dci LIKE ?)'; params.push(`%${q}%`, `%${q}%`); }
  if (form && form !== 'eq.' && form !== 'null') { sql += ' AND form = ?'; params.push(form.replace(/^eq\./, '')); }
  sql += ' ORDER BY name LIMIT ?';
  params.push(limit);
  const rows = all(sql, params);
  res.json({ success: true, data: rows });
});

app.get('/api/v1/catalog/medications/stock', requireAuth, (req, res) => {
  const pid = pharmacyOf(req);
  const idsParam = req.query.ids;
  if (idsParam) {
    const ids = idsParam.split(',').map(s => s.trim()).filter(Boolean);
    if (ids.length === 0) return res.json({ success: true, data: [] });
    const placeholders = ids.map(() => '?').join(',');
    const rows = all(`SELECT m.id AS medication_id, COALESCE(SUM(sb.quantity - sb.reserved_quantity), 0) AS quantity
                      FROM medications m
                      LEFT JOIN stock_balances sb ON sb.medication_id = m.id AND sb.pharmacy_id = ?
                      WHERE m.id IN (${placeholders}) AND (m.pharmacy_id IS NULL OR m.pharmacy_id = ?)
                      GROUP BY m.id`, [...ids, pid]);
    return res.json({ success: true, data: rows });
  }
  const rows = all(`SELECT m.id AS medication_id, COALESCE(SUM(sb.quantity - sb.reserved_quantity), 0) AS quantity
                    FROM medications m
                    LEFT JOIN stock_balances sb ON sb.medication_id = m.id AND sb.pharmacy_id = ?
                    WHERE m.pharmacy_id IS NULL OR m.pharmacy_id = ?
                    GROUP BY m.id`, [pid, pid]);
  res.json({ success: true, data: rows });
});

app.get('/api/v1/catalog/medications/facets', requireAuth, (req, res) => {
  const pid = pharmacyOf(req);
  const forms = all('SELECT DISTINCT form FROM medications WHERE (pharmacy_id IS NULL OR pharmacy_id = ?) AND form IS NOT NULL', [pid]).map(r => r.form);
  const total = all('SELECT COUNT(*) AS c FROM medications WHERE pharmacy_id IS NULL OR pharmacy_id = ?', [pid])[0].c;
  res.json({ success: true, data: { forms: forms.map(f => ({ name: f })), indications_total: total } });
});

app.get('/api/v1/catalog/medications/pathologies', requireAuth, (req, res) => {
  const pid = pharmacyOf(req);
  const rows = all('SELECT DISTINCT category_name AS indication FROM medications WHERE (pharmacy_id IS NULL OR pharmacy_id = ?) AND category_name IS NOT NULL', [pid]);
  res.json({ success: true, data: rows.map(r => r.indication) });
});

app.get('/api/v1/catalog/medications/barcode/:code', requireAuth, (req, res) => {
  const pid = pharmacyOf(req);
  const row = get('SELECT * FROM medications WHERE barcode_ean13 = ? AND (pharmacy_id IS NULL OR pharmacy_id = ?)', [req.params.code, pid]);
  res.json({ success: !!row, data: row });
});

// ---------------------------------------------------------------------------
// Ventes (idempotentes, transaction cohérente)
// ---------------------------------------------------------------------------

function computeLine({ quantity, unit_price, discount, tva_rate }) {
  const gross = quantity * unit_price;
  const discountAmount = gross * (discount / 100);
  const net = gross - discountAmount;
  return { net, tax: net * (tva_rate / 100), discountAmount };
}

app.post('/api/v1/sales', requireAuth, (req, res) => {
  const { pharmacyId, branchId, customerId, items, payments, saleType = 'pos', notes, prescriptionId, discount_percent: discountPercent = 0, discount_amount: discountAmount = 0, clientSaleId } = req.body || {};
  const user = req.user;
  const pid = pharmacyId || pharmacyOf(req);
  const bid = branchId || user.branch_id;
  const uid = user.id;

  if (!pid) return res.status(400).json({ error: 'Pharmacie requise', code: 'PHARMACY_REQUIRED' });
  if (!items || !items.length) return res.status(422).json({ error: 'Panier vide', code: 'EMPTY_CART' });

  // Hash canonique (articles triés, insensible à l’ordre)
  const canonicalItems = [...items].map(it => ({
    medication_id: it.medication_id ?? null,
    quantity: it.quantity,
    unit_price: it.unit_price ?? null,
    discount: it.discount ?? 0,
    tva_rate: it.tva_rate ?? null,
    lot_id: it.lot_id ?? null,
  })).sort((a, b) => String(a.medication_id).localeCompare(String(b.medication_id)));
  const canonicalPayments = [...(payments || [])].map(p => ({ method: p.method, amount: Number(p.amount || 0), reference: p.reference ?? null, generateInvoice: !!p.generateInvoice }));
  const contentHash = clientSaleId ? crypto.createHash('sha256').update(JSON.stringify({ items: canonicalItems, payments: canonicalPayments })).digest('hex') : null;

  const exec = () => {
    db.exec('BEGIN TRANSACTION');
    let result;
    try {
      // Vérification idempotence dans la transaction
      if (clientSaleId) {
        const existing = get('SELECT id, content_hash FROM sales WHERE pharmacy_id = ? AND client_sale_id = ?', [pid, clientSaleId]);
        if (existing) {
          if (existing.content_hash === contentHash || existing.content_hash == null) {
            const sale = get(`SELECT s.*, b.name AS branch_name, c.name AS customer_name FROM sales s
                              LEFT JOIN branches b ON b.id = s.branch_id
                              LEFT JOIN customers c ON c.id = s.customer_id
                              WHERE s.id = ?`, [existing.id]);
            db.exec('COMMIT');
            return res.json({ success: true, data: sale });
          }
          throw { status: 409, code: 'IDEMPOTENCY_CONFLICT', message: 'Vente en double avec contenu différent (conflit idempotence)' };
        }
      }

      const saleId = uuid();
      const number = 'VTE-' + Date.now().toString(36).slice(-6);
      let subtotal = 0, discountTotal = 0, taxTotal = 0, costTotal = 0;
      const saleItems = [];
      const prepared = [];

      for (const item of items) {
        const med = get('SELECT id, name, price_sale, tva_rate, price_purchase, status FROM medications WHERE id = ? AND (pharmacy_id IS NULL OR pharmacy_id = ?)', [item.medication_id, pid]);
        if (!med) throw { status: 404, code: 'NOT_FOUND', message: `Médicament introuvable : ${item.medication_id}` };
        if (med.status === 'retired') throw { status: 409, code: 'NOT_SALEABLE', message: `${med.name} est retiré de la vente` };
        const unitPrice = item.unit_price ?? Number(med.price_sale);
        const tvaRate = item.tva_rate ?? Number(med.tva_rate);
        const discount = item.discount ?? 0;
        const calc = computeLine({ quantity: item.quantity, unit_price: unitPrice, discount, tva_rate: tvaRate });
        // Stock FEFO simplifié : prendre le lot disponible
        const sb = get('SELECT id AS lot_id, (quantity - reserved_quantity) AS avail FROM stock_balances WHERE medication_id = ? AND pharmacy_id = ? AND (quantity - reserved_quantity) >= ? ORDER BY id LIMIT 1', [item.medication_id, pid, item.quantity]);
        if (!sb || sb.avail < item.quantity) throw { status: 409, code: 'INSUFFICIENT_STOCK', message: `Stock insuffisant pour ${med.name}` };
        prepared.push({ medicationId: item.medication_id, lotId: sb.lot_id, quantity: item.quantity, unitPrice, costPrice: Number(med.price_purchase), tvaRate, discount, net: calc.net, tax: calc.tax, lotsUsed: [{ lot_id: sb.lot_id, quantity: item.quantity }] });
        subtotal += unitPrice * item.quantity;
        discountTotal += calc.discountAmount;
        taxTotal += calc.tax;
        costTotal += Number(item.quantity) * Number(med.price_purchase);
        saleItems.push({ medication_id: item.medication_id, name: med.name, quantity: item.quantity, unit_price: unitPrice, net: calc.net });
      }

      const globalDiscount = Math.min(subtotal, discountPercent > 0 ? subtotal * (discountPercent / 100) : discountAmount);
      const taxable = subtotal - globalDiscount;
      const taxTotalCorrected = taxable * (taxTotal / subtotal || 1);
      const total = Math.round((taxable + taxTotalCorrected) * 100) / 100;
      discountTotal = Math.round((discountTotal + globalDiscount) * 100) / 100;
      taxTotal = Math.round(taxTotalCorrected * 100) / 100;
      const paidAmount = (payments || []).reduce((acc, p) => acc + Number(p.amount || 0), 0);
      const changeAmount = paidAmount > total ? Math.round((paidAmount - total) * 100) / 100 : 0;

      run(`INSERT INTO sales (id, pharmacy_id, branch_id, user_id, customer_id, number,
                sale_type, status, subtotal, discount_total, tax_total, total, cost_total,
                paid_amount, change_amount, payment_method, notes, prescription_id, sale_date, payments, client_sale_id, content_hash)
           VALUES (?,?,?,?,?,?,?,'completed',?,?,?,?,?,?,?,?,?,?,CURRENT_DATE,?,?,?)`,
        [saleId, pid, bid, uid, customerId || null, number, saleType, subtotal, discountTotal, taxTotal, total, costTotal, paidAmount, changeAmount,
         (payments || []).map(p => p.method).join('+') || 'credit', notes || null, prescriptionId || null, JSON.stringify(payments || []), clientSaleId || null, contentHash]);

      for (const p of prepared) {
        for (const l of p.lotsUsed) {
          run('UPDATE stock_balances SET quantity = quantity - ?, reserved_quantity = reserved_quantity + ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?', [l.quantity, l.quantity, l.lot_id]);
          run('INSERT INTO sale_items (id, pharmacy_id, sale_id, medication_id, lot_id, quantity, unit_price, cost_price, tva_rate, discount) VALUES (?,?,?,?,?,?,?,?,?,?)',
            [uuid(), pid, saleId, p.medicationId, l.lot_id, p.quantity, p.unitPrice, p.costPrice, p.tvaRate, p.discount]);
        }
      }

      for (const p of payments || []) {
        run('INSERT INTO payments (id, pharmacy_id, sale_id, customer_id, method, amount, reference, received_by) VALUES (?,?,?,?,?,?,?,?)',
          [uuid(), pid, saleId, customerId || null, p.method, p.amount, p.reference || null, uid]);
      }

      result = { saleId, number, total, subtotal, tax_total: taxTotal, discount_total: discountTotal, paid_amount: paidAmount, change_amount: changeAmount, items: saleItems, content_hash: contentHash };
      db.exec('COMMIT');
    } catch (e) {
      try { db.exec('ROLLBACK'); } catch (_) {}
      if (e && e.status === 409) return res.status(409).json({ error: e.message, code: e.code });
      throw e;
    }
    const sale = { id: result.saleId, pharmacy_id: pid, branch_id: bid, user_id: uid, ...result };
    res.json({ success: true, data: sale });
  };

  // Sérialisation par clé d'idempotence (évite les doublons concurrents)
  if (clientSaleId) {
    idemLock(pid, clientSaleId, exec).catch(err => {
      if (!res.headersSent) res.status(500).json({ error: 'Erreur serveur', code: 'INTERNAL_ERROR' });
    });
  } else {
    exec().catch(err => {
      if (!res.headersSent) res.status(500).json({ error: 'Erreur serveur', code: 'INTERNAL_ERROR' });
    });
  }
});

// ---------------------------------------------------------------------------
// Inventaire (caisse)
// ---------------------------------------------------------------------------

app.post('/api/v1/inventory/sessions', requireAuth, (req, res) => {
  const { branchId } = req.body || {};
  const pid = pharmacyOf(req);
  const id = uuid();
  run('INSERT INTO inventory_sessions (id, pharmacy_id, branch_id, user_id, status) VALUES (?,?,?,?,?)', [id, pid, branchId, req.user.id, 'open']);
  res.json({ success: true, data: { id, status: 'open' } });
});

app.post('/api/v1/inventory/sessions/:sessionId/close', requireAuth, (req, res) => {
  run('UPDATE inventory_sessions SET status = ?closed?, closed_at = CURRENT_TIMESTAMP WHERE id = ?', [req.params.sessionId]);
  res.json({ success: true });
});

// ---------------------------------------------------------------------------
// Start
// ---------------------------------------------------------------------------

initDb();
app.listen(PORT, '127.0.0.1', () => {
  console.log(`PHARMA+ Local Backend démarré sur http://127.0.0.1:${PORT}`);
  console.log(`Base SQLite persistante : ${DB_PATH}`);
  console.log('Mode: LOCAL (hors-ligne, isolation pharmacie, idempotence ventes)');
});

process.on('unhandledRejection', (err) => {
  console.error('Rejet non géré:', err);
});
