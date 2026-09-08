# database/

Schémas et seeds de la base PostgreSQL (Supabase).

- `schema/` : migrations SQL appliquées par `npm run db:migrate` (depuis `backend/`),
  triées puis exécutées dans l'ordre alphabétique, chacune dans une transaction.
  Toute nouvelle migration doit être **idempotente** (`IF NOT EXISTS`, etc.).
- `seeds/` : fichiers SQL de données initiales appliqués par `npm run db:seed`.

> Note : le schéma initial (tables users, pharmacies, roles, …) a été créé
> directement dans la base Supabase gérée ; seules les migrations incrémentales
> sont versionnées ici.

## Migrations

- `900_add_users_username.sql` — colonne username (users)
- `910_add_purchase_receptions.sql` — réceptions de commandes
- `920_add_supplier_type_ice.sql` — fournisseurs : colonnes `type`
  (laboratoire / grossiste / distributeur / fournisseur) et `ice`
  (identifiant fiscal marocain). Migration 100 % additive.

## Base initiale Maroc

- **Médicaments** : `backend/src/modules/reference/reference_data.json`
  (instantané « maroc-officiel-snapshot-v1 » : 45 produits réels — DCI,
  dosage, forme, laboratoire, catégorie ; codes AMM/barcodes/prix
  renseignés uniquement lorsqu'ils sont vérifiables, sinon null, à
  valider contre le répertoire officiel DMP). Import via le module
  Référence (synchronisation idempotente), puis import contrôlé vers le
  catalogue de la pharmacie.
- **Fournisseurs / laboratoires** : `backend/scripts/import-morocco-suppliers.js`
  — insère sans doublon ni écrasement (vérification par nom) les
  laboratoires et distributeurs présents au Maroc pour chaque pharmacie.
  Usage : `node scripts/import-morocco-suppliers.js` (ou `--pharmacy=<uuid>`).

