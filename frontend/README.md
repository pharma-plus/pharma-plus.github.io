# PHARMA MAROC GOLD — Application Flutter

Application mobile & bureau (Android / iOS / Windows / macOS / Linux / Web / PWA)
de gestion de pharmacie. Compilée en français, arabe et anglais, thème clair /
sombre / auto, avec mode hors-ligne et synchronisation.

## Prérequis

- Flutter SDK ≥ 3.27 (stable channel)
- Un backend PHARMA MAROC GOLD accessible (`backend/`)

## Démarrage

```bash
# 1. Générer les dossiers de plateforme (une seule fois)
flutter create . --project-name pharma_maroc_gold \
  --platforms=android,ios,windows,macos,linux,web

# 2. Récupérer les dépendances
flutter pub get

# 3. Lancer sur l'appareil / l'émulateur
flutter run

# Web / PWA
flutter run -d chrome
flutter build web --release
```

> Ne pas écraser `lib/`, `pubspec.yaml`, `analysis_options.yaml`.

## Connexion au backend

Depuis l'écran **Paramètres → Serveur**, renseignez l'adresse de l'API
(ex. `http://192.168.1.10:4000/api/v1`).

Compte de démonstration (après seed) : `admin@demo.ma` / `Demo123!`

## Architecture

```
lib/
  main.dart                 Point d'entrée
  app.dart                  Aiguillage (connexion / shell)
  core/
    l10n/strings.dart       Traductions FR / AR / EN
    models/                 Modèles (User, Medication)
    services/               ApiClient, AuthStore, OfflineStore, SyncEngine
    theme/                  Design system Material 3 + 3D
    utils/format.dart       MAD / dates
    widgets/                GlassCard, GradientButton, StatsTile…
  features/
    auth/                   Connexion + 2FA
    shell/                  Menu latéral sombre + onglets
    dashboard/              Indicateurs + courbe CA
    pos/                    Point de vente (panier, scan, encaissement)
    catalog/                Catalogue médicaments
    stock/                  Niveaux + alertes péremption
    settings/               Profil, langue, thème, serveur, sync
```

## Fonctionnalités clés

- **Hors-ligne** : les ventes sont mises en file (SQLite) et rejouées à la
  reconnexion (`SyncEngine`).
- **Catalogue delta** : synchronisation par révision du serveur.
- **2FA** : connexion en deux étapes (TOTP).
- **Thème** : palette surchargeable depuis l'API (couleurs de la pharmacie).

## Tests

```bash
flutter analyze
flutter test
```
