# Modèle de Données — PHARMA MAROC GOLD ENTERPRISE V2.0

## Conventions

- **Clés primaires** : `uuid` via `gen_random_uuid()` (sauf `audit_logs` séquentielle pour la performance append-only).
- **Multi-tenant** : toute table métier porte `pharmacy_id uuid NOT NULL` + **RLS** (`fn_apply_tenant_rls`) filtrée sur `current_setting('app.pharmacy_id')`.
- **Succursales** : tables de stock référencent `branch_id` ; les documents de vente/achat aussi (rapports par succursale).
- **Monnaie** : `numeric(14,2)` (MAD par défaut, configurable par pharmacie).
- **Synchronisation** : colonnes `revision bigint` sur les tables synchronisables + `updated_at timestamptz`.
- **Audit** : table `audit_logs` append-only (aucune API de DELETE/UPDATE).

## Fichiers de migration (ordre d'application)

| Fichier | Contenu |
|---|---|
| `001_extensions.sql` | Extensions (pgcrypto, pg_trgm, unaccent, citext), triggers génériques (`updated_at`, recherche, révision), `sequence_counters` + `fn_next_number`, helper RLS |
| `002_core.sql` | `pharmacies`, `branches`, `licenses`, `app_settings`, `roles`, `permissions`, `role_permissions`, `users`, `user_sessions`, `audit_logs`, `notifications` |
| `003_catalog.sql` | `categories`, `therapeutic_families`, `laboratories`, `medications` (+ colonne `search` tsvector), `medication_equivalents`, `medication_suppliers` |
| `004_stock.sql` | `lots`, `stock_balances`, `stock_movements`, `inventory_sessions`, `inventory_items`, `stock_transfers` |
| `005_partners.sql` | `suppliers`, `supplier_payments`, `customers` (+ FKs différées sur catalogue/lots) |
| `006_purchases.sql` | `purchase_orders`, `purchase_order_items`, `purchase_receptions`, `purchase_reception_items`, `purchase_returns`, `purchase_return_items` |
| `007_sales.sql` | `sales`, `sale_items`, `payments`, `invoices`, `invoice_items`, `sale_returns`, `sale_return_items`, `receipts`, `reservations` |
| `008_prescriptions.sql` | `prescriptions`, `prescription_items` |
| `009_hr.sql` | `employees`, `employee_documents`, `attendance`, `leaves`, `schedules`, `bonuses`, `evaluations` |
| `010_accounting.sql` | `accounts`, `journal_entries`, `journal_lines`, `cash_registers`, `cash_register_movements`, `expense_categories`, `expenses`, `closing_periods` |
| `011_ops.sql` | `backups`, `sync_operations`, `update_releases`, `support_tickets`, `support_messages`, `announcements`, `website_settings`, `blog_categories`, `blog_posts` |
| `012_triggers_views.sql` | Moteur de stock par trigger, `mv_daily_sales`, `mv_stock_levels`, index couvrants |

## Moteur de stock (intégrité applicative au niveau base)

`stock_balances` est **dérivée** : chaque mutation passe par une ligne dans `stock_movements`, et le trigger `trg_stock_movement_apply` met à jour la balance :

- **Entrant** : `purchase_receipt`, `sale_return`, `inventory_in`, `transfer_in`, `release` → `+quantity`
- **Réservation** : `reservation` → `+reserved_quantity` (bloque la quantité sans la décrémenter)
- **Sortant** : `sale`, `inventory_out`, `transfer_out`, `write_off`, `expiry_loss` → `-quantity` avec **refus si le solde devient négatif**

Conséquence : aucune requête applicative ne peut créer de stock fantôme ou négatif. Les transferts inter-succursales génèrent deux mouvements (`transfer_out` source + `transfer_in` cible) dans la même transaction.

## Vues matérialisées

| Vue | Contenu | Rafraîchissement |
|---|---|---|
| `mv_daily_sales` | CA, ventes, TVA, bénéfice par pharmacie/succursale/jour | `CONCURRENTLY` sur chaque mutation `sales` |
| `mv_stock_levels` | Solde, réservé, disponible, péremption par succursale/lot | manuel / planifié |

## Numérotation

`fn_next_number(pharmacy, prefix)` génère atomiquement des numéros type `FAC-2026-000123` par pharmacie et par an (table `sequence_counters`). Utilisée pour ventes, factures, bons de commande, réceptions, retours, transferts.

## Recherche plein texte

- `medications.search` (tsvector `simple`) mis à jour par trigger sur nom/DCI/générique/dosage/présentation/code-barres.
- Index `gin (name gin_trgm_ops)` pour la recherche floue ; `unaccent` pour tolérer les accents (FR).
