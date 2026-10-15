# PHARMA+ — RAPPORT D'AUDIT GLOBAL (prompt intégral)

**Date :** 15 octobre 2026 · **Commit audité :** `000ce85` (main = remote) · **Backup :** tag `backup-audit-global-20261015` (`72b6b3d`)
**Déploiement vérifié :** `https://pharma-plus.github.io/` → index servi avec `flutter_bootstrap.js?v=202610151401`, `main.202610151401.dart.js` HTTP 200 (5 361 650 octets, identique local)
**Edge :** `pharma-api` @ lwepnnecnrqdzadesyqo (déployé, `deno check` EXIT 0)

---

## A. ÉTAT GÉNÉRAL

| Domaine | État |
|---|---|
| Branche / remote | `main` local = `origin/main` = `000ce85` |
| Build web | `flutter build web --release` OK (525 s) |
| CDN | 200 vérifié (stamp + bundle) |
| Edge | `deno check` 0 erreur, fonction déployée + testée en réel |
| Restauration | `git checkout backup-audit-global-20261015` ou commit précédent |

## B. TABLEAU DES FONCTIONNALITÉS

| Fonctionnalité | Statut | Gravité | Preuve | Fichier | Test | Action |
|---|---|---|---|---|---|---|
| Caisse / POST /sales | **VALIDÉ** | — | cycle complet réel | `index.ts:4941-5316` | `_test_pos_cycle.mjs` + DB | — |
| Paiement (cash) : lignes `payments` créées | **VALIDÉ** | — | `payments` cash 35.00 status=completed | `index.ts:5295-5316` | `_audit_sale98.mjs` | — |
| Décrément stock à la vente | **VALIDÉ** | — | 46→45 et 296→295 | trigger + `index.ts:5230-5260` | `_test_stock_decrement.mjs`, `_test_global_stock.mjs` | — |
| Idempotence vente hors-ligne | **VALIDÉ** | — | `clientSaleId` dédupliqué | `index.ts:5128-5151` | code + audit | — |
| Numérotation POS atomique | **VALIDÉ** | — | `fn_next_number` échec = refus explicite | `index.ts:5106-5126` | `_test_switch_user.mjs` | — |
| TVA : source = fiche produit (client non spoofable) | **VALIDÉ** | — | tva_rate lu sur `medications` | `index.ts:4989-5019` | `_test_pos_cycle.mjs` | — |
| TVA 0 % médicaments | **VALIDÉ** | faible | 5 lignes sale_items à 0.00 post-fix 13/10 | Edge fix `defaultTvaFor` | `_audit_sales.mjs` | voir §C migration |
| Session caisse auto-rattachée | **VALIDÉ** | — | `cash_session_id` | `index.ts:5153-5163` | code | — |
| 17.C caisse partagée | **VALIDÉ** | — | 15/15 | — | `_test_switch_user.mjs` | — |
| 17.F switch utilisateur | **VALIDÉ** | — | 9/9 + audit `user_switched` wrappé | `index.ts:2376-2382` | `_test_switch_user.mjs` (42/42) | — |
| PIN (2FA caissier) | **VALIDÉ** | — | PINs 4 chiffres sur comptes de test | `auth_store`/Edge | `_test_switch_user.mjs` | — |
| Filtrage modules par utilisateur | **VALIDÉ** | — | `visible_modules` + nav filtrée + checkboxes admin | migration + `home_shell.dart` | 40/40 flutter | — |
| RLS | **VALIDÉ** | — | RLS ON sur 17 tables, deny-by-default (audit/roles sans policy = service_role Edge uniquement) | DB | `_audit_db.mjs` | — |
| Suppression utilisateur = soft-delete | **VALIDÉ** | — | `status: inactive` | `index.ts` users DELETE | `_test_switch_user.mjs` | — |
| Rapports (5 endpoints) | **VALIDÉ** | — | 200 + données réelles | Edge reports | `_test_reports_api.mjs` | — |
| Dashboard | **VALIDÉ** | — | KPI réels depuis API | `dashboard_page.dart` | `_test_dashboard.mjs` | — |
| Soldes stock négatifs | **VALIDÉ** | — | 0 négatif | `stock_balances` | `_audit_db.mjs` | — |
| Audit stock/caisse | **VALIDÉ** | — | écritures réelles après validation pharmaciens | `audit_page.dart` | `_test_global_stock.mjs` | — |
| Corrections session (P1–P3) | **VALIDÉ** | — | commit `000ce85` | 9 fichiers | suites complètes | — |
| Paiement carte (TPE) | **LIMITÉ** | **P0 assumé** | bouton « Simuler » explicite, aucun TPE branché | `payment_sheet.dart:499-519` | — | intégration TPE future |
| Sauvegardes (pg_dump) | **INCOMPLET** | **P1** | worker déclaré inexistant | `settings_page.dart:1534-1569` | — | worker backups à créer |
| Export CSV/Word hors Web | **HONNÊTE** | P2 | message explicite non-web (fix `000ce85`) | `reports_page.dart` | — | export natif futur |
| OCR ordonnance | **WEB UNIQUE** | P2 | stub + message device | `ocr_service_stub.dart` | — | moteur OCR futur |
| Login Google | **NON IMPLÉMENTÉ** | P2 | « prochainement » assumé | `login_page.dart:667` | — | OAuth futur |
| Caméras (aperçu flux) | **PARTIEL** | P2 | statut seulement, pas de flux | `cameras_page.dart` | — | lecteur vidéo futur |

## C. RÉSULTATS DÉTAILLÉS PAR DOMAINE

1. **Interfaces** : audit 96 fichiers Dart — 0 TODO/FIXME, 0 `onPressed: null`, 0 donnée fictive dans les listes/KPI/POS. Corrections livrées : URL serveur réellement appliquée, bouton mot de passe oublié honnête, exports non-web honnêtes, **227 séquences de double-encodage (mojibake) réparées** dans `audit_page`, `purchases_page`, `pharmacy_plan_page`, `home_shell`.
2. **Calculs** : total = Σ net + TVA − remise plafonnée (`index.ts:5051-5099`); TVA 0 valide (fix 13/10) ; contrôle Edge vs DB `TVA_DIVERGENCE` en logs si écart (migration fix en attente d'autorisation).
3. **Caisse** : ventes sans paiement détectées = **ventes de test API uniquement** (scripts sans tableau `payments`) ; le POS Flutter envoie bien `payments` (`pos_page.dart:711`).
4. **Stock** : FIFO périmancy → `lots`, `quantity > 0`, mouvements compensés si échec.
5. **Sécurité** : `_logAction` sur 8 points (7 routes wrappées expose=AUDIT_FAILED + délégation `auditAttendance`) ; CORS PATCH ; écritures génériques PATCH ; uuid writes inconnus → 404 ; identité serveur (`currentUserId` JWT) jamais client.
6. **DB** : `sale_items.tax_rate` DEFAULT 20.00 et trigger historique 20 % **documentés** (Edge override = sûr) ; RLS ON 17/17 tables cibles ; 0 stock négatif ; 0 vente sans lignes ; 4 ventes sans `payments` = fixtures de test.

## D. DÉFAUTS RESTANTS

| # | Défaut | Gravité | Fichier |
|---|---|---|---|
| 1 | Paiement carte **simulé** (aucun TPE réel) — libellé honnête « Simuler » | P0 métier assumé | `payment_sheet.dart:499` |
| 2 | Export sauvegardes : worker pg_dump **absent du dépôt** | P1 | `settings_page.dart:1534` |
| 3 | Migration « fix TVA 20 % historique » **en attente d'autorisation** (défaut colonne 20.00 + trigger) | P1 | migration à rédiger |
| 4 | Dette : `backend/src/**` — 15 fichiers legacy **non committés** dans le working tree (depuis semaines) | P1 | `backend/src` |
| 5 | OCR, Google login, aperçu caméras, réinitialisation complète : non fonctionnels **assumés** | P2 | fichiers cités §B |
| 6 | Sparkline dashboard fixe ; double titre `cardTickets` | P3 | `dashboard_page.dart`, `settings_page.dart` |
| 7 | Résidus de test en DB : ventes `POS-2026-000093…98` (notes/échantillons de test) — `DELETE /sales/:id` = 405 par design | mineur | Edge |
| 8 | Fichier junk `renderer` régénéré par `build/web` — retiré manuellement à chaque déploiement | mineur | build |

## E. ACTIONS REQUISES (PowerShell)

```powershell
# 1) Tests complets (déjà verts aujourd'hui)
cd backend; node --experimental-test-module-mocks --test "test/*.test.js"
cd ../frontend; flutter analyze; flutter test

# 2) Déploiement (procédure validée)
cd frontend; flutter build web --release
Copy-Item -Path "build\web\*" -Destination "C:\Users\Merouan\Documents\Default Project\pharma-maroc-gold" -Recurse -Force
# puis stamp index.html + dup main.<stamp>.dart.js + retirer le junk "renderer" à la racine
# npx supabase functions deploy pharma-api --project-ref lwepnnecnrqdzadesyqo

# 3) Décisions utilisateur (NON exécutées — sensibles)
# 3a. Migration fix TVA (UPDATE/ALTER DEFAULT sale_items.tax_rate + trigger) : SQL à préparer, autorisation requise
# 3b. Committer ou abandonner les modifications legacy backend/src/** (15 fichiers)
# 3c. Créer le worker de sauvegarde pg_dump chiffrée (P1)

# 4) Restauration rapide
# git checkout backup-audit-global-20261015   # ou le commit précédent
```

## F. VERDICT

**PRÊT SOUS RÉSERVES** — périmètre testé : caisse (vente/paiement/stock/TVA/numérotation), multi-pharmacie & isolation, utilisateurs/PIN/switch, filtrage modules, rapports, audit, sécurité (RLS/audit log/proxy).

Réserves explicites : aucun TPE réel (paiement carte simulé assumé), worker de sauvegarde absent, migration fix TVA historique et dette `backend/src/**` en attente de décision.

---

*Rapport produit le 15/10/2026. Aucun identifiant secret n'y figure.*
