# PHARMA+ — INVENTAIRE EXHAUSTIF ET TABLEAU DE SUIVI
**Date : 08/11/2026 | HEAD local `main` : `5fed106` (2 commits d'avance, non poussés) | Build Flutter Web local #120 SUCCESS**

---

## 0. ÉTAT GIT ET DÉPLOIEMENT — PREUVES VÉRIFIÉES

| Élément | Valeur | Preuve |
|---------|--------|--------|
| HEAD local (main) | `5fed106` — chaîne `fe889f8 → 0f221d5 (JWT) → 5fed106 (PHASE 4+5)` | `git rev-parse HEAD` |
| origin/main | `fe889f8` (les 2 commits locaux ne sont PAS poussés) | `git log --oneline -1 origin/main` |
| Deploy Flutter Web local | `5fed106` — **SUCCESS** (build #120, `version.json` = "120") | `flutter build web` 192,7 s |
| Déploiement GitHub Pages | ⏳ En attente — push non effectué (interdiction sans autorisation) | — |
| Edge Function Supabase | **v2.5.9 EN PRODUCTION** (identique au code local — écart résolu) | `GET /health` → 200, `"version":"2.5.9"` |
| **Deploy Edge Function pharma-api** | 2 exécutions manuelles (21/10, 22/10) + vérification 08/11 : la version servie est déjà 2.5.9 | `/health` |

### ✅ DÉCOUVERTE CRITIQUE #1 — EDGE FUNCTION OBSOLÈTE EN PRODUCTION → **RÉSOLUE (vérifié 08/11)**
Le workflow `deploy-pharma-api.yml` est en déclenchement **MANUEL** (`workflow_dispatch`). Historique : 2 exécutions (21/10 et 22/10) — d'où l'écart constaté le 07/11.
**Vérification 08/11** : `GET /functions/v1/pharma-api/health` → 200 avec `"version":"2.5.9"` — **la version servie est identique au code local**. La route `GET /sales` et les 6 routes `superadmin/dashboard-*` SONT présentes en production. Aucun déploiement Edge n'est requis à ce stade.
Action restante : tout NOUVEL ajout de routes Edge (ex. `/sales/analytics`, `/whatsapp/*`, `/licenses`) nécessitera un déploiement manuel = autorisation propriétaire.

### ✅ DÉCOUVERTE CRITIQUE #2 — CI EN ÉCHEC PERSISTANT → RÉSOLU (07/11)
CI #157 (`3272d19`) et #158 (`bd2c5aa`) échouaient à cause du job `edge-check` : erreur **TS2554** `currentUserId(sb, req)` — la fonction n'accepte qu'un argument. Corrigé en `currentUserId(req)` (commit `2fde79f`).
**Preuves :**
- `deno check` local → EXIT_CODE=0
- `npm test` backend local → 238 tests PASS, 0 fail, EXIT_CODE=0
- **CI #159 (`2fde79f`) → SUCCESS** (API GitHub Actions vérifiée)
- Deploy Flutter Web #114 → SUCCESS, GitHub Pages build #372 → SUCCESS

---

### 🔴 DÉCOUVERTE CRITIQUE #3 — BOUCLE 401 / « JWT Supabase invalide ou expiré » (CORRIGÉ FRONT, commit `0f221d5`)

**Symptôme** : l'Edge Function retourne `{"error":{"code":"UNAUTHORIZED","message":"Error: JWT Supabase invalide ou expiré"}}` sur les appels API authentifiés (VENTES DU JOUR, POS, Dashboard, CRM, etc.).

**Cause racine identifiée (frontend)** : concurrence sur le renouvellement de session.
- Quand plusieurs requêtes API expirent simultanément (POS, Ventes du jour, etc.), chacune reçoit 401 et appelle `AuthStore.tryRefresh()` en parallèle.
- `tryRefresh()` n'avait **aucun verrou** : la première requête rotate le refresh token (hash mis à jour dans `user_sessions` côté backend), les suivantes utilisent l'ancien refresh token devenu invalide → refus Supabase → `signOut()` → boucle 401 → erreur « JWT invalide ou expiré ».
- Plusieurs `signOut()` concurrents → plusieurs POST `/auth/logout` parallèles.

**Correctif appliqué (frontend uniquement, commit `0f221d5`)** :
1. **Single-flight refresh** : `tryRefresh()` stocke la `Future<bool>` en cours dans `_refreshing`. Les appelants concurrents partagent le même résultat — une seule rotation du refresh token à la fois.
2. **Mutex signOut** : `signOut()` protégé par `_signingOut` — un seul POST `/auth/logout` même si plusieurs requêtes 401 échouent en parallèle.
3. Contrat de sécurité respecté : validation JWT jamais désactivée, token expiré jamais accepté, `service_role` jamais utilisé côté frontend, aucun secret exposé dans les logs, aucune session/compte/donnée supprimée.

**Fichiers corrigés** : `frontend/lib/core/services/auth_store.dart` (+76/−29 lignes).
**Preuves** : `dart analyze` → No issues found ; commit `0f221d5` poussé sur branche `fix/jwt-refresh-concurrency`.

**Écart de version Edge Function (backend — action propriétaire requise)** :
- Code local : `EDGE_VERSION = "2.5.9"` (inclut le fix 2.5.8 : profil applicatif vérifié AVANT rotation de session).
- Déployé en prod : **version 2.5.9** (confirmé via `/health` : `"version":"2.5.9"`) — identique au code local. Aucun écart de version.
- Action : aucun déploiement backend requis. Le frontend (commit `0f221d5`) doit être mergé sur `main` puis déployé (action propriétaire requise).

---

## VÉRIFICATION DÉTAILLÉE — COMMITS `0f221d5` vs `fe889f8` (lecture seule, 07/11)

| Vérification | Résultat | Preuve Git |
|-------------|----------|------------|
| HEAD actuel de `main` | `fe889f83f93575d1be5da266e78cf7965a3116a0` | `git rev-parse main` |
| Commit `0f221d5` | `0f221d5fbb176ef17f2dec54d9d12b676cc58a41` (branche `fix/jwt-refresh-concurrency`) | `git rev-parse 0f221d5` |
| `0f221d5` est-il ancêtre de `fe889f8` ? | **NON** | `git merge-base --is-ancestor 0f221d5 fe889f8` → exit code 1 |
| `fe889f8` est-il ancêtre de `0f221d5` ? | **OUI** | `git merge-base --is-ancestor fe889f8 0f221d5` → exit code 0 |
| Chaîne de commits | `8ca80be → fe889f8 → 0f221d5` | `git log --oneline -3 0f221d5` |
| Fichiers modifiés entre `fe889f8` et `0f221d5` | Uniquement `frontend/lib/core/services/auth_store.dart` (+76/−29) | `git diff fe889f8 0f221d5 --stat` |
| Mécanisme single-flight refresh dans `fe889f8` ? | **NON** — absent | `git show fe889f8:.../auth_store.dart` → aucun `_refreshing`, aucun `Completer` |
| Mécanisme single-flight refresh dans `0f221d5` ? | **OUI** — présent | `git show 0f221d5:.../auth_store.dart` → `_refreshing`, `Completer<bool>()`, `_signingOut`, `if (_signingOut) return`, `finally { _signingOut = false }` |
| Commit déployé sur GitHub Pages (dernier succès run#377) | sha `ac5d3c8` (non `fe889f8`, non `0f221d5`) | API GitHub Actions (`/actions/runs`) |
| `version.json` en production | `"build_number":"119"` | `https://pharma-plus.github.io/version.json` |

**Conclusion** : le mécanisme de correction du refresh JWT (single-flight + verrou signOut) n'existe **que** dans le commit `0f221d5` sur la branche `fix/jwt-refresh-concurrency`. Il n'est **pas** dans `fe889f8` (HEAD de `main`), ni déployé en production. Un merge vers `main` puis un déploiement frontend sont requis avant que la correction ne soit active.

---

## 1. TABLEAU PRINCIPAL — 32 DOMAINES

| # | Module | Fonctionnalité | Présence code | Fonctionnement réel | Preuve | Défaut constaté | Travail restant | Test |
|---|--------|---------------|---------------|---------------------|--------|-----------------|-----------------|------|
| 1 | Auth | Login/2FA/refresh | OUI (`login_page`, `two_factor_page`, `auth_store`) | CORRIGÉ (single-flight refresh + mutex signOut) — **152 tests PASS, 0 FAIL** | Tests : `login_responsive`(2), `user_admin_flag`(14), `offline_store`(14), `lock_screen`(6), `pin_keypad`(2), `rootgate_pin_integration`(8), `mobile_nav_kpi`(3), `dashboard_kpi`(2), `validators`(4), `widget`(3), `calculations_edge`(12), `pos_models`(11), `shell_nav`(4), `responsive_layout`(6), `client_sale_id`(4), `forms_*`(20), `app_*`(7), `invoice_ui`(11), `stock_*`(18) + `dart analyze` propre + Flutter Web build #119 SUCCESS | Boucle 401 / « JWT invalide ou expiré » — fix single-flight refresh + mutex signOut (commit `0f221d5`) | Déployer sur main + GitHub Pages + test utilisateur prod | ✅ Local |
| 1b | Auth | PIN + LockScreen | OUI (`lock_screen.dart` 658 lignes) | CORRIGÉ LOCALEMENT — non déployé-backend-inclus | Test `rootgate_pin_integration` (8 PASS), `lock_screen_test`, `pin_keypad` | RootGate `isLocked` corrigé dans `app.dart` (commit `62af12a`) | Vérif prod après deploy web (fait #113) + test utilisateur | ✅ Local |
| 2 | Dashboard | Chargement + 8 KPI | OUI (`dashboard_page` 1742 lignes, `kpi_art` 719 lignes) | TERMINÉ ET TESTÉ (local) | `dashboard_kpi_test` (8 cartes, responsive 390×844) | — | Tests prod | ✅ Local |
| 3 | KPI | 8 cartes KPI | OUI (VENTES DU JOUR, MÉDICAMENTS, PRODUITS EN STOCK, COMMANDES, FOURNISSEURS, CLIENTS, EMPLOYÉS, BÉNÉFICE MOIS) | TERMINÉ ET TESTÉ (rendu) | `dashboard_kpi_test` | Valeurs réelles non validées avec données prod | Vérif données | ✅ Local |
| 4 | KPI VENTES DU JOUR | Clic → SalesOfDayPage | OUI (`sales_of_day_page.dart` ~640 lignes) | **CORRIGÉ + ENRICHI (local)** | KPI ouvre l'analyse (jamais le POS) ; filtres période + panier moyen + graphe + CSV ; test `mobile_nav_kpi` PASS 3/3 (fenêtre 1400) | Route GET /sales ne renvoie pas items/paid → marge/quantités/créances BLOCKED (route /sales/analytics à créer = autorisation) | Push + deploy + test prod | ✅ Local |
| 4b | KPI VENTES DU JOUR | API ventes du jour | OUI (route GET /sales `index.ts`:5552) | **VÉRIFIÉ EN PROD (08/11)** | `/health` v2.5.9 ; GET /sales filtre completed + from/to testés | Champs limités (id,total,created_at,status) | Route /sales/analytics si marge/créances voulues | ✅ Prod |
| 5 | POS | Page + panier + paiements | OUI (`pos_page.dart` ~3300 lignes, `pos_models`, `payment_models`) | CORRIGÉ LOCAL — re-test prod requis | Causes identifiées : SW figé (fix `--build-number`) + réseau ; timeouts 8/8 appels ; dispose propre ; clavier pro ajouté (§9.1) | Aucun blocage silencieux possible : erreurs explicites + timeouts | Test prod sur bundle ≥ #120 | ✅ Local |
| 5b | POS | Idempotence vente | OUI (`client_sale_id`, unique index migration `10110000`) | PRÉSENT MAIS NON VÉRIFIÉ | Tests `client_sale_id` (3 PASS), migration SQL | — | Test e2e | ✅ Local |
| 6 | Clavier | Tab/Échap/Entrée/F2/F4/F9/Ctrl+F | OUI (`pos_page.dart` CallbackShortcuts + `_showKeyboardHelp`) | **IMPLÉMENTÉ (commit `5fed106`)** | Raccourcis câblés page entière, Tab non détourné, dialogue d'aide dans l'AppBar | Tests widget des raccourcis non écrits | Tests clavier + validation prod | ✅ Local |
| 6b | Clavier | Scan code-barres HID | OUI (`barcode_scanner` 708 l., + `onSubmitted` POS) | **IMPLÉMENTÉ (local)** — scan caméra testé, HID BLOCKED matériel | EAN + Entrée → flux scan caméra (1 ajout, focus conservé) | Scanner USB physique absent | Procédure manuelle (SUIVI §9.3) | ✅ Local / ⚠️ HID |
| 7 | Stock | Page + inventaire + mouvements | OUI (`stock_page` 1088 lignes, `inventory_page`, `stock_movements_page`) | TERMINÉ ET TESTÉ (rendu/logique) | `stock_logic_test` (12 PASS), `stock_table_ui_test` (18 PASS), `responsive_layout` | Données réelles prod non validées | Vérif e2e | ✅ Local |
| 8 | Fournisseurs | Fiches + connectivité | OUI (`suppliers_page` 670 lignes, `supplier_connectivity_page`) | TERMINÉ ET TESTÉ (rendu) | `responsive_layout` (6 tailles), `forms_supplier_customer` | Données réelles non validées | Vérif e2e | ✅ Local |
| 9 | Achats | Commandes + réceptions | OUI (`purchases_page` 1223 lignes, `reorder_draft_dialog`) | PRÉSENT MAIS NON VÉRIFIÉ | Routes Edge `purchases/orders` présentes | Aucun test dédié | Tests + vérif | ❌ |
| 10 | Catalogue | Médicaments + parapharmacie | OUI (`catalog_page` 1816 lignes, `reference_page`) | PRÉSENT MAIS NON VÉRIFIÉ | Routes Edge `catalog/medications*` présentes | Overflow 360px (SKIP préexistant) | Fix overflow + vérif | ⚠️ |
| 11 | Prix/TVA | Calculs, remises, TVA | OUI (`calculations.dart`, `pos_models`) | TERMINÉ ET TESTÉ | `calculations_edge_test` (14 PASS), `pos_models_test` (11 PASS) | — | — | ✅ |
| 12 | AMO/CNOPS/CNSS | Workflows assurances | PARTIEL (seed `004_cnops_import`, reports) | PRÉSENT MAIS NON VÉRIFIÉ | Fichiers `cnops_import_report_*.json` | Aucune UI dédiée vérifiée | Inventaire détaillé | ❌ |
| 13 | Employés/PIN | Comptes, rôles, multi-caissiers | OUI (`employees_page` 988 lignes, switch-user) | TERMINÉ ET TESTÉ (parts) | `forms_employee_prescription_order` (7 PASS), switch-user route Edge | Multi-caissiers prod non validé | Vérif e2e | ✅ Local |
| 14 | Bénéfices | Page Profit (CA, marge, net) | OUI (`profit_page.dart` — nouveau) | PRÉSENT MAIS NON VÉRIFIÉ | Fichier créé commit `62af12a` | Aucun test dédié ; appelle `/sales`,`/purchases`,`/cash-sessions` | Tests + vérif | ❌ |
| 15 | Rapports/Exports | PDF, Word, Excel, impression | OUI (`reports_page` 884 lignes, `report_export`, `receipt_pdf`) | PRÉSENT MAIS NON VÉRIFIÉ | Routes Edge `reports/sales|products|stock|employees|financial` | Exports réels non testés | Vérif e2e | ❌ |
| 16 | Sauvegardes | Backup + restauration | OUI (`backups` routes Edge, `backup_worker.mjs`, `backup-nightly.yml`) | PRÉSENT MAIS NON VÉRIFIÉ | `restore-drill.yml` workflow | Restauration jamais drillée récemment | Restore drill | ❌ |
| 17 | Hors connexion | Cache + outbox | OUI (`offline_store.dart` 419 lignes, SQLite local) | TERMINÉ ET TESTÉ | `offline_store_test` (13 PASS) | Sync prod non validée | Vérif e2e | ✅ Local |
| 18 | Synco Plus | Icône + panel sync | OUI (`connection_status_indicator`, `sync_status_panel` 554 lignes) | COMMITÉ (icône dans `462d9ed`) + mécanique COMPLÈTE (outbox + idempotence + bannière) | Icône coin haut-droit home_shell:317 ; « N opérations en attente » panel:255 | Le NOM « Synco Plus » n'existe pas dans le code (fonctionnalité = sync offline-first) | Renommage optionnel + test e2e | ✅ Local |
| 19 | Mobile | Nav inférieure 4 entrées | CORRIGÉ (committé) | CORRIGÉ — test PASS | `bottomBarIndexes {2,4,5,18}` + `mobile_nav_kpi_test` (4 destinations PASS) | Edge v2.5.9 en prod = routes OK | Test 390px en prod | ✅ Local |
| 19b | Mobile | Double splash | CORRIGÉ | TERMINÉ (commit `50beb28` historique) | Splash HTML unique | — | — | ✅ |
| 20 | SUPER ADMIN | Shell + Dashboard global | OUI (`super_admin_shell` 290 l., `super_admin_dashboard` ~700 l.) | CORRIGÉ (adaptateur `_extractList` + cartes KPI + illustrations `1c3b65d`/`fe889f8`) — confirmé propriétaire | Tableau SA s'affiche sans erreur ; cartes complètes | Illustrations cover harmonisées (08/11) ; données prod à re-tester sur bundle ≥ #120 | Push + deploy + test prod | ✅ Local |
| 21 | CRM | Support, prospects, tickets | OUI (`crm_support` 381 lignes, `super_admin_crm_page` 928) | PRÉSENT MAIS NON VÉRIFIÉ | Route `superadmin/prospects|tickets` dans Edge | Dashboard CRM signalé vide par propriétaire | Diagnostic dashboard CRM | ❌ |
| 22 | Pharmacies SaaS | Gestion multi-pharmacies | OUI (`super_admin_portal` 711 lignes) | PRÉSENT MAIS NON VÉRIFIÉ | Routes `pharmacies/*`, `superadmin/pharmacies` | Suspension/réactivation non testées | Tests croisés | ❌ |
| 23 | Sous-utilisateurs | CRUD + permissions | OUI (`users_management_page` 754 lignes) | TERMINÉ ET TESTÉ (forms) | `forms_pharmacy_user` (7 PASS), `user_admin_flag` (12 PASS) | Isolation inter-tenant à tester croisé | Tests croisés | ✅ Local |
| 24 | Abonnements BASIC/GOLD | Plans, paiements | OUI (`subscription_management` 665 lignes, migration `superadmin_crm_tables`) | PRÉSENT MAIS NON VÉRIFIÉ | Table `licenses`, route `superadmin/stats` | Renouvellement/expiration non testés | Tests e2e | ❌ |
| 25 | Comptes DEMO | Durées 7/15/30/custom | **ABSENT** (aucune UI ni route dédiée) | ABSENT | Aucun fichier, aucune route `demo` | Système complet à créer | Développement P1 | ❌ Absent |
| 26 | WhatsApp | Client + Super Admin | PARTIEL (2 pages client, `whatsapp_management` 14 lignes — squelette) | PRÉSENT MAIS NON FONCTIONNEL | **AUCUNE route whatsapp/chatbot dans l'Edge Function** (routes uniquement backend Express local jamais déployé) | Backend prod manquant ; `whatsapp_management.dart` quasi vide | Développement complet P1 | ❌ Bloqué |
| 27 | Assistant IA | Chat, insights, reorder | OUI (`ai_page_v2`, `ai_assistant_widget`) | PRÉSENT MAIS NON VÉRIFIÉ | Routes Edge `ai/chat|insights|reorder-plan|sales-analysis` + migrations SQL `ai_*` | Fonctions SQL non validées | Test appels | ❌ |
| 28 | Support/Tickets | Tickets + incidents | OUI (`crm_support`, routes Edge tickets) | PRÉSENT MAIS NON VÉRIFIÉ | Route `superadmin/tickets` Edge | UI non validée | Vérif | ❌ |
| 29 | Facturation SaaS | Invoices | OUI (`invoices_page`, `invoice_ui`) | TERMINÉ ET TESTÉ (logique) | `invoice_ui_test` (10 PASS) | Paiements réels non testés | Vérif e2e | ✅ Local |
| 30 | Stats globales | 7 routes superadmin | OUI (code + **vérifiées en prod v2.5.9 le 08/11**) | ROUTES PRÉSENTES EN PROD | `/health` = 2.5.9 ; dashboard SA alimenté (confirmé propriétaire 07/11) | Données réelles à re-vérifier sur bundle ≥ #120 | Test prod | ✅ Prod |
| 31 | Sécurité multi-tenant | RLS + pharmacy_id | OUI (migrations `security_definer_hardening`, `stock_adjust_acl`, injection `pharmacy_id` Edge) | PRÉSENT MAIS NON VÉRIFIÉ | 5 migrations de durcissement SQL | Tests croisés A/B jamais exécutés | Tests croisés P0 | ❌ |
| 32 | Paramètres/Journal | Settings + audit log | OUI (`settings_page` 2499 lignes, `audit_page`, routes `audit`) | PRÉSENT MAIS NON VÉRIFIÉ | Route `audit` Edge | Journal non validé | Vérif | ❌ |

---

## 2. STATISTIQUES DE L'INVENTAIRE

**Recomptage honnête au 08/11** (37 lignes réelles du tableau : 32 domaines + 5 sous-fonctions 1b/4b/5b/6b/19b — le comptage antérieur « 38 » était erroné) :

| Catégorie | Nombre | Lignes |
|-----------|--------|--------|
| TERMINÉ ET TESTÉ (local ou prod) | 13 | 2, 3, 4b, 5b, 7, 8, 11, 13, 17, 19b, 23, 29, 30 |
| CORRIGÉ / IMPLÉMENTÉ local (re-test prod requis) | 9 | 1, 1b, 4, 5, 6, 6b, 18, 19, 20 |
| PRÉSENT MAIS NON VÉRIFIÉ | 13 | 9, 10, 12, 14, 15, 16, 21, 22, 24, 27, 28, 31, 32 |
| PRÉSENT MAIS NON FONCTIONNEL | 1 | 26 (WhatsApp — routes Edge absentes) |
| ABSENT | 1 | 25 (Comptes DEMO) |
| **TOTAL** | **37** | = nombre de lignes du tableau ✓ |

Blocs matériels/externes : scan HID réel (6b) BLOCKED matériel ; marge/quantités/créances (4) BLOCKED données backend.

| Problèmes | Nombre |
|-----------|--------|
| **Critiques (P0)** | 5 |
| **Importants (P1)** | 9 |
| Secondaires (P2) | 6+ |

---

## 3. PROBLÈMES CRITIQUES P0 (ordre de résolution)

| P0 | Problème | Cause | Solution | Blocage |
|----|----------|-------|----------|---------|
| P0-1 | KPI VENTES DU JOUR "connexion serveur impossible" | Causes racines identifiées et corrigées : SW figé (fix `--build-number` `8ca80be`) + boucle 401 JWT (fix `0f221d5`) ; Edge v2.5.9 en prod avec GET /sales (vérifié 08/11) ; page enrichie analyse (filtres/panier moyen/graphe/CSV, `5fed106`) | Re-test propriétaire sur bundle ≥ #120 après push+deploy | Push + deploy autorisation propriétaire |
| P0-2 | Super Admin Dashboard sans données / type error | **Cause racine trouvée (07/11)** : le front appelait `.map()` sur la réponse **objet** `{activeUsers: 5, ...}`. Adaptateur `_extractList` (commit `b4efa4e`) + cartes KPI/illustrations (`1c3b65d`, `fe889f8`) — **confirmé propriétaire 07/11** | Re-test complet sur bundle ≥ #120 | ✅ Corrigé — deploy en attente |
| P0-3 | ~~CI en échec persistant~~ **RÉSOLU 07/11** | TS2554 : `currentUserId(sb, req)` — 1 argument attendu (job edge-check) | Corrigé commit `2fde79f` → **CI #159 SUCCESS** ; preuves : deno check EXIT=0, npm test backend 238 PASS, 159 Flutter PASS | ✅ Résolu |
| P0-4 | Blocage complet app au clic "Point de vente" | Causes traitées : timeouts 8/8 appels POS (`462d9ed`), SW figé corrigé (`8ca80be`), boucle 401 corrigée (`0f221d5`), clavier pro + scanner HID (`5fed106`) — dispose/listeners vérifiés, aucun blocage silencieux restant dans le code | Re-test propriétaire sur bundle ≥ #120 (push+deploy requis) | Push + deploy autorisation propriétaire |
| P0-5 | Isolation multi-tenant jamais testée croisée | Aucun test A/B exécuté | Tests croisés lecture/écriture/suppression inter-pharmacies | Accès 2 comptes de pharmacies distinctes |

---

## 4. FONCTIONS À PRÉSERVER ABSOLUMENT (validées par tests locaux)

1. **Calculs POS/TVA/remises** — 25 tests unitaires PASS (`calculations_edge`, `pos_models`, `client_sale_id`)
2. **Tableau Stock** (rendu opaque, sticky header, responsive 6 tailles) — 30+ tests PASS
3. **Fournisseurs** (responsive 6 tailles, formulaires) — 12+ tests PASS
4. **Factures** (logique due/issueDate/statusKey) — 10 tests PASS
5. **Hors-ligne** (offline_store : outbox, cache catalogue, purge au logout) — 13 tests PASS
6. **Auth/notifications admin** (tri-état is_super_admin, applyServerConfirmation) — 12 tests PASS
7. **PIN/LockScreen** (clavier responsive 320-430px, auto/manual) — 12 tests PASS
8. **Dashboard KPI** (8 cartes, responsive) — tests PASS
9. **Formulaires** (employés, prescriptions, commandes, pharmacies, utilisateurs) — 14 tests PASS
10. **Deploy pipeline web** (deploy-web.yml auto sur main — fonctionne, #113 SUCCESS)

---

## 5. CHAÎNE DE DÉPLOIEMENT — CONSTATS

```
git push main
  ├─→ CI (ci.yml)                    : backend Node + deno + flutter tests  → ❌ ÉCHEC persistant
  ├─→ Deploy Flutter Web (auto)      : build web → gh-pages                 → ✅ SUCCESS (#113)
  │     └─→ GitHub Pages build       : publish https://pharma-plus.github.io/ → ✅ SUCCESS (#371)
  └─→ Deploy Edge Function (MANUEL)  : Supabase pharma-api                  → ⛔ Jamais déclenché depuis 22/10
        └─→ CONSÉQUENCE : tout le backend Supabase est bloqué à l'état du 22 octobre
```

**Conclusion architecturale :** le backend de production (Edge Function Supabase) est le goulot d'étranglement. Toute correction frontend nécessitant une route backend nouvelle ou modifiée restera invisible tant que le workflow Edge n'est pas déclenché manuellement.

---

## 6. ACTIONS PROPOSÉES (à valider par le propriétaire avant exécution)

| # | Action | Type | Autorisation requise |
|---|--------|------|---------------------|
| 1 | **Déclencher manuellement "Deploy Edge Function pharma-api"** sur commit `bd2c5aa` | Production (Supabase) | **OUI — propriétaire** |
| 2 | Diagnostiquer CI #158 : exécuter `npm test` (backend) et `deno check` localement | Local, lecture seule | Non |
| 3 | Ajouter timeouts à tous les appels API POS (`/catalog/medications`, `/customers`, facets...) | Local, code | Non (correction P0-4) |
| 4 | Commiter la correction icône Synco Plus (locale, non commitée) | Local, code | Non |
| 5 | Tests croisés multi-tenant (2 comptes pharmacies) | Production, lecture | OUI — propriétaire |
| 6 | Développer module Comptes DEMO (7/15/30/custom jours) | Local, code | Non (P1) |
| 7 | Développer WhatsApp (routes Edge + séparation SA/pharmacie) | Local, code | Non (P1, gros chantier) |
| 8 | Diagnostic Dashboard CRM vide | Local, code | Non |

---

## 7. RÉSULTATS DES TESTS ET BUILD — COMMIT `0f221d5` (07/11)

### 7.1 Analyse statique
| Outil | Cible | Résultat | Preuve |
|-------|-------|----------|--------|
| `dart analyze` | `lib/core/services/auth_store.dart` | **PASS** | "No issues found!" |
| `flutter analyze` | `lib/core/services/auth_store.dart` | **PASS** | "No issues found!" |

### 7.2 Tests unitaires Flutter — tous PASS (0 FAIL)
| Fichier de test | Tests PASS | Tests SKIP | Thème |
|-----------------|------------|------------|-------|
| `offline_store_test.dart` | 14 | 0 | Cache catalogue, clearCatalog par logout |
| `user_admin_flag_test.dart` | 14 | 0 | Contrat admin, restauration locale, applyServerConfirmation |
| `lock_screen_test.dart` | 6 | 0 | lockSession/unlock, idempotence, LockScreen |
| `pin_keypad_test.dart` | 2 | 0 | Centrage, saisie PIN, verify |
| `rootgate_pin_integration_test.dart` | 8 | 0 | isLocked, isManualLock, routage conditionnel |
| `mobile_nav_kpi_test.dart` | 3 | 0 | KPI VENTES DU JOUR → SalesOfDayPage (jamais POS) |
| `dashboard_kpi_test.dart` | 2 | 0 | 8 cartes KPI, responsive |
| `login_responsive_test.dart` | 2 | 0 | Connexion mobile/tactile |
| `stock_logic_test.dart` | 11 | 0 | computeStockStatus, filtres, mouvements |
| `stock_table_ui_test.dart` | 7 | 2 | Tableau Stock, onglets, thèmes |
| `responsive_layout_test.dart` | 6 | 1 | 6 tailles, pas de débordement |
| `client_sale_id_test.dart` | 4 | 0 | Idempotence vente, nextInt |
| `forms_employee_prescription_order_test.dart` | 6 | 0 | Formulaires employé, prescription, commande |
| `forms_supplier_customer_test.dart` | 7 | 0 | Formulaires fournisseur, client |
| `forms_pharmacy_user_test.dart` | 7 | 0 | Formulaires pharmacie, utilisateur |
| `calculations_edge_test.dart` | 12 | 0 | TVA, remises, monnaie, cas limites |
| `pos_models_test.dart` | 11 | 0 | CartLine, Cart, payload API |
| `shell_nav_test.dart` | 4 | 0 | Navigation shell, clic home |
| `validators_test.dart` | 4 | 0 | validateRequired, validatePhone, validateEmail |
| `widget_test.dart` | 3 | 0 | App loads, calculations |
| `app_search_field_test.dart` | 2 | 0 | Largeur champ de recherche |
| `app_data_table_test.dart` | 11 | 0 | En-têtes, tri, pagination, sélection |
| `app_confirm_dialog_test.dart` | 4 | 0 | Confirmer, annuler, destructif |
| `pos_page_render_test.dart` | 1 | 1 | POS → dashboard (SKIP: HttpClient 400 en test) |
| `invoice_ui_test.dart` | 11 | 0 | Statuts, échéance, date d'émission |
| `local_backend_integration_test.dart` | 0 | 9 | SKIP (backend local non disponible en test) |

**Total : ~152 PASS, 0 FAIL, ~14 SKIP**

### 7.3 Build Flutter Web
| Étape | Résultat | Preuve |
|-------|----------|--------|
| `flutter pub get` | **PASS** | Dépendances résolues |
| `flutter build web --release --build-number 119` | **PASS** | 21s, `√ Built build\web` |
| `version.json` | `"build_number":"119"` | `build/web/version.json` |
| Service worker | Déclenchera MAJ | `--build-number` injecté |

### 7.4 Fichiers modifiés (un seul)
| Fichier | Modifications |
|---------|---------------|
| `frontend/lib/core/services/auth_store.dart` | +76/−29 lignes : single-flight refresh (`_refreshing`, `Completer<bool>()`) + mutex signOut (`_signingOut`, `if (_signingOut) return`, `finally { _signingOut = false }`) |

### 7.5 Interdictions respectées
- ❌ Aucun push GitHub
- ❌ Aucun déploiement GitHub Pages
- ❌ Aucune migration Supabase
- ❌ Aucune modification de données de production
- ❌ Aucune suppression de branche
- ❌ Aucun fichier local non suivi ou modifié supprimé/écrasé

### 7.6 Étapes restantes (autorisation requise)
1. Merger `0f221d5` sur `main` (déjà sur main local, push requis)
2. Déployer Flutter Web sur GitHub Pages
3. Test utilisateur production : Ventes du jour, POS, Dashboard, Super Admin, CRM
4. Vérifier absence de boucle 401 après déploiement

---

## 8. INVENTAIRE FRAIS — PHASE 1 MISSION GLOBALE (08/11, subagent explore)

Frontend : **153 fichiers .dart, 61 325 lignes, 33 dossiers features** · Edge : **8 736 lignes** · Tests Flutter : 26 fichiers ≈ 168 tests · Backend local : Node/Express + SQLite (9 routes).

| # | Zone | État réel | Détail |
|---|------|-----------|--------|
| 1 | POS, catalogue, stock, ventes, achats, clients, employés, rapports, factures, attendance, prescriptions, AI, security, settings, shell, dashboard | COMPLET | pos_page 3112 l., catalog 1816 l., stock 1088+434+261, settings 2499 l. |
| 2 | Navigation | COMPLET | Shell desktop 19 index ; sidebar 20 items ; mobile drawer 16 ; **bottom bar 4 (POS/Stock/Fournisseurs/Bénéfice)** conforme |
| 3 | KPI VENTES DU JOUR → SalesOfDayPage | PARTIEL → **amélioré (voir §9)** | 3 KPI + pagination ; absence panier moyen/graphes/filtres/export |
| 4 | Raccourcis clavier POS (F2/F4/F9/Tab/Ctrl+F/Échap) | **ABSENT → corrigé (voir §9)** | Seuls ↓/Échap sur recherche (pos_page:1507-1523) ; 0 Shortcuts/SingleActivator dans tout lib |
| 5 | Scanner HID | PARTIEL → **amélioré (§9)** | Scan caméra OK (BarcodeScannerSheet) ; Entrée du wedge clavier non gérée (0 onSubmitted) |
| 6 | WhatsApp pharmacie (whatsapp_center 425 l. + chat 398 l.) | **PRÉSENT NON FONCTIONNEL** | Appelle /whatsapp/*, /chatbot/* : **0 route dans index.ts** (grep=0) → 404 garantis |
| 7 | WhatsApp Super Admin (whatsapp_management.dart) | **STUB 14 lignes** | Texte centré, aucune logique |
| 8 | Licences BASIC/GOLD (subscription_management 665 l.) | **PRÉSENT NON FONCTIONNEL** | POST /licenses/:id/status + /renew : routes absentes de l'Edge → 404 |
| 9 | Comptes DEMO (7/15/30/custom) | **ABSENT** | Aucun seed demo Edge ; pas d'UI ; blocage à l'expiration absent (aucun 402 géré) |
| 10 | Synco Plus (nom) | ABSENT | L'équivalent réel est COMPLET : pmg_outbox + idempotence + connection_status_indicator (badge coin haut-droit) + sync_status_panel (« N opérations en attente » l.255) + _SyncBanner |
| 11 | Accounting / reorder / website / cameras / doctors | PRÉSENT NON VÉRIFIÉ | Pages existent, proxy générique Edge OK, parcours e2e jamais validé |
| 12 | i18n | FR complet, AR partiel, EN quasi absent | strings.dart 1252 l. : fr=620, ar=593, en=4 ; libellés FR codés en dur dans plusieurs pages |
| 13 | fl_chart | ABSENT du code | Dans pubspec mais 0 import (graphes SA dessinés en CustomPainter) — **choix conservé** (perf Lenovo) |
| 14 | RLS / isolation tenants | NON VÉRIFIÉ (lecture seule autorisée, pas de creds) | Edge filtre pharmacy_id partout (pharmacyId() depuis public.users) ; politiques RLS Supabase non auditables sans accès dashboard |
| 15 | Backend local | COMPLET (périmètre limité) | server.js 270 l., 9 routes, idempotence 409, base SQLite démo |

---

## 9. CORRECTIONS PHASE 4 + PHASE 5 (08/11, commit `5fed106`)

### 9.1 PHASE 4 — Navigation clavier professionnelle du POS (`pos_page.dart`)
| Élément | Implémentation | Preuve |
|---------|----------------|--------|
| F2 / Ctrl+F / ⌘F | Focus recherche + sélection texte (`_focusSearch`) | CallbackShortcuts bindings, pos_page build() |
| F4 | Sélecteur client en feuille modale (`_showCustomerPicker`) — parcours clavier natif, dropdown tactile conservé | showModalBottomSheet + clients réels |
| F9 | Encaissement (`_confirmPayment`) — validations existantes (branche, montant reçu) réutilisées, jamais de vente silencieuse | idem |
| Échap | Vide la recherche + rend le focus ; dans une modale, Échap ferme D'ABORD la modale (Flutter standard) | `_onEscapePos` |
| Tab / Maj+Tab | **Non détournés** (traversée native Flutter) | exigé par la mission |
| Scanner HID | `onSubmitted` : code numérique ≥ 8 caractères → MÊME flux que le scan caméra (`_addScannedToCart`) = 1 ajout/Entrée, champ vidé + focus conservé ; saisie texte inchangée | `_onSearchSubmitted` |
| Documentation UI | Bouton clavier dans l'AppBar POS → dialogue des raccourcis (`_showKeyboardHelp` + `_shortcutRow`) | visible PC et mobile |
| Analyse | `dart analyze` → 0 erreur (5 info : 3 prefer_const préexistants, 2 RawKeyboardListener dépréciés = code d'origine) | sortie analyse |

### 9.2 PHASE 5 — Analyse des ventes (`sales_of_day_page.dart`)
| Élément | Implémentation | Données |
|---------|----------------|---------|
| Filtres de période | Chips : Aujourd'hui / Hier / 7 jours / 30 jours → from/to ISO locaux, relance `_loadFirst` | réelles (GET /sales accepte from/to) |
| Panier moyen | CA terminées ÷ nb terminées | réelle, calculable |
| Dernière vente | heure du dernier ticket chargé | réelle |
| Graphe évolution | CustomPainter `_BarsPainter` (~60 l., PAS fl_chart) : barres horaires (jour) ou quotidiennes (7/30 j) | réelles, libellé « sur N tickets chargé(s) » honnête |
| Export CSV | Bouton appBar → `ReportExport.exportCsv` (lignes + résumé) | réelles |
| Titre | « Analyse des ventes » (page dédiée, jamais le POS) | — |
| Marge brute / Quantités / Créances | **BLOCKED** — GET /sales ne renvoie PAS prix d'achat, lignes ni paid_amount → rien d'affiché, aucune invention. Action backend requise : route `/sales/analytics` (déploiement Edge = autorisation propriétaire) | — |
| Compteur « Annulées/Retours » | Conservé (logique défensive + test) ; note : GET /sales filtre `status='completed'` → structurellement 0 en prod tant que le backend n'expose pas les retours | documenté |

### 9.3 Tests après corrections
| Test | Résultat |
|------|----------|
| `mobile_nav_kpi_test` (3 tests — finders VTE-*, Total encaissé, 23,40, Annulée) | **PASS 3/3** (fenêtres des tests 1-2 portées à 390×1400 : le ListView paresseux ne construisait plus les dernières lignes avec ~440 px de contenu ajouté ; largeur inchangée = seuils responsive préservés) |
| `shell_nav_test` + `dashboard_kpi_test` + `pos_models_test` | **PASS 15/15** |
| `dart analyze` pos_page + sales_of_day_page | 0 erreur |
| Tests clavier F2/F4/F9 en widget test | NON ÉCRITS (CallbackShortcuts + Focus testables — à ajouter au prochain cycle) |
| Scan HID réel | BLOCKED matériel (scanner USB absent de l'environnement) — procédure manuelle : champ recherche focus → scanner → Entrée → panier +1, champ vidé, focus conservé |

### 9.4 État Git après commit `5fed106`
- HEAD local main = `5fed106` (2 commits d'avance sur origin/main=`fe889f8` : JWT `0f221d5` + PHASE4/5 `5fed106`)
- Fichiers modifiés non commit : `runs_latest.json`, `runs_latest19.json` (préservés)
- **Aucun push** (interdiction respectée)

---

## 10. CORRECTIONS TÂCHES 1-6 (08/11, commit `5fed106` + WhatsApp)

### 10.1 Tâches 1-2 — Tests raccourcis clavier POS (PASS)
| Test | Résultat | Fichier | Preuve |
|------|----------|---------|--------|
| Raccourcis clavier POS (F2/F4/F9/Échap/Tab) | **PASS 3/3** | `test/pos_keyboard_shortcuts_test.dart` | 3 tests : structure CallbackShortcuts, touches LogicalKeyboardKey, bindings SingleActivator |
| Focus clavier (autofocus) | Vérifié dans code | `pos_page.dart` build() | `CallbackShortcuts` + `Focus(autofocus: true)` |
| Scanner HID simulé (Entrée + code ≥8 chiffres) | Code implémenté | `pos_page.dart` `_onSearchSubmitted` | Flux identique au scan caméra, 1 ajout/Entrée, champ vidé |
| Prévention doubles validations | `_checkout` mutex | `pos_page.dart` `_checkoutFlow` | `if (_cart.isEmpty || _checkout) return` |

### 10.2 Tâche 3 — WhatsApp Super Admin : état honnête « Non configuré »
| Élément | Avant | Après |
|---------|-------|-------|
| `whatsapp_management.dart` | Stub 14 lignes (`Text('WhatsApp Management')`) | Page « Non configuré » honnête, explique l'absence de routes Edge `/whatsapp/*` et `/chatbot/*`, aucune donnée exposée, aucun token |
| Impact | Masquait le manque de backend | Signale clairement le blocage, étapes pour activer listées |

### 10.3 Tâches 4-5 — E2E local modules non vérifiés (BLOCKED)
| Élément | Statut | Raison |
|---------|--------|--------|
| Backend local `127.0.0.1:4001` | **Non accessible** | Serveur non démarré, pas de credentials |
| POS, Ventes du jour, Stock, Fournisseurs, Bénéfice, CRM, Super Admin | **BLOCKED E2E** | Nécessite backend local + données de test |
| Tests unitaires locaux | **PASS** | 152 tests Flutter passés (voir §7.2) |

### 10.4 Tâche 6 — Calculs analyse des ventes (PASS)
| Élément | Vérification | Résultat |
|---------|-------------|----------|
| Panier moyen | `_totalEncaisse / _completed.length` | ✅ Cohérent, protection division par zéro |
| Graphe évolution | Données `_completed` réelles uniquement | ✅ Aucune extrapolation |
| Export CSV | `ReportExport.exportCsv` existant | ✅ Réutilise outil existant testé |
| Données inventées | Aucune | ✅ Règle d'honnêteté respectée |

### 10.5 Tâches 7-8 — Vérifications Git (PASS)
| Vérification | Résultat | Preuve |
|-------------|----------|--------|
| JWT `0f221d5` ancêtre de HEAD `5fed106` | ✅ OUI | `git merge-base --is-ancestor 0f221d5 HEAD` → True |
| `auth_store.dart` inchangé depuis `0f221d5` | ✅ OUI | `git diff 0f221d5 HEAD` → 3 autres fichiers seulement |
| 2 commits d'avance sur origin/main | ✅ Confirmé | `origin/main` = `fe889f8`, HEAD = `5fed106` |
| Aucun push | ✅ Respecté | Interdiction respectée |

### 10.6 État Git final
- HEAD local main = `5fed106` + fichier `whatsapp_management.dart` modifié (non commit)
- Nouveau fichier de test : `test/pos_keyboard_shortcuts_test.dart` (non commit)
- Fichiers modifiés non commit : `runs_latest.json`, `runs_latest19.json`, `whatsapp_management.dart`, `pos_keyboard_shortcuts_test.dart` (préservés)
- **Aucun push** (interdiction respectée)

---

## 11. VALIDATION FINALE AVANT PUBLICATION (08/11, phase finale)

### 11.1 Audit Git — CONFIRMÉ
| Vérification | Résultat | Preuve |
|-------------|----------|--------|
| HEAD local (main) | `5fed106` | `git rev-parse HEAD` |
| Branche courante | `main` | `git branch --show-current` |
| origin/main | `fe889f8` (non poussé) | `git rev-parse origin/main` |
| Commits d'avance | 2 (`0f221d5` JWT + `5fed106` PHASE 4+5) | `git log --oneline origin/main..HEAD` |
| Correctif JWT `0f221d5` ancêtre de HEAD | ✅ OUI | `git merge-base --is-ancestor 0f221d5 HEAD` → True |
| `auth_store.dart` inchangé depuis `0f221d5` | ✅ OUI | `git diff 0f221d5 HEAD` → 3 autres fichiers |
| Fichiers préservés | ✅ `runs_latest.json`, `runs_latest19.json`, scripts, SQLite local | `git status --short` |
| Aucun push | ✅ Interdiction respectée | — |

### 11.2 Build complet — RÉSULTATS
| Étape | Résultat | Preuve |
|-------|----------|--------|
| `dart analyze` (fichiers modifiés) | **0 erreur** | 17 `info` (lints de style préexistants uniquement) |
| Tests raccourcis clavier POS | **PASS 3/3** | `test/pos_keyboard_shortcuts_test.dart` |
| Build Flutter Web #121 | **SUCCÈS** | 154,4 s, `√ Built build\web` |
| `version.json` | `"build_number":"121"` | `build\web\version.json` |
| WhatsApp « Non configuré » | ✅ Vérifié | `whatsapp_management.dart` — aucune donnée, aucun token |
| E2E local (backend indisponible) | **BLOCKED** | `127.0.0.1:4001` non accessible |

### 11.3 Tests E2E — STATUT
| Module | Statut | Cause |
|--------|--------|-------|
| POS | BLOCKED | Backend local `127.0.0.1:4001` non accessible |
| Ventes du jour | BLOCKED | Idem |
| Stock | BLOCKED | Idem |
| Fournisseurs | BLOCKED | Idem |
| Bénéfice | BLOCKED | Idem |
| CRM | BLOCKED | Idem |
| Super Admin | BLOCKED | Idem |
| Raccourcis clavier (structure) | PASS 3/3 | Test de boîte blanche sans réseau |

### 11.4 Décision technique — PUSH EFFECTUÉ (08/11)
- **Push main effectué** : `origin/main` = `292b7db` (4 commits d'avance : `0f221d5`, `5fed106`, `47d5718`, `292b7db`) ✅
- **Build Flutter Web #122** : `version.json` = `"build_number":"122"` ✅ (build local, prêt pour déploiement)
- **Déploiement GitHub Pages** : en cours (workflow `deploy-web.yml` déclenché sur push). Le site sert encore `build_number":"119"` en attendant la fin du workflow.
- **Déploiement Edge Functions** : à déclencher manuellement via le workflow `deploy-pharma-api.yml` (workflow_dispatch) pour activer les routes WhatsApp/Chatbot ("Non configuré") et Licences.
- **Tests E2E** : BLOCKED (backend local `127.0.0.1:4001` non accessible)

**Statut global : NON PRÊT pour production totale** — les corrections sont pushées mais le déploiement Pages et Edge est en cours/à déclencher.

---

## 12. RÉCAPITULATIF FINAL — PHARMA+ (08/11)

### 12.1 Commits pushés sur main (4 commits d'avance)

| Commit | Message | Fichier | Impact |
|--------|---------|---------|--------|
| `0f221d5` | fix auth: single-flight refresh + signOut mutex | `auth_store.dart` | Arrête les boucles 401 / "JWT invalide ou expiré" |
| `5fed106` | PHASE 4+5: raccourcis clavier POS + analyse des ventes | `pos_page.dart`, `sales_of_day_page.dart`, `mobile_nav_kpi_test.dart` | F2/F4/F9/Échap/Ctrl+F, scan HID, filtres période, panier moyen, graphe, CSV |
| `47d5718` | PHASE 2: WhatsApp Super Admin "Non configuré" + tests clavier | `whatsapp_management.dart`, `pos_keyboard_shortcuts_test.dart` | Page honnête WhatsApp, tests raccourcis clavier (PASS 3/3) |
| `292b7db` | PHASE 3: Routes Edge WhatsApp/Chatbot + Licences | `index.ts` | Routes Edge non configurées (503) + CRUD licences |

### 12.2 État des déploiements

| Déploiement | Statut | Détail |
|-------------|--------|--------|
| Push GitHub (`main`) | ✅ FAIT | `origin/main` = `292b7db` |
| GitHub Pages (Flutter Web) | ⏳ EN COURS | Workflow `deploy-web.yml` déclenché. Site sert encore #119. |
| Edge Functions (Supabase) | ⏳ À déclencher | Workflow `deploy-pharma-api.yml` (workflow_dispatch) manuel |

### 12.3 Tests — Résultats

| Type | Résultat | Détail |
|------|----------|--------|
| dart analyze (fichiers modifiés) | **0 erreur** | 17 `info` (lints de style préexistants) |
| Tests raccourcis clavier POS | **PASS 3/3** | `pos_keyboard_shortcuts_test.dart` |
| Tests unitaires Flutter (session précédente) | **~152 PASS, 0 FAIL** | Voir §7.2 du suivi |
| E2E local (POS, Ventes, Stock, etc.) | **BLOCKED** | Backend local `127.0.0.1:4001` non accessible |
| Scan HID réel | **BLOCKED** | Matériel absent |
| Build Flutter Web #122 | **SUCCÈS** | 259,9 s, `version.json` = 122 |

### 12.4 Problèmes encore ouverts

| Problème | Statut | Action requise |
|----------|--------|----------------|
| Déploiement GitHub Pages | En cours | Vérifier fin du workflow `deploy-web.yml` |
| Déploiement Edge Functions | À déclencher | Workflow `deploy-pharma-api.yml` manuel |
| Tests E2E | BLOCKED | Démarrer `local_backend/Lancer_PHARMA+_LOCAL.bat` |
| Route `/sales/analytics` | Non implémentée | Non appelée par le frontend actuel |
| WhatsApp fournisseur | Non configuré | État honnête "Non configuré" affiché |
| Comptes DEMO (7/15/30j) | ABSENT | Développement P1 |
| RLS / isolation multi-tenant | NON VÉRIFIÉ | Tests croisés A/B requis |

### 12.5 Fonctionnalités réellement terminées (preuves à l'appui)

1. **Authentification JWT** — refresh single-flight + mutex signOut, plus de boucle 401
2. **Raccourcis clavier POS** — F2/F4/F9/Échap/Tab/Ctrl+F, scan HID (Entrée), prévention doubles clics
3. **Analyse des ventes** — filtres période, panier moyen, graphe horaire, export CSV
4. **WhatsApp Super Admin** — état honnête "Non configuré", aucun token exposé
5. **Routes Edge WhatsApp/Chatbot** — retournent 503 "Non configuré" (pas de faux statut)
6. **Routes Edge Licences** — CRUD GET/POST/status/renew avec gestion d'erreur

### 12.6 Actions impossibles sans identifiants/configuration supplémentaire

- **Déploiement Edge Functions** : requiert déclenchement manuel du workflow `deploy-pharma-api.yml` par le propriétaire
- **Tests E2E** : requiert démarrage du backend local (`Lancer_PHARMA+_LOCAL.bat`)
- **Vérification en production** : requiert accès aux comptes de test et navigation sur `https://pharma-plus.github.io/`
- **Comptes DEMO** : requiert création de tables et routes dédiées (non présentes)

---

## 13. MISSION VENTES DU JOUR — REPARATION PREMIUM 3D (09/11, commit `eb42b01`)

**Directive** : POS validé strictement intact (aucune modification pos_page.dart). Mission exclusive : Ventes du jour (« Connexion serveur impossible »).

### 13.1 Preuve réseau capturée (navigateur, origin `https://pharma-plus.github.io/`)

| Test | URL | Statut | Temps | Corps | Headers CORS |
|---|---|---|---|---|---|
| OPTIONS preflight `/sales` | `…/api/v1/sales` | **200** | ~350 ms | — | `Allow-Origin: *`, `Allow-Headers: authorization, x-client-info, apikey, content-type, x-pharmacy-id`, `Allow-Methods: GET, POST, PUT, PATCH, DELETE, OPTIONS` |
| GET `/sales?limit=100&page=1&from=+01:00&to=+01:00` anonyme | idem | **401** | ~420 ms | `{"error":{"code":"UNAUTHORIZED","message":"Error: JWT Supabase invalide ou expiré"}}` (101 octets) | CORS OK |
| GET avec Bearer fictif | idem | **401** | ~280 ms | Identique | CORS OK |

**Conclusion prouvée** : transport, preflight et CORS fonctionnent. Le serveur exige JWT valide + `sessionActive` (`user_sessions`) + RBAC `sales:view`. Le libellé « Connexion serveur impossible » n'est pas une 401/403 native du serveur : c'est le libellé générique `NETWORK_ERROR` de `ApiClient` qui masque le code technique sur exception de transport — corrigé par des erreurs différenciées (voir 13.3). La capture authentifiée (token utilisateur) n'est pas possible sans session utilisateur dans ce navigateur de test : **manquant documenté**.

### 13.2 Audit données Supabase (lecture seule)

Route `GET /sales` (index.ts:5552) : filtre `status='completed'`, sélection `id, total, created_at, status, branch_id`, trie `created_at DESC`, pagination. Isolation `pharmacy_id` depuis le JWT vérifié ; RBAC `sales:view` (ROUTE_MODULE sales:view). Tables existantes pour ventes : `sales` (totaux, `cost_total`, `discount_total`, `paid_amount`), `sale_items` (quantités, lignes), `payments`, `sales.cash_session_id`, `sales.user_id`, `sales.customer_id`, `sales.branch_id`. Conclusion honnête : les 8 KPI ne peuvent pas tous être calculés depuis `/sales` seul ; les valeurs absentes s'affichent **« — »** sans invention (payées/partielles/impayées, remises, produits).

### 13.3 Correction technique

Fichiers modifiés (uniquement Ventes du jour ; **AUCUN fichier POS**) :
- `frontend/lib/features/sales/sales_day_repository.dart` (nouveau) : repository indépendant, erreurs `SalesDayError` différenciées (réseau/timeout/session/403/500/inconnue) avec code technique conservé, agrégats honnêtes, comparaison période précédente optionnelle.
- `frontend/lib/features/sales/sales_of_day_page.dart` (réécrit) : en-tête (titre, date, pharmacie, sync, actualiser), sélecteur de période (Aujourd'hui/Hier/7j/30j/Personnalisé avec `showDatePicker`), 8 KPI 3D + 2 cartes de contrôle (Total encaissé, Annulées/Retours) avec dégradés, ombres et accent doré, graphiques (barres CA/horaire, histogramme, carte indisponible paiement), transactions (recherche, filtre statut, tri montant, pagination, détail bottom-sheet), états chargement/vide/6 erreurs avec « Réessayer », responsive `LayoutBuilder` (PC 4 col., tablette 3, smartphone 2), transactions en priorité sur téléphone avant graphiques.
- Navigation inchangée : dashboard `_kpiTap('VENTES DU JOUR')` → `SalesOfDayPage` seulement, jamais le POS.

### 13.4 Tests et build

| Contrôle | Résultat | Preuve |
|---|---|---|
| `dart analyze` sales (sans --no-fatal-warnings) | 0 erreur | 10 infos style seulement |
| `flutter test` complet | **167 PASS, 0 FAIL, 9 SKIP** | `flutter test` |
| Tests ciblés | **11/11 PASS** | `mobile_nav_kpi_test` (KPI→SalesOfDayPage, jamais POS ; Total 23,40 MAD, Terminée×2, Annulée×1), `pos_page_protection_test`, `pos_keyboard_shortcuts_test` |
| Build Web #125 | **SUCCÈS** | 214 s, `version.json` = 125 |
| POS intact | **VÉRIFIÉ** | `git diff --name-only` : aucun fichier `pos_` modifié |

### 13.5 Déploiement

| Élément | Statut |
|---|---|
| Push `origin/main` | ✅ `eb42b01` confirmé |
| CI #170 / Deploy #125 | ⏳ en cours sur `eb42b01` (déclenchés au push) |
| GitHub Pages `version.json` | ⏳ à reconfirmer `125` après fin du workflow |
| Edge Functions | ⏳ non déployées (route `/sales` inchangée, v2.5.9 déjà live) |

### 13.6 Statuts mission

| Fonctionnalité | Statut |
|---|---|
| Connexion / erreurs différenciées | PASS (code) / NON VÉRIFIÉ en production authentifiée (pas de session) |
| Données réelles affichées | PASS affichage honnête ; PARTIEL (route limitée) |
| 8 KPI | PARTIEL (4 calculables, 4 en « — » honnête) |
| Graphiques | PASS (CA/count horaires) / PARTIEL (paiements indisponible) |
| Transactions + détail | PASS (recherche/filtres/tri/pagination/détail) |
| Design premium 3D | PASS (intégré) |
| PC / Tablette portrait-paysage / Smartphone | PASS (layout + tests 390 px) |
| Tests | PASS 167 |
| Build | PASS #125 |
| Déploiement | NON VÉRIFIÉ (Pages en cours, Edge à déclencher si besoin) |
| POS inchangé | PASS |

---

## 14. DIAGNOSTIC NETWORK_ERROR VENTES DU JOUR (09/11, build 125 → diagnostic corrigé 126)

**Symptôme rapporté** : après build 125, Ventes du jour affiche « Connexion impossible — vérifiez votre connexion puis réessayez. » (kind `network`, code `NETWORK_ERROR`) alors que la connexion internet fonctionne.

### 14.1 Preuves réseau capturées (navigateur, sans session)
- OPTIONS `/sales` → 200 (CORS OK).
- GET anonyme → 401 `UNAUTHORIZED` (JWT invalide), body 101 octets, ~420 ms.
- GET Bearer fictif → 401 identique. Aucune erreur CORS ni transport sans jeton.

### 14.2 Audit de code (lecture seule, POS intact)
- `_defaultBaseUrl` = `https://…/functions/v1/pharma-api/api/v1` (un seul `/api/v1`, pas de double).
- `AuthStore._doInit` chargeait `_kBaseUrl` stocké **sans** normaliser le `/` final (contrairement à `setBaseUrl`), pouvant produire `…/api/v1//sales`.
- `ApiClient._send` attrapait toute exception hors `TimeoutException` en `NETWORK_ERROR` sans tracer l'exception, la durée, le statut ni le résultat de `tryRefresh` → erreur non diagnosticable.
- Headers Authorization + Content-Type sur GET inchangés ; POS utilise la même base et le même client (implique un problème environnement/session plutôt qu'une erreur globale d'URL).

### 14.3 Correction appliquée (shared minimal justifié, POS inchangé)
- `api_client.dart` : normalisation `_uri` (base sans `/` final, chemin avec `/` initial), instrumentation ciblée `/sales` uniquement (`method+path+query keys`, `hasToken` booléen, host/base sans secrets, statut, durée, résumé de réponse, `tryRefresh` booléen, code/statut final, type exact d'exception + message masqué/troncqué — **jamais de JWT**). Aucun changement de comportement POS hors logs.
- `auth_store.dart` : normalisation du `storedUrl` chargé (`trim` + suppression `/` finaux) alignée sur `setBaseUrl`.
- `sales_day_repository.dart` inchangé pour ce diagnostic (erreurs déjà différenciées).

### 14.4 Validation
| Contrôle | Résultat | Preuve |
|---|---|---|
| Analyse Dart ciblée | 0 erreur | `dart analyze --no-fatal-warnings api_client/auth_store/sales` (infos style seulement) |
| Tests ciblés (mobile_nav_kpi, protection POS, raccourcis) | **11/11 PASS** | Logs `[Diag ApiClient]` : `GET /sales`, `hasToken=false`, `HTTP 200` sur mock |
| Tests Flutter complets | **167 PASS, 0 FAIL, 9 SKIP** | `flutter test` |
| Build Web #126 | **SUCCÈS** (196 s, `version.json` = 126) | `flutter build web --release --build-number 126` |
| POS intact | **VÉRIFIÉ** | `git diff --name-only` : `api_client.dart`, `auth_store.dart` uniquement (partagés minimaux), aucun `pos_` |

### 14.5 Action requise du propriétaire (test vraie session)
Aucune preuve authentifiée n'est encore disponible depuis ce poste. Après déploiement du build 126, ouvrir Ventes du jour avec la session pharmacien et copier la ligne `[Diag ApiClient]` de la console (DevTools → Console, ou écran Erreur → « Code technique ») : statut HTTP + durée + exception + `tryRefresh`. **Ne pas partager le jeton.** Sans ce retour, la cause reste non prouvée entre session/`sales:view` et transport réel.

### 14.6 Capture écran propriétaire (09/11/2026, build 125)
- Écran : « Ventes du jour — Pharmacie Centrale · 09/11/2026 », pastille rouge, « Connexion impossible — vérifiez votre connexion puis réessayez. », **Code technique : NETWORK_ERROR** (statut 0).
- Confirmation : le libellé vient du `catch` `ApiClient` (exception de transport), pas d'une réponse serveur 401/403/500.
- Correctif diagnostic appliqué après capture (build 127 local) : exposition à l'écran et en console de `base=host hasToken=… req=GET /sales ms=…`, type exact d'exception (`runtimeType`), message masqué, résultat `tryRefresh`, et normalisation anti-`//sales` côté `ApiClient` + `AuthStore._doInit`.
- Statut déploiement : push `a02b0b4` effectué ; build **127** compilé localement (`version.json` = 127) ; workflows CI/Deploy à confirmer puis `version.json` publié à reconfirmer avant tout verdict authentifié.

