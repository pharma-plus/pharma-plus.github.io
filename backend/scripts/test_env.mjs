// Garde d'environnement pour les scripts de test PHARMA+.
//
// Règles (sécurité) :
//  - Aucun identifiant n'est codé en dur : les scripts lisent les variables
//    PHARMA_TEST_* (fournies par l'opérateur via l'environnement, jamais via
//    Git).
//  - Toute cible dont l'URL contient une référence de PRODUCTION est refusée,
//    même si les autres variables sont renseignées : un nom de variable
//    « TEST » ou un compte « test » n'est PAS une preuve d'isolement.
//  - Les scripts mutants exigent en plus une confirmation explicite
//    PHARMA_TEST_ALLOW_MUTATIONS="YES_NOT_PRODUCTION".
//
// Prérequis : un projet Supabase de TEST distinct (ou une API locale isolée)
// n'appartenant pas à la production. Sans cela, les scripts s'arrêtent avec le
// code 3 et n'exécutent AUCUNE opération.

export const PRODUCTION_PROJECT_REFS = ["lwepnnecnrqdzadesyqo"];

export function requireIsolatedTestEnv({ mutations = false, script = "script" } = {}) {
  const base = (process.env.PHARMA_TEST_BASE_URL ?? "").trim().replace(/\/+$/, "");
  const email = (process.env.PHARMA_TEST_ADMIN_EMAIL ?? "").trim();
  const password = process.env.PHARMA_TEST_ADMIN_PASSWORD ?? "";
  const problems = [];
  if (!base) problems.push("PHARMA_TEST_BASE_URL absent (URL de l'API de test)");
  if (!email) problems.push("PHARMA_TEST_ADMIN_EMAIL absent (compte de l'environnement de test)");
  if (!password) problems.push("PHARMA_TEST_ADMIN_PASSWORD absent");
  if (mutations && process.env.PHARMA_TEST_ALLOW_MUTATIONS !== "YES_NOT_PRODUCTION") {
    problems.push('PHARMA_TEST_ALLOW_MUTATIONS doit valoir exactement "YES_NOT_PRODUCTION"');
  }
  if (base) {
    for (const ref of PRODUCTION_PROJECT_REFS) {
      if (base.includes(ref)) {
        problems.push(`cible = projet de PRODUCTION (${ref}) — interdit pour ${script}`);
      }
    }
  }
  if (problems.length) {
    console.error(`[${script}] ENVIRONNEMENT DE TEST NON CONFORME — exécution refusée :`);
    for (const p of problems) console.error(`  - ${p}`);
    console.error(
      "Prérequis : projet Supabase de TEST distinct (ou API locale isolée) " +
        "avec ses propres identifiants. Aucune opération n'a été exécutée.",
    );
    process.exit(3);
  }
  return { BASE: base, email, password };
}

// Garde minimaliste pour les scripts qui n'ont besoin que d'une URL (lecture
// seule) : refuse la production, n'exige pas d'identifiants.
export function requireNonProductionUrl({ script = "script" } = {}) {
  const base = (process.env.PHARMA_TEST_BASE_URL ?? "").trim().replace(/\/+$/, "");
  const problems = [];
  if (!base) problems.push("PHARMA_TEST_BASE_URL absent");
  if (base) {
    for (const ref of PRODUCTION_PROJECT_REFS) {
      if (base.includes(ref)) problems.push(`cible = production (${ref}) — interdit`);
    }
  }
  if (problems.length) {
    console.error(`[${script}] URL refusée :`);
    for (const p of problems) console.error(`  - ${p}`);
    process.exit(3);
  }
  return base;
}

// Garde « ops » pour les outils de maintenance qui ciblent volontairement la
// base renseignée dans DATABASE_URL (ex. nettoyage de ventes de test) :
// exige que l'opérateur confirme le projet cible avant TOUTE mutation.
export function requireOpsConfirm(databaseUrl, { script = "script" } = {}) {
  const u = String(databaseUrl ?? "");
  // Référence projet : hôte direct <ref>.supabase.co, ou userinfo du pooler
  // postgres.<ref>@<region>-pooler.supabase.com.
  const m =
    /\/([a-z0-9]+)\.supabase\.(?:co|com)/i.exec(u) ||
    /^postgres(?:ql)?:\/\/postgres\.([a-z0-9]+)(?::[^@]*)?@/i.exec(u);
  const ref = m ? m[1] : "";
  const confirm = (process.env.PHARMA_OPS_CONFIRM_PROJECT ?? "").trim();
  if (!ref) {
    console.error(
      `[${script}] impossible d'extraire la référence projet de DATABASE_URL — refus (cible non identifiée).`,
    );
    process.exit(3);
  }
  if (confirm !== ref) {
    console.error(
      `[${script}] OPÉRATION MUTANTE REFUSÉE : définissez PHARMA_OPS_CONFIRM_PROJECT="${ref}" ` +
        "pour confirmer explicitement la cible (aucune autre variable ne protège cette opération).",
    );
    process.exit(3);
  }
  return ref;
}

// Contrôle complémentaire pour les scripts qui ouvrent une connexion SQL
// directe (DATABASE_URL) : refuse toute référence de production connue.
// Une URL locale (127.0.0.1) ou un autre projet est accepté.
export function assertNonProductionDb(databaseUrl, { script = "script" } = {}) {
  const url = String(databaseUrl ?? "");
  if (!url) {
    console.error(`[${script}] DATABASE_URL absente — exécution refusée.`);
    process.exit(3);
  }
  for (const ref of PRODUCTION_PROJECT_REFS) {
    if (url.includes(ref)) {
      console.error(
        `[${script}] DATABASE_URL = base de PRODUCTION (${ref}) — refus. ` +
          "Pointer la variable vers la base de test avant exécution.",
      );
      process.exit(3);
    }
  }
  return url;
}
