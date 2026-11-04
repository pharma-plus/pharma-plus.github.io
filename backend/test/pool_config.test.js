import { test } from 'node:test';
import assert from 'node:assert/strict';
import { pool, query, isWriteQuery } from '../src/db/pool.js';

/**
 * P9 — Tests du pool PostgreSQL (gestion des connexions).
 *
 * Ces tests vérifient la configuration du pool et la robustesse face aux
 * erreurs de connexion. Aucun compte de production n'est sollicité.
 */

test('pool : configuration du pool (max, idleTimeout, connectionTimeout, maxLifetimeSeconds)', () => {
  assert.ok(pool, 'le pool doit exister');
  const opts = pool.options || {};
  assert.strictEqual(opts.max, 20, 'max doit valoir 20');
  assert.strictEqual(opts.idleTimeoutMillis, 30_000, 'idleTimeoutMillis doit valoir 30000');
  assert.strictEqual(opts.connectionTimeoutMillis, 5_000, 'connectionTimeoutMillis doit valoir 5000');
  assert.strictEqual(opts.maxLifetimeSeconds, 1_800, 'maxLifetimeSeconds doit valoir 1800');
});

test('pool : événement d\'erreur est configuré', () => {
  // Le pool doit avoir un gestionnaire d'erreur 'error' attaché.
  assert.ok(
    pool._events && pool._events.error,
    'le pool doit avoir un gestionnaire d\'erreur "error"',
  );
});

test('pool : fonction query est exportée et est une fonction', () => {
  assert.strictEqual(typeof query, 'function', 'query doit être une fonction');
});

test('pool : isWriteQuery détecte les écritures simples', () => {
  assert.strictEqual(isWriteQuery("INSERT INTO users (name) VALUES ('x')"), true);
  assert.strictEqual(isWriteQuery("UPDATE users SET name='x' WHERE id=1"), true);
  assert.strictEqual(isWriteQuery("DELETE FROM users WHERE id=1"), true);
  assert.strictEqual(isWriteQuery("  INSERT INTO users (name) VALUES ('x')"), true);
});

test('pool : isWriteQuery détecte les requêtes WITH ... écriture (CTE)', () => {
  assert.strictEqual(
    isWriteQuery("WITH ins AS (INSERT INTO users (name) VALUES ('x') RETURNING id) SELECT * FROM ins"),
    true,
    'une requête WITH ... INSERT doit être détectée comme écriture',
  );
  assert.strictEqual(
    isWriteQuery("WITH upd AS (UPDATE users SET name='x' WHERE id=1 RETURNING id) SELECT * FROM upd"),
    true,
    'une requête WITH ... UPDATE doit être détectée comme écriture',
  );
});

test('pool : isWriteQuery ne détecte pas les lectures simples', () => {
  assert.strictEqual(isWriteQuery("SELECT * FROM users WHERE id=1"), false);
  assert.strictEqual(isWriteQuery("SELECT name FROM users"), false);
  assert.strictEqual(isWriteQuery("  SELECT * FROM users WHERE id=1"), false);
});

test('pool : isWriteQuery ne détecte pas SELECT ... FOR UPDATE', () => {
  assert.strictEqual(
    isWriteQuery("SELECT * FROM users WHERE id=1 FOR UPDATE"),
    false,
    'SELECT ... FOR UPDATE reste une lecture (verrouillage, pas d\'écriture)',
  );
});
