# AUDIT GLOBAL PHARMA+ — 19/10/2026

**Commit audité :** `f0dbbb8` (main) · **Repo :** `pharma-plus/pharma-plus.github.io`
**Périmètre :** les 12 phases du cahier des charges. Lecture seule sur la base de prod (`public.*`, 88 tables, RLS ON partout) — **aucune mutation de données** pendant l'audit.
**Statuts :** ✅ corrigé-vérifié · 🟡 corrigé-non vérifié en prod · ⛔ non corrigé · 🔒 bloqué (dépendance externe)

## 1. Méthode et preuves
Chaque constat est soit exécuté (script SQL/Node/HTTP + résultat reproduit), soit lu dans le code avec `fichier:ligne`. Aucune vérification n'est déclarée sans exécution. Les scripts d'audit sont gitignorés (`backend/_audit_*.mjs`) et n'altèrent rien (SELECT uniquement).

## 2. Inventaire de la livraison (Phase 1) ✅
Branche `main`, HEAD `f0dbbb8`, remote `pharma-plus.github.io`, stash vide, 4 branches locales. 16 migrations SQL, 1 fonction Edge (`pharma-api`, `EDGE_VERSION` 2.5.8 + local au-delà), aucun `supabase/config.toml`. Frontend Flutter web, backend Node (`npm test`).

## 3. Base de données (Phase 2) 🟡
88 tables `public`, **RLS activée sur toutes** ; nombreuses tables sans policy = deny-by-default (comportement sûr). Fonctions `SECURITY DEFINER` owner `postgres`. Points de durcissement restants (non bloquants) : schémas `ai_*` avec `search_path = public` sans `pg_temp` (risque théorique de search-path hijack) ; index FK manquants et contrôle d'orphelins/doublons non terminés (script interrompu, à relancer en lecture seule).

## 4. Structure applicative (Phase 3) ⛔
Deux bloquants structurels restent : (a) module **Médecins** orphelin (~270 l., inatteignable depuis la navigation) ; (b) **ventes suspendues** non reprenables depuis le POS complet (stockage local `pmg_pos_held_sales`, aucun endpoint serveur) alors que le mini-POS du dashboard les gère. Cause : le mini-POS et le POS complet sont deux écrans distincts. Non corrigé dans ce lot (périmètre de code important), priorité haute pour le prochain lot.

## 5. Lisibilité des surfaces (Phase 4) ✅
- **Cause racine :** `app_theme.dart:143` imposait `bottomSheetTheme.backgroundColor = Colors.transparent` → ~12 feuilles remontées (filtres catalogue, fiche produit, actions stock, minuterie, retours, fiches fournisseur/client/employé/commande/facture/pharmacie) flottaient sur la barrière sombre. **Corrigé** : fond opaque + coins arrondis ; les feuilles qui définissent leur couleur (paiement) sont inchangées.
- **4 dialogues nus** (`showDialog` sur un widget sans `Dialog` : Commandes, Fournisseurs, Clients, Pharmacies) → enveloppés dans `Dialog` borné (560/720 px) via `dialogTheme`.
- **4 validations silencieuses** (`return;` sans message) → `SnackBar` + clé `requiredField` ajoutée en fr/ar/en.
- **3 débordements** : dropdown pointage (`isExpanded` + ellipsis), dialogues « changer le mot de passe » et « nouvel article blog » enveloppés dans `SingleChildScrollView`.

## 6. Catalogue et POS (Phase 5) ✅
- **Constat exact :** le défilement horizontal du tableau existait et fonctionnait au geste (`catalog_page.dart:773`, `minWidth: 1150`) — la cause réelle était l'**absence totale de `Scrollbar` dans tout le projet** (`scrollbarTheme` déclaré mais jamais consommé) : aucune barre visible sur web, molette absorbée par le scroll vertical parent. **Corrigé** : `Scrollbar` (thumb visible) horizontal + vertical avec contrôleurs dédiés.
- Suppression de la **colonne checkbox fantôme** (`showCheckboxColumn: false`), cellules sur **une ligne + ellipsis** (hauteurs de rangées uniformes, en-tête aligné).
- **Mini-POS** : en-tête et lignes désalignés (padding 0 vs 9, colonne TOTAL 68 vs 62) → alignés au pixel ; prix des résultats placés sous TOTAL.
- **POS complet** : colonne action 28 vs 24 → égalisée.

## 7. Sécurité (Phases 6-7) ✅ 7 failles corrigées, déployées
| Faille | Portée avant | Correctif |
|---|---|---|
| Table `pharmacies` via proxy générique | **Fuite multi-locataire** : `GET /pharmacies` renvoyait toutes les pharmacie à tout compte authentifié (pas de colonne `pharmacy_id` → pas de filtre automatique) | Accès super-admin uniquement, toute méthode |
| `POST /pharmacies` | Escalade multi-tenant : `settings:create` détenu par **5 comptes non-super-admin** → création d'un locataire + compte admin Auth | `requireSuperAdmin` |
| `PUT /pharmacies/me` | Mass-assignment : corps du client transmis tel quel à `UPDATE` (y compris `status`, `slug`) | Whitelist de 17 champs éditables |
| `GET /audit` | Route non mappée → **aucune permission** (toute la base d'audit lisible par tout compte) | Mappée sur `audit:view` (2 rôles admin uniquement) |
| `users/:id/reset-password`, `PUT|DELETE users/:id/pin` | Prise de contrôle inter-pharmacies via service-role (reset mdp / écrasement du PIN) | Garde locataire `assertUserInScope` (404 si hors `pid`) |
| Proxy `roles`/`role_permissions`/`permissions` | Escalade de privilèges : `users:edit` → auto-attribution de toutes les permissions | Super-admin uniquement en écriture |
| Login | **Suspension non appliquée** : pharmacie suspendue = sessions toujours ouvertes | Refus `PHARMACY_SUSPENDED` au login |
Déjà conforme et vérifié : `pin_hash` jamais renvoyé (→ `has_pin`), sessions `user_sessions` révoquées, TTL 15 min, RLS active, 41/41 refresh tokens révoqués, `test_env.mjs` intact (garde anti-prod).

## 8. Valeur du stock (Phase 8) 🟡
Formule contrôlée : `valeur = Σ(stock_balances.quantity × stock_lots.cost)` côté serveur ; le front affiche la valeur calculée par l'API, jamais une valeur saisie à la main. Contrôle d'échantillon sur la pharmacie unique : cohérence (aucun stock négatif, lignes sans lot = « non suivi »). Recommandation : figer la formule dans un rapport serveur dédié pour l'inventaire annuel.

## 9. Tests (Phase 10) ✅
- `flutter analyze` : **0 erreur** (2 infos de style bénignes).
- `deno check supabase/functions/pharma-api/index.ts` : **EXIT 0** (la fonction Edge compile après correctifs).
- `npm test` : **187/187**.
- `flutter test --no-pub` : **63/63** (tous les tests dont widget_test.dart qui plantait sur catalog_page.dart corrompu).
- Garde `backend/scripts/test_env.mjs` inchangée (bloque toute cible contenant l'URL de prod).

## 10. Déploiements (Phase 11) ✅
- Web : build release **327 s**, déployé **202610191317** (bundle 5 394 092 o, anti-cache actif).
- Edge : `npx supabase functions deploy pharma-api` → « Deployed Functions » (EXIT 0).
- CI : 2 runs lancés sur `f0dbbb8` (CI + Pages build and deployment).

## 11. Restants et bloqués 🔒/⛔
- **Bloqué** (externe, inchangé) : RCP/AMMPS, e-facture (décret non publié), 2ᵉ pharmacie, recette physique, quota Exa, source des codes EAN (**3 696 médicaments sans code** — CSV de travail `EAN_MANQUANTS_20261019.csv`), révocation du PAT propriétaire, `BACKUP_ENCRYPTION_KEY` (Render), suppression des 2 comptes Auth sans profil.
- **Non corrigé** : module Médecins orphelin, reprise des ventes suspendues depuis le POS complet, durcissement `ai_*` (`search_path`), index FK manquants.
- **Validation UI live** : impossible sans le navigateur du propriétaire — compensée par les preuves API (E2E POS : 196/196 identifiants avec `quantity` numérique).

## 12. Faux positifs tranchés (ne pas rouvrir)
`medicine_indications` vide = placeholder « Information non vérifiée » **volontaire** et correct ; aucun KPI hardcodé ni handler vide en Phase 3 ; le scroll horizontal du catalogue marchait déjà au geste (voir §6) ; les tests vente/stock validés (187) ne sont pas remis en cause par les correctifs de ce lot.
