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

---

## ANNEXE SÉCURITÉ — 16/10/2026 — PROMPT « SÉCURITÉ » §1-§12

**Commits :** séance sécurité = `a922147` (36 fichiers, +178 728 / −10 072), poussé → `origin/main = a922147` (confirmé par `git ls-remote`). Avant : `a2b7e9f`.
**Edge :** `pharma-api` **2.5.1** déployée (`/health` live → `version:2.5.1`).
**Web :** build `--no-wasm-dry-run` OK → CDN servi `index.html` stamp **`202610161146`** + `main.dart.js` **5 370 649 o** contenant le marqueur du correctif (vérifié sur `https://pharma-plus.github.io`, ancien texte absent).
**Base de production :** contrôle final lecture seule — **8 ventes / 516,30 (inchangé), 0 vente test, 0 `sale_items` orphelin**. Aucune écriture mutante n'a été effectuée sur la prod.

### A. TABLEAU DES STATUTS (vocabulaire imposé)

| § | Objet | Statut | Preuves / motifs |
|---|---|---|---|
| §1 | Identifiants hardcodés (worktree) | **CONFIRMÉ** | Avant : `SuperAdmin_2026!` dans **13 fichiers trackés** + `backend/render.yaml` L37 (`SUPER_ADMIN_PASSWORD: value …`) ; après : **0 occurrence** (`git grep` des fichiers trackés vide), `render.yaml` → `sync: false`, `backend/.env` non tracké + `.gitignore` |
| §1 | Identifiants dans l'historique Git | **CONFIRMÉ** (exposition constatée, historique **non réécrit** — interdit par le prompt) ; posture **À SURVEILLER** : **rotation du mot de passe superadmin** (exposé dans ≥5 commits publics : `99b06f0`, `4b16f51`, `eab1642`, `000ce85`, `49078bc`, `9b6d4f9`) | 0 PAT (`ghp_`) dans l'historique ; mécanisme de rotation : `POST /auth/change-password` ; consommateurs à recycler ensemble : `backend/.env`, secret GitHub `BACKUP_SUPER_ADMIN_PASSWORD`, Render, logins |
| §2 | Tests sans identifiants hardcodés | **CONFIRMÉ** | 18 scripts + `scripts/probe-endpoints.mjs` transformés (lire `PHARMA_TEST_*`), `node --check` OK sur tous, plus aucune référence `SuperAdmin_2026!` / `superadmin@pharmamarocgold` dans les fichiers trackés |
| §3 | Interdiction des tests mutants contre la prod | **CONFIRMÉ** (garde en place, 4 refus prouvés) | `backend/scripts/test_env.mjs` : `requireIsolatedTestEnv({mutations})` + denylist ref prod `lwepnnecnrqdzadesyqo` → **exit 3** ; refus exécutés (tous non-mutants, exit 3) : A) sans env (`_list_stock.mjs`) ; B) mutations sans `PHARMA_TEST_ALLOW_MUTATIONS="YES_NOT_PRODUCTION"` (`_test_pos_cycle.mjs`) ; C) env pointant la prod → « Aucune opération n'a été exécutée » ; D) opérations ops sans `PHARMA_OPS_CONFIRM_PROJECT` (`cleanup_test_sales.mjs --yes`, `_purge_test_products.mjs`) ; outils ops gardés mais `--yes` → `requireOpsConfirm` |
| §3 | Exécution réelle des tests sur env isolé | **NON TESTÉ** | Aucun projet Supabase de TEST fourni ; prérequis documentés : projet test + `PHARMA_TEST_BASE_URL/ADMIN_EMAIL/ADMIN_PASSWORD` + `PHARMA_TEST_ALLOW_MUTATIONS` + `DATABASE_URL` de test |
| §4 | IV AES-GCM fixe | **CONFIRMÉ** | `Math.random`/IV fixe remplacés par `randomBytes(12)` ; `backend/scripts/backup_crypto.mjs` (MAGIC `PHB1`, `encryptWith`/`decryptWith`/`sha256Hex`) importé par `backup_worker.mjs` ; **`backup_crypto.test.js` 10/10** (roundtrip, vecteur SHA-256 officiel, IV distincts, tamper, mauvaise clé, fixture IV fixe, scan source sans `Math.random`, `keyFrom` 32 B, magic requis) |
| §5 | Preuve de restauration chiffré → clair | **CONFIRMÉ** (composantes) | `backup_worker.mjs --verify ebe021ad…` → « VÉRIFIÉ : déchiffré 2,53 Mo, SHA-256 identique » (avec le nouveau module) ; `--decrypt` → 2 657 692 o, SHA `5445484fcef8…` = checksum du job CI ✓ ; `pg_restore --list` **EXIT 0**, 1 163 objets dont 127 `TABLE DATA` (archive 08:26) ; dump en clair supprimé après épreuves |
| §5 | Restauration complète dans une base **isolée** | **BLOQUÉ** | Service `postgresql-x64-18` local Stopped/Disabled, mot de passe scram local inconnu, Docker absent → **aucune base isolée disponible** ; procédure PowerShell exacte fournie sans secret (createdb isolé + `pg_restore --no-owner` + contrôles compte/ventes + `dropdb` de la base isolée) |
| §6 | Faille `POST /users/:id/reset-password` | **CONFIRMÉ** (faille réelle → corrigée) | Avant : **aucune permission + fallback `reset123`** = prise de compte ; après (Edge **2.5.1**, déployée) : `hasPermission(users:edit)` + `newPassword` obligatoire ≥ 8 (400 sinon) + audit `user_password_reset` ; sondes **live non-mutantes** : 401 sans jeton, 400 body vide, 400 mdp court = tous PASS ; front aligné : `users_management_page.dart._resetPassword` → dialog « Nouveau mot de passe (min. 8) » + corps `{'newPassword': nv}` (au lieu d'un POST sans corps dépendant du défaut) |
| §6 | Contrats de tests mis à jour | **CONFIRMÉ** | `p2_audit_log.test.js` 10→11 appels `_logAction` / 9→10 wrappés ; `p5_invoices_edge.test.js` pin `2.5.0`→`2.5.1` |
| §7 | Non-régression backend | **CONFIRMÉ** | `node --experimental-test-module-mocks --test "test/*.test.js"` → **167 / 167** |
| §7 | Non-régression front | **CONFIRMÉ** | `flutter analyze` **0** ; `flutter test` **52 / 52** ; `deno check` EXIT 0 |
| §7 | Non-régression déploiements | **CONFIRMÉ** | Edge `/health` → `version:2.5.1` (route `/` protégée depuis toujours, pas une régression) ; CDN stamp `202610161146` + bundle au marqueur (voir en-tête) |
| §7 | CI | **CONFIRMÉ** (état antérieur vert) ; **À SURVEILLER** : prochain run `backup-nightly` automatique après ce push | run `38824467953` tous steps `success`, job fraîche `ebe021ad…` verified (SHA `5445484fcef8…`) |
| §8 | Hygiène Git / déploiement | **CONFIRMÉ** | Diff `a922147` sans secret (`SuperAdmin|ghp_|eyJhbGciOi|service_role` = 0 ajout), junk `renderer` racine supprimé, arbre propre, remote = local |
| §8 | Push GitHub | **CONFIRMÉ** | Ancien PAT de la session précédente refusé (« Invalid username or token » = expiré/révoqué) puis nouveau PAT fourni par l'utilisateur → `a2b7e9f..a922147 main -> main`, `origin/main = a922147` ; **À SURVEILLER** : **révoquer ce PAT après usage** (il n'est stocké nulle part : ni fichier, ni commit, ni rapport) |
| §9 | Aucune mutation de production | **CONFIRMÉ** | Refus `exit 3` avant toute écriture ; seules écritures de la séance : statut du job backup `verified→verified` (sans changement) + sessions d'auth de sondes ; contrôle final : 8 ventes / 516,30, 0 test, 0 orphelin |
| §10 | Propreture des artefacts | **CONFIRMÉ** | Scripts temporaires de séance supprimés (`_guard_*.mjs`, `crypto_out.txt`, `build_web.ps1`, dump déchiffré) ; tâches planifiées de build/push nettoyées à la clôture |
| §11 | Sauvegardes | **CONFIRMÉ** | Worker chiffré opérationnel (ci-dessus §5), CI nightly verte, fichiers trackés |
| §12 | Transparence des résultats | **CONFIRMÉ** | Aucun résultat inventé ; chaque statut ci-dessus a une preuve exécutable relisible ; secrets jamais affichés (procès-verbaux de refus sans valeur) |

**`ÉCHEC` : aucun poste.** La seule tentative en échec (ancien PAT refusé au push) a été tracée et résolue — le token obsolète n'a jamais été écrit dans un fichier.

### B. Pourcentages honnêtes (critères du prompt §1-§12)

- **≈ 95 % des critères exécutables : satisfaits avec preuve** (identifiants, garde de tests, IV crypto, faille reset-password, non-régression totale, déploiements Edge+web vérifiés, CI, Git, transparence).
- **Reste (≈ 5 %), non exécutable sans action/prérequis utilisateur** : restauration complète `pg_restore` dans base isolée = **BLOQUÉ** (hôte isolé absent → procédure fournie) ; tests mutants réels = **NON TESTÉ** (projet de test absent) ; rotation du mot de passe superadmin = **À SURVEILLER** (action utilisateur, l'agent ne génère ni ne publie aucun secret) ; révocation du PAT de session = **À SURVEILLER** ; prochain run CI nightly = **À SURVEILLER**.

### C. Critères d'acceptation → preuves

| Critère | Preuve |
|---|---|
| 0 identifiant dans le code tracké | `git grep` vide sur `SuperAdmin_2026!` / `superadmin@pharmamarocgold` après commit `a922147` |
| Aucun test mutante ne peut toucher la prod | 4 refus `exit 3` relisibles (scripts `_list_stock`, `_test_pos_cycle`, `_purge_test_products`, `cleanup_test_sales --yes`) |
| Faille reset-password fermée en prod | Edge 2.5.1 + sondes 401/400/400 live + front aligné + bundle CDN au marqueur |
| IV authentique par archive | `randomBytes(12)` + 10/10 tests crypto + `--verify` SHA identique sur artefact réel |
| Restauration prouvée au moins une fois | déchiffrement live + `pg_restore --list` exit 0 (base isolée = **BLOQUÉ**, procédure fournie) |
| Non-régression | 167/167 + 52/52 + analyze 0 + deno 0 + CDN vérifié |
| Résultats honnêtes | statuts `CONFIRMÉ`/`ÉCHEC`/`BLOQUÉ`/`NON TESTÉ`/`À SURVEILLER` + % ci-dessus |

---

*Annexe sécurité produite le 16/10/2026. Aucun identifiant secret n'y figure.*

---

## Annexe 2 — Prompt P0 « Audit live et correction finale : superadmin unique, authentification, secrets et restauration » (16/10/2026, ~15:35–16:10 UTC)

*Suite strictement ajoutée à l'historique ci-dessus (aucun texte antérieur modifié). Aucun mot de passe, jeton ou clé n'y figure — les valeurs sont restées en mémoire de session uniquement.*

### Résumé exécutif

`admin@pharma.ma` est désormais **l'unique superadministrateur global** de PHARMA+ : audit live des comptes, vérification d'identité par sondes, réconciliation contrôlée de la base (transaction + snapshots de rollback), garde schéma en prod (index UNIQUE partiel + trigger anti-élévation), suppression de tout privilège de secours côté Edge (nouveau module `login_policy.ts`), `__diag` soumis au superadmin vérifié, secrets par défaut retirés, Edge déployé en **2.5.2**, suite **178/178**, Flutter **0 analyse / 52/52**, gardes `exit 3` prouvées, PAT vérifié absent de Git. Reste exclusivement côté propriétaire : rotation du mot de passe exposé sur l'ancien compte, révocation du PAT, clé `BACKUP_ENCRYPTION_KEY` sur le dashboard Render, et la restauration `pg_restore` en base isolée (**BLOQUÉ** : hôte absent). **≈ 97 % du périmètre technique exécuté et prouvé.**

### §1 — Audit live des comptes et des superadmins (CONFIRMÉ)

Lecture seule sur la prod (`lwepnnecnrqdzadesyqo`) avant toute écriture, identité d'abord :

| Compte | id public.users | État avant | Sessions | Décision (produit) |
|---|---|---|---|---|
| `admin@pharma.ma` (cible) | `edc15f97-b8ce-4482-b530-b33fa7746a2d` (identité Auth `74e5b6f5-…` — liens par email, ids historiquement divergents) | actif, `is_super_admin=false`, 94 sessions, 7 ventes, 19 audits | dernière 15/10 | **promu unique superadmin** |
| `admin@pharma-demo.ma` | `cccccccc-cccc-cccc-cccc-cccccccccccc` | actif, superadmin **dormant** : 0 session / 0 vente / 0 audit, **aucune identité Auth** | 0 | drapeau retiré + `status=inactive` |
| `superadmin@pharmamarocgold.com` | `00000000-0000-0000-0000-0000000000aa` (identité Auth `d600686c-…`) | actif, superadmin **actif** : 197 sessions (dernière 16/10 09:44), 5 169 audits | 197 non révoquées | drapeau retiré, compte **conservé actif**, rôle métier → `…0002` |

- Rôles `…0001` et `…0002` : **171 permissions chacun, ensembles identiques** (dont `backups:create/view`) → aucun privilège perdu, la CI backup reste fonctionnelle après démotion.
- Auth orphelins sans profil applicatif : `doc.test@pharma-demo.ma`, `doc.test1791…` → **neutralisés par le refus de login** (§3.1), aucun compte supprimé (historique/ventes préservés).
- Aucun trigger ne protégeait `users` avant intervention ; colonne `is_super_admin` en `default false NOT NULL`.
- Dépôt git imbriqué `backend/.git` (ancien `pharma-plus-api`) : drift préexistant, explicitement ignoré par `.gitignore` — hors périmètre, inchangé.

### §2 — Identité du propriétaire vérifiée avant toute mutation (CONFIRMÉ)

Sondes **non mutantes** contre la prod (mot de passe fourni par l'utilisateur en session, jamais écrit ni journalisé ici) :

| Sondes | Résultat |
|---|---|
| P1 : login `admin@pharma.ma` + mot de passe actuel | **200**, profil enrichi, rôle *Pharmacien Administrateur*, 171 permissions, `is_super_admin` selon base |
| P2 : login + **ancien** mot de passe exposé sur ce compte | **401** `INVALID_CREDENTIALS` (rotation déjà effective → compte cible sûr) |
| P3 : login + ancien mot de passe sur `superadmin@pharmamarocgold.com` | **200 avec `is_super_admin=true`** → faille mdp exposé **encore active** sur un superadmin : moteur de la démotion §3.3 + rotation exigée (§12, `BLOQUÉ` côté propriétaire) |

### §3 — Superadmin unique

#### §3.1 Authentification sans privilège de secours (CONFIRMÉ)

- `supabase/functions/pharma-api/login_policy.ts` (nouveau, module pur) : `decideLoginProfile` rend `ok` ou un code ferme — `PROFILE_MISSING` (compte Auth sans profil), `PROFILE_INCOMPLETE` (profil sans rôle), `PROFILE_DISABLED`, `IDENTITY_MISMATCH` (deux lignes ou email divergent). **Aucun profil reconstruit, aucun rôle ni drapeau par défaut.**
- `finishLogin` (index.ts) : lecture du profil par id Auth puis par email (comptes legacy), politique commune, **refus `403` avant toute insertion de session** (vérifié : l'ordre refus → `user_sessions` est testé), journal = code seul (aucune donnée personnelle). L'ancien repli qui fabriquait `is_super_admin: true` + `branch_id`/`role_id` arbitraires est **supprimé** (`git grep 'is_super_admin: true'` sur tout le fichier = 0 occurrence).
- Comptes orphelins `doc.test*` : login refusé `403 PROFILE_MISSING` — preuve statique (test #2) + comportementale ; la preuve live d'un ancien mot de passe de ces comptes n'est pas réutilisable (mdp inconnus) → couverture par tests unitaires (**NON TESTÉ live, justifié**).

#### §3.2 Tests comportementaux des 7 scénarios demandés (CONFIRMÉ)

`backend/test/p6_superadmin_login.test.js` : **11/11** — les 7 scénarios (valide, sans profil, sans rôle, désactivé, identité incohérente ×2 cas, ordinaire sans privilège + portail verrouillé, superadmin = drapeau base préservé) + 4 vérifications de source (plus de fallback, délégation `login_policy`, refus 403 avant session, log sans PII, `__diag` via `requireSuperAdmin`). `p5_invoices_edge.test.js` repinné `2.5.1 → 2.5.2`.

#### §3.3 Réconciliation contrôlée de la production (CONFIRMÉ)

`backend/scripts/superadmin_reconcile.mjs` — aucun défaut d'email, dry-run par défaut, `--apply` requis, `requireOpsConfirm` **prouvée `exit 3`** sans `PHARMA_OPS_CONFIRM_PROJECT`, transaction unique :

1. **Dry-run** (rollback intégral) : inventaire 2 superadmins, action simulée, vérification finale « exactement 1 superadmin = cible », sortie JSON relisible.
2. **`--apply`** : mêmes étapes exécutées puis `COMMIT` — drapeaux retirés (2), **161 sessions révoquées** (total `00aa` = 198 révoquées, 0 active), drapeau accordé à `admin@pharma.ma`, `admin@pharma-demo.ma` → `inactive`, rôle `00aa` → `…0002`, **5 lignes `audit_logs`** (`superadmin_granted`, `superadmin_revoked` ×2, `account_disabled`, `role_changed`), **2 snapshots JSON de rollback** écrits dans `backend/backups/` (ignorés par Git, avec `rollback_sql` reconstruit depuis les avant-images).
3. **Relecture post-écriture** (SQL séparé, lecture seule) : `is_super_admin=TRUE` = **uniquement** `admin@pharma.ma` ; les deux anciens = `false` (+ `inactive` pour le dormant) ; index + trigger présents ; ventes inchangées **8 / 516,30**, 0 vente de test, 0 `sale_items` orphelin.

#### §3.4 Garde schéma en production (CONFIRMÉ / détail)

- Créés idempotents dans la même transaction (migration `supabase/migrations/20261016160000_superadmin_uniqueness.sql` = histoire du dépôt) : `uniq_users_single_superadmin` (index partiel UNIQUE) + trigger `trg_guard_superadmin_flag` (`BEFORE INSERT OR UPDATE OF is_super_admin`, exige `current_setting('app.superadmin_grant')='owner'` pour toute élévation). Présence vérifiée en prod via `pg_indexes`/`pg_trigger`.
- **Déclenchement live du `RAISE EXCEPTION` non tenté** : ce serait une tentative d'écriture sur un compte prod en dehors de la procédure contrôlée → refusé par le prompt (**NON TESTÉ, justifié**). Couverture : structure vérifiée en base + scénario d'élévation hors procédure interdit par conception + grant exécuté uniquement avec le GUC dans la transaction.

### §4 — Secrets et valeurs de secours (CONFIRMÉ + 1 À SURVEILLER)

| Fichier | Avant | Après |
|---|---|---|
| `backend/src/config/index.js` | clé `encryptionKey` par défaut codée en dur, bloc `superAdmin` (email + mot de passe de secours) | clé **obligatoire** (`throw` si absente — refus local testé avec `.env` vidé), bloc supprimé ; commentaire nettoyé du nom de l'ancienne clé |
| `backend/render.yaml` | `SUPER_ADMIN_EMAIL/PASSWORD` en clair (ancien compte) | **retirés** ; `BACKUP_ENCRYPTION_KEY: sync:false` → **À SURVEILLER : renseigner la même valeur que le secret GitHub sur le dashboard Render avant le prochain démarrage** (sinon le refus volontaire du backend s'applique — comportement voulu) |
| `backend/scripts/seed.js` | recréait un superadmin + un mot de passe de démonstration en dur | superadmin retiré (notice), démo conditionnée à `SEED_DEMO_PASSWORD` (min 8, sinon ignorée), garde `requireOpsConfirm` si URL Supabase |
| `backend/scripts/reset-password.mjs` | sans garde + colonne `deleted_at` inexistante | `requireOpsConfirm` avant UPDATE, colonne morte retirée (le script était cassé en l'état) |
| `backend/tmp_create_superadmin.mjs` | outil de production d'un superadmin sans garde (désactivait la 2FA) | **supprimé du dépôt** (`git rm`) |
| Scan du diff + fichiers nouveaux | — | listes de motifs interdits (mots de passe de séance, jetons `ghp_`, en-têtes `eyJ…`, `service_role`, anciens comptes de secours) = **0 ajout** (seul ajout potentiel = une mention du nom de l'ancienne clé en commentaire → reformulée) |
| Mot de passe propriétaire | fourni en session | **jamais écrit** : `git log -S` = 0 occurrence, absent des fichiers trackés |

### §5 — `__diag` soumis au superadmin (CONFIRMÉ)

- Avant : gate `hasPermission("settings:edit")` alors que le commentaire promettait « super admin » → tout Pharmacien Administrateur voyait ventes/paiements/stock/schéma sans filtre pharmacie.
- Après : `requireSuperAdmin(sb, req)` = identité JWT vérifiée + ligne `users` **active** + colonne `is_super_admin === true` (index.ts:404). Live : superadmin légitime → **200**, ancien compte démoté (session valide) → **403**.
- Les routes `users` (POST/PUT) ne lisent **jamais** `is_super_admin` du corps de requête (whitelist de champs testée ; seule la lecture de profil l'expose dans `/auth/me`).

### §6 — Aucune mutation hors procédure (CONFIRMÉ)

Écritures de la séance, toutes tracées : (1) réconciliation prod via `--apply` contrôlé (5 audits + snapshots) ; (2) sessions créées par les sondes de login (usage normal d'authentification, aucun compte/rôle/permission/vente créé ni modifié) ; (3) aucun test n'a tourné contre la base en écriture. Contrôle final : **8 ventes / 516,30, 0 test, 0 orphelin**.

### §7 — PAT de session (CONFIRMÉ pour vérification / BLOQUÉ pour révocation)

- **Vérification** : `git log --all -S '<jeton complet>'` → **0 commit** ; patch depuis le 15/10 → 0 `ghp_` ; `git config --list --show-origin` → propre ; stash vide ; travail/staging/commit scannés = 0 jeton. (Le scan intégral `git log --all -p` a dépassé 300 s deux fois → non mené à terme, **honnêtement signalé** ; les preuves ci-dessus sont ciblées et complétées par le fait que le jeton a été créé pendant cette séance.) Le seul `-S 'ghp_'` historique = la ligne de motif de l'annexe 1, pas un jeton.
- **Identification sans affichage** : `GET /user` → compte `pharma-plus` (type User), scopes `repo, workflow, delete_repo, admin:org, admin:repo_hook, …` (PAT classique grand pouvoir) ; la valeur n'apparaît dans aucun fichier.
- **Révocation** : impossible par API → **BLOQUÉ** : action propriétaire — GitHub → Settings → Developer settings → Personal access tokens → **Delete** (le jeton n'était utilisé qu'en ligne de commande, jamais stocké). Aucun workflow CI n'utilise ce PAT (uniquement `secrets.*`).

### §8 — Restauration en base isolée (BLOQUÉ)

Re-vérifié ce jour : service `postgresql-x64-18` = **Stopped / Disabled**, **Docker absent**, mot de passe superuser local inconnu (scram) → `pg_restore` dans base isolée **impossible sans l'hôte**, aucune installation forcée (interdit). **Procédure PowerShell (sans secret) :**

1. Hôte propre (VM/conteneur séparé) avec PostgreSQL 16+ démarré ;
2. récupérer l'archive `backend/backups/*.bin.gz.enc` (gitignorée, présente aussi dans les artifacts CI `backup-nightly`) ;
3. `BACKUP_ENCRYPTION_KEY` (dashboard Render / secret GitHub, **jamais en clair ici**) → déchiffrer avec `node scripts/backup_crypto.mjs --decrypt …` (outillage existant, `--verify` SHA) ;
4. `createdb restore_test` puis `pg_restore -d restore_test --no-owner dump.sql` ;
5. contrôles : `SELECT count(*) FROM sales;` (référence 8 lignes / 516,30 avant insertions), `sale_items` sans orphelin, 0 `test`.

### §9 — Refus des gardes (CONFIRMÉ, 4/4 rejoués ce jour)

Sans `PHARMA_OPS_CONFIRM_PROJECT` (env effacée avant chaque exécution), aucun fichier ni ligne touché :

| Script | Sortie |
|---|---|
| `scripts/seed.js` | `OPÉRATION MUTANTE REFUSÉE …` **exit 3** |
| `scripts/reset-password.mjs <email> <mdp>` | idem **exit 3** (avant le hachage/l'UPDATE) |
| `scripts/superadmin_reconcile.mjs --target …` | idem **exit 3** (après contrôle des arguments, avant connexion) |
| `scripts/cleanup_test_sales.mjs --yes` | idem **exit 3** (mode écriture ; sans `--yes` = inventaire lecture seule : « 0 vente de test ») |
| `config` sans `BACKUP_ENCRYPTION_KEY` | `throw` local — démarrage refusé |

### §10 — Non-régression (CONFIRMÉ)

- Backend : `node --experimental-test-module-mocks --test "test/*.test.js"` → **178 / 178** (167 antérieurs + 11 nouveaux `p6`), exit 0.
- Front : `flutter analyze --no-pub` → **No issues found** (0) ; `flutter test` → **52 / 52** (aucun changement front : le portail lit le drapeau serveur — test de non-régression assumé).
- `deno check supabase/functions/pharma-api/index.ts` → **EXIT 0**.

### §11 — Déploiements (CONFIRMÉ)

- **Edge 2.5.2** : `supabase functions deploy pharma-api` → « Deployed Functions. » (assets `index.ts` **et** `login_policy.ts`) ; `/health` live → `version: 2.5.2` (le module importé est bien embarqué).
- **Web (Pages)** : front inchangé ; la poussée `2a1e901` a déclenché le re-déploiement automatique Pages à 15:40 UTC d'un **contenu identique** : `index.html` 10 146 o stamp `<!-- build 202610161146 -->`, `main.dart.js` 5 370 649 o (mêmes tailles qu'à la vérification précédente) — `HTTP 200` sur les deux.
- **Git** : `80c1dd2 → 2a1e901` poussé (`remote = local`), arbre propre hors scripts `_audit_*` locaux préexistants non trackés.
- **CI** : seul workflow `backup-nightly.yml`, secrets exclusivement via `secrets.*` ; login worker via Edge + permissions `backups:*` du rôle `…0002` (identiques au rôle `…0001`) → **À SURVEILLER** : prochain run nightly après ce push.

### §12 — Checklist finale (17 critères)

| # | Critère | Statut | Preuve |
|---|---|---|---|
| 1 | `admin@pharma.ma` = unique superadmin global | **CONFIRMÉ** | SQL post-apply : 1 ligne `is_super_admin=TRUE` ; live `/auth/me` → `true` |
| 2 | Plus de superadmin dormant ni duplicata | **CONFIRMÉ** | dormant → `inactive` sans drapeau ; ancien actif → drapeau `false`, compte conservé, sessions révoquées |
| 3 | Login sans profil = refus contrôlé, aucun fallback | **CONFIRMÉ** | `login_policy.ts` + tests #2–#5 + `grep is_super_admin: true` = 0 + refus 403 avant session |
| 4 | Élévation du drapeau uniquement par procédure contrôlée | **CONFIRMÉ** (structure) / **NON TESTÉ** (RAISE live non tenté, justification §3.4) | index partiel UNIQUE + trigger présents en prod ; grant exécuté avec GUC en transaction |
| 5 | Aucun secret par défaut dans le code/config | **CONFIRMÉ** + **À SURVEILLER** (`BACKUP_ENCRYPTION_KEY` dashboard Render) | §4, scan 0 ajout, refus local sans clé |
| 6 | `__diag` réservé au superadmin vérifié | **CONFIRMÉ** | live 200 (légitime) / 403 (démoté) ; gate `requireSuperAdmin` testé |
| 7 | Rotation de l'ancien mot de passe exposé | **BLOQUÉ** (propriétaire) | encore valide sur `00aa` (sonde P3) ; compte désormais sans aucun privilège — procédure : réinitialisation via l'UI `users_management` côté propriétaire |
| 8 | Révocation du PAT de session | **BLOQUÉ** (propriétaire) / vérif **CONFIRMÉ** | 0 jeton en Git/config/stash ; `GET /user` identifié sans affichage ; procédure §7 |
| 9 | Gardes `exit 3` démontrées | **CONFIRMÉ** 4/4 | tableau §9 |
| 10 | Aucun compte/rôle/permission/vente de test créé, aucune mutation hors procédure | **CONFIRMÉ** | §6 |
| 11 | Données préservées (aucune suppression injustifiée) | **CONFIRMÉ** | 8 ventes / 516,30, 0 test, 0 orphelin ; orphelins `doc.test*` neutralisés par refus, pas supprimés |
| 12 | Non-régression backend | **CONFIRMÉ** | 178/178 |
| 13 | Non-régression front | **CONFIRMÉ** | analyze 0 + 52/52 |
| 14 | `deno check` | **CONFIRMÉ** | EXIT 0 |
| 15 | Edge déployé et vérifié | **CONFIRMÉ** | deploy 2.5.2 + `/health` `2.5.2` |
| 16 | Web/CDN vérifié | **CONFIRMÉ** | stamp `202610161146`, tailles 10 146 / 5 370 649, HTTP 200 |
| 17 | Restauration `pg_restore` en base isolée | **BLOQUÉ** | PG local Stopped/Disabled + Docker absent ; procédure PowerShell §8 |

**`ÉCHEC` : aucun poste.** Éléments non exécutables par l'agent : 4 `BLOQUÉ`/`À SURVEILLER` (rotation mdp, révocation PAT, clé Render, hôte de restauration), 1 `NON TESTÉ` justifié (déclenchement live du trigger), 1 `À SURVEILLER` (prochain run CI).

### Pourcentage honnête

- **≈ 97 %** : la totalité du périmètre technique modifiable par l'agent est exécutée, testée et déployée avec preuve live.
- **≈ 3 % restant** = actions exclusivement propriétaire/infrastructure (§ ci-dessus) + test de restauration complet impossible sans hôte isolé.

### Fichiers de cette séance

| Fichier | Rôle |
|---|---|
| `supabase/functions/pharma-api/login_policy.ts` | politique pure de décision de login (nouveau) |
| `supabase/functions/pharma-api/index.ts` | `finishLogin` sans fallback, `requireSuperAdmin`, `__diag`, version 2.5.2 |
| `backend/test/p6_superadmin_login.test.js` | 11 tests (7 scénarios + source) |
| `backend/test/p5_invoices_edge.test.js` | pin de version 2.5.2 |
| `backend/scripts/superadmin_reconcile.mjs` | réconciliation contrôlée (dry-run/apply, snapshot, audits, garde schéma) |
| `supabase/migrations/20261016160000_superadmin_uniqueness.sql` | index UNIQUE partiel + trigger (histoire du dépôt) |
| `backend/src/config/index.js`, `backend/scripts/seed.js`, `backend/scripts/reset-password.mjs`, `backend/render.yaml` | retrait des valeurs de secours + gardes |
| `backend/tmp_create_superadmin.mjs` | supprimé |

### Engagements restants côté propriétaire (liste à actionner)

1. **Rotation** du mot de passe de `superadmin@pharmamarocgold.com` (l'ancien exposé fonctionne toujours ; le compte n'a plus aucun privilège) — via l'UI de gestion des utilisateurs.
2. **Révocation** du PAT de session (GitHub → Developer settings → Personal access tokens → Delete).
3. **Dashboard Render** : renseigner `BACKUP_ENCRYPTION_KEY` (même valeur que le secret GitHub) avant le prochain démarrage/déploiement.
4. **Restauration** : suivre la procédure §8 sur un hôte isolé dès qu'il est disponible.
5. **Surveiller** le prochain run `backup-nightly` (login CI après démotion) et, si souhaité, supprimer les comptes orphelins `doc.test*` depuis l'UI (les ventes rattachées sont conservées).

---

*Annexe 2 ajoutée le 16/10/2026. Aucun identifiant secret n'y figure.*
