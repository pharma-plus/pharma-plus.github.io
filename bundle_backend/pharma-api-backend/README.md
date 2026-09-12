# PHARMA MAROC GOLD ENTERPRISE V2.0

Plateforme Enterprise de gestion de pharmacies pour le marché marocain — multi-pharmacies, multi-succursales, multi-plateformes, prête à la commercialisation.

## Plateformes

| Plateforme | Technologie | État |
|---|---|---|
| Android / iOS / iPadOS / Windows / macOS / Linux / Web (PWA) | **Flutter** (Material Design 3) | codebase `frontend/` |
| API REST + Portail Super Admin | **Node.js / Express** (modulaire) | `backend/` |
| Base de données | **PostgreSQL** | `database/` |
| Portail Web d'administration | Flutter Web / PWA | `portal/` |

## Structure du dépôt

```
pharma-maroc-gold/
├── docs/                 # Architecture, API, manuels (FR/AR/EN), déploiement
├── database/             # Schéma SQL (migrations), seeds, sauvegarde/restauration
├── backend/              # API REST Node.js/Express — modules indépendants
│   ├── src/core/         # auth, tenants, users, RBAC, audit
│   ├── src/modules/      # catalog, stock, sales, purchases, accounting, ...
│   └── test/             # Tests unitaires & d'intégration
├── frontend/             # Application Flutter multi-plateformes
│   ├── lib/core/         # navigation, services, états
│   ├── lib/theme/        # Design system premium 3D / Material 3
│   ├── lib/widgets/      # Composants 3D, boutons, cartes
│   └── lib/features/     # Écrans métier (POS, stock, comptabilité, ...)
├── portal/               # Portail Super Administrateur
├── scripts/              # Installation, sauvegarde, restauration, CI/CD
└── tests/                # Jeux de tests fonctionnels / compatibilité
```

## Démarrage rapide (backend)

```bash
cd backend
npm install
cp .env.example .env          # configurer DATABASE_URL, JWT_SECRET
npm run db:migrate            # applique database/schema/*.sql
npm run db:seed               # seeds de démonstration
npm run dev                   # serveur API sur http://localhost:4000
npm test                      # tests unitaires / intégration
```

## Documentation

- [Architecture technique](docs/architecture.md)
- [Modèle de données](docs/database.md)
- [API REST](docs/api.md)
- [Design system & UI/UX](docs/design-system.md)
- [Manuels utilisateur (FR/AR/EN)](docs/manuals/)
- [Déploiement & commercialisation](docs/deployment.md)

## Réglementation & évolutivité

Les fonctionnalités liées aux médicaments, ordonnances, prix et données personnelles sont configurables (voir `docs/architecture.md` § Réglementation) afin de s'adapter aux exigences de chaque pays.
