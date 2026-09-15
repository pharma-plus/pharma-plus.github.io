import crypto from 'node:crypto';

/** Génère un identifiant unique (UUID v4). */
export const uuid = () => crypto.randomUUID();

/** Hache une valeur (sessions, jetons) — SHA-256, jamais stocké en clair. */
export const sha256 = (value) =>
  crypto.createHash('sha256').update(String(value)).digest('hex');

/** Retire les champs sensibles d'un objet avant réponse. */
export function sanitizeUser(user) {
  if (!user) return user;
  const copy = { ...user };
  delete copy.password_hash;
  delete copy.pin_hash;
  delete copy.two_factor_secret;
  return copy;
}

/** Chiffrement symétrique AES-256-GCM pour les sauvegardes. */
export function encryptBuffer(plain, key) {
  const iv = crypto.randomBytes(12);
  const cipher = crypto.createCipheriv('aes-256-gcm', key, iv);
  const enc = Buffer.concat([cipher.update(plain), cipher.final()]);
  return Buffer.concat([iv, cipher.getAuthTag(), enc]);
}

export function decryptBuffer(data, key) {
  const iv = data.subarray(0, 12);
  const tag = data.subarray(12, 28);
  const enc = data.subarray(28);
  const decipher = crypto.createDecipheriv('aes-256-gcm', key, iv);
  decipher.setAuthTag(tag);
  return Buffer.concat([decipher.update(enc), decipher.final()]);
}

/** Dérive une clé AES-256 à partir d'une passphrase (PBKDF2). */
export function deriveKey(passphrase) {
  return crypto.scryptSync(String(passphrase), 'pmg-salt-v1', 32);
}

/** Norme EAN-13 : calcule la clé de contrôle. */
export function ean13CheckDigit(ean12) {
  const digits = String(ean12).padStart(12, '0').split('').map(Number);
  const sum = digits.reduce((acc, d, i) => acc + d * (i % 2 === 0 ? 1 : 3), 0);
  const check = (10 - (sum % 10)) % 10;
  return check;
}

export function isEan13Valid(ean) {
  if (!/^\d{13}$/.test(String(ean))) return false;
  const check = ean13CheckDigit(String(ean).slice(0, 12));
  return check === Number(String(ean)[12]);
}
