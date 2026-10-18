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
| 14 | Frontend live | stamp `202610171903` servi par Pages ; build live contient l'URL Supabase, **0 `onrender.com`** | VÉRIFIÉ |
| 15 | `signOut()` ↔ architecture déployée | build live contient `auth/logout` ; `POST /auth/logout` sans jeton → **401** (route présente) | VÉRIFIÉ |
| 16 | Erreurs d'auth gérées proprement | login email inexistant → **401 JSON** (clé `message`), pas de 500 | VÉRIFIÉ |
| 17 | RLS / tenant en direct (lecture seule) | live : **88/88 tables publiques RLS actif, 0 désactivé, 24 policies** | VÉRIFIÉ |
| 18 | Render absent du chemin de production | 0 référence opérationnelle (code/scripts/config/workflows) ; `backend/render.yaml` absent du HEAD et du disque | NON APPLICABLE (démontré) |
| 19 | Suites de tests (réexécutées) | npm **188/188**, `deno check` **0**, `flutter analyze` **0**, `flutter test` **52/52** | VÉRIFIÉ |
| 20 | CI sur les commits de sécurité | runs CI `2f3ba73` et `49f3b56` = **VERT 3/3** (Backend / Edge / Flutter) | VÉRIFIÉ |
| 21 | **Restauration sur serveur distant isolé** (levée du bloquage) | workflow `restore-drill.yml`, **run 39086715065 (sha efff7f5) = success** : déchiffrement du dernier dump (`--decrypt`), cluster PG 17 **éphémère** sur runner GitHub (port 55432), rôles **13/13**, `pg_restore` = **16 erreurs toutes plateforme** (0 hors-catégories), parité `{"ok":true, comparees:127, ecarts_metier:[]}` **exit 0**, nettoyage OK (dump clair détruit), logs = **0 secret** (ghp_/JWT/URL=0) | VÉRIFIÉ |
| 22 | Anciennes sauvegardes (avant le 16/10) | les 4 sauvegardes ayant un artefact se **déchiffrent avec la clé actuelle** et **échouent avec l'ancien défaut** (exit 1, 0 fichier) → l'ancienne clé de l'historique est sans effet | NON APPLICABLE (démontré) — aucune suppression nécessaire |
| 23 | Comptes de test résiduels | `doc.test*` déjà supprimés ; `test.rbac` = **INACTIVE** (bloquée par `login_policy`) ; `superadmin`, `h.oujnine`, `admin@pharma-demo` = **INACTIFS** ; seuls comptes actifs = admin, backup, d.ach | VÉRIFIÉ (voir §11.3 pour l'unique test optionnel restant) |

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
| `flutter test` | **52/52** (exit 0) |
| CI GitHub (push `2f3ba73`) | **VERT 3/3** |

Aucune régression introduite (seules modification : 2 blocs `permissions` de workflows, testés en conditions réelles).

## 9. État vérifié de la production Supabase

- Projet `lwepnnecnrqdzadesyqo` : **accessible**, Edge `pharma-api` **2.5.8**, `database=connected`, 1 pharmacie.
- Frontend GitHub Pages : stamp **202610171903**, build live = URL Supabase, 0 référence Render.
- `POST /auth/logout` : 401 sans jeton (route existante) ; build live contient l'appel `signOut`.
- Login sur email inexistant : 401 JSON propre (pas de 500).
- RLS : 88/88 tables publiques actives, 24 policies, 0 table sans RLS.
- Aucune modification n'a été apportée à l'API/Edge pendant cette session (contrôles en lecture seule uniquement).

## 10. Références Render actives restantes

- **0 référence opérationnelle** (code, scripts, config, workflows) : vérifié par scan ; `render.yaml` absent du HEAD et du disque (annexe 9).
- Les occurrences restantes = 1) rapports historiques (documentaires) et 2) faux positifs du framework Flutter (`render tree`, aperçu PDF…).
- **Dépendance production = aucune** : frontend et Edge n'appellent aucun endpoint Render. NON APPLICABLE.

## 11. Opérations restantes et statuts des actions propriétaire

1. **Service Render éventuel dans le dashboard** — *SEULE ACTION PROPRIÉTAIRE RESTANTE*.
   - Action : ouvrir le dashboard Render → si un service `pharma-plus-api` (ou autre) existe, le supprimer (aucun chemin de prod ne l'utilise ; preuve : 0 URL `.onrender.com` dans tout le dépôt et dans le build live).
   - Je ne touche à aucun service cloud sans autorisation explicite.
2. **7 sauvegardes antérieures au 16/10** — **NON APPLICABLE (démontré cette session)**.
   - Démonstration : les 4 sauvegardes ayant un artefact se **déchiffrent avec la clé actuelle** (SHA-256 identique) et **échouent avec l'ancien défaut de clé** de l'historique (exit 1, 0 fichier extrait) → la valeur codée en dur jusqu'au commit `2a1e901` est sans effet sur ces fichiers.
   - **Aucune suppression de sauvegarde n'est requise.** Le mdp PostgreSQL étant déjà changé par le propriétaire, aucune rotation supplémentaire n'est requise (les 2 connexions ont été testées en direct avec la configuration actuelle).
3. **Ancien mot de passe de test de l'historique Git** (10 commits `_test_*` des 14-16/10, valeur volontairement absente de ce rapport) — *VÉRIFIÉ (sécurité) ; un test optionnel reste ouvert*.
   - Vérifié : ≠ des deux mot de passe admin actuels (comparaisons par empreinte SHA-256, aucune valeur affichée).
   - Comptes contrôlés : `test.rbac` = **INACTIVE** (login_policy refuse), `superadmin`/`h.oujnine`/`admin@pharma-demo` = **INACTIFS**, `doc.test*` = déjà supprimés → aucun compte actif ne l'utilise visiblement.
   - Test optionnel (action propriétaire) : vérifier le mot de passe du compte actif `d.ach@pharma.ma` — impossible pour moi sans tenter une authentification contre la prod (interdit ; risque de lockout).

## 12. Limitations techniques

1. **RÉSOLU — restauration sur serveur distant isolé** (était BLOQUÉ : Docker, WSL, SSH/VM absents de la machine) : contourné par le **workflow `restore-drill.yml` sur runner GitHub éphémère** — exercice complet exécuté avec succès (run **39086715065 = success**, §6). Le drill est rejouable à tout moment (`workflow_dispatch`).
2. **NON VÉRIFIABLE — contenu des secrets GitHub** : les secrets sont en écriture seule (API) ; leur validité n'est prouvable que par l'exécution des workflows → c'est fait (2 exécutions succès).
3. **CONSTAT PRÉEXISTANT — `npm run lint` (eslint)** : eslint absent du projet, pas de config ; volontairement hors CI (documenté depuis l'annexe 8).
4. Outil local : l'obtention du PAT via `git credential fill` exige de fournir `username=` (sinon GCM ouvre une invite « Select an account ») — incident d'outil, résolu, sans impact projet.

---

## Pourcentage d'avancement (méthode explicite)

**Méthode :** 32 points de contrôle uniques (base inchangée depuis la première édition de ce rapport — les preuves ajoutées cette session : drill distant §3.21, démonstration anciennes sauvegardes §3.22, comptes §3.23, §6 « distant » — sont les compléments qui résolvent respectivement le point BLOQUÉ, l'action propriétaire §11.2 et affinent §11.3 ; elles ne créent pas de nouveau point).

- **VÉRIFIÉ ou CORRIGÉ ET RETESTÉ : 30/32** (28 initiaux + restauration distant isolé + démonstration anciennes sauvegardes)
- **NON APPLICABLE (démontré, compté comme vérifié) : inclus dans les 30** (Render)
- **ACTION PROPRIÉTAIRE RESTANTE : 2/32** (dashboard Render ; test optionnel du mdp de `d.ach@pharma.ma` — impossible sans test d'authentification contre la prod, interdit pour moi)
- **BLOQUÉ : 0/32**

**Score : 30/32 = 93,75 %** du périmètre de la mission. Les 6,25 % restants exigent exclusivement un accès que je ne détiens pas (dashboard Render) ou une action explicitement réservée au propriétaire — **aucun travail technique réalisable avec les accès actuels n'est resté inachevé, et aucun bloquage ne subsiste**.

*Aucun secret dans ce rapport. Aucune donnée supprimée. Aucun service cloud modifié. Aucun force-push.*
