-- ============================================================
-- 20261009123000_security_definer_scope_fix.sql
-- CORRECTION du verrou multi-pharmacies de public.fn_tenant_scope
-- (introduit par 20261009120000_security_definer_hardening.sql).
--
-- Defaut constate sur la base de production (tests de lecture,
-- 2026-10-09) : dans une fonction SECURITY DEFINER, `current_user`
-- vaut le PROPRIETAIRE de la fonction (postgres) et jamais le role
-- appelant. La branche "pilote de confiance" declenchait donc pour
-- TOUT appelant : enregistre mesure
--   authenticated + pharmacie etrangere -> scope_other = pharmacie
--   demandee (0 ligne au lieu du refus 42501).
--
-- Principe du correctif :
--   * seul le contexte de confiance reel du serveur ouvre un
--     perimetre large : le claim de role portee par le jeton deja
--     verifie par Postgrenos (role = service_role), c'est le chemin
--     Edge qui derive la pharmacie du profil authentifie ;
--   * aucun role ni identifiant de pharmacie n'est cru sur parole
--     lorsque le client l'envoie : pour `authenticated`, l'appartenance
--     est recalculee cote serveur (public.users) a partir des
--     identifiants du jeton (sub, a defaut email unique) ;
--   * contexte absent, role inconnu/anon, jeton malforme, utilisateur
--     introuvable, email ambigu (plusieurs comptes) ou pharmacie
--     differente -> refus SQL 42501 (echec ferme) ;
--   * p_requested NULL -> aucun perimetre (resultat vide), jamais de
--     perimetre par defaut.
--
-- Portee : cette seule fonction. CREATE OR REPLACE conserve la
-- signature, le proprietaire et les privileges (proacl) accordes par
-- la migration precedente.
--
-- AUCUNE donnee, table, colonne, policy ni privilege n'est modifie.
-- NON APPLIQUEE en production : application subordonnee a une
-- autorisation explicite (voir RAPPORT_LEVEE_BLOQUANTS.md).
-- ============================================================

create or replace function public.fn_tenant_scope(p_requested uuid)
returns uuid
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $fn$
declare
  v_claims  jsonb  := null;
  v_role    text   := '';
  v_sub     uuid   := null;
  v_email   text   := '';
  v_self    uuid   := null;
  v_cnt     integer := 0;
  v_resolved boolean := false;
begin
  /* ---------------------------------------------------------
     1. Contexte d'execution : les claims JWT tels que Postgrenos
        les publie APRES verification de la signature. Ce n'est
        ni current_user (toujours le proprietaire ici) ni une
        valeur lue dans la requete du client.
     --------------------------------------------------------- */
  begin
    v_claims := nullif(current_setting('request.jwt.claims', true), '')::jsonb;
  exception when others then
    v_claims := null;                      -- JSON absent/corrompu
  end;
  if v_claims is null or jsonb_typeof(v_claims) <> 'object' then
    v_claims := null;
  end if;

  if v_claims is not null then
    v_role := left(coalesce(v_claims ->> 'role', ''), 64);
    if v_role = '' then
      begin                                 -- repli sur l'aide Supabase
        v_role := left(coalesce(auth.role(), ''), 64);
      exception when others then
        v_role := '';
      end;
    end if;

    if coalesce(v_claims ->> 'sub', '')
         ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' then
      v_sub := (v_claims ->> 'sub')::uuid;
    end if;
    v_email := left(lower(coalesce(v_claims ->> 'email', '')), 320);
  end if;

  /* ---------------------------------------------------------
     2. Unique pilote de confiance : service_role.
        Ce role n'est obtainable qu'avec la cle de service (JWT
        signe par le projet) ; Postgrenos le porte dans les claims.
        La Edge Function derive deja p_pharmacy du profil
        authentifie (pharmacyId(req)) avant l'appel : l'identifiant
        ne provient jamais directement du client.
     --------------------------------------------------------- */
  if v_role = 'service_role' then
    if p_requested is null then
      return null;
    end if;
    return p_requested;
  end if;

  /* ---------------------------------------------------------
     3. Tous les autres contextes : perimetre strictement
        personnel, prouve par les donnees serveur.
     --------------------------------------------------------- */
  if p_requested is null then
    return null;
  end if;

  if v_role <> 'authenticated' then
    raise exception 'pharmacy scope violation: no authenticated JWT context'
      using errcode = '42501';
  end if;

  begin
    if v_sub is not null then
      select u.pharmacy_id into v_self
        from public.users u
       where u.id = v_sub;
      v_resolved := found;
    end if;

    /* public.users.id ne correspond pas toujours au sub Supabase :
       repli sur l'adresse du jeton, uniquement si elle designe
       exactement un compte (0 ou plusieurs comptes => refus). */
    if not v_resolved and v_email <> '' then
      select count(*), (array_agg(u.pharmacy_id))[1] into v_cnt, v_self
        from public.users u
       where lower(u.email) = v_email;
      if v_cnt = 1 then
        v_resolved := true;
      else
        v_self := null;                     -- introuvable ou ambigu
        v_resolved := false;
      end if;
    end if;
  exception when others then
    v_self := null;
    v_resolved := false;
  end;

  if not v_resolved or v_self is null then
    raise exception 'pharmacy scope violation: membership not proven'
      using errcode = '42501';
  end if;

  if v_self <> p_requested then
    raise exception 'pharmacy scope violation: caller may not read requested pharmacy'
      using errcode = '42501';
  end if;

  return p_requested;
end;
$fn$;
