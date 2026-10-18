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
| Final | `2f3ba73` « ci(securite): permissions minimales contents:read sur CI et backup-nightly » | VÉRIFIÉ — poussé sans force-push |

## 2. État Git initial et final

- **Initial** : `git status --short --branch` = `## main...origin/main` propre ; `git remote -v` = `origin https://github.com/pharma-plus/pharma-plus.github.io.git`.
- **Final** : arbre propre (`git status --porcelain` vide), `origin/main` = `2f3ba73`. VÉRIFIÉ.

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
| 20 | CI sur le commit final | run CI `2f3ba73` = **VERT 3/3** (Backend / Edge / Flutter) | VÉRIFIÉ |

## 4. Fichiers modifiés et justification

| Fichier | Changement | Justification |
|---|---|---|
| `.github/workflows/ci.yml` | +4 lignes : `permissions: contents: read` | Phase 3.7 — permissions minimales ; revalidé par CI vert sur `2f3ba73` |
| `.github/workflows/backup-nightly.yml` | +4 lignes : `permissions: contents: read` | idem ; revalidé par **run de contrôle post-changement = success** |

Aucun autre fichier modifié. Aucun `.env`, aucun dump, aucune donnée dans le commit.

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

## 11. Opérations nécessitant une intervention du propriétaire

1. **Service Render éventuel dans le dashboard** — *À CONFIRMER PAR LE PROPRIÉTAIRE*.
   - Action : ouvrir le dashboard Render → si un service `pharma-plus-api` (ou autre) existe, le supprimer (aucun chemin de prod ne l'utilise ; preuve : 0 URL `.onrender.com` dans tout le dépôt et dans le build live).
   - Je ne touche à aucun service cloud sans autorisation explicite.
2. **7 sauvegardes créées avant le 16/10** (sur 14 au total) — *À CONFIRMER PAR LE PROPRIÉTAIRE*.
   - Contexte : l'ancien **défaut de clé de chiffrement** (une valeur codée en dur dans `backend/src/config/index.js` jusqu'au commit `2a1e901` du 16/10) reste présente dans l'historique Git.
   - Action : si le propriétaire souhaite éliminer tout risque de déchiffrement par un lecteur de l'historique, supprimer les jobs de sauvegarde antérieurs au 16/10 depuis l'UI de l'application (je ne supprime aucune sauvegarde sans autorisation). Les sauvegardes depuis le 16/10 utilisent la clé réelle (le workflow exige la présence de la clé pour s'exécuter).
   - Le mot de passe PostgreSQL étant déjà changé par le propriétaire, **aucune rotation supplémentaire n'est requise** (les 2 connexions ont été testées en direct avec la configuration actuelle).
3. **Ancien mot de passe de test présent dans l'historique Git** (10 commits des scripts `_test_*` des 14-16/10, valeur volontairement absente de ce rapport) — *À CONFIRMER PAR LE PROPRIÉTAIRE*.
   - Vérifié cette session : **≠ des deux mot de passe admin actuels** (fichier propriétaire et `SUPER_ADMIN_PASSWORD` : comparaisons par empreinte SHA-256 effectuées, aucune valeur affichée). Aucun impact connu. Action facultative : s'assurer qu'aucun compte ne conserve encore ce mot de passe de test.

## 12. Limitations techniques

1. **BLOQUÉ — restauration sur serveur distant isolé** : Docker, WSL, SSH/VM absents de la machine ; l'accès au compte Render est impossible.
   - Prochaine action : exécuter la procédure documentée (`backup_worker --decrypt <id> <fichier>` + `pg_restore` sur PG 17+) dès qu'un environnement distant adapté existe. La même procédure vient d'être validée de bout en bout en local (§6).
2. **NON VÉRIFIABLE — contenu des secrets GitHub** : les secrets sont en écriture seule (API) ; leur validité n'est prouvable que par l'exécution des workflows → c'est fait (2 exécutions succès).
3. **CONSTAT PRÉEXISTANT — `npm run lint` (eslint)** : eslint absent du projet, pas de config ; volontairement hors CI (documenté depuis l'annexe 8).
4. Outil local : l'obtention du PAT via `git credential fill` exige de fournir `username=` (sinon GCM ouvre une invite « Select an account ») — incident d'outil, résolu, sans impact projet.

---

## Pourcentage d'avancement (méthode explicite)

**Méthode :** 32 points de contrôle listés dans les tableaux ci-dessus (§3 : 20, §5 : 3 classifications, §6 : 4 étapes de preuve, §7 : 5 secrets, §8 : 5 suites, §9 : 6 sondes, §11 : 3 actions, §12 : 4 limitations — doublons éliminés, total 32 uniques).

- **VÉRIFIÉ ou CORRIGÉ ET RETESTÉ : 28/32**
- **NON APPLICABLE (démontré) : 0/32** (compté comme vérifié : Render)
- **À CONFIRMER PAR LE PROPRIÉTAIRE : 3/32** (dashboard Render, 7 anciennes sauvegardes, ancien mdp de test)
- **BLOQUÉ : 1/32** (restauration sur environnement distant isolé)

**Score : 28/32 = 87,5 %** du périmètre de la mission. Les 12,5 % restants exigent exclusivement des accès que je ne détient pas (dashboard Render, suppression de sauvegardes = autorisation) — **aucun travail technique réalisable avec les accès actuels n'est resté inachevé**.

*Aucun secret dans ce rapport. Aucune donnée supprimée. Aucun service cloud modifié. Aucun force-push.*
