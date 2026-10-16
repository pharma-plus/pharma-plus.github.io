/**
 * Procédure contrôlée — superadministrateur global unique (prompt §3.3/§3.4).
 *
 *   node scripts/superadmin_reconcile.mjs --target <email> [options] [--apply]
 *
 * Options (toutes explicites, AUCUN défaut) :
 *   --target <email>          compte qui DOIT être l'unique superadmin (requis)
 *   --disable <email>         passe le compte en status inactive (répétable)
 *   --set-role <email>:<uuid> attribue un rôle métier (répétable)
 *   --apply                   exécute les écritures (sans : dry-run complet)
 *
 * Sécurités :
 *   - requireOpsConfirm : cible Supabase identifiée + PHARMA_OPS_CONFIRM_PROJECT
 *     égal à la référence projet AVANT toute écriture ;
 *   - transaction unique : inventaire → réconciliation → garde schéma →
 *     vérification, COMMIT ou ROLLBACK complet ;
 *   - snapshot JSON des avant-images écrit dans backend/backups/ (hors Git)
 *     pour rollback manuel ;
 *   - garde schéma idempotente : index partiel UNIQUE (1 seul porteur du flag)
 *     + trigger refusant toute élévation hors procédure (set local
 *     app.superadmin_grant='owner') ;
 *   - toutes les changements journalisés dans audit_logs ;
 *   - sessions des comptes démotées révoquées (les anciens jetons ne
 *     conservent aucun droit global : la source de vérité est la colonne).
 *
 * Aucun identifiant, mot de passe ou clé n'est codé en dur ni imprimé.
 */
import 'dotenv/config';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import pg from 'pg';
import { requireOpsConfirm } from './test_env.mjs';

const __dirname = path.dirname(fileURLToPath(import.meta.url));

const args = process.argv.slice(2);
const takeAll = (flag) => {
  const out = [];
  for (let i = 0; i < args.length; i++) {
    if (args[i] === flag && args[i + 1]) out.push(args[++i]);
  }
  return out;
};
const targetEmail = (takeAll('--target')[0] ?? '').trim();
const disableList = takeAll('--disable');
const setRoleList = takeAll('--set-role');
const APPLY = args.includes('--apply');

if (!targetEmail) {
  console.error('REFUS : --target <email> requis (aucun compte par défaut).');
  process.exit(1);
}
for (const pair of setRoleList) {
  if (!/^[^:]+:[0-9a-f-]{36}$/i.test(pair)) {
    console.error(`REFUS : --set-role attend <email>:<uuid> (reçu : ${pair.split(':')[0]}:…)`);
    process.exit(1);
  }
}

// --- Garde de cible : Supabase identifiée + confirmation explicite ---------
requireOpsConfirm(process.env.DATABASE_URL, { script: 'scripts/superadmin_reconcile.mjs' });

const rawUrl = process.env.DATABASE_URL ?? '';
const useSsl = /(sslmode=require|supabase|amazonaws|\.rds\.)/i.test(rawUrl);
let connectionString = rawUrl;
if (useSsl) {
  const u = new URL(rawUrl);
  u.searchParams.delete('sslmode');
  connectionString = u.toString();
}
const db = new pg.Client({
  connectionString,
  ssl: useSsl ? { rejectUnauthorized: false } : undefined,
});

const SCHEMA_GUARD = `
  CREATE UNIQUE INDEX IF NOT EXISTS uniq_users_single_superadmin
    ON public.users (is_super_admin) WHERE is_super_admin IS TRUE;
  CREATE OR REPLACE FUNCTION public.guard_superadmin_flag() RETURNS trigger
    LANGUAGE plpgsql AS $fn$
    BEGIN
      IF NEW.is_super_admin IS TRUE AND OLD.is_super_admin IS DISTINCT FROM TRUE THEN
        IF current_setting('app.superadmin_grant', true) = 'owner' THEN
          RETURN NEW;
        END IF;
        RAISE EXCEPTION 'superadmin : élévation refusée (procédure contrôlée uniquement)';
      END IF;
      RETURN NEW;
    END $fn$;
  DROP TRIGGER IF EXISTS trg_guard_superadmin_flag ON public.users;
  CREATE TRIGGER trg_guard_superadmin_flag
    BEFORE INSERT OR UPDATE OF is_super_admin ON public.users
    FOR EACH ROW EXECUTE FUNCTION public.guard_superadmin_flag();
`;

try {
  await db.connect();
  const result = { mode: APPLY ? 'APPLY' : 'DRY-RUN', steps: [] };
  const auditRows = [];

  await db.query('BEGIN');
  try {
    // --- 1. Inventaire + vérifications préalables -------------------------
    const target = await db.query(
      `SELECT id, email::text, status, is_super_admin, role_id, pharmacy_id
         FROM public.users WHERE lower(email::text) = lower($1)`,
      [targetEmail],
    );
    if (target.rowCount !== 1) {
      throw new Error(`cible "${targetEmail}" introuvable ou ambiguë (${target.rowCount} ligne)`);
    }
    const tgt = target.rows[0];
    if (tgt.status !== 'active') {
      throw new Error(`cible "${targetEmail}" non active (${tgt.status}) — réactiver d'abord le compte`);
    }
    result.target = {
      id: tgt.id, email: tgt.email, status: tgt.status,
      is_super_admin: tgt.is_super_admin, role_id: tgt.role_id,
    };
    result.steps.push(`cible OK : ${tgt.email} (flag actuel = ${tgt.is_super_admin})`);

    for (const mail of disableList) {
      if (mail.toLowerCase() === targetEmail.toLowerCase()) {
        throw new Error('--disable ne peut pas viser la cible');
      }
    }
    for (const pair of setRoleList) {
      const [mail, roleUuid] = pair.split(':');
      if (mail.toLowerCase() === targetEmail.toLowerCase()) {
        throw new Error('--set-role ne peut pas viser la cible (rôle de la cible inchangé)');
      }
      const r = await db.query('SELECT id FROM public.roles WHERE id = $1', [roleUuid]);
      if (r.rowCount !== 1) throw new Error(`rôle inconnu pour ${mail.split('@')[0]}@…`);
    }

    const superadmins = await db.query(
      `SELECT id, email::text, status FROM public.users WHERE is_super_admin IS TRUE ORDER BY email`,
    );
    result.before_superadmins = superadmins.rows.map((r) => ({ id: r.id, email: r.email, status: r.status }));
    result.steps.push(`avant : ${superadmins.rowCount} superadmin(s)`);

    // --- 2. Snapshot rollback (avant-images) ------------------------------
    const demotedIds = superadmins.rows.filter((r) => r.id !== tgt.id).map((r) => r.id);
    const beforeTargets = await db.query(
      `SELECT id, email::text, status, role_id FROM public.users
        WHERE lower(email::text) = ANY($1::text[])`,
      [[...disableList, ...setRoleList.map((p) => p.split(':')[0])].map((m) => m.toLowerCase())],
    );
    const snapshot = {
      created_at: new Date().toISOString(),
      script: 'superadmin_reconcile.mjs',
      target_before: result.target,
      superadmins_before: result.before_superadmins,
      others_before: beforeTargets.rows,
      rollback_sql: [
        ...result.before_superadmins.map((r) =>
          `UPDATE public.users SET is_super_admin = TRUE WHERE id = '${r.id}';`),
        ...beforeTargets.rows.map((r) =>
          `UPDATE public.users SET status = '${r.status}', role_id = ${r.role_id ? `'${r.role_id}'` : 'NULL'} WHERE id = '${r.id}';`),
      ],
    };
    const outDir = path.resolve(__dirname, '../backups');
    fs.mkdirSync(outDir, { recursive: true });
    const snapFile = path.join(outDir, `superadmin_reconcile_${Date.now()}.json`);
    fs.writeFileSync(snapFile, JSON.stringify(snapshot, null, 2));
    result.snapshot = snapFile;
    result.steps.push(`snapshot rollback : ${path.basename(snapFile)}`);

    // --- 3. Réconciliation des drapeaux -----------------------------------
    if (demotedIds.length) {
      const demoted = await db.query(
        `UPDATE public.users SET is_super_admin = FALSE, updated_at = now()
          WHERE id = ANY($1::uuid[]) RETURNING id, email::text`,
        [demotedIds],
      );
      result.demoted = demoted.rows.map((r) => ({ id: r.id, email: r.email }));
      result.steps.push(`drapeaux retirés : ${demoted.rowCount}`);
      // Révocation des sessions (aucun jeton ancien ne conserve de droits).
      const rev = await db.query(
        `UPDATE public.user_sessions SET revoked_at = now()
          WHERE revoked_at IS NULL AND user_id = ANY($1::uuid[])`,
        [demotedIds],
      );
      result.sessions_revoked = rev.rowCount;
      result.steps.push(`sessions révoquées : ${rev.rowCount}`);
      for (const r of demoted.rows) {
        auditRows.push({
          pharmacy_id: tgt.pharmacy_id, user_id: tgt.id,
          action: 'superadmin_revoked', module: 'security',
          entity: 'users', entity_id: r.id,
          old_values: { is_super_admin: true, email: r.email },
          new_values: { is_super_admin: false },
        });
      }
    }
    if (!tgt.is_super_admin) {
      await db.query(`SELECT set_config('app.superadmin_grant', 'owner', true)`);
      await db.query(
        `UPDATE public.users SET is_super_admin = TRUE, updated_at = now() WHERE id = $1`,
        [tgt.id],
      );
      result.granted = tgt.email;
      result.steps.push(`drapeau accordé : ${tgt.email}`);
      auditRows.push({
        pharmacy_id: tgt.pharmacy_id, user_id: tgt.id,
        action: 'superadmin_granted', module: 'security',
        entity: 'users', entity_id: tgt.id,
        old_values: { is_super_admin: false }, new_values: { is_super_admin: true },
      });
    }

    // --- 4. Comptes à désactiver (usage : --disable) ----------------------
    for (const mail of disableList) {
      const up = await db.query(
        `UPDATE public.users SET status = 'inactive', updated_at = now()
          WHERE lower(email::text) = lower($1) AND status <> 'inactive'
          RETURNING id, email::text`,
        [mail],
      );
      if (up.rowCount === 0) result.steps.push(`--disable ${mail} : déjà inactif ou introuvable`);
      else {
        result.disabled = [...(result.disabled ?? []), up.rows[0].email];
        result.steps.push(`compte désactivé : ${up.rows[0].email}`);
        auditRows.push({
          pharmacy_id: tgt.pharmacy_id, user_id: tgt.id,
          action: 'account_disabled', module: 'security',
          entity: 'users', entity_id: up.rows[0].id,
          old_values: { status: 'active' }, new_values: { status: 'inactive' },
        });
      }
    }

    // --- 5. Attribution de rôle métier (usage : --set-role email:uuid) ----
    for (const pair of setRoleList) {
      const [mail, roleUuid] = pair.split(':');
      const up = await db.query(
        `UPDATE public.users SET role_id = $2, updated_at = now()
          WHERE lower(email::text) = lower($1) AND role_id IS DISTINCT FROM $2
          RETURNING id, email::text, role_id`,
        [mail, roleUuid],
      );
      if (up.rowCount === 0) result.steps.push(`--set-role ${mail.split('@')[0]}@… : rôle déjà attribué ou introuvable`);
      else {
        result.roles_changed = [...(result.roles_changed ?? []), { email: up.rows[0].email, role_id: roleUuid }];
        result.steps.push(`rôle attribué : ${up.rows[0].email} → ${roleUuid}`);
        auditRows.push({
          pharmacy_id: tgt.pharmacy_id, user_id: tgt.id,
          action: 'role_changed', module: 'security',
          entity: 'users', entity_id: up.rows[0].id,
          old_values: null, new_values: { role_id: roleUuid },
        });
      }
    }

    // --- 6. Garde schéma (unicité + trigger) ------------------------------
    await db.query(SCHEMA_GUARD);
    result.steps.push('garde schéma : index UNIQUE partiel + trigger anti-élévation (idempotent)');

    // --- 7. Audit ---------------------------------------------------------
    for (const row of auditRows) {
      await db.query(
        `INSERT INTO public.audit_logs (pharmacy_id, user_id, action, module, entity, entity_id, old_values, new_values)
         VALUES ($1,$2,$3,$4,$5,$6,$7,$8)`,
        [row.pharmacy_id, row.user_id, row.action, row.module, row.entity, row.entity_id,
         row.old_values ? JSON.stringify(row.old_values) : null,
         row.new_values ? JSON.stringify(row.new_values) : null],
      );
    }
    result.audit_rows = auditRows.length;

    // --- 8. Vérification finale dans la transaction -----------------------
    const after = await db.query(
      `SELECT id, email::text FROM public.users WHERE is_super_admin IS TRUE`,
    );
    if (after.rowCount !== 1 || after.rows[0].id !== tgt.id) {
      throw new Error(
        `vérification finale échouée : ${after.rowCount} superadmin(s), attendu = 1 (${tgt.email})`,
      );
    }
    result.after_superadmins = after.rows.map((r) => r.email);
    result.steps.push('vérification finale : exactement 1 superadmin = ' + after.rows[0].email);

    if (APPLY) {
      await db.query('COMMIT');
      result.status = 'APPLIED';
    } else {
      await db.query('ROLLBACK');
      result.status = 'DRY-RUN (rollback — relancer avec --apply pour écrire)';
    }
  } catch (e) {
    await db.query('ROLLBACK');
    console.error('ROLLBACK complet : ' + e.message);
    console.error('Aucune écriture n\'a été conservée.');
    await db.end();
    process.exit(1);
  }

  console.log(JSON.stringify(result, null, 2));
  await db.end();
} catch (e) {
  console.error('ERREUR : ' + e.message);
  process.exit(1);
}
