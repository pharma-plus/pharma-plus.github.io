// =============================================================================
// PHARMA+ — chiffrement des sauvegardes (AES-256-GCM).
// Extrait de backup_worker.mjs pour être testable (test/backup_crypto.test.js)
// et pour garantir un générateur d'IV cryptographiquement sûr.
//
// Conteneur chiffré « PHB1 » : magic(4) || iv(12) || tag(16) || ciphertext
//   - IV = crypto.randomBytes(12) (CSPRNG) — jamais un PRNG non
//     cryptographique (l'implémentation historique utilisait un PRNG de
//     tribunal, corrigée le 16/10/2026).
//   - Clé = SHA-256(passphrase) — format inchangé (compat dumps historiques).
//   - L'IV est stocké dans le conteneur : tout IV 12 octets valide est lu à
//     l'ouverture (compatibilité des anciennes sauvegardes).
// Aucun secret n'est accepté autrement que par argument, aucun n'est journalisé.
// =============================================================================
import { createHash, createCipheriv, createDecipheriv, randomBytes } from "node:crypto";

export const MAGIC = Buffer.from("PHB1");
export const IV_LEN = 12;
export const TAG_LEN = 16;

export function keyFrom(passphrase) {
  return createHash("sha256").update(String(passphrase)).digest();
}

export function encryptWith(plain, key) {
  const iv = randomBytes(IV_LEN);
  const c = createCipheriv("aes-256-gcm", key, iv);
  const ct = Buffer.concat([c.update(plain), c.final()]);
  return Buffer.concat([MAGIC, iv, c.getAuthTag(), ct]);
}

export function decryptWith(blob, key) {
  if (blob.subarray(0, 4).toString() !== "PHB1") throw new Error("magic PHB1 absent");
  const iv = blob.subarray(4, 4 + IV_LEN);
  const tag = blob.subarray(4 + IV_LEN, 4 + IV_LEN + TAG_LEN);
  const ct = blob.subarray(4 + IV_LEN + TAG_LEN);
  const d = createDecipheriv("aes-256-gcm", key, iv);
  d.setAuthTag(tag);
  return Buffer.concat([d.update(ct), d.final()]);
}

export const sha256Hex = (b) => createHash("sha256").update(b).digest("hex");
