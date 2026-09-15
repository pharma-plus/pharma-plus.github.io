/**
 * R├®initialisation du mot de passe d'un utilisateur (usage op├®rateur).
 *
 *   node scripts/reset-password.mjs <email> <nouveau-mot-de-passe> [--keep-change-flag]
 *
 * - Hachage identique au service auth (argon2id) ;
 * - d├®verrouille le compte (failed_attempts = 0, locked_until = NULL) ;
 * - force le changement de mot de passe ├á la prochaine connexion sauf si
 *   --keep-change-flag est omis... (par d├®faut : must_change_password = true,
 *   passer --no-force-change pour ne pas forcer le changement).
 *
 * ÔÜá´©Å ├ëcrit en base : ├á ex├®cuter uniquement en connaissance de cause.
 */
import 'dotenv/config';
import argon2 from 'argon2';
import { pool } from '../src/db/pool.js';

const [email, password, flag] = process.argv.slice(2);

if (!email || !password) {
  console.error('Usage : node scripts/reset-password.mjs <email> <nouveau-mot-de-passe> [--no-force-change]');
  process.exit(1);
}
if (password.length < 8) {
  console.error('Mot de passe trop court (8 caract├¿res minimum).');
  process.exit(1);
}
const forceChange = flag !== '--no-force-change';

const hash = await argon2.hash(password, { type: argon2.argon2id });
const { rows } = await pool.query(
  `UPDATE users
      SET password_hash = $1,
          failed_attempts = 0,
          locked_until = NULL,
          must_change_password = $2,
          updated_at = now()
    WHERE lower(email) = lower($3)
      AND deleted_at IS NULL
   RETURNING email, status, is_super_admin`,
  [hash, forceChange, email],
);

if (rows.length === 0) {
  console.error(`Aucun utilisateur actif trouv├® pour ┬½ ${email} ┬╗.`);
  await pool.end();
  process.exit(1);
}

console.log(`Mot de passe mis ├á jour pour ${rows[0].email} (statut : ${rows[0].status}${rows[0].is_super_admin ? ', super admin' : ''}).`);
console.log(forceChange ? 'Le changement de mot de passe sera exig├® ├á la prochaine connexion.' : 'Aucun changement forc├® ├á la connexion.');
await pool.end();
