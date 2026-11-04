# PHARMA+ LOCAL — Installation et utilisation hors-ligne

## Présentation
`local_backend/` est un serveur autonome (Node.js + SQLite) qui permet d'utiliser PHARMA+
sans connexion Internet, sur un poste PC local, avec persistance réelle des données sur disque.

Il est invoqué par l'application Flutter en mode local :
- `AuthStore._localMode = true` (persisté en SharedPreferences sous `pmg_local_mode`)
- URL backend : `http://127.0.0.1:4001/api/v1`

## Prérequis
- Node.js >= 20 (testé avec v24)
- Aucune dépendance externe lourde : `node:sqlite` est intégré à Node >= 22
- Dépendances npm : `express`, `cors`, `jsonwebtoken`

## Installation (PC local)

### 1. Déplacer le dossier
Copier le dossier `local_backend/` sur le PC cible (ex: `C:\PHARMA+\local_backend`).

### 2. Installer les dépendances
```powershell
cd C:\PHARMA+\local_backend
npm install
```

### 3. Initialiser / démarrer le serveur
```powershell
# Démarre le serveur sur http://127.0.0.1:4001
npm start
```
Au premier démarrage, une base SQLite `pharma-local.sqlite` est créée automatiquement avec :
- une pharmacie démo, une branche, un utilisateur `admin@pharma.local` / `admin123` (super admin),
- un catalogue de médicaments et des stocks initiaux.

La base est persistante : les données survivent au redémarrage du PC.

## Variables d'environnement (optionnel)
| Variable | Valeur par défaut | Rôle |
|---|---|---|
| `PHARMA_LOCAL_DB` | `./pharma-local.sqlite` | Chemin du fichier base SQLite |
| `PHARMA_LOCAL_JWT_SECRET` | `pharma-local-change-me` | Secret de signature des jetons |
| `PORT` | `4001` | Port d'écoute |

## Fonctionnement sans Internet
Une fois le serveur démarré localement, l'application Flutter (mode local activé dans les paramètres) fonctionne entièrement hors-ligne :
- Authentification (login, profil, permissions Super Admin)
- Catalogue et stock des médicaments (lecture)
- Création de ventes avec idempotence (pas de double vente, même en cas de retry)
- Décrément de stock (FEFO), lignes de vente, paiements
- Sessions d'inventaire
- Tous les écrans POS (branches, clients, recherche médicaments, passage en caisse)

## Synchronisation au retour d'Internet
Quand la connexion est rétablie, l'utilisateur bascule en mode distant (`AuthStore.setLocalMode(false)`).
Le `SyncEngine` vide la file hors-ligne (outbox) vers le serveur distant Supabase :
- chaque opération de vente envoyée avec l'en-tête `Idempotency-Key` ;
- les doublons sont détectés côté serveur (contrainte UNIQUE partiel sur `client_sale_id`) ;
- un conflit `409 IDEMPOTENCY_CONFLICT` est conservé en file, pas dupliqué ;
- les opérations Super Admin ne sont pas envoyées hors-ligne (confirmation serveur requise).

## Isolation pharmacies
Toutes les requêtes portent un `pharmacy_id`. Les données d'une pharmacie ne sont jamais visibles par une autre.

## Sauvegarde / restauration
La base est un simple fichier `pharma-local.sqlite` :
- **Sauvegarde** : copier le fichier `pharma-local.sqlite` (et le fichier WAL `-wal` / `-shm` s'ils existent) sur un support externe.
- **Restauration** : remplacer le fichier `pharma-local.sqlite` par la copie sauvegardée, puis redémarrer `npm start`.

## Arrêt du serveur
`Ctrl+C` dans le terminal où `npm start` est lancé.

## Contrats API (préfixe /api/v1)
- `GET /health` — état du serveur
- `POST /auth/login` — `{email, password}` → `{success, data:{accessToken, refreshToken, user, pharmacy, role}}`
- `POST /auth/refresh` — `{refreshToken}` → nouveaux jetons
- `POST /auth/logout` — déconnexion
- `GET /auth/me` — profil utilisateur connecté
- `GET /branches` — liste des branches de la pharmacie
- `GET /customers?limit=200` — liste des clients
- `GET /catalog/medications?limit=60&q=...&form=...` — recherche médicaments
- `GET /catalog/medications/stock?ids=...` — disponibilité stock
- `GET /catalog/medications/facets` — facettes (formes, indications)
- `GET /catalog/medications/barcode/:code` — lookup par code-barres
- `POST /sales` — création vente (idempotente via `clientSaleId` + header `Idempotency-Key`)
- `POST /inventory/sessions` — ouverture session inventaire
- `POST /inventory/sessions/:id/close` — clôture session

## Tests locaux recommandés
1. Démarrer le serveur sans réseau, créer une vente, l'arrêter, le redémarrer : la vente doit encore être présente (persistance).
2. Envoyer deux fois la même vente avec le même `clientSaleId` : seule la première est créée, la seconde retourne l'existante.
3. Envoyer la même `clientSaleId` avec un contenu différent : réponse `409 IDEMPOTENCY_CONFLICT`.
4. Vérifier qu'une vente créée par la pharmacie A n'est pas visible par la pharmacie B.
