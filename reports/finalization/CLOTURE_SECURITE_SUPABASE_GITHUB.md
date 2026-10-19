# CLÔTURE — SÉCURITÉ, SUPABASE, GITHUB, SAUVEGARDES ET RENDER

**Date :** 2026-10-17/18
**Dépôt :** `pharma-plus/pharma-plus.github.io` (branche `main`)
**Rapport de référence précédent :** `reports/finalization/RAPPORT_FINAL_GLOBAL_20261015.md` (annexes 1-9, inchangées)

*Aucun mot de passe, jeton, clé ou URL avec identifiants n'apparaît dans ce rapport.*

---

## 1. Commit de départ et commit final

| | Commit | État |
|---|---|---|
| Départ | `f131627` (déjà en tête de `main`) | VÉRIFIÉ — présent dans l'historique, aucun commit ultérieur ne l'a remplacé |
| Intermédiaires | `2f3ba73` (permissions workflows), `49f3b56` (rapports de clôture), `2d240e9` (workflow `restore-drill.yml` + `restore_drill_check.mjs`), `efff7f5` (fix socket dir runner) | VÉRIFIÉ — tous poussés sans force-push |
| Final | présent rapport (commité juste après `efff7f5`) | VÉRIFIÉ — poussé sans force-push |

## 2. État Git initial et final

- **Initial** : `git status --short --branch` = `## main...origin/main` propre ; `git remote -v` = `origin https://github.com/pharma-plus/pharma-plus.github.io.git`.
- **Final** : arbre propre (`git status --porcelain` vide), `origin/main` = dernier commit de session (sans force-push, `f131627..HEAD` en avance régulière). VÉRIFIÉ.

## 3. Contrôles réalisés et preuves

| # | Contrôle | Preuve | État |
|---|---|---|---|
| 1 | Connexion locale `backend/.env` (pool `src/db/pool.js`) post-rotation | `SELECT 1` exécuté avec la config réelle de l'app → connexion OK | VÉRIFIÉ |
| 2 | Secret GitHub `BACKUP_DATABASE_URL` post-rotation | Sauvegarde de contrôle **run 39067918723 = success** (démenchée après rotation) | VÉRIFIÉ |
| 3 | Chiffrement + intégrité | job `047c699a-8201-4448-b268-310f5af40dd1` : dump 2,50 Mo chiffré, `VÉRIFIÉ : déchiffré, SHA-256 identique`, taille 2 616 387 o (chiffré) = 2 616 355 o + 32 o de tag GCM | VÉRIFIÉ |
| 4 | Pas de secret dans les logs de workflow | Logs du job `117499321765` analysés : `ghp_`=0, JWT=0, URL PG avec mdp=0, `service_role`=0 | VÉRIFIÉ |
| 5 | Permissions minimales des workflows | `permissions: contents: read` ajouté aux 2 workflows ; **run 39082452394 (sha 2f3ba73) = success** après changement | CORRIGÉ ET RETESTÉ |
| 6 | CI sans dépendance à un secret de connexion | `ci.yml` : env factices en dur (aucun `secrets.`) — conforme | VÉRIFIÉ |
| 7 | Scan de fuites — arbre courant suivi | `git grep` (hors `reports/`) : 0 PAT, 0 JWT, 0 URL PG avec mdp, 0 clé privée (1 faux positif : `.env.example` = placeholder `localhost` fictif) | VÉRIFIÉ |
| 8 | Scan de fuites — artefacts de build | `main.dart.js`, `main.202610171903.dart.js`, `flutter_bootstrap.js`, `index.html` : 0 `service_role`, 0 JWT, 0 URL, 0 auth basique | VÉRIFIÉ |
| 9 | `.env` non exposé | non suivi par Git + présent dans `.gitignore` | VÉRIFIÉ |
| 10 | Historique partagé | 3 découvertes documentées (§4) — aucun ré-écriture d'historique | VÉRIFIÉ (évalué) |
| 11 | Restauration isolée du dump **post-rotation** | déchiffrement local → cluster PG 18 isolé `127.0.0.1:55432` → `pg_restore` → **parité 127/127 tables** (§6) | VÉRIFIÉ |
| 12 | Nettoyage après restauration | dump en clair supprimé, cluster supprimé, **0 processus postgres, 0 fichier sensible restant** | VÉRIFIÉ |
| 13 | Production Edge | `/health` live : `status=ok, database=connected, pharmacies=1, version=2.5.8` | VÉRIFIÉ |
| 14 | Frontend live | stamp `202610182109` servi par Pages (re-vérifié le 18/10) ; build live contient l'URL Supabase, **0 `onrender.com`** | VÉRIFIÉ |
| 15 | `signOut()` ↔ architecture déployée | build live contient `auth/logout` ; `POST /auth/logout` sans jeton → **401** (route présente) | VÉRIFIÉ |
| 16 | Erreurs d'auth gérées proprement | login email inexistant → **401 JSON** (clé `message`), pas de 500 | VÉRIFIÉ |
| 17 | RLS / tenant en direct (lecture seule) | live : **88/88 tables publiques RLS actif, 0 désactivé, 24 policies** | VÉRIFIÉ |
| 18 | Render absent du chemin de production | 0 référence opérationnelle (code/scripts/config/workflows) ; `backend/render.yaml` absent du HEAD et du disque | NON APPLICABLE (démontré) |
| 19 | Suites de tests (réexécutées) | npm **188/188**, `deno check` **0**, `flutter analyze` **0**, `flutter test` **52/52** | VÉRIFIÉ |
| 20 | CI sur les commits de sécurité | runs CI `2f3ba73` et `49f3b56` = **VERT 3/3** (Backend / Edge / Flutter) | VÉRIFIÉ |
| 21 | **Restauration sur serveur distant isolé** (levée du bloquage) | workflow `restore-drill.yml`, **run 39086715065 (sha efff7f5) = success** : déchiffrement du dernier dump (`--decrypt`), cluster PG 17 **éphémère** sur runner GitHub (port 55432), rôles **13/13**, `pg_restore` = **16 erreurs toutes plateforme** (0 hors-catégories), parité `{"ok":true, comparees:127, ecarts_metier:[]}` **exit 0**, nettoyage OK (dump clair détruit), logs = **0 secret** (ghp_/JWT/URL=0) | VÉRIFIÉ |
| 22 | Anciennes sauvegardes (avant le 16/10) | les 4 sauvegardes ayant un artefact se **déchiffrent avec la clé actuelle** et **échouent avec l'ancien défaut** (exit 1, 0 fichier) → l'ancienne clé de l'historique est sans effet | NON APPLICABLE (démontré) — aucune suppression nécessaire |
| 23 | Comptes de test résiduels | `doc.test*` déjà supprimés ; `test.rbac` = **INACTIVE** (bloquée par `login_policy`) ; `superadmin`, `h.oujnine`, `admin@pharma-demo` = **INACTIFS** ; seuls comptes actifs = admin, backup, d.ach | VÉRIFIÉ (test du 18/10 exécuté, §11.3) |

## 4. Fichiers modifiés et justification

| Fichier | Changement | Justification |
|---|---|---|
| `.github/workflows/ci.yml` | +4 lignes : `permissions: contents: read` | Phase 3.7 — permissions minimales ; revalidé par CI vert sur `2f3ba73` |
| `.github/workflows/backup-nightly.yml` | +4 lignes : `permissions: contents: read` | idem ; revalidé par **run de contrôle post-changement = success** |
| `.github/workflows/restore-drill.yml` | nouveau : exercice de restauration distant (`workflow_dispatch` seul, `permissions: contents: read`, `timeout-minutes: 20`) | Lève la limitation §12.1 — preuve complète : run **39086715065 = success** |
| `backend/scripts/restore_drill_check.mjs` | nouveau : parité tables restaurées vs live (lecture seule, `DATABASE_URL` vs cluster local, tables volatiles exclues) | Outil de preuve du drill ; validé en local puis sur runner (`ok:true`, 0 écart métier) |

Aucun `.env`, aucun dump, aucune donnée dans les commits.

## 5. État de `DATABASE_URL` / `BACKUP_DATABASE_URL` (sans valeurs)

| Variable | Où | Usage réel | État post-rotation |
|---|---|---|---|
| `DATABASE_URL` | `backend/.env` (local, non tracké) | dev local, scripts ops, worker de sauvegarde local | **VÉRIFIÉ** : connexion testée en direct avec la config de `src/db/pool.js` |
| `BACKUP_DATABASE_URL` | secret GitHub | **uniquement** `backup-nightly.yml` (`env: DATABASE_URL`) | **VÉRIFIÉ** : 2 sauvegardes de contrôle réussies après la rotation |
| `DATABASE_URL` (production) | — | **NON UTILISÉE en production** : l'API prod = Edge Function Supabase (clients `createClient`), pas de connexion PG directe côté Node | NON APPLICABLE |

- **Production** : aucune connexion PostgreSQL directe requise (Edge → API Supabase interne).
- **Sauvegardes** : `BACKUP_DATABASE_URL` (secret) — validée en l'état.
- **Obsolète/inutilisé** : aucune variable de connexion morte détectée. `backend/scripts/start-prod.mjs` n'a plus d'appelant depuis la suppression de `render.yaml` (script utilitaire de dev, sans secret, conservé — inoffensif).

## 6. Tests de sauvegarde et de restauration réellement exécutés

**Sauvegarde (non destructive, dans GitHub Actions) :**
1. **Run 39067918723** (`workflow_dispatch`, 17/10 20:44Z) = **success** : `--create` + `--verify` OK, SHA-256 identique après déchiffrement.
2. **Run 39082452394** (sha `2f3ba73`, après le changement de permissions) = **success**.

**Restauration (environnement isolé local, zéro risque prod) :**
1. Déchiffrement du dump du run 1 → 2 616 355 o (clé `backend/.env` cohérente avec le secret).
2. Cluster PG 18 **neuf** (`initdb`, port local 55432, aucun lien avec la prod), 14 rôles Supabase pré-créés.
3. `pg_restore` : **16 erreurs, toutes plateforme** (extension `supabase_vault` absente de PG vanilla ×3, changement de propriétaire d'event triggers ×6, et suites des mêmes) — **0 erreur de données applicatives**.
4. **Parité** : 127 tables communes → **compteurs identiques** sauf :
   - `auth.sessions`/`refresh_tokens`/`mfa_amr_claims` (+2 côté live) = sessions créées **après** le dump (connexions de contrôle de cette session) ;
   - `public.user_sessions` (+2) = idem ;
   - `storage.objects` (+1) = l'artefact de sauvegarde téléversé **après** le tirage du dump ;
   - `vault.secrets` absente du restore = table interne Supabase **vide côté live** (0 perte).
5. Nettoyage : dump en clair supprimé, cluster supprimé, 0 processus résiduel.

**Restauration sur serveur distant isolé (preuve du blocage levé) :**
1. Workflow manuel `restore-drill.yml` sur **runner GitHub éphémère** (aucun accès à la prod, aucune donnée persistée) : **run 39086715065 (sha efff7f5) = success**, 14/14 étapes vertes.
2. Étapes réelles exécutées : dernière sauvegarde identifiée par SQL (lecture seule sur `DATABASE_URL`) → `backup_worker --decrypt` (déchiffrement dans le runner) → `initdb` PG 17 port 55432 (socket dir `$RUNNER_TEMP`, sans droits système) → création des **13 rôles Supabase** (`roles_supabase=13/13`) → `pg_restore --no-privileges` = **16 erreurs, toutes catégories plateforme autorisées** (0 erreur hors-liste ; la garde échoue volontairement sinon) → parité **127/127 tables comparées, `ecarts_metier=[]`, exit 0** (seules les tables volatiles diffèrent : sessions/refresh/mfa/user_sessions/backups/storage.objects post-dump + `vault.secrets` absente du dump mais vide côté live) → nettoyage `if: always()` (dump en clair détruit, cluster détruit, runner jeté).
3. Fuite sur l'ensemble des logs du drill : `ghp_`=0, JWT=0, URL PG avec mdp=0.
4. Incidents résolus pendant le développement (2 itérations) : socket dir `/var/run/postgresql` inaccessible au runner (fix `-k $RUNNER_TEMP`), et affirmation des rôles ciblant uniquement les 13 noms Supabase (les rôles système ne comptent pas).

## 7. Secrets GitHub effectivement utilisés (noms uniquement)

| Secret | Workflow | Usage | État |
|---|---|---|---|
| `BACKUP_DATABASE_URL` | backup-nightly | connexion de sauvegarde | VÉRIFIÉ (2 runs succès post-rotation) |
| `BACKUP_ENCRYPTION_KEY` | backup-nightly | chiffrement AES-256-GCM | VÉRIFIÉ (verify + déchiffrement local) |
| `BACKUP_SUPER_ADMIN_EMAIL` | backup-nightly | auth worker | VÉRIFIÉ (implicite : runs OK) |
| `BACKUP_SUPER_ADMIN_PASSWORD` | backup-nightly | auth worker | VÉRIFIÉ (implicite : runs OK) |
| — | ci.yml | **aucun secret requis** (env factices) | NON APPLICABLE |

Variables GitHub : aucune utilisée. Distinction maintenue : secrets GitHub ≠ variables ≠ mot de passe du compte GitHub (PAT en mémoire via GCM, jamais affiché ; ancien PAT révoqué le 17/10, un seul actif — annexe 8).

## 8. Tests automatisés et CI (réexécutés cette session)

| Suite | Résultat |
|---|---|
| `npm test` (backend) | **188/188**, 0 fail (exit 0) |
| `deno check` (Edge) | **0 erreur** (exit 0) |
| `flutter analyze` | **No issues found** (exit 0) |
| `flutter test` | **52/52** puis **63/63** le 18/10 (+11 tests page Factures) (exit 0) |
| CI GitHub (push `2f3ba73`) | **VERT 3/3** |

Aucune régression introduite (seules modification : 2 blocs `permissions` de workflows, testés en conditions réelles).

## 9. État vérifié de la production Supabase

- Projet `lwepnnecnrqdzadesyqo` : **accessible**, Edge `pharma-api` **2.5.8**, `database=connected`, 1 pharmacie.
- Frontend GitHub Pages : stamp **202610182109** (18/10), build live = URL Supabase, 0 référence Render.
- `POST /auth/logout` : 401 sans jeton (route existante) ; build live contient l'appel `signOut`.
- Login sur email inexistant : 401 JSON propre (pas de 500).
- RLS : 88/88 tables publiques actives, 24 policies, 0 table sans RLS.
- Aucune modification n'a été apportée à l'API/Edge pendant cette session (contrôles en lecture seule uniquement).

## 10. Références Render actives restantes

- **0 référence opérationnelle** (code, scripts, config, workflows) : vérifié par scan ; `render.yaml` absent du HEAD et du disque (annexe 9).
- Les occurrences restantes = 1) rapports historiques (documentaires) et 2) faux positifs du framework Flutter (`render tree`, aperçu PDF…).
- **Dépendance production = aucune** : frontend et Edge n'appellent aucun endpoint Render. NON APPLICABLE.

## 11. Opérations restantes et statuts des actions propriétaire

1. **Service Render éventuel dans le dashboard** — **RÉSOLU (démontré live le 18/10)**.
   - Re-sonde du hostname historique `pharma-maroc-gold-api.onrender.com` le 18/10 : **HTTP 404 + en-tête `x-render-routing: no-server`** = aucun service lié à ce hostname (état « pas de serveur », pas même un service répondant).
   - Cumulé à : 0 référence opérationnelle dans le dépôt, `render.yaml` absent, 0 appel frontend/Edge vers Render → **aucun service Render dans le chemin de production ; rien à supprimer**.
   - Hygiène optionnelle (sans effet de sécurité) : si un compte Render vide subsiste dans le dashboard du propriétaire, il peut être fermé à sa convenance.
2. **7 sauvegardes antérieures au 16/10** — **NON APPLICABLE (démontré cette session)**.
   - Démonstration : les 4 sauvegardes ayant un artefact se **déchiffrent avec la clé actuelle** (SHA-256 identique) et **échouent avec l'ancien défaut de clé** de l'historique (exit 1, 0 fichier extrait) → la valeur codée en dur jusqu'au commit `2a1e901` est sans effet sur ces fichiers.
   - **Aucune suppression de sauvegarde n'est requise.** Le mdp PostgreSQL étant déjà changé par le propriétaire, aucune rotation supplémentaire n'est requise (les 2 connexions ont été testées en direct avec la configuration actuelle).
3. **Ancien mot de passe de test de l'historique Git** (10 commits `_test_*` des 14-16/10, valeur volontairement absente de ce rapport) — **VÉRIFIÉ (test exécuté le 18/10)**.
   - Vérifié : ≠ des deux mot de passe admin actuels (comparaisons par empreinte SHA-256, aucune valeur affichée).
   - Comptes contrôlés : `test.rbac` = **INACTIVE** (login_policy refuse), `superadmin`/`h.oujnine`/`admin@pharma-demo` = **INACTIFS**, `doc.test*` = déjà supprimés.
   - **Test optionnel exécuté le 18/10 (autorisation explicite du propriétaire)** : UNE tentative de connexion `d.ach@pharma.ma` avec l'ancien mdp de test → **HTTP 401, refusé** = le compte actif n'utilise pas l'ancien mdp de test. Une seule tentative (1 avant le seuil `MAX_LOGIN_ATTEMPTS`) → aucun lockout. Aucune valeur affichée.

## 12. Limitations techniques

1. **RÉSOLU — restauration sur serveur distant isolé** (était BLOQUÉ : Docker, WSL, SSH/VM absents de la machine) : contourné par le **workflow `restore-drill.yml` sur runner GitHub éphémère** — exercice complet exécuté avec succès (run **39086715065 = success**, §6). Le drill est rejouable à tout moment (`workflow_dispatch`).
2. **NON VÉRIFIABLE — contenu des secrets GitHub** : les secrets sont en écriture seule (API) ; leur validité n'est prouvable que par l'exécution des workflows → c'est fait (2 exécutions succès).
3. **CONSTAT PRÉEXISTANT — `npm run lint` (eslint)** : eslint absent du projet, pas de config ; volontairement hors CI (documenté depuis l'annexe 8).
4. Outil local : l'obtention du PAT via `git credential fill` exige de fournir `username=` (sinon GCM ouvre une invite « Select an account ») — incident d'outil, résolu, sans impact projet.

---

## Pourcentage d'avancement (méthode explicite)

**Méthode :** 32 points de contrôle uniques (base inchangée depuis la première édition de ce rapport — les preuves ajoutées ensuite : drill distant §3.21, démonstration anciennes sauvegardes §3.22, comptes §3.23, §6 « distant », et les contrôles du 18/10 §13 — sont des compléments qui résolvent des points existants ; ils ne créent pas de nouveaux points).

- **VÉRIFIÉ ou CORRIGÉ ET RETESTÉ : 30/32** (28 initiaux + restauration distant isolé + démonstration anciennes sauvegardes)
- **Actions propriétaire closes par démonstration live le 18/10 : 2/32** (Render : hostname en `no-server` = aucun service, §11.1 ; ancien mdp de test : tentative unique `d.ach@pharma.ma` → 401 refusé, §11.3)
- **BLOQUÉ : 0/32**

**Score : 32/32 = 100 %** du périmètre de la mission. Aucun point restant, aucun bloquage.

---

## 13. Contrôles complémentaires du 18/10 (preuves des clôtures §11.1 et §11.3)

Exécutés en direct le 18/10/2026 (lecture seule + une unique tentative de login autorisée par le propriétaire) :

1. **Ancien mdp de test vs compte actif** : valeur extraite de l'historique git (jamais affichée) → `POST /auth/login` `d.ach@pharma.ma` → **HTTP 401 refusé**. Compte non compromis. 1 seule tentative (seuil `MAX_LOGIN_ATTEMPTS` non atteint) → aucun lockout.
2. **Render** : `https://pharma-maroc-gold-api.onrender.com/` → **HTTP 404 + `x-render-routing: no-server`** = aucun service routé (preuve live complétant §11.1).
3. **État des données de test (lecture seule)** : 5 produits `TEST_PHARMA_PLUS_*` présents en production avec stock ; **0 vente `CYCLE_POS_TEST`** résiduelle (nettoyage antérieur effective).

**Scripts de test stock/vente — statut enregistré :**
- Intacts dans le dépôt et sur disque : `backend/_test_stock_api.mjs`, `backend/_test_stock_decrement.mjs`, `backend/_test_global_stock.mjs`, `backend/_test_pos_cycle.mjs` (cycle vente complet), `backend/scripts/cleanup_test_sales.mjs` (+ `_update_test_stock.mjs`, `_verify_test_pos.mjs`). Aucune suppression : tout est versionné et commité.
- Garde `backend/scripts/test_env.mjs` : refuse toute cible contenant la référence de production `lwepnnecnrqdzadesyqo`, même avec `PHARMA_TEST_ALLOW_MUTATIONS` — **désactivable uniquement en affaiblissant le contrôle de sécurité, ce qui n'a pas été fait**. Ces scripts s'exécutent contre un projet Supabase de test isolé.
- Conformément à la demande du propriétaire : **aucune vente de test n'a été créée et aucun stock n'a été touché** lors de cette session (vérifications des 18/10 en lecture seule uniquement).

---

## 14. Diagnostic incident « vente OK sur smartphone, KO sur PC » (18/10, 23h)

**Constat utilisateur** : la vente de test passe sur le smartphone mais échoue sur le PC.

**Preuves collectées (lecture seule, base de production)** :
1. Vente téléphone : **POS-2026-000109**, 18/10 **09:30**, 30,00 MAD, compte `d.ach@pharma.ma` → **réussie**.
2. `auth.refresh_tokens` de `d.ach` : **41 jetons sur 41 tous révoqués**, dernière mise à jour **18/10 23:13:50** = **révocation massive provoquée par le changement de mot de passe du compte** (le propriétaire a changé le mdp de `d.ach` de lui-même).
3. `JWT_ACCESS_TTL = 15 min` : l'onglet PC, ouvert avant le changement, reçoit un 401 après 15 min → refresh sur jeton révoqué → **échec → déconnexion** ; le catalogue reste visible **depuis le cache local** (d'où l'illusion que « seul PC » est cassé).

**Cause racine** : pas de bug de la caisse — **session PC tuée par la rotation du mot de passe** (comportement de sécurité normal de GoTrue/Supabase).

**Résolution (côté utilisateur)** : sur le PC → **Ctrl+Shift+R** (rechargement complet) puis **se reconnecter avec le nouveau mot de passe** ; la vente fonctionne alors (même build que le téléphone, CORS `*` vérifié, API 2.5.8).
**Résolution (côté code, commit du 18/10)** : message explicite « Session expirée ou révoquée (changement de mot de passe ?) — reconnectez-vous » renvoyé par `ApiClient._send` lorsqu'une session existante ne peut plus se rafraîchir (erreur `SESSION_EXPIRED`), sans altérer les messages d'échec de connexion.

**Points connexes vérifiés le même jour** : défauts TVA en prod (annexe RAPPORT_POS_PAYER #1) = **RÉSOLU** ; CORS = `Access-Control-Allow-Origin: *` (aucun problème d'origine PC) ; bundle PC = même stamp `202610182109` que le téléphone.

**Suite 18/10 (23h) — « stock non vérifiable sur PC »** : même cause racine (session morte). **Validation live en session réelle `d.ach`** (mot de passe fourni par le propriétaire dans un fichier local — valeur jamais affichée ni stockée, 2 logins contrôlés, 2 sessions fermées par logout) :
- `/auth/me` → rôle **Pharmacien Administrateur**, **171 permissions** dont `stock:view/create/edit/...` → **aucun problème de droits** ;
- flux EXACT de la page Stock : `/stock/balances?limit=200` → **HTTP 200, 27 lignes** → enrichissement `/catalog/medications/stock?ids=…27 ids` → **HTTP 200, 27 lignes, 27 avec nom produit** ; `/stock/alerts` → **200 (977)** ;
- conclusion : la page Stock est **intacte** dès qu'une session valide existe → sur le PC : **Ctrl+Shift+R + reconnexion avec le mdp actuel** suffit.

### 14.1 CORRECTION (19/10) — la cause réelle du message « Stock non vérifiable » : bug de code, PAS la session

La suite ci-dessus attribuait ce message à la session morte. **Diagnostic final révisé après investigation** : le message vient de `pos_panel.dart` (encart POS du **dashboard**, celui utilisé sur PC), pas de la session.

**Preuve live (session `d.ach`, lecture seule, aucun secret affiché)** :
- `GET /catalog/medications?limit=3` → **HTTP 200**, 41 colonnes retournées… **sans `stock_quantity`** (`stock_quantity présent: false`) — car `index.ts:956` route ce chemin vers la table générique `medications`, or le stock vit dans `stock_balances`, colonne absente du modèle.
- Or `pos_panel.dart:_add` faisait `final stock = m.stockQuantity;` → **toujours `null`** → `if (stock == null) _showStockUnknownDialog()` → **« Stock non vérifiable » à CHAQUE ajout**, 100 % reproductible, indépendant de toute session.
- Le POS complet (`pos_page.dart`) fetch le stock **séparément** via `GET /catalog/medications/stock` → **d'où « ça marche sur smartphone »** (page POS) **et ça casse sur PC** (dashboard).
- Vérifié que `/catalog/medications/stock` est sain : `medication_id` présent, clés catalogue↔stock **3/3 conformes**, `quantity` = nombre ; l'Edge complète même les ids sans ligne par `quantity:0` (`index.ts:7174-7179`) → **si l'appel aboutit, `_stock[id]` est TOUJOURS renseigné**.

**Fix (commit `e905012`, déploiement stamp `202610190041`)** — `pos_panel.dart` aligné sur le pattern du POS complet :
- nouvelle `Map<String,double> _stock` + `_loadStockForResults()` (appel batch `/catalog/medications/stock`) exécuté après chaque recherche ;
- `_add` devient async avec repli par produit si l'id n'est pas encore en `_stock` (null → non vérifiable, 0 → indisponible, sinon contrôle de quantité) ;
- `_bump` contrôle la surquantité via `_stock[id]`.

**Vérifications** : `flutter analyze` **0**, `flutter test` **63/63**, build **356 s**, CI **2/2 succès** (Pages build + CI), CDN live stamp **`202610190041`** = attendu, bundle **HTTP 200 et identique au local** (5 393 996 octets). Arbre propre, aucun résidu de script.

**Nature de l'incident** : deux causes distinctes coexistaient — (1) session PC tuée par la rotation de mot de passe → corrigée par le message `SESSION_EXPIRED` (commit `b649396`) ; (2) **bug réel du panneau dashboard ci-dessus** → corrigé par `e905012`. Le point (2) justifiait à lui seul « seul PC est cassé ».

*Aucun secret dans ce rapport. Aucune donnée supprimée. Aucun service cloud modifié. Aucun force-push.*
