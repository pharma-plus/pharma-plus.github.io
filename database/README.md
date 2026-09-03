# database/

Schémas et seeds de la base PostgreSQL (Supabase).

- `schema/` : migrations SQL appliquées par `npm run db:migrate` (depuis `backend/`),
  triées puis exécutées dans l'ordre alphabétique, chacune dans une transaction.
  Toute nouvelle migration doit être **idempotente** (`IF NOT EXISTS`, etc.).
- `seeds/` : fichiers SQL de données initiales appliqués par `npm run db:seed`.

> Note : le schéma initial (tables users, pharmacies, roles, …) a été créé
> directement dans la base Supabase gérée ; seules les migrations incrémentales
> sont versionnées ici.
