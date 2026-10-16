/* POLITIQUE DE LOGIN — décision d'attribution de privilèges au moment de
   la création de session (prompt sécurité §3.2).

   Module PUR : aucun accès réseau, aucun secret, aucune dépendance Deno —
   importable par Deno (index.ts) et par Node (tests backend, strip-types).

   Règle absolue : les privilèges ne viennent QUE du profil applicatif
   public.users. Un compte Supabase Auth sans profil valide reçoit un refus
   contrôlé — JAMAIS de privilèges par défaut, jamais de reconstruction
   synthétique de profil (l'ancien fallback attribuait is_super_admin: true). */

export type LoginProfileRow = {
  id?: string | null;
  email?: string | null;
  pharmacy_id?: string | null;
  branch_id?: string | null;
  role_id?: string | null;
  status?: string | null;
  is_super_admin?: boolean | null;
  [k: string]: unknown;
};

export type ProfileRefusalCode =
  | "PROFILE_MISSING"
  | "PROFILE_INCOMPLETE"
  | "PROFILE_DISABLED"
  | "IDENTITY_MISMATCH";

export type LoginProfileDecision =
  | { ok: true; profile: LoginProfileRow }
  | { ok: false; code: ProfileRefusalCode; message: string };

function norm(v: unknown): string {
  return String(v ?? "").trim().toLowerCase();
}

/**
 * Décide si une session peut être construite, à partir du profil trouvé
 * par id Auth (si présent) et/ou par email.
 *
 * - les deux recherches trouvent des lignes différentes → IDENTITY_MISMATCH ;
 * - aucun profil → PROFILE_MISSING (refus contrôlé, aucun privilège) ;
 * - email du profil ≠ email de la session → IDENTITY_MISMATCH ;
 * - statut ≠ active → PROFILE_DISABLED ;
 * - rôle absent → PROFILE_INCOMPLETE (profil incomplet, refus) ;
 * - sinon OK : les privilèges (is_super_admin, permissions) sont ceux
 *   stockés en base, jamais déduits.
 */
export function decideLoginProfile(input: {
  profileById?: LoginProfileRow | null;
  profileByEmail?: LoginProfileRow | null;
  sessionEmail: string;
}): LoginProfileDecision {
  const wanted = norm(input.sessionEmail);
  const byId = input.profileById ?? null;
  const byEmail = input.profileByEmail ?? null;

  if (byId && byEmail && String(byId.id ?? "") !== String(byEmail.id ?? "")) {
    return {
      ok: false,
      code: "IDENTITY_MISMATCH",
      message: "Identité incohérente — contactez l'administrateur",
    };
  }

  const profile = byId ?? byEmail;
  if (!profile) {
    return {
      ok: false,
      code: "PROFILE_MISSING",
      message: "Profil applicatif introuvable — accès refusé",
    };
  }

  if (wanted && norm(profile.email) !== wanted) {
    return {
      ok: false,
      code: "IDENTITY_MISMATCH",
      message: "Identité incohérente — contactez l'administrateur",
    };
  }

  if (norm(profile.status) !== "active") {
    return {
      ok: false,
      code: "PROFILE_DISABLED",
      message: "Compte désactivé — contactez l'administrateur",
    };
  }

  if (!profile.role_id) {
    return {
      ok: false,
      code: "PROFILE_INCOMPLETE",
      message: "Profil sans rôle attribué — accès refusé",
    };
  }

  return { ok: true, profile };
}
