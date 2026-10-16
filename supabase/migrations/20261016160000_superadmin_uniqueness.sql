-- ============================================================================
-- Superadministrateur global UNIQUE (prompt sécurité §3.4) — 16/10/2026
--
-- Contrainte d'unicité au niveau de la base + garde d'élévation :
--   1. index partiel UNIQUE  → au plus UN porteur de is_super_admin = true ;
--   2. trigger               → toute élévation (false/NULL → true) exige la
--                              procédure contrôlée qui pose
--                              set_config('app.superadmin_grant','owner', true)
--                              dans SA transaction (scripts/superadmin_reconcile.mjs).
--
-- AVANT d'appliquer : réconcilier les comptes existants (plusieurs porteurs
-- possibles feraient échouer l'index) — c'est le rôle du script
-- backend/scripts/superadmin_reconcile.mjs (dry-run puis --apply, dans une
-- transaction unique, avec snapshot de rollback). Ce fichier est l'histoire
-- ; l'application en production se fait via ce script (supabase CLI interdit
-- par le prompt).
--
-- Aucune donnée n'est supprimée : les rôles/drapeaux/sessions sont ajustés,
-- l'historique métier (ventes, audits) est intégralement préservé.
-- ============================================================================

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
