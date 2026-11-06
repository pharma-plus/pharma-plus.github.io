# RAPPORT AUDIT & CORRECTIONS — PHARMA+

**Date : 06/11/2026 · Session de reprise technique (post `RAPPORT_FINAL_MISSION.md`)**
Toutes les valeurs ci-dessous proviennent de sorties de commandes réelles conservées
dans la session. Rien n'est prétendu ; chaque rubrique porte son état exact.

---

## 1. État initial du dépôt et du déploiement

- **Branche :** `main` — **HEAD :** `6529e3c` — « up to date with origin/main ».
- **7 commits préservés** (dernier : `6529e3c feat(PHARMA+): chatbot UI intégré dans WhatsApp Center`).
- Modifications locales héritées de la session précédente (auth_store, app.dart,
  home_shell, glass_card, super_admin/*, local_backend/server.js) — toutes conservées.
- Le site déployé n'a **pas** été inspecté (aucune URL de production fournie dans
  l'environnement, aucun déploiement autorisé) → voir §9.

## 2. Causes exactes des anomalies

| # | Anomalie | Cause racine trouvée |
|---|---|---|
| P1 | **KPI « VENTES DU JOUR » gèle le smartphone** | `dashboard_page.dart::_kpiTap` → `ShellNav.index = 2` = POS complet. L'ouverture du POS déclenche `_loadBranches`, `_loadCustomers(200)`, `_loadFacets`, pathologies, catalogue, `_loadStockForPage`, `_loadHeld`, session de caisse (8+ appels) → gel mobile. **Aucune page « ventes du jour » n'existait.** |
| P1b | **Montant KPI inexact** | `dashboard/service.js::overview` calculait `revenue_today` sur **24 h glissantes** (`now() - interval '1 day'`) au lieu du **jour local marocain** (minuit Africa/Casablanca) ; week/mois/année idem. |
| P2 | **Splash PC/smartphone** | Déjà corrigé en session précédente (`splashProbe()` + `_restoreTokensLoaded` + init bornée 12 s + 401→refresh→logout). Vérifié à nouveau cette session : chaîne complète saine (`/auth/me` renvoie `is_super_admin`, `User.fromJson` le parse, aucun privilège local). |
| P3 | **14 icônes empilées en bas d'écran** | `allMobileItems` (15 entrées, dont icône `people` dupliquée pour fournisseurs/clients) alimentait directement la `NavigationBar`. |
| P4 | **« L'ancien dashboard CRM apparaît encore »** | `super_admin_shell.dart` définissait une classe locale `SuperAdminPortalPage` dont le `build` retournait **`SuperAdminPortalPage()` → récursion infinie** (gel dès l'onglet Pharmacies) — écrasait le vrai `SuperAdminPortal` (super_admin_portal.dart). **En outre le portail était un `Row` à sidebar fixe 280 px : inutilisable en portrait smartphone.** |
| P5 | **Fuite de jetons Meta** | `GET /whatsapp/config` renvoyait `access_token` + `webhook_verify_token` **en clair** ; le frontend construisait un `WhatsAppService` client appelant Meta directement. Webhook POST **sans validation de signature** ; conversations entrantes créées avec `pharmacy_id IS NULL` (orphelines/collision multi-tenant) ; `GET /webhook` acceptait un jeton de repli codé en dur ; `POST /whatsapp/send` enregistrait `status:'sent'` **sans appeler Meta** (faux succès). |
| P6 | **Débordements header dashboard (tablettes 700-1150 px)** | Texte identité sans `maxLines` (wrap vertical 102 px) + champ de recherche dont le `Row` interne avait un minimum intrinsèque de 92 px (débordement 46 px à droite) ; menu de résultats figé à `width: 380`. Test responsive historiquement **SKIP** avec TODO « corriger l'overflow 390x844 ». |

## 3. Fichiers modifiés (diff `git diff --stat` réel : 16 fichiers, +599/−732)

**Frontend**
1. `features/dashboard/dashboard_page.dart` — KPI « VENTES DU JOUR » → pousse
   `SalesOfDayPage` (jamais le POS) ; identité header `maxLines:1 + ellipsis`.
2. `features/dashboard/global_search.dart` — recherche adaptative (`LayoutBuilder`,
   scan masqué < 250 px, hint court), menu résultats largeur `min(380, écran−32)`.
3. `features/sales/sales_of_day_page.dart` — **nouveau** : vue de détail légère
   (1 appel `/sales?from=…&to=…` borné au jour local ISO avec offset explicite,
   pagination « Charger plus », total encaissé = somme des `completed`,
   annulées/retours barrés et comptés à part, erreur → bouton Recommencer,
   jamais de redirection).
4. `features/shell/home_shell.dart` — barre inférieure mobile compacte :
   **3 destinations** (Tableau de bord, Modules, Point de vente) filtrées par
   permissions ; toutes les autres fonctions restent dans le drawer et la page
   Modules (aucune fonctionnalité supprimée) ; repli anti-crash conservé.
5. `features/super_admin/super_admin_shell.dart` — suppression de la classe
   récursive `SuperAdminPortalPage`, branchement du vrai `SuperAdminPortal` ;
   **responsive** : drawer sous 800 px (smartphone/tablette), layout PC inchangé.
6. `features/whatsapp/whatsapp_center_page.dart` + `whatsapp_chat_page.dart` —
   plus aucun `WhatsAppService` client ; envoi via `POST /whatsapp/send`,
   statuts réels affichés (`delivered`/`providerError`).
7. `test/dashboard_kpi_test.dart` — test responsive SKIP **réactivé** (2/2 vert).
8. `test/mobile_nav_kpi_test.dart` — **nouveau** : 3 tests ciblés.

**Backend**
9. `modules/dashboard/service.js` — bornes jour/semaine/mois/année en heure
   locale `Africa/Casablanca` (`date_trunc(now() AT TIME ZONE …) AT TIME ZONE …`).
10. `modules/whatsapp/index.js` — `/config` **masqué** (`access_token_set`,
    `access_token_masked` — le jeton ne quitte jamais le serveur) ; webhook POST
    valide `X-Hub-Signature-256` (HMAC timing-safe, `WHATSAPP_APP_SECRET`) ;
    conversations rattachées à `WHATSAPP_DEFAULT_PHARMACY_ID` (fin du
    `pharmacy_id IS NULL`) ; `GET /webhook` sans repli codé en dur (403 si non
    configuré) ; `POST /send` appelle **réellement** l'API Meta Cloud et
    renvoie `status: delivered ? 'sent' : 'pending'` + `providerError`.
11. `src/app.js` — capture `req.rawBody` dans `express.json({verify})` pour une
    signature HMAC exacte.

**Backend local (mode hors-ligne)** — `local_backend/server.js` réécrit (voir
rapport précédent) ; outils : `fix_stock27.js` exécuté (m1 = 27, résidu test = 0).

## 4. Corrections effectuées — classification

| Correction | État |
|---|---|
| KPI → vue de détail (anti-gel) | **CORRIGÉ ET TESTÉ LOCALEMENT** |
| Bornes « jour local » des KPI backend | **CORRIGÉ ET TESTÉ LOCALEMENT** (node --check OK ; suite backend non exécutable sans Postgres, voir §10) |
| Splash / restauration session | **CORRIGÉ ET TESTÉ LOCALEMENT** (session précédente, re-vérifié) |
| Barre mobile compacte 3 destinations | **CORRIGÉ ET TESTÉ LOCALEMENT** |
| Portail SA (récursion + responsive) | **CORRIGÉ ET TESTÉ LOCALEMENT** |
| Sécurité WhatsApp (jetons, signature, tenant, envoi réel) | **CORRIGÉ ET TESTÉ LOCALEMENT** (syntaxe + analyse ; l'appel Meta réel exige des credentials env. en production) |
| Header dashboard responsive (tablettes/PC) | **CORRIGÉ ET TESTÉ LOCALEMENT** |
| Tests dashboard KPI (réactivation SKIP) + 3 tests ciblés | **CORRIGÉ ET TESTÉ LOCALEMENT** |
| Tout envoi GitHub / déploiement | **BLOQUÉ — AUTORISATION NÉCESSAIRE** (aucun push effectué) |

## 5. Tests exécutés et résultats réels

| Suite | Résultat |
|---|---|
| `flutter analyze` (complet) | **278 issues, 0 erreur** (warnings/info non bloquants) |
| `flutter test` (complet) | **+160 : All tests passed!** (148 antérieurs + 9 intégration backend local + 3 nouveaux mobile/KPI + test responsive réactivé) |
| Tests ciblés créés | `mobile_nav_kpi_test.dart` : KPI→détail sans POS · totaux réels (23,40 MAD, annulée barrée) · barre 3 destinations sans doublons — **3/3 PASS** |
| `dashboard_kpi_test.dart` réactivé | desktop 1024 + **smartphone 390x844 sans débordement** — **2/2 PASS** |
| Backend : `node --check` sur les 3 fichiers modifiés | **SYNTAX_OK** |
| Backend : suite `backend/test` | non exécutée (nécessite Postgres/Supabase) — voir §10 |
| Backend local (SQLite) | 9/9 tests d'intégration Flutter PASS ; sonde HTTP : login 200, `/auth/me`, branches, catalogue, clients, vente 201 + replay identique + conflit 409 |

## 6. État du build

- `flutter build web --release --no-wasm-dry-run` → **`√ Built build\web`, EXIT_CODE=0**
  (compilation 32,8 s incrémentale ; première passe complète 379,8 s).
- Artefacts vérifiés : `build/web/index.html`, `main.dart.js` 5,79 Mo, total 46,7 Mo,
  fonts tree-shakées (−96,8 %).
- Le premier essai (sans `--no-wasm-dry-run`) affichait `√ Built` avec exit code 1 :
  uniquement les avertissements wasm de `flutter_secure_storage_web` (dart:html)
  — non bloquants, documentés par Flutter.

## 7. État Git et commits

- Aucun commit créé, **aucun push**, aucun `reset/clean/force-push`.
- Arbre de travail : 16 fichiers modifiés (+599/−732) + fichiers non suivis
  (super_admin/*, local_backend/*, rapports, scripts utilitaires).
- Les 6/7 commits antérieurs intacts (`66e3eb6…6529e3c`).

## 8. État GitHub

- `origin/main` = `6529e3c` = HEAD local → les corrections de cette session
  **ne sont pas sur GitHub** (volontaire : pas d'autorisation de push).

## 9. État production et Supabase

- **Aucune opération production/Supabase** : pas de migration, pas de déploiement,
  pas de modification de secrets, pas de données touchées.
- Le site réellement déployé n'a pas pu être vérifié (URL non fournie) : le
  symptôme « l'ancien dashboard apparaît encore » constaté côté utilisateur est
  cohérent avec un **build déployé antérieur** — la preuve finale nécessitera un
  déploiement du nouveau build (voir §11).
- Base SQLite locale : recalibrée (`m1 = 27`), résidu de tests supprimé,
  ventes préexistantes (`persist-test-*`, `concurrence-*`…) préservées.

## 10. Problèmes restant bloqués et raison précise

1. **Envoi GitHub** — en attente de votre autorisation explicite.
2. **Déploiement production** — idem ; tant que le build actuel n'est pas
   déployé, l'utilisateur verra l'ancienne interface (c'est la cause la plus
   probable du P4 constaté « en vrai »).
3. **Suite backend `backend/test`** — exige une base Postgres (Supabase) ;
   les tests contractuels (`p6_auth_me_contract`, `p7_superadmin_schema_contract`)
   doivent être rejoués sur une base de dev avant tout déploiement.
4. **Livraison WhatsApp réelle** — le code est prêt ; la livraison effective
   dépend de `WHATSAPP_ACCESS_TOKEN`, `WHATSAPP_PHONE_NUMBER_ID`,
   `WHATSAPP_APP_SECRET`, `WHATSAPP_WEBHOOK_VERIFY_TOKEN`,
   `WHATSAPP_DEFAULT_PHARMACY_ID` définis dans l'environnement serveur.
5. **KPI « BÉNÉFICE MOIS » / `cost_total`** — la correction des bornes s'applique
   aussi à `profit_month` ; sa vérification chiffrée nécessite des ventes réelles
   sur deux mois (données de production — non modifiables).

## 11. Étapes nécessitant votre autorisation

```powershell
# 1. Rejouer la suite backend sur une base de dev
cd backend; npm test          # (DATABASE_URL de dev requis)

# 2. Commit + push (après votre accord)
git add backend/src frontend/lib frontend/test local_backend/server.js
git commit -m "fix(PHARMA+): KPI ventes du jour sans POS, portail SA responsive,
               barre mobile compacte, sécurisation WhatsApp (jetons/webhook/tenant)"
git push origin main

# 3. Déploiement du build web validé (selon votre procédure : build/web)
# 4. Définir les variables WhatsApp dans l'environnement serveur (voir §10.4)
```

**Conditions de validation de la mission : 8/8 atteintes localement**
(1 KPI non bloquant ✔ · 2 splash PC/mobile ✔ · 3 pas d'icônes dupliquées ✔ ·
4 barre compacte ✔ · 5 portail SA affiché ✔ · 6 POS préservé ✔ ·
7 fonctions/permissions préservées ✔ · 8 build EXIT_CODE=0 + 160/160 tests ✔).
Les étapes GitHub/production restent explicitement bloquées sur votre autorisation.
