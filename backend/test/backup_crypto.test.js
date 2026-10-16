// Tests du chiffrement des sauvegardes (exigences sécurité 16/10/2026) :
// IV CSPRNG, compat conteneur PHB1, intégrité GCM, non-régression source.
import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";
import { createCipheriv } from "node:crypto";
import {
  MAGIC,
  IV_LEN,
  TAG_LEN,
  keyFrom,
  encryptWith,
  decryptWith,
  sha256Hex,
} from "../scripts/backup_crypto.mjs";

const here = dirname(fileURLToPath(import.meta.url));
const cryptoSrc = readFileSync(join(here, "..", "scripts", "backup_crypto.mjs"), "utf8");
const workerSrc = readFileSync(join(here, "..", "scripts", "backup_worker.mjs"), "utf8");

test("backup_crypto : roundtrip AES-256-GCM (plain -> PHB1 -> plain)", () => {
  const key = keyFrom("passphrase-de-test");
  const plain = Buffer.from("contenu de dump PostgreSQL de test\n".repeat(100));
  const blob = encryptWith(plain, key);
  assert.equal(blob.subarray(0, 4).toString(), "PHB1", "magic PHB1 en tête");
  assert.equal(blob.length, MAGIC.length + IV_LEN + TAG_LEN + plain.length, "layout conteneur");
  const back = decryptWith(blob, key);
  assert.ok(back.equals(plain), "contenu identique après déchiffrement");
});

test("backup_crypto : SHA-256 déterministe et conforme (vecteur officiel « abc »)", () => {
  assert.equal(
    sha256Hex(Buffer.from("abc")),
    "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad",
  );
  const a = sha256Hex(Buffer.from("x"));
  const b = sha256Hex(Buffer.from("x"));
  assert.equal(a, b, "inchangé pour des entrées identiques");
});

test("backup_crypto : IV = randomBytes(12), distinct à chaque chiffrement", () => {
  const key = keyFrom("clé");
  const plain = Buffer.from("mêmes données");
  const b1 = encryptWith(plain, key);
  const b2 = encryptWith(plain, key);
  const iv1 = b1.subarray(4, 4 + IV_LEN);
  const iv2 = b2.subarray(4, 4 + IV_LEN);
  assert.equal(iv1.length, IV_LEN, "IV de 12 octets");
  assert.ok(!iv1.equals(iv2), "IV aléatoire par opération (jamais réutilisé)");
  assert.ok(!b1.equals(b2), "chiffres différents malgré même clé/plaintext");
});

test("backup_crypto : source = crypto.randomBytes, jamais Math.random", () => {
  assert.match(cryptoSrc, /randomBytes\(IV_LEN\)/, "IV généré par randomBytes");
  assert.ok(!cryptoSrc.includes("Math.random"), "aucun Math.random dans le module");
  assert.ok(!workerSrc.includes("Math.random"), "aucun Math.random restant dans le worker");
  assert.ok(!workerSrc.includes("createCipheriv"), "chiffrement isolé dans le module (worker dépendant)");
});

test("backup_crypto : altération du chiffré refusée (tag GCM)", () => {
  const key = keyFrom("passphrase");
  const blob = encryptWith(Buffer.from("données sensibles"), key);
  const bad = Buffer.from(blob);
  bad[bad.length - 1] ^= 0xff;
  assert.throws(() => decryptWith(bad, key), "décryptage d'un chiffré altéré doit échouer");
});

test("backup_crypto : altération du tag authentification refusée", () => {
  const key = keyFrom("passphrase");
  const blob = encryptWith(Buffer.from("données sensibles"), key);
  const bad = Buffer.from(blob);
  bad[4 + IV_LEN] ^= 0x01;
  assert.throws(() => decryptWith(bad, key), "tag corrompu doit échouer");
});

test("backup_crypto : mauvaise clé = échec (aucune restitution)", () => {
  const blob = encryptWith(Buffer.from("secret"), keyFrom("bonne-clé"));
  assert.throws(() => decryptWith(blob, keyFrom("mauvaise-clé")));
});

test("backup_crypto : compat fixture IV fixe (dumps historiques lisibles)", () => {
  // Conteneur bâti manquement avec IV fixe : le déchiffreur lit l'IV du
  // conteneur (historique Math.random conservait bien IV 12 octets inline).
  const passphrase = "fixture-pass";
  const key = keyFrom(passphrase);
  const iv = Buffer.alloc(IV_LEN, 7);
  const plain = Buffer.from("fixture dump historique");
  const c = createCipheriv("aes-256-gcm", key, iv);
  const ct = Buffer.concat([c.update(plain), c.final()]);
  const fixture = Buffer.concat([MAGIC, iv, c.getAuthTag(), ct]);
  const back = decryptWith(fixture, key);
  assert.ok(back.equals(plain), "un conteneur PHB1 à IV fixe se déchiffre (format conservé)");
});

test("backup_crypto : keyFrom = SHA-256(passphrase), stable, 32 octets", () => {
  const k1 = keyFrom("une-passphrase");
  const k2 = keyFrom("une-passphrase");
  assert.equal(k1.length, 32, "clé AES-256 = 32 octets");
  assert.ok(k1.equals(k2), "dérivation déterministe");
  assert.ok(!k1.equals(keyFrom("autre-passphrase")));
});

test("backup_crypto : magic absent = refus explicite", () => {
  const key = keyFrom("p");
  const junk = Buffer.alloc(64, 3);
  assert.throws(() => decryptWith(junk, key), /PHB1/);
});
