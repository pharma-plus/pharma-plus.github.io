# Architecture Technique — PHARMA MAROC GOLD ENTERPRISE V2.0

## 1. Vue d'ensemble

Plateforme SaaS multi-locataires (multi-tenant) destinée aux pharmacies marocaines. Une seule base de code Flutter génère toutes les applications (mobile, tablette, desktop, web/PWA). Un backend Node.js/Express modulaire expose une API REST sécurisée. PostgreSQL stocke les données avec isolation stricte par pharmacie (tenant).

### 1.1 Diagramme

```
┌────────────────────────────────────────────────────────────────────┐
│                          CLIENTS                                  │
│  Flutter (Android/iOS/Windows/macOS/Linux/Web/PWA)                 │
│  Portail Super Admin (Web)      Site Web pharmacie + Espace client │
└───────────────┬────────────────────────────────────────────────────┘
                │ HTTPS (TLS 1.2+) / JWT Bearer
┌───────────────▼────────────────────────────────────────────────────┐
│                      GATEWAY / REVERSE PROXY                        │
│         (TLS, rate-limiting, WAF, gzip, static PWA)                │
└───────────────┬────────────────────────────────────────────────────┘
┌───────────────▼────────────────────────────────────────────────────┐
│                       API REST (Node.js/Express)                    │
│   core:  auth · users · RBAC · tenants · audit · licence            │
│   modules: catalog · stock · sales(POS) · purchases · suppliers ·   │
│            customers · employees · accounting · reports ·            │
│            dashboard · notifications · backups · sync · IA          │
│   middleware: authJWT · requirePerm · tenantGuard · validate ·      │
│               rateLimit · errorHandler · auditLogger                │
└───────┬───────────────────────────────┬────────────────────────────┘
        │ pg (pooled)                    │ (redis/queue optionnel)
┌───────▼───────────────────────┐  ┌─────▼───────────────────────────┐
│  PostgreSQL (multi-tenant)    │  │  File storage (local / S3)       │
│  • schema `pharma` public      │  │  logos, notices, ordonnances,   │
│  • RLS par pharmacy_id         │  │  sauvegardes chiffrées          │
└───────────────────────────────┘  └─────────────────────────────────┘
```

## 2. Choix technologiques

| Couche | Choix | Justification |
|---|---|---|
| Frontend | **Flutter 3 + Material 3** | Une seule codebase → 7 plateformes ; rendu fluide sur milieu de gamme ; animations 60fps ; gestion offline via SQLite (drift/sqflite) + outbox |
| Backend | **Node.js 20 LTS + Express 4** | Léger, rapide, écosystème mature ; architecture modulaire par dossier ; facile à maintenir et à faire évoluer |
| Validation | **Joi / zod** | Validation forte des entrées API (anti-injection) |
| ORM | **node-postgres (pg)** + migrations SQL versionnées | Contrôle total du SQL, perf, utilisation native des types PG (jsonb, tsvector, uuid) |
| Base de données | **PostgreSQL 15+** | JSONB, RLS, rôles, fonctions, tsvector pour la recherche, transactions, FK + CHECK |
| Cache | Redis (optionnel, futur) | Sessions, rate-limit distribué, cache dashboard |
| Stockage fichiers | Local (disque) + S3-compatible (MinIO/Cloudflare R2) | Logos, notices PDF, photos, ordonnances, sauvegardes |
| Notifications | SMTP (email), Firebase Cloud Messaging (push), SMS/WhatsApp via providers (Twilio/Mobile4com/EasySendSMS) — pluggables | Marché marocain (EasySendSMS / WhatsApp Business API) |
| Auth | JWT (access court + refresh), argon2 pour les mots de passe, OTP TOTP 2FA, device fingerprint | Sécurité enterprise |
| Recherche | Postgres tsvector (FR/AR/EN) + trigramme | Rapide, sans service externe |
| Tests | Jest (backend), flutter_test + integration_test (frontend) | Automatisation CI |
| Déploiement | Docker Compose + Nginx (système), PM2 ou K8s (scale), GitHub Actions CI/CD | Dev/prod reproductibles |

## 3. Multitenancy (multi-pharmacies)

- **Modèle de données :** chaque table métier possède la colonne `pharmacy_id` (UUID) et les lignes sont filtrées par RLS PostgreSQL (`policy` sur `current_setting('app.pharmacy_id')`).
- **Contraintes :** tous les accès API passent par le middleware `tenantGuard` qui vérifie que l'utilisateur appartient bien à la pharmacie du token.
- **Succursales :** entité `branches` rattachée à `pharmacies` ; les tables de stock référencent `branch_id` pour permettre le transfert et les rapports par succursale.
- **Isolation :** RLS + clés étrangères + validation applicative = isolation en profondeur.

## 4. Modules (indépendants et évolutifs)

Chaque module est un dossier autonome dans `backend/src/modules/<module>/` :
`routes.js`, `controller.js`, `service.js`, `repository.js`, `schema.js` (validation), `permissions.js`.

| Module | Responsabilité |
|---|---|
| `auth` | Connexion, refresh, 2FA, biométrie (handle-side), verrouillage, sessions, journal de connexion |
| `users` | Utilisateurs, rôles, permissions, profil, changement de mot de passe |
| `pharmacies` / `branches` | Tenants, succursales, paramètres, personnalisation (logo, couleurs, devise, langues) |
| `licenses` | Types (Essai/Standard/Pro/Enterprise), activation, renouvellement, expiration, alertes |
| `catalog` | Médicaments, DCI, catégories, familles, laboratoires, formes, TVA, prix, notices |
| `stock` | Lots, péremptions, entrées/sorties, inventaire, ajustements, alertes, transferts inter-succursales |
| `sales` | POS : panier, remises, paiements (espèces/carte/mobile/mixte/crédit), tickets, factures, retours/avoirs |
| `prescriptions` | Ordonnances scannées/PDF, archivage, association client, historique |
| `purchases` | Commandes fournisseurs, brouillons, validations, réceptions partielles/complètes, retours |
| `suppliers` | Fournisseurs, catalogues, conditions, historiques, performance |
| `customers` | Clients, fidélité, crédit, historiques, notes |
| `employees` | RH : dossier, contrat, salaire, primes, horaires, congés, évaluations, documents |
| `attendance` | Pointage (PIN/QR/biométrie), arrivée/départ/pause, retards, absences, planning |
| `accounting` | Journaux (caisse, banque, ventes, achats), TVA, avoirs, clôtures, caisse |
| `reports` | Rapports avec filtres période/succursale, exports PDF/XLSX/DOCX/CSV |
| `dashboard` | KPIs temps réel, graphiques interactifs, objectifs, alertes |
| `notifications` | Centre de notifications, push/email/SMS/WhatsApp, préférences |
| `backups` | Sauvegardes chiffrées auto/manuelles, restauration, vérification d'intégrité |
| `audit` | Journal d'audit immuable (append-only) |
| `ai` | Assistant IA : prédiction rupture, suggestions réappro, anomalies, rapports auto, Q&A |
| `sync` | Moteur de synchronisation offline (outbox, vecteurs de version, résolution de conflits) |
| `web` | Site public par pharmacie + espace client + SEO (sitemap, OG, Schema.org) |
| `update` | Mises à jour applicatives (publique ciblée), journal, rollback |

## 5. Sécurité

- Mots de passe hachés **argon2id** (coût mémoire élevé).
- **JWT access (15 min) + refresh (30 j, rotation, détection de rejeu)**.
- **2FA TOTP** optionnelle ; biométrie gérée côté client via `local_auth` (l'empreinte n'est jamais transmise).
- **Verrouillage de compte** après 5 échecs (backoff exponentiel) ; déconnexion auto après inactivité configurable.
- **RBAC** : 9 rôles + permissions granaires ; contrôle au niveau route et ligne.
- **Protections Web :** SQLi (requêtes paramétrées + validation), XSS (échappement, CSP), CSRF (tokens SameSite), rate limiting, en-têtes de sécurité (helmet).
- Chiffrement des données sensibles au repos (colonnes `pgcrypto` PGP) et des sauvegardes (AES-256).
- Journal d'audit **append-only** : l'API d'audit ne propose pas de DELETE/UPDATE.

## 6. Synchronisation hors ligne

- Chaque table synchronisable possède `updated_at`, `revision` (bigint monotone) et une table d'outbox des mutations locales.
- Le client Flutter stocke localement (SQLite/drift) et rejoue l'outbox à la reconnexion (reprise auto, retry exponentiel).
- Résolution de conflits : **dernière écriture gagnante (LWW)** paramétrée par module + journalisation des conflits ; les entités critiques (ventes) sont validées côté serveur.
- Synchronisation delta (depuis la dernière révision) pour minimiser la bande passante.

## 7. Performances

- Index couvrants sur : `(pharmacy_id, updated_at)`, recherche `tsvector`+GIN, `(branch_id, product_id)`, `(product_id, expiry_date)`.
- Pagination curseur + fenêtrage ; requêtes agrégées pré-calculées (vues matérialisées pour dashboards).
- Pool pg, requêtes préparées, connexion reuse ; lazy loading des écrans Flutter ; `const` widgets, `RepaintBoundary`.
- Vues matérialisées rafraîchies par triggers/worker : `mv_daily_sales`, `mv_stock_levels`.

## 8. Sauvegardes & restauration

- `pg_dump` custom format + chiffrement AES-256 ; rotation (horaires/journées/mensuelles) ; retention configurable.
- Sauvegarde locale + cloud (S3-compatible) ; vérification d'intégrité post-copie (checksum) ; restauration en 1 clic avec test de cohérence.
- Scripts : `scripts/backup.ps1`, `scripts/restore.ps1`, `scripts/verify-backup.ps1`.

## 9. Réglementation (configurable)

- Gestion des médicaments, ordonnances, prix et données personnelles : **paramètres par pharmacie** (`settings` JSONB) pour se conformer aux règles locales (Maroc : Loi 17-04, prix fixés, vente de médicaments sous ordonnance, etc.).
- PII : minimisation, consentement client, suppression configurable, journal des accès.
- Les informations affichées sur le site public respectent la réglementation (listes de produits "autorisés à afficher").

## 10. Évolutivité (futurs modules)

Architecture modulaire prête pour : fidélité, e-commerce, click & collect, téléconsultation, multi-entrepôts, IA avancée, connecteurs tiers, nouveaux moyens de paiement, nouveaux rapports.

## 11. Qualité

- Code documenté, modules indépendants, conventions ESLint + Prettier.
- Tests : unitaires (Jest), intégration (supertest + base de test), fonctionnels (Playwright pour portail Web), performance (k6), sécurité (OWASP ZAP), compatibilité (BrowserStack/Device Farm).
- CI/CD : lint → test → build → analyse sécurité → déploiement.
