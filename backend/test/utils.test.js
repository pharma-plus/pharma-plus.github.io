import { test } from 'node:test';
import assert from 'node:assert/strict';
import { sha256, ean13CheckDigit, isEan13Valid, sanitizeUser, deriveKey, encryptBuffer, decryptBuffer } from '../src/utils/crypto.js';
import { paginate } from '../src/utils/response.js';
import { AppError, NotFoundError, UnauthorizedError, ForbiddenError, ConflictError, ValidationError } from '../src/utils/errors.js';

test('sha256 est déterministe et une fonction de hachage hex', () => {
  const h1 = sha256('secret');
  const h2 = sha256('secret');
  assert.equal(h1, h2);
  assert.match(h1, /^[0-9a-f]{64}$/);
  assert.notEqual(sha256('secret'), sha256('autre'));
});

test('sanitizeUser retire les secrets', () => {
  const user = { id: 'u1', password_hash: 'x', pin_hash: 'y', two_factor_secret: 'z', email: 'a@b.c' };
  const clean = sanitizeUser(user);
  assert.equal(clean.password_hash, undefined);
  assert.equal(clean.pin_hash, undefined);
  assert.equal(clean.two_factor_secret, undefined);
  assert.equal(clean.email, 'a@b.c');
});

test('EAN-13 : clé de contrôle correcte (340093605541 → 4)', () => {
  assert.equal(ean13CheckDigit('340093605541'), 4);
  assert.ok(isEan13Valid('3400936055414'));
  assert.ok(!isEan13Valid('3400936055415'));
  assert.ok(!isEan13Valid('34009360554'));
});

test('chiffrement/déchiffrement AES-256-GCM roundtrip', () => {
  const key = deriveKey('passphrase-de-test');
  const data = Buffer.from('données sensibles de sauvegarde');
  const enc = encryptBuffer(data, key);
  const dec = decryptBuffer(enc, key);
  assert.equal(dec.toString('utf8'), data.toString('utf8'));
  // Le chiffré doit différer du clair (IV aléatoire)
  assert.notEqual(enc.toString('hex'), data.toString('hex'));
});

test('paginate calcule pages et offset', () => {
  const pg = paginate(2, 10, 25);
  assert.equal(pg.page, 2);
  assert.equal(pg.limit, 10);
  assert.equal(pg.offset, 10);
  assert.equal(pg.pages, 3);
  assert.equal(pg.total, 25);
  // Bornes
  const clamped = paginate(0, 999, 5);
  assert.equal(clamped.page, 1);
  assert.equal(clamped.limit, 200);
});

test('erreurs applicatives typées', () => {
  assert.equal(new AppError('x').status, 400);
  assert.equal(new NotFoundError().status, 404);
  assert.equal(new UnauthorizedError().status, 401);
  assert.equal(new ForbiddenError().status, 403);
  assert.equal(new ConflictError().status, 409);
  assert.equal(new ValidationError([{ field: 'a' }]).status, 422);
});
