# PHARMA+ — RAPPORT FINAL (prompt global §1-§12) — 15 octobre 2026

> **MISE À JOUR 16/10/2026** : la séance de suivi (« corrige les points restants ») a levé **les deux postes `BLOQUÉ`** et plusieurs résidus — voir **ANNEXE 16/10** en bas de rapport (TVA migrée, worker + CI nightly verts, ventes test nettoyées, exports desktop, garde de paiement TTC). Les statuts §3.3/§3.4/§6 ci-dessous sont complétés par l'annexe.

**Commit de départ :** `f9c8996` (état réel : working tree propre, `backend/src/**` bien tracké — la « dette 15 fichiers » était un artefact git)
**Commit final :** `49078bc` (HEAD = `origin/main`, arbre propre)
**Backup :** tag `backup-finalisation-20261015` = `f9c8996`
**Rapports antérieurs :** `RAPPORT_AUDIT_GLOBAL_20261015.md` (audit de départ), ce rapport le remplace comme preuve finale.

---

## 1. Prouves de déploiement (production)

| Cible | Preuve |
|---|---|
| Web (GitHub Pages) | `https://pharma-plus.github.io/index.html` servi avec `flutter_bootstrap.js?v=202610151724` (HTTP 200 vérifié après rebuild Pages) |
| Bundle | `main.dart.js` HTTP 200, **5 369 630 octets** = identique local, dupliqué `main.202610151724.dart.js` |
| Junk | fichier `renderer` régénéré supprimé de la racine après copie |
| Edge Function | `pharma-api` @ `lwepnnecnrqdzadesyqo` déployée **2 fois** (PIN routes, puis wrapping audit), `deno check` EXIT 0 |
| Git | push `f9c8996..49078bc` confirmé, `HEAD == origin/main` |

## 2. Résultats de tests (dernier run, tous verts)

| Suite | Résultat |
|---|---|
| Backend `node --test "test/*.test.js"` | **157 / 157** (0 fail) |
| `flutter analyze` | **No issues found** (209,5 s) |
| `flutter test` | **52 / 52** (40 historiques + 12 nouveaux cas limites) |
| `deno check pharma-api` | **EXIT 0** |
| `backend/_test_pin_flow.mjs` (§3D, nouveau) | **29 / 29** |
| `backend/_test_switch_user.mjs` (17.C/17.F, rejoué après déploiement) | **42 / 42** |

## 3. TABLEAU DES STATUTS

### 3.1 `CORRIGÉ ET TESTÉ`

| § | Objet | Correction livrée | Preuve |
|---|---|---|---|
| §3 | Code PIN : paramètres Sécurité | Section « Code PIN » (`settings_page.dart`, `case 'security'`), état configuré/non, dialog PIN+confirmation validé `^\d{4,6}$` → `PUT /auth/pin` | `_test_pin_flow.mjs` 29/29 |
| §3 | PIN gestion employés / comptes | `DELETE /users/:id/pin` (désactivation, `users:edit`), `has_pin` exposé, **jamais** `pin_hash` (côté `/auth/me`, `/users`) | tests PIN + checks `pin_hash absent` |
| §3 | Verrouillage / poste partagé | `switch-user` avec PIN → session cible + **vente attribuée à la personne switcheée** (pas au compte d'origine) | `_test_pin_flow.mjs` (DB `sales.user_id = d.ach`), `_test_switch_user.mjs` 42/42 |
| §4 | Gestion utilisateurs | Modèle `User.hasPin`, sous-titre « · PIN configuré », action « Effacer PIN » + suppression avec confirmation listant la préservation de l'historique, auto-compte protégé | tests PIN (création 201, format 400, soft-delete) |
| §4 | Cohérence GET/PUT users | `GET /users` : `has_pin` présent, `pin_hash` absent ; `POST /users` exige `role_id` (400 sinon — comportement vérifié) ; `PUT /users/:id` edit (relink) + `DELETE` soft-delete couverts | `_test_switch_user.mjs:293,309,326` |
| §5 | « Modèle » (plan 3D) | Audit : tap produit appelle l'API réelle, toutes les actions de zones fonctionnelles, **aucun bouton fantôme / POST-PUT manquant** → rien à corriger | audit `pharmacy_plan_page.dart` |
| §6 | Tableaux | Audit ciblé : état vide + indicateur de chargement sur **toutes** les pages liste, **0** bouton mort (`onPressed: null`), **0** TODO/FIXME réel (sensible à la casse), recherche avec debounce + pagination dans le catalogue | inventaire automatique |
| §7 | Formules / TVA | `calculateSaleTotalExcl` : garde `subtotal <= 0 → tva = 0` (zéro division/NaN) ; test tautologique remplacé par calcul indépendant (`23999`, `closeTo`) ; **12 nouveaux tests** de cas limites (panier vide, prix 0, remise > sous-total, remise 100 %, qty 0, cohérence front↔Edge, monnaie flottante, tolérance 0,009) | `calculations_edge_test.dart`, `pos_models_test.dart` |
| §8 | Caisse / stock | `RangeError` (`nextInt(0x7fffffff)`) confirmé corrigé ; contrôle stock POS (stock inconnu/0/dépassement → refus + dialog) solide ; cycle vente+paiement+stock+TVA validé en réel | audit + `_test_pos_cycle.mjs` (départ) |
| §9 | Backend / permissions | `users:gate` (GET view / POST create / PUT edit / DELETE delete) vérifié ; refus **403** sur `PUT/DELETE /users/:id/pin` sans `users:edit` ; contrat audit `_logAction` étendu à **10 appels (9 wrappés `AUDIT_FAILED` + 1 délégation)** — les 2 nouvelles routes PIN wrappées | `p2_audit_log.test.js` 157/157 |
| §10 | Tests / déploiement | Toutes suites vertes + déploiements web **et** Edge poussés et revérifiés CDN | §1 et §2 ci-dessus |

### 3.2 `CORRIGÉ MAIS NON DÉPLOYÉ`

*Aucun.* Toutes les corrections de ce tour sont en production (web + Edge).

### 3.3 `BLOQUÉ`

*Les deux postes de ce tableau ont été levés le 16/10 — voir ANNEXE 16/10 : sauvegardes `CORRIGÉ ET TESTÉ` (worker + routes artefact + CI nightly verte), migration TVA `CORRIGÉ ET TESTÉ` (exécutée, trigger prouvé).*

### 3.4 `NON CORRIGÉ` (assumés / hors périmètre)

| § | Objet | État |
|---|---|---|
| §8 | Paiement carte TPE | bouton « Simuler » explicite, aucun TPE branché (P0 métier assumé) |
| §10 | Export CSV/Word natif (web), OCR, Google login, aperçu caméras | messages honnêtes non-web / « prochainement » (P2 assumés) — **les exports desktop (csv/pdf/doc) sont désormais réels** (ANNEXE 16/10) |
| §1 | Dette « 15 fichiers `backend/src/**` non committés » | **soldée par l'état réel** : fichiers trackés, arbre propre — artefact git antérieur, aucune action restante |

## 4. Fichiers touchés (commit `49078bc`, 14 fichiers)

- `supabase/functions/pharma-api/index.ts` — `has_pin` (`enrichProfile`), selects `/auth/me` + `finishLogin` + `GET /users`, `user_pin_set`/`user_pin_cleared` wrappés `AUDIT_FAILED`, route `DELETE /users/:id/pin`
- `frontend/lib/core/models/user.dart` — `hasPin`
- `frontend/lib/features/settings/settings_page.dart` — section Code PIN + `_editMyPin`
- `frontend/lib/features/super_admin/users_management_page.dart` — `_clearPin`, `_deleteUser`, sous-titre PIN
- `frontend/lib/core/utils/calculations.dart` — garde NaN `calculateSaleTotalExcl`
- `frontend/test/pos_models_test.dart`, `frontend/test/calculations_edge_test.dart` (nouveau)
- `backend/test/p2_audit_log.test.js` — contrat 10 appels / 9 wrappés
- `backend/_test_pin_flow.mjs` (nouveau), `backend/_debug_users_create.mjs` (nouveau)
- `index.html`, `main.dart.js`, `flutter_bootstrap.js`, `main.202610151724.dart.js`

## 5. ACTIONS RESTANTES (décisions utilisateur)

1. **Migration TVA** (SQL de fix du défaut 20 % + trigger) → préparer et obtenir l'autorisation avant exécution.
2. **Worker de sauvegarde** pg_dump chiffrée (P1) — fonctionnalité actuellement déclarée mais non implémentée.
3. Nettoyage manuel des ventes de test si souhaité (aucune API de suppression de vente).

## 6. VERDICT

**PRÊT SOUS RÉSERVES** — toutes les sections exécutables du prompt ont été livrées, testées et déployées ; aucun critère de test en échec (157 + 52 + 29 + 42 verts, analyze/deno nuls, CDN revérifié).

Réserve explicite (15/10) : deux postes restaient `BLOQUÉ` (worker de sauvegarde absent, migration TVA en attente d'autorisation). **Levée le 16/10** — voir ANNEXE : plus aucun poste `BLOQUÉ` ; restent uniquement des `NON CORRIGÉ` assumés (TPE, OCR, Google OAuth, aperçu caméras).

---

## ANNEXE 16/10/2026 — SUIVI « CORRIGE LES POINTS RESTANTS »

**Commits séance :** `9b6d4f9` (corrections + workflow), `bfab2cc` + `20e5cbe` (worker durci + CI pg17), `38e5e61` (deploy web).
**Edge :** déployée (2.5.0 + garde paiement), `deno check` EXIT 0.
**Web :** `flutter_bootstrap.js?v=202610160521` servi par CDN, `main.202610160521.dart.js` HTTP 200, **5 370 130 octets**.

### A. Statuts révisés (postes BLOQUÉ →)

| § | Objet | Statut | Preuves |
|---|---|---|---|
| §7 | Migration TVA | **CORRIGÉ ET TESTÉ** | `_migrate_tva_fix.mjs` exécuté : 11 lignes `product=0 → stocké=0`, `ALTER COLUMN tax_rate DROP DEFAULT` (`column_default=null`), trigger `trg_sale_item_tax_from_product` actif ; **0 divergence** post-migration ; preuve en transaction : insert volontaire `tax_rate=99` → stocké 20/0 (produit TVA 20/0) → ROLLBACK (aucune donnée écrite) ; schéma fichiers synchronisés (`007_sales.sql`, `012_triggers_views.sql`) |
| §9 | Sauvegardes | **CORRIGÉ ET TESTÉ** | `backend/scripts/backup_worker.mjs` (`--create` / `--verify` / `--decrypt`, AES-256-GCM, sha256) ; routes Edge `POST/GET /backups/:id/artifact` (permissions, cloisonnement, cap 64 Mo) ; jobs locales `completed`→`verified` ; **CI nightly `backup-nightly` VERT E2E** (run `38824467953` : tous steps success — client pg17, dump 2,53 Mo en 53 s, chiffré, uploadé) puis `--verify` local de l'artefact CI : *« VÉRIFIÉ : déchiffré 2,53 Mo, SHA-256 identique »* ; 4 secrets GitHub (libsodium `crypto_box_seal`) ; worker durci : reconnexion post-`spawnSync` + `failJob` infaillible |
| §8 | Résidus ventes test | **CORRIGÉ ET TESTÉ** | `scripts/cleanup_test_sales.mjs` (dry-run par défaut, backup JSON) exécuté 2 fois : 11+2 ventes supprimées, compensations `stock_movements` (soldes restaurés, ex. `c08f0ba8=50`), paiements/mouvements/`sale_items`/`receipts` purgés ; **0 vente test, 0 orphelins (vraie requête FK), 0 référence_id orphelin, 0 solde négatif**, 8 ventes réelles intactes (516,30) |
| §10 | Exports non-web | **CORRIGÉ ET TESTÉ** | `download_file_stub.dart` = export dart:io réel (Downloads → courant → temp, BOM UTF-8, `lastSavedPath`/`lastSaveError`) ; web : getters null ; `reports_page._export` try/catch + snackbar affichant le chemin d'enregistrement (desktop) ou « généré » (web) ; analyze 0 + 52/52 + build web déployé |
| §8 | Caisse : sous-paiement | **CORRIGÉ ET TESTÉ** (nouveau) | `POST /sales` : contrôle `paid + 0.009 >= total TTC` pour `pos/cash/online` (crédit/réservation exemptés) + refus des montants négatifs — avant, 35 payés pour 42 dus étaient acceptés ; **preuve live** : cycle POS `8/8` (sous-paiement → `400 PAYMENT_INSUFFISANT`, vente TTC correcte, monnaie rendue, stock décrémenté) |
| §3/§4 | Tests déterministes | **CORRIGÉ ET TESTÉ** | `_test_pin_flow.mjs` **29/29** (paiement TTC corrigé), `_test_switch_user.mjs` **43/43** (fixture autonome `sanspin.switch@test.ma` créée+supprimée, `DELETE /users/:id` testé après déverrouillage), `_test_pos_cycle.mjs` **8/8** réécrit (formes d'API réelles, stock via `medication_stock_map`) |

### B. Séries de tests finales (après la séance)

| Suite | Résultat |
|---|---|
| Backend `node --test "test/*.test.js"` | **157 / 157** |
| `flutter analyze` | **No issues found** |
| `flutter test` | **52 / 52** |
| `deno check pharma-api` | **EXIT 0** |
| `_test_pin_flow.mjs` | **29 / 29** |
| `_test_switch_user.mjs` | **43 / 43** |
| `_test_pos_cycle.mjs` | **8 / 8** |
| Worker local `--create` + `--verify` | dump 2,53 Mo → `VÉRIFIÉ` SHA identique |
| CI `backup-nightly` (dispatch) | **success** — run `38824467953`, tous steps `success` |
| CDN | stamp `202610160521` + bundle 5 370 130 B (HTTP 200) |

### C. Reste en `NON CORRIGÉ` (assumé, inchangé)

TPE (simulation explicite), OCR, Google OAuth (besoin identifiants), aperçu caméras, export Office natif sous web (PDF web via `Printing`), suppression dure de ventes via API (405 par design — nettoyage scripté documenté).

### D. Outils de séance (suivi repo, non committés sauf mention)

`_migrate_tva_fix.mjs`, `_prove_tva_trigger.mjs` (preuve rollback), `_verify_cleanup.mjs` / `_verify_orphans.mjs` (corrigés : vraie requête orphelins + `mv_daily_sales`), `scripts/cleanup_test_sales.mjs` et `scripts/backup_worker.mjs` (trackés).

---

*Annexe produite le 16/10/2026. Aucun identifiant secret n'y figure.*
