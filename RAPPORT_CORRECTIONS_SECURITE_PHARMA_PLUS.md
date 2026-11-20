# RAPPORT_CORRECTIONS_SECURITE_PHARMA_PLUS.md

**Projet :** PHARMA+ (`pharma-maroc-gold`)  
**Branche :** `phase5-validation` (HEAD local, aucun commit/push/merge effectué)  
**Date :** 20 novembre 2026  
**Auteur :** Agent d'ingénierie sécurité  
**Statut :** Corrections locales appliquées + tests exécutés. **Aucun déploiement, aucun commit, aucun push.**

---

## 1. EXECUTIVE SUMMARY

L'audit de sécurité a porté sur l'isolation multi-tenant (RLS), les routes service_role de l'Edge Function `pharma-api`, le super admin global unique, et le fonctionnement offline-first.

**Constat principal :** l'isolation multi-tenant est appliquée de manière cohérente côté applicatif dans l'Edge Function : chaque requête de table utilise `eq("pharmacy_id", pid)` où `pid` est dérivé du JWT vérifié + profil `public.users` résolu côté serveur. Le client `service_role` contourne la RLS PostgreSQL, donc l'isolation effective repose sur ce filtrage applicatif (la variable `app.pharmacy_id` n'est jamais définie par l'Edge Function, voir §2).

**Corrections apportées (code local uniquement) :**
1. `frontend/lib/core/services/sync_engine.dart` — `markSaleSynced()` est maintenant appelé après qu'une vente hors-ligne soit flushée avec succès (nettoyage de l'entrée orphele dans `pmg_pending_sales`).
2. `frontend/lib/core/services/offline_store.dart` — ajout de `prunePendingSales()` pour nettoyer différément les entrées `synced=1` anciennes (évite la croissance indéfinie de `pmg_pending_sales`).
3. `frontend/test/sync_engine_offline_test.dart` (nouveau) — tests prouvant que `markSaleSynced()` est appelé après un flush réussi et qu'aucun doublon n'est créé en cas d'échec.
4. `frontend/test/offline_store_test.dart` — 3 nouveaux tests sur `markSaleSynced` et `prunePendingSales`.

**Résultat des tests :** `flutter test --no-pub` → **325 tests passés, 9 skip, 0 échec**.

---

## 2. FICHIERS RÉELLEMENT MODIFIÉS

| Fichier | Action | Objet |
|---------|--------|-------|
| `frontend/lib/core/services/sync_engine.dart` | Modification | Appel de `markSaleSynced()` après flush de vente réussi + appel de `prunePendingSales()` en fin de sync |
| `frontend/lib/core/services/offline_store.dart` | Modification | Ajout de la méthode `prunePendingSales(maxAgeDays)` |
| `frontend/test/sync_engine_offline_test.dart` | Création | Tests d'intégration offline-first (flush réussi → synced ; flush échoué → pas de doublon) |
| `frontend/test/offline_store_test.dart` | Modification | 3 tests supplémentaires (`markSaleSynced`, `prunePendingSales` ancien/récent/non synced) |

**Fichiers NON modifiés (conformément aux consignes) :** aucune migration SQL, aucune route Supabase distante, aucun contrat API backend, aucun fichier POS/caisse/verrouillage global, aucun secret.

---

## 3. CORRECTIONS ESSENTIELLES — AVANT / APRÈS

### 3.1 Offline-first : `markSaleSynced()` jamais appelé en production

**Avant :** Lorsqu'une vente échouait avec `NETWORK_ERROR`, elle était écrite à la fois dans `pmg_pending_sales` (via `savePendingSale`) et dans `pmg_outbox` (via `enqueue`). Après synchronisation réussie via `SyncEngine`, seule l'entrée outbox était supprimée. L'entrée `pmg_pending_sales` restait avec `synced = 0` à vie — `markSaleSynced()` existait (`offline_store.dart:153`) mais n'était **jamais appelée** en production.

**Après :** Dans `sync_engine.dart`, après qu'une vente (`POST /sales` avec `clientSaleId`) soit flushée avec succès, `markSaleSynced('sale-<clientSaleId>')` est appelé. L'entrée `pmg_pending_sales` passe à `synced = 1` et est ensuite éligible au nettoyage par `prunePendingSales()`.

**Code ajouté (`sync_engine.dart`) :**
```dart
if (method == 'POST' && path == '/sales' &&
    body != null && body.containsKey('clientSaleId')) {
  await _store.markSaleSynced('sale-${body['clientSaleId']}');
}
```

### 3.2 Offline-first : nettoyage différé des entrées synchronisées

**Avant :** Aucun mécanisme ne purgeait les entrées `pmg_pending_sales` marquées `synced = 1`. La map croissait indéfiniment.

**Après :** Nouvelle méthode `prunePendingSales(maxAgeDays = 30)` dans `offline_store.dart`, appelée en fin de `SyncEngine.sync()`. Elle supprime les entrées `synced = 1` dont `created_at` est antérieur à `now - 30 jours`. Les entrées `synced = 0` (ventes encore en attente) sont conservées quelle que soit leur ancienneté.

---

## 4. TESTS EXÉCUITÉS ET RÉSULTATS RÉELS

### 4.1 Suite complète Flutter

```
flutter test --no-pub
→ 03:13 +325 ~9: All tests passed!
```

- **325 tests passés** (dont les 19 tests des fichiers modifiés/nouveaux)
- **9 tests skip** (préexistants, capturations visuelles conditionnelles)
- **0 échec**

### 4.2 Nouveaux tests de sécurité / offline-first

| Test | Fichier | Résultat | Ce qui est prouvé |
|------|---------|----------|-------------------|
| `markSaleSynced retire la vente des ventes en attente` | `offline_store_test.dart` | ✅ | Une vente marquée synced n'apparaît plus dans `pendingSales()` |
| `prunePendingSales supprime les entrées synced=1 anciennes` | `offline_store_test.dart` | ✅ | Entrées > 30j supprimées ; récentes conservées |
| `prunePendingSales ne supprime pas les entrées non synchronisées` | `offline_store_test.dart` | ✅ | `synced=0` conservé quel que soit l'âge |
| `SyncEngine appelle markSaleSynced après un flush de vente réussi` | `sync_engine_offline_test.dart` | ✅ | Bout de chaîne : vente flushée → `pmg_pending_sales` nettoyé |
| `SyncEngine ne marque pas comme synced si le flush échoue` | `sync_engine_offline_test.dart` | ✅ | Vente en échec reste en attente, aucun doublon créé |

### 4.3 Analyse Dart

```
dart analyze lib/core/services/sync_engine.dart lib/core/services/offline_store.dart test/offline_store_test.dart test/sync_engine_offline_test.dart
→ 4 issues found (toutes de type "info" : prefer_const_constructors / prefer_const_declarations, pas d'erreur ni de warning)
```

Le `dart analyze` complet du projet (`lib test`) a été exécuté précédemment (contexte) : **0 erreur, 69 warnings, 373 infos** — aucun nouveau problème introduit par ces modifications.

---

## 5. AUDIT D'ISOLATION MULTI-TENANT — RÉSULTATS

L'audit du code de l'Edge Function (`supabase/functions/pharma-api/index.ts`) confirme :

### 5.1 Comment `pid` (pharmacy_id) est déterminé

| Étape | Fichier:Ligne | Mécanisme |
|-------|--------------|-----------|
| JWT vérifié (ES256/JWKS) | `index.ts:68-115` | `verifyJWT()` valide la signature et l'expiration |
| Profil résolu depuis le JWT | `index.ts:140-166` | `computeVerified()` lit `public.users` par `id` (sub) puis par `email` |
| `pharmacy_id` de confiance | `index.ts:357-363` | `pharmacyId(req)` retourne `v.user.pharmacy_id` ; le header `x-pharmacy-id` client est **ignoré** pour les routes protégées |
| Client données | `index.ts:1524` | `createClient(url, serviceKey)` — contourne la RLS (service_role) |
| Filtrage tenant | `index.ts:5653, 5724, ...` | `.eq("pharmacy_id", pid)` sur **chaque** requête de table |

### 5.2 Routes service_role — inventaire des contrôles

Toutes les routes de données sont protégées par :
1. **JWT obligatoire** (sauf routes publiques `login/refresh/health`) — `index.ts:1506-1518`
2. **Session active** (`user_sessions`) — `index.ts:1540-1554`
3. **Verrouillage session (PIN)** — `index.ts:1558-1570`
4. **RBAC `module:action`** — `index.ts:1573-1579` via `enforcePathPermission()`

**Routes non couvertes par `module:action`** (seulement session active) : `dashboard/overview`, `ai/*`, `reports/*`, `sync/*`, `pharmacies/global-stats`. Ces routes ne sont pas appelées par le frontend (sauf `ai/insights` via RPC avec `p_pharmacy: pid` filtré). Elles ne présentent pas de fuite inter-tenant car elles filtrent par `pid` dérivé du JWT.

### 5.3 Preuve d'absence de fuite inter-tenant

Aucune requête de table métier n'a été trouvée sans filtre `.eq("pharmacy_id", pid)` hors des routes réservées au super admin (`__diag`, `superadmin/*`). Une pharmacie A ne peut pas lire ou modifier les données d'une pharmacie B via l'Edge Function.

---

## 6. SUPER ADMIN GLOBAL UNIQUE — VÉRIFICATION

| Élément | Statut | Preuve |
|---------|--------|--------|
| Index unique partiel `uniq_users_single_superadmin` | ✅ Présent | `supabase/migrations/20261016160000_superadmin_uniqueness.sql:22-23` |
| Trigger `guard_superadmin_flag` | ✅ Présent | Même fichier :25-35, 37-40 |
| Élévation réservée à `set_config('app.superadmin_grant','owner',true)` | ✅ | `backend/scripts/superadmin_reconcile.mjs:198` |
| Un seul super admin global | ✅ Imposé par l'index partiel | Aucune création de 2ème super admin possible |
| Frontend ne fait pas confiance aux valeurs locales | ✅ | `auth_store.dart:294-295` (`withoutAdminConfirmation`) |

Aucun utilisateur ordinaire (Manager, pharmacien, caissier) ne peut s'auto-attribuer le rôle super admin.

---

## 7. TESTS NON EXÉCUTÉS ET RAISONS

| Test | Raison |
|------|--------|
| Validation contre Supabase staging réel (`fsonhwzqkxbpltbwkgvz`) | Aucun accès/comte fourni ; interdiction d'exécuter du SQL distant |
| Build Web release (`flutter build web --release`) | Déjà exécuté précédemment (contexte) : `√ Built build\web` |
| Tests sur smartphone physique | Aucun appareil connecté |
| CI GitHub Ubuntu | Pas de push autorisé (consigne) |
| `git diff --check` | Déjà exécuté précédemment : propre hors avertissements LF |

---

## 8. PROBLÈMES RESTANTS ET RISQUES RÉSIDUELS

### 8.1 RLS PostgreSQL non effective (risque résiduel connu)

La variable `app.pharmacy_id` est référencée dans les politiques RLS (`fn_apply_tenant_rls`, `database/schema/001_extensions.sql:54-63`) mais **jamais définie** par l'Edge Function via `SET LOCAL` ou `set_config`. L'isolation effective repose donc exclusivement sur le filtrage applicatif TypeScript (`eq("pharmacy_id", pid)`), le client `service_role` contournant la RLS.

**Risque :** si un attaquant accédait directement à PostgREST avec la clé `service_role`, la RLS ne protégerait pas les données.

**Recommandation :** faire définir `app.pharmacy_id` par l'Edge Function avant chaque requête (via une fonction RPC transactionnelle ou `SET LOCAL` dans une requête unique), ou basculer sur un client authentifié (non service_role) avec RLS effective. Ceci nécessite un déploiement autorisé.

### 8.2 Routes non couvertes par RBAC spécifique

`dashboard/overview`, `ai/*`, `reports/*`, `sync/*` n'ont pas de contrôle `module:action` (seulement session active). Elles filtrent par `pid` mais n'exigent pas de permission granulaire.

**Recommandation :** ajouter `enforcePathPermission` sur ces routes lors de la prochaine version de l'Edge Function.

### 8.3 Données réelles Supabase non vérifiées

Aucune validation contre une instance Supabase réelle n'a pu être effectuée (pas d'accès). Les tests locaux prouvent la logique côté client, mais l'isolation serveur n'est pas démontrée en production.

---

## 9. PROCÉDURE DE VALIDATION STAGING À VENIR

Lorsque l'autorisation explicite sera donnée :

1. **Déployer l'Edge Function corrigée** sur le projet staging `fsonhwzqkxbpltbwkgvz` (pas sur production `lwepnnecnrqdzadesyqo`).
2. **Exécuter les tests Flutter** contre le staging réel (tests d'isolation multi-tenant : pharmacie A lit ses données, ne lit pas B, ne modifie pas B).
3. **Vérifier le super admin** : tentative d'élévation par un utilisateur ordinaire → refus ; attribution via `superadmin_reconcile.mjs` → exactement 1 super admin.
4. **Vérifier l'offline-first** : vente hors-ligne → rejet réseau → rejouée sans doublon → marquée synced après confirmation.
5. **Exécuter `dart analyze` et `flutter build web --release`** sur la branche finale.
6. **`git diff --check`** propre avant merge.
7. **Une fois validé en staging**, demander autorisation pour la production.

---

## 10. CONDITION FINALE

✅ Code lu et audité  
✅ Défauts identifiés (offline-first : `markSaleSynced()` non appelé, pas de nettoyage `pmg_pending_sales`)  
✅ Fichiers modifiés localement (4 fichiers)  
✅ Tests ajoutés et exécutés (325 passés, 0 échec)  
✅ Rapport produit  

⏳ En attente d'autorisation explicite pour : commit, push, merge, déploiement staging/production, exécution de SQL distant.

**Aucun GO en production n'est annoncé : les tests critiques contre un vrai serveur Supabase n'ont pas pu être démontrés (pas d'accès).**
