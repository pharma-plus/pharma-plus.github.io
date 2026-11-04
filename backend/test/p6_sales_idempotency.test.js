import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync, existsSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

const root = join(dirname(fileURLToPath(import.meta.url)), '..');
const service = readFileSync(join(root, 'src/modules/sales/service.js'), 'utf8');
const route = readFileSync(join(root, 'src/modules/sales/index.js'), 'utf8');

test('sales : le hash de contenu est persisté dans INSERT (colonne + placeholder + paramètre)', () => {
  const insertMatch = service.match(/INSERT INTO sales \([^)]*content_hash[^)]*\)[\s\S]*?VALUES \(([^)]*)\)/);
  assert.ok(insertMatch, 'INSERT sales doit mentionner content_hash');
  const placeholders = insertMatch[1].match(/\$\d+/g);
  assert.ok(placeholders, 'placeholders $n présents');
  assert.equal(
    placeholders[placeholders.length - 1],
    '$20',
    'le dernier placeholder doit être $20 (content_hash)',
  );
  assert.ok(
    /clientSaleId \|\| null, contentHash\]/.test(service),
    'le paramètre contentHash doit être transmis en dernière position',
  );
  assert.ok(
    /const contentHash = clientSaleId/.test(service),
    'le hash ne doit être calculé que si clientSaleId est fourni',
  );
});

test('sales : hash canonique insensible à l’ordre des articles', () => {
  assert.ok(
    /\.sort\(\(a, b\) => String\(a\.medication_id\)\.localeCompare\(String\(b\.medication_id\)\)\)/.test(service),
    'les articles doivent être triés avant hachage',
  );
  assert.ok(
    /sha256\(JSON\.stringify\(\{ items: canonicalItems, payments: canonicalPayments \}\)\)/.test(service),
    'le hash couvre articles ET paiements',
  );
});

test('sales : verrouillage transactionnel anti-concurrence avant relecture', () => {
  assert.ok(
    /pg_advisory_xact_lock\(hashtext\(\$\d+\)\)/.test(service),
    'un advisory lock doit sérialiser les retries simultanés',
  );
  assert.ok(
    /SELECT id, content_hash FROM sales WHERE pharmacy_id = \$1 AND client_sale_id = \$2/.test(service),
    'relecture par client_sale_id obligatoire dans la transaction',
  );
  assert.ok(
    /IDEMPOTENCY_CONFLICT/.test(service),
    'conflit 409 si même clé et contenu différent',
  );
});

test('sales : la relecture idempotente retourne un objet vente exploitable', () => {
  const replay = service.match(/const replay = await client\.query\([\s\S]*?return replay\.rows\[0\];/);
  assert.ok(replay, 'la relecture doit retourner replay.rows[0] et non le résultat brut');
});

test('sales : la vente, ses lignes, mouvements de stock et paiements partagent la transaction', () => {
  assert.ok(/return withTransaction\(pharmacyId, async \(client\) => \{/.test(service), 'transaction unique');
  assert.ok(/INSERT INTO sale_items/.test(service), 'lignes de vente dans la transaction');
  assert.ok(/insertMovement\(client,/.test(service), 'mouvements de stock dans la transaction');
  assert.ok(/INSERT INTO payments/.test(service), 'paiements dans la transaction');
});

test('sales : route accepte Idempotency-Key en en-tête HTTP (fallback)', () => {
  assert.ok(
    /Idempotency-Key/i.test(route),
    'la route doit lire l’en-tête Idempotency-Key',
  );
});

test('migration 003 : colonnes, index UNIQUE partiel et contenu différentiel', () => {
  const migrationPath = join(root, 'migrations/003_add_client_sale_id_to_sales.sql');
  assert.ok(existsSync(migrationPath), 'migration 003 doit exister (préparée, non appliquée en prod)');
  const migration = readFileSync(migrationPath, 'utf8');
  assert.ok(/client_sale_id\s+uuid/i.test(migration), 'colonne client_sale_id');
  assert.ok(/content_hash\s+char\(64\)/i.test(migration), 'colonne content_hash');
  assert.ok(/unique/i.test(migration), 'index UNIQUE partiel obligatoire');
  assert.ok(/create index/i.test(migration), 'index de recherche content_hash');
});

test('migration 003 : strictement additive (aucune suppression ni modification destructive)', () => {
  const migration = readFileSync(join(root, 'migrations/003_add_client_sale_id_to_sales.sql'), 'utf8');
  assert.ok(!/\bdrop\s+table\b/i.test(migration), 'aucun DROP TABLE');
  assert.ok(!/\bdelete\s+from\b/i.test(migration), 'aucune suppression de données');
  assert.ok(!/\bdrop\s+column\b/i.test(migration), 'aucune suppression de colonne');
});
