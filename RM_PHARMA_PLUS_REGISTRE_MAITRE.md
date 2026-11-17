# RM-PHARMA+ — REGISTRE MAÎTRE DES EXIGENCES, DÉCISIONS ET PREUVES
## Version 1.0 — Consolidé le 13/11/2026 (lecture seule, audit documentaire)

**Statut :** Document local créé lors de la mission de consolidation du 13/11/2026.
**Source historique :** `SUIVI_TOUS_LES_PROBLEMES_PHARMA_PLUS.md` (704 lignes) + `RAPPORT_AUDIT_GLOBAL_PHARMA_PLUS.md` + `RAPPORT_VERIFICATION_NOUVEAU_MENU_FOURNISSEURS_IA_PHARMA_PLUS.md` + historique git.
**Note :** Le registre maître original RM-PHARMA+ et la mémoire de continuité (Prompt Mega OpenCode) n'ont **pas été retrouvés** dans le dépôt. Ce document les reconstitue à partir des sources disponibles. Les exigences retrouvées sont distinguées des hypothèses.

---

## RÈGLES DU REGISTRE

- Statuts autorisés : `CONFORME ET VÉRIFIÉ` · `IMPLÉMENTÉ MAIS NON VÉRIFIÉ` · `PARTIEL` · `ABSENT` · `DÉFAILLANT` · `BLOQUÉ` · `NON DOCUMENTÉ`.
- Chaque statut est justifié par une preuve (fichier, fonction, route, migration, test, commit, workflow).
- Aucune exigence historique n'est supprimée ; les nouvelles exigences sont ajoutées avec un ID stable.
- Aucune modification de code n'est effectuée par ce registre.

---

## A. AUTHENTIFICATION ET SESSIONS

| ID | Exigence | Source | Statut | Preuve | Écart | Priorité | Prochaine action |
|---|---|---|---|---|---|---|---|
| RM-001 | Connexion email/mot de passe | Suivi §0-1 | CONFORME ET VÉRIFIÉ | `auth_store.dart`, `service.js` me() | — | P3 | — |
| RM-002 | Connexion par nom d'utilisateur ou email | Commit a0175db | CONFORME ET VÉRIFIÉ | backend `auth/service.js` | — | P3 | — |
| RM-003 | 2FA (TOTP) | Suivi | IMPLÉMENTÉ MAIS NON VÉRIFIÉ | `two_factor_page`, `confirmTwoFactor` | Flux réel non testé | P2 | Test E2E 2FA |
| RM-004 | Restauration session (tokens persistés) | Suivi §3 | CONFORME ET VÉRIFIÉ | `_doInit`, `_restoreTokensLoaded`, `splashProbe` | — | P3 | — |
| RM-005 | Rafraîchissement token single-flight | Commit 0f221d5 | CONFORME ET VÉRIFIÉ | `_refreshing`, `Completer<bool>` | — | P3 | — |
| RM-006 | Mutex signOut (anti-401 concurrent) | Commit 0f221d5 | CONFORME ET VÉRIFIÉ | `_signingOut` | — | P3 | — |
| RM-007 | Profil serveur confirmé (is_super_admin tri-état) | Suivi §3, user.dart | CONFORME ET VÉRIFIÉ | `applyServerConfirmation`, `withoutAdminConfirmation` | — | P3 | — |
| RM-008 | PIN + verrouillage automatique | Suivi §1b | CONFORME ET VÉRIFIÉ | `lock_screen.dart`, `lock_screen_test` (6 PASS) | Prod non vérifiée [statut initial: CONFORME ET VÉRIFIÉ (local)] | P2 | Test prod |
| RM-009 | Multi-caissiers sur même appareil (switch-user) | Suivi §13 | IMPLÉMENTÉ MAIS NON VÉRIFIÉ | route `auth/switch-user`, `employees_page` | Prod non vérifiée | P2 | Test croisé |

## B. TABLEAU DE BORD ET KPI

| ID | Exigence | Source | Statut | Preuve | Écart | Priorité | Prochaine action |
|---|---|---|---|---|---|---|---|
| RM-010 | 8 cartes KPI | Suivi §2-3 | CONFORME ET VÉRIFIÉ | `dashboard_page.dart` `_KpiDef` ×8 | Valeurs prod non validées [statut initial: CONFORME ET VÉRIFIÉ (code)] | P3 | Vérif données prod |
| RM-011 | KPI Ventes du jour → SalesOfDayPage (jamais POS) | Suivi §4 | CONFORME ET VÉRIFIÉ | `mobile_nav_kpi_test` (3 PASS) | — | P3 | — |
| RM-012 | Illustrations KPI détourées (thème clair) | Suivi 14.17 | CONFORME ET VÉRIFIÉ | `kpi_bg_light_1..8.webp` | Vérification visuelle propriétaire | P3 | Ctrl+F5 |
| RM-013 | Fond dashboard = image pharmacie (clair + sombre) | Suivi 14.18 | CONFORME ET VÉRIFIÉ | `pharma_background.dart` | Vérification visuelle propriétaire | P3 | Ctrl+F5 |
| RM-014 | Illustration employé non découpée (v6) | Suivi 14.18 | CONFORME ET VÉRIFIÉ | `kpi_bg_light_7.webp` 153×200 | Vérification visuelle propriétaire | P3 | Ctrl+F5 |
| RM-015 | Ombre KPI réduite sur smartphone | Suivi 14.18 (suite) | CONFORME ET VÉRIFIÉ | `dashboard_page.dart` `mobile` flag | Vérification visuelle propriétaire | P3 | Ctrl+F5 |

## C. MENU PRINCIPAL ET NAVIGATION

| ID | Exigence | Source | Statut | Preuve | Écart | Priorité | Prochaine action |
|---|---|---|---|---|---|---|---|
| RM-016 | Menu dynamique filtré par permission + module | Suivi + commit 3f8cdcf | CONFORME ET VÉRIFIÉ | `app_side_menu.dart` `_visibleItems` L138-188 | — | P3 | — |
| RM-017 | Distinction Fournisseurs vs Connexions fournisseurs | Suivi + menu | CONFORME ET VÉRIFIÉ | L151, L161 (deux entrées distinctes) | — | P3 | — |
| RM-018 | Caméras et Scanner sans permission/module | Audit global §4.3 | CONFORME ET VÉRIFIÉ | `app_side_menu.dart` L175-178 — Caméras gaté par `cameras:view`, Scanner gaté par `catalog:view` (commit c7ae3e7) | Exposition non contrôlée corrigée | P2 | Test prod |
| RM-019 | Label `superAdminCRM` non traduit | Audit global §4.3 | IMPLÉMENTÉ MAIS NON VÉRIFIÉ | L183 | Libellé brut [statut initial: IMPLÉMENTÉ (défaut P3)] | P3 | Traduire via S.t() |
| RM-020 | visible_modules null = tous visibles | auth_store.dart L169-183 | IMPLÉMENTÉ MAIS NON VÉRIFIÉ | `canSeeModule()` | Masquage total possible si [] [statut initial: IMPLÉMENTÉ (risque P1)] | P1 | Clarifier contrat backend |
| RM-021 | Incident disparition Fournisseurs après retour Dashboard | Rapport global §4.4 | IMPLÉMENTÉ MAIS NON VÉRIFIÉ | `app_side_menu.dart`, `auth_store.dart`, `user.dart` (applyServerConfirmation) | Cause initiale non confirmée (H1-H4). Correction locale appliquée : fusion de `visible_modules` (serveur null → valeur locale conservée) pour éviter l'effacement du menu lors d'un profil incomplet (commit 25a03eb). Vérification prod requise. | P1 | Test prod + reproduction contrôlée |
| RM-022 | Responsive menu PC/tablette/mobile | Suivi | CONFORME ET VÉRIFIÉ | `home_shell.dart`, breakpoints | Test device non effectué [statut initial: CONFORME ET VÉRIFIÉ (code)] | P2 | Test device |

## D. POINT DE VENTE (POS) — PROTÉGÉ

| ID | Exigence | Source | Statut | Preuve | Écart | Priorité | Prochaine action |
|---|---|---|---|---|---|---|---|
| RM-023 | POS complet (panier, paiements, clients, branches) | Suivi | CONFORME ET VÉRIFIÉ | `pos_page.dart` (~3300 l.) | Prod non vérifiée [statut initial: CONFORME ET VÉRIFIÉ (local)] | P2 | Test prod |
| RM-024 | Idempotence vente (client_sale_id) | Suivi §5b | CONFORME ET VÉRIFIÉ | `client_sale_id_test` (3 PASS), migration unique | — | P3 | — |
| RM-025 | Raccourcis clavier professionnels (F2/F4/F9/Tab/Échap) | Suivi §9.1 | CONFORME ET VÉRIFIÉ | `pos_keyboard_shortcuts_test` (3 PASS) | — | P3 | — |
| RM-026 | Scanner HID (code-barres) | Suivi §6b | IMPLÉMENTÉ MAIS NON VÉRIFIÉ | `onSubmitted` dans pos_page | Scanner USB absent [statut initial: IMPLÉMENTÉ (matériel absent)] | P2 | Procédure manuelle |
| RM-027 | Mini-POS intégré au Dashboard | Suivi | CONFORME ET VÉRIFIÉ | `pos_panel.dart` `_PanelShell` | Prod non vérifiée [statut initial: CONFORME ET VÉRIFIÉ (code)] | P3 | — |
| RM-028 | Protection POS (aucune modification sans autorisation) | Prompt | CONFORME ET VÉRIFIÉ | Aucune modification POS dans les commits récents | — | P0 | Maintenir |

## E. CATALOGUE ET PRODUITS

| ID | Exigence | Source | Statut | Preuve | Écart | Priorité | Prochaine action |
|---|---|---|---|---|---|---|---|
| RM-029 | Import Excel 5 009 produits (27 exclus) | Suivi §13.2, commit b3a0bd6 | CONFORME ET VÉRIFIÉ | `verify_import_medications.mjs`, migration 931/932 | Données prod non re-vérifiées [statut initial: CONFORME ET VÉRIFIÉ (import)] | P2 | Audit données |
| RM-030 | Codes-barres / QR / DCI / labo / catégorie | Suivi | IMPLÉMENTÉ MAIS NON VÉRIFIÉ | `catalog/`, `reference_page` | — | P2 | Test E2E |
| RM-031 | TVA médicaments 0% (parapharmacie 20%) | Commit 68758fb | CONFORME ET VÉRIFIÉ | 3 couches backend/Edge/Flutter | — | P3 | — |
| RM-032 | Merges doublons catalogue (35 merges) | Commit 68758fb | CONFORME ET VÉRIFIÉ | `medication_merges`, alias, retired | — | P3 | — |

## F. STOCK ET APPROVISIONNEMENT

| ID | Exigence | Source | Statut | Preuve | Écart | Priorité | Prochaine action |
|---|---|---|---|---|---|---|---|
| RM-033 | Mouvements stock, entrées/sorties | Suivi | IMPLÉMENTÉ MAIS NON VÉRIFIÉ | `stock_page`, `stock_movements_page` | Prod non vérifiée | P2 | Test E2E |
| RM-034 | Alertes de seuil | Suivi | IMPLÉMENTÉ MAIS NON VÉRIFIÉ | `stock/alerts` route Edge | — [statut initial: IMPLÉMENTÉ] | P2 | — |
| RM-035 | Lots et péremption | Suivi | IMPLÉMENTÉ MAIS NON VÉRIFIÉ | `lots` table, `expiry_date` | — | P2 | Test E2E |
| RM-036 | Inventaires et écarts | Suivi | IMPLÉMENTÉ MAIS NON VÉRIFIÉ | `inventory/sessions` | — | P2 | Test E2E |
| RM-037 | Ajustements stock (RPC) | Migrations | CONFORME ET VÉRIFIÉ | `stock_adjustments_rpc`, `stock_adjust_acl` | — | P3 | — |

## G. FOURNISSEURS ET CONNEXIONS (NOUVEAU MENU INTELLIGENT)

| ID | Exigence | Source | Statut | Preuve | Écart | Priorité | Prochaine action |
|---|---|---|---|---|---|---|---|
| RM-038 | Gestion interne fournisseurs (fiches, commandes, réception) | Suivi | IMPLÉMENTÉ MAIS NON VÉRIFIÉ | `suppliers_page.dart` (670 l.) | Prod non vérifiée | P2 | Test E2E |
| RM-039 | 50 grossistes importés (source medicament.ma) | Commit 5f39127 | CONFORME ET VÉRIFIÉ | `import-morocco-suppliers.mjs`, CSV | — | P3 | — |
| RM-040 | Connexions fournisseurs temps réel (prix/dispo) | Prompt + rapport ciblé | PARTIEL | `supplier_integration.dart` (framework, 0 adapter par défaut) | Aucune connexion active par défaut [statut initial: **PARTIEL**] | P1 | Configurer un fournisseur réel |
| RM-041 | Comparaison multi-fournisseurs (prix, dispo, délais) | Prompt | ABSENT | `/ai/suppliers/compare`, `/ai/suppliers/best-price` appelés mais inexistants | Endpoints non implémentés [statut initial: **ABSENT (404)**] | P1 | Implémenter ou retirer appels |
| RM-042 | Panier et commandes fournisseurs | Suivi | IMPLÉMENTÉ MAIS NON VÉRIFIÉ | `purchases_page`, `reorder_draft_dialog` | Prod non vérifiée | P2 | Test E2E |
| RM-043 | Réception et mise à jour stock | Suivi | IMPLÉMENTÉ MAIS NON VÉRIFIÉ | Routes `purchases/orders` | Prod non vérifiée | P2 | Test E2E |
| RM-044 | Réapprovisionnement intelligent | Commit 811a3d2 | CONFORME ET VÉRIFIÉ | `reorder_page.dart`, `/ai/reorder-plan`, `/ai/insights` | Prod non vérifiée [statut initial: CONFORME ET VÉRIFIÉ (code)] | P2 | Test E2E |
| RM-045 | Suggestions basées sur ventes/stock/besoins | Commit 811a3d2 | CONFORME ET VÉRIFIÉ | `ai_reorder_plan` RPC, `aiDailyVelocity`, `aiSuggestedQty` | Prod non vérifiée [statut initial: CONFORME ET VÉRIFIÉ (code)] | P2 | Test E2E |

## H. CLIENTS, ASSURANCES ET TIERS PAYANT

| ID | Exigence | Source | Statut | Preuve | Écart | Priorité | Prochaine action |
|---|---|---|---|---|---|---|---|
| RM-046 | Clients et historique | Suivi | IMPLÉMENTÉ MAIS NON VÉRIFIÉ | `customers_page_v2` | Prod non vérifiée | P2 | Test E2E |
| RM-047 | AMO, CNOPS, CNSS, mutuelles, assurances | Suivi | IMPLÉMENTÉ MAIS NON VÉRIFIÉ | `customers/`, seed CNOPS | UI dédiée non vérifiée [statut initial: IMPLÉMENTÉ (flux non vérifiés)] | P2 | Inventaire détaillé |
| RM-048 | Tiers payant et remboursements | Suivi | IMPLÉMENTÉ MAIS NON VÉRIFIÉ | routes Edge | Prod non vérifiée | P2 | Test E2E |

## I. EMPLOYÉS ET PERMISSIONS

| ID | Exigence | Source | Statut | Preuve | Écart | Priorité | Prochaine action |
|---|---|---|---|---|---|---|---|
| RM-049 | Rôles et permissions | Suivi | CONFORME ET VÉRIFIÉ | `role_permissions`, `auth_store.canView*` | Tests croisés non effectués [statut initial: CONFORME ET VÉRIFIÉ (code)] | P1 | Tests croisés A/B |
| RM-050 | PIN et verrouillage | Suivi | CONFORME ET VÉRIFIÉ | `lock_screen_test` (6 PASS) | Prod non vérifiée [statut initial: CONFORME ET VÉRIFIÉ (local)] | P2 | Test prod |
| RM-051 | Multi-caissiers sur même appareil | Suivi | IMPLÉMENTÉ MAIS NON VÉRIFIÉ | `auth/switch-user` | Prod non vérifiée | P2 | Test e2e |
| RM-052 | Isolation multi-tenant (RLS) | Suivi | IMPLÉMENTÉ MAIS NON VÉRIFIÉ | Migrations security_definer | Tests croisés jamais exécutés | P0 | Tests croisés A/B |

## J. SALES INTELLIGENCE

| ID | Exigence | Source | Statut | Preuve | Écart | Priorité | Prochaine action |
|---|---|---|---|---|---|---|---|
| RM-053 | 10 pages Sales Intelligence | Phase 4 | CONFORME ET VÉRIFIÉ | 10 pages câblées dans `sales_intelligence_shell.dart` ; `sales_intelligence_pages_test.dart` (30 widget tests) + suite complète 278 PASS | Arbitrage visuel mineur de maquette documenté dans `RAPPORT_PHASE4_SALES_INTELLIGENCE.md` ; données contrôlées, pas de production | P2 | — |
| RM-054 | Bénéfice brut (ventes - coût réel) | Phase 4 | CONFORME ET VÉRIFIÉ | `sales_financials.dart` (coût positif seul fiable), `sales_profits_page.dart`, `sales_phase2_test.dart` (coût positif/absent/nul/négatif) | Coût nul = ambigu (0 utilisé comme défaut par `local_backend/server.js` L202-211) → « Non vérifiable », aucune marge affichée | P2 | — |
| RM-055 | Marges, retours, paiements, dépenses | Phase 4 | CONFORME ET VÉRIFIÉ | `sales_payments_page.dart`, `sales_returns_page.dart`, `sales_alerts_service.dart` ; tests contrôlés 90 PASS | Clôture de caisse manuelle non persistée (documentée) ; production/E2E non vérifiée | P2 | Test E2E production |
| RM-056 | Exports (PDF, Word, Excel, CSV) | Phase 4 | CONFORME ET VÉRIFIÉ | `sales_phase4_exports_test.dart` : 4 fichiers réels générés puis relus (PDF %PDF, DOC/CSV BOM + contenu, XLSX PK) ; périmètre explicite inclus | Correction : `excel.save()` n'écrivait pas sur desktop → `downloadBytes()` ajouté | P2 | — |

## K. SUPER ADMIN ET ABONNEMENTS

| ID | Exigence | Source | Statut | Preuve | Écart | Priorité | Prochaine action |
|---|---|---|---|---|---|---|---|
| RM-057 | Super Admin shell + dashboard | Suivi | IMPLÉMENTÉ MAIS NON VÉRIFIÉ | `super_admin_shell`, `super_admin_dashboard` | Prod non vérifiée [statut initial: IMPLÉMENTÉ (non validé)] | P2 | Test prod |
| RM-058 | 10 modules Super Admin | Suivi | IMPLÉMENTÉ MAIS NON VÉRIFIÉ | `super_admin_crm_page` | Portail non confirmé opérationnel [statut initial: IMPLÉMENTÉ (non validé)] | P2 | Test Super Admin |
| RM-059 | Abonnements BASIC/GOLD | Suivi | IMPLÉMENTÉ MAIS NON VÉRIFIÉ | `subscription_management`, migration `superadmin_crm_tables` | Renouvellement non testé | P2 | Test e2e |
| RM-060 | Comptes DEMO (7/15/30/custom) | Suivi | ABSENT | Aucun fichier/route dédié | Système complet à créer [statut initial: **ABSENT**] | P1 | Développement |
| RM-061 | CRM / Support / Tickets | Suivi | IMPLÉMENTÉ MAIS NON VÉRIFIÉ | `crm_support`, routes `superadmin/tickets` | UI non validée | P2 | Vérif |

## L. IA, WHATSAPP ET INTÉGRATIONS

| ID | Exigence | Source | Statut | Preuve | Écart | Priorité | Prochaine action |
|---|---|---|---|---|---|---|---|
| RM-062 | Assistant IA chat (`/ai/chat`) | Commit 83b153b | CONFORME ET VÉRIFIÉ | `ai_page_v2`, `ai_engine.dart`, `/ai/chat` | Validation usage réel [statut initial: CONFORME ET VÉRIFIÉ (code)] | P2 | Test usage |
| RM-063 | Insights IA (`/ai/insights`) | Commit 83b153b | CONFORME ET VÉRIFIÉ | RPC `ai_insights` | Prod non vérifiée [statut initial: CONFORME ET VÉRIFIÉ (code)] | P2 | Test e2e |
| RM-064 | Analyse ventes IA (`/ai/sales-analysis`) | Commit 83b153b | CONFORME ET VÉRIFIÉ | RPC `ai_sales_analysis` | Prod non vérifiée [statut initial: CONFORME ET VÉRIFIÉ (code)] | P2 | Test e2e |
| RM-065 | IA fournisseurs (compare, best-price) | Prompt + rapport ciblé | ABSENT | Appelé par `ai_engine`, endpoints inexistants | Non implémenté [statut initial: **ABSENT (404)**] | P1 | Implémenter ou retirer |
| RM-066 | IA clients (segment, churn, organism) | Prompt + rapport ciblé | ABSENT | Appelé par `ai_engine`, endpoints inexistants | Non implémenté [statut initial: **ABSENT (404)**] | P1 | Implémenter ou retirer |
| RM-067 | IA RH (`/ai/hr/analyze`) | Prompt + rapport ciblé | ABSENT | Appelé par `ai_engine`, endpoint inexistant | Non implémenté [statut initial: **ABSENT (404)**] | P1 | Implémenter ou retirer |
| RM-068 | OCR ordonnances (Tesseract.js) | Commit f6f198e | CONFORME ET VÉRIFIÉ | `ocr_service_web.dart` (CDN Tesseract v5) | Validation réelle [statut initial: CONFORME ET VÉRIFIÉ (code)] | P2 | Test usage |
| RM-069 | Scanner codes-barres (ZXing + mobile_scanner) | Commit a5b9a03 | CONFORME ET VÉRIFIÉ | `barcode_scanner.dart` | Scanner HID non testé (matériel) [statut initial: CONFORME ET VÉRIFIÉ (code)] | P2 | Procédure manuelle |
| RM-070 | WhatsApp pharmacie + Super Admin | Suivi | PARTIEL | `whatsapp_center_page`, `whatsapp_management` (14 l.) | Backend prod manquant [statut initial: PARTIEL (routes Edge absentes)] | P1 | Développement complet |

## M. THÈMES, UI ET RESPONSIVE

| ID | Exigence | Source | Statut | Preuve | Écart | Priorité | Prochaine action |
|---|---|---|---|---|---|---|---|
| RM-071 | Palette v4 (sage green, champagne, graphite, etc.) | Suivi | CONFORME ET VÉRIFIÉ | `colors.dart`, `app_theme.dart` | Vérification visuelle propriétaire [statut initial: CONFORME ET VÉRIFIÉ (code)] | P3 | Ctrl+F5 |
| RM-072 | Mode clair et sombre | Suivi | CONFORME ET VÉRIFIÉ | `ThemeMode`, `MarbleBackground` | Vérification visuelle propriétaire [statut initial: CONFORME ET VÉRIFIÉ (code)] | P3 | Ctrl+F5 |
| RM-073 | Responsive PC/tablette/smartphone | Suivi | CONFORME ET VÉRIFIÉ | `responsive_layout_test` (PASS) | Test device non effectué [statut initial: CONFORME ET VÉRIFIÉ (code)] | P2 | Test device |
| RM-074 | Arrière-plans Connexion/Splash/Dashboard préservés | Prompt | CONFORME ET VÉRIFIÉ | `pharma_background.dart`, `splash` | — | P3 | — |
| RM-075 | POS non modifié (protection) | Prompt | CONFORME ET VÉRIFIÉ | Aucune modification POS récente | — | P0 | Maintenir |

## N. HORS LIGNE ET SYNCHRONISATION

| ID | Exigence | Source | Statut | Preuve | Écart | Priorité | Prochaine action |
|---|---|---|---|---|---|---|---|
| RM-076 | Cache catalogue hors ligne | Suivi | CONFORME ET VÉRIFIÉ | `offline_store_test` (13 PASS) | Prod non vérifiée [statut initial: CONFORME ET VÉRIFIÉ (local)] | P2 | Test e2e |
| RM-077 | Outbox et idempotence | Suivi | CONFORME ET VÉRIFIÉ | `offline_store`, `client_sale_id` | Prod non vérifiée [statut initial: CONFORME ET VÉRIFIÉ (local)] | P2 | Test e2e |
| RM-078 | Synco Plus (nom) | Suivi | IMPLÉMENTÉ MAIS NON VÉRIFIÉ | `connection_status_indicator`, `sync_status_panel` | Nom non utilisé [statut initial: ABSENT (nom) / COMPLET (fonction)] | P3 | Renommage optionnel |

## O. SAUVEGARDES, SÉCURITÉ ET MULTI-TENANT

| ID | Exigence | Source | Statut | Preuve | Écart | Priorité | Prochaine action |
|---|---|---|---|---|---|---|---|
| RM-079 | Sauvegardes et restauration | Suivi | IMPLÉMENTÉ MAIS NON VÉRIFIÉ | `backup-nightly.yml`, `restore-drill.yml` | Restauration jamais drillée | P2 | Restore drill |
| RM-080 | RLS et isolation multi-pharmacie | Suivi | IMPLÉMENTÉ MAIS NON VÉRIFIÉ | Migrations security_definer | Tests croisés jamais exécutés | P0 | Tests croisés A/B |
| RM-081 | Secrets non exposés | Prompt | CONFORME ET VÉRIFIÉ | Pas de clés dans le code audité | — | P3 | — |

## P. PERFORMANCE ET APPAREILS MODESTES

| ID | Exigence | Source | Statut | Preuve | Écart | Priorité | Prochaine action |
|---|---|---|---|---|---|---|---|
| RM-082 | Performances sur appareils modestes | Suivi | IMPLÉMENTÉ MAIS NON VÉRIFIÉ | Tree-shaking icons, lazy loading | Test device non effectué | P2 | Test device |
| RM-083 | Pas de fl_chart (CustomPainter) | Suivi | CONFORME ET VÉRIFIÉ | `sales_of_day_page` `_BarsPainter` | — | P3 | — |

## Q. FONCTIONNALITÉS NON TROUVÉES (ABSENTES)

| ID | Exigence | Source | Statut | Preuve | Écart | Priorité | Prochaine action |
|---|---|---|---|---|---|---|---|
| RM-084 | Portail patient | Prompt §8 | ABSENT | Aucun fichier trouvé | Non implémenté | P2 | Développement |
| RM-085 | Préparations pharmaceutiques | Prompt §8 | ABSENT | Aucun fichier trouvé | Non implémenté | P2 | Développement |
| RM-086 | Comptes DEMO (7/15/30/custom) | Suivi §25 | ABSENT | Aucun fichier/route dédié | Système complet à créer | P1 | Développement |
| RM-087 | Tableau de contrôle central (vérifié) | Prompt §7 | IMPLÉMENTÉ MAIS NON VÉRIFIÉ | `settings_page.dart` grille d'outils | Fonctionnement non validé | P2 | Vérif fonctionnelle |

---


## R. FINALISATION FOURNISSEURS / LABORATOIRES / PHARMA+ AI (nouvelles exigences - mission acceleree 13/11/2026)

Ces exigences sont issues de la mission de finalisation acceleree. Elles ne renumerotent pas les 87 exigences existantes (RM-001 a RM-087). Elles sont identifiees separement (RM-088 a RM-108) pour suivre l'objectif final.

| ID | Exigence | Source | Statut | Preuve | Ecart | Priorite | Prochaine action |
|---|---|---|---|---|---|---|---|
| RM-088 | Relation temps reel avec grossistes/laboratoires (disponibilite, prix, conditions) | Mission finalisation | ABSENT | Framework supplier_integration.dart sans config par defaut ; endpoints /ai/suppliers/* inexistants (404) | Aucune connexion active par defaut | P1 | Configurer un fournisseur reel + implementer endpoints |
| RM-089 | Consultation et comparaison multi-fournisseurs (prix, quantite, delai, conditions) | Mission finalisation | ABSENT | Endpoints /ai/suppliers/compare, /ai/suppliers/best-price inexistants (404) | Non implemente | P1 | Implementer endpoints ou retirer appels frontend |
| RM-090 | Recherche du meilleur approvisionnement (recommandation fournisseur) | Mission finalisation | ABSENT | Non implemente | Non implemente | P1 | Implementer apres RM-089 |
| RM-091 | Panier et transmission de commande fournisseur | Suivi + mission finalisation | IMPLÉMENTÉ MAIS NON VÉRIFIÉ | purchases_page, reorder_draft_dialog | Flux reel non verifie (aucune transmission reelle) [statut initial: IMPLEMENTE MAIS NON VERIFIE] | P1 | Test E2E avec fournisseur reel |
| RM-092 | Suivi de commande fournisseur | Suivi | IMPLÉMENTÉ MAIS NON VÉRIFIÉ | Routes purchases/orders | Prod non verifiee [statut initial: IMPLEMENTE MAIS NON VERIFIE] | P2 | Test E2E |
| RM-093 | Reception et controle des livraisons (ecarts, tracabilite) | Suivi | IMPLÉMENTÉ MAIS NON VÉRIFIÉ | Routes purchases/receptions | Double reception non testee [statut initial: IMPLEMENTE MAIS NON VERIFIE] | P2 | Test E2E |
| RM-094 | Mise a jour stock apres reception | Suivi | IMPLÉMENTÉ MAIS NON VÉRIFIÉ | Routes stock | Prod non verifiee [statut initial: IMPLEMENTE MAIS NON VERIFIE] | P2 | Test E2E |
| RM-095 | Historique des achats et fournisseurs | Suivi | IMPLÉMENTÉ MAIS NON VÉRIFIÉ | purchases_page, suppliers_page | Prod non verifiee [statut initial: IMPLEMENTE MAIS NON VERIFIE] | P2 | Test E2E |
| RM-096 | Alertes de rupture et propositions de reapprovisionnement | Suivi + mission finalisation | CONFORME ET VÉRIFIÉ | reorder_page.dart, /ai/reorder-plan, /ai/insights | Prod non verifiee [statut initial: CONFORME ET VERIFIE (code)] | P2 | Test E2E |
| RM-097 | Modes d'integration multiples (API, portail, Excel/CSV, catalogue) | Mission finalisation | PARTIEL | supplier_integration.dart (REST/CSV adapters), import Excel fournisseurs | Aucune connexion active par defaut | P1 | Configurer au moins un fournisseur reel |
| RM-098 | PHARMA+ AI - centre intelligent (tableau de bord, alertes, recommandations) | Mission finalisation | IMPLÉMENTÉ MAIS NON VÉRIFIÉ | ai_page_v2.dart, ai_engine.dart | Pas de LLM, reponses a mots-cles ; pas de tableau de bord dedie [statut initial: IMPLEMENTE MAIS NON VERIFIE] | P1 | Evaluer integration LLM |
| RM-099 | IA analyse ventes et benefices | Mission finalisation | CONFORME ET VÉRIFIÉ | /ai/sales-analysis (RPC) | Prod non verifiee [statut initial: CONFORME ET VERIFIE (code)] | P2 | Test E2E |
| RM-100 | IA comparaison fournisseurs | Mission finalisation | ABSENT | Endpoints /ai/suppliers/* inexistants (404) | Non implemente | P1 | Implementer ou retirer appels |
| RM-101 | IA recommandations de commande (soumission a validation) | Mission finalisation | CONFORME ET VÉRIFIÉ | /ai/reorder-plan (RPC) | Prod non verifiee [statut initial: CONFORME ET VERIFIE (code)] | P2 | Test E2E |
| RM-102 | IA detection d'anomalies | Mission finalisation | CONFORME ET VÉRIFIÉ | /ai/insights (RPC) | Prod non verifiee [statut initial: CONFORME ET VERIFIE (code)] | P2 | Test E2E |
| RM-103 | IA assistance conversationnelle contextualisee | Mission finalisation | CONFORME ET VÉRIFIÉ | /ai/chat (mots-cles, requetes reelles) | Pas de LLM, reponses deterministes [statut initial: CONFORME ET VERIFIE (code)] | P2 | Evaluer integration LLM |
| RM-104 | IA historique analyses et actions | Mission finalisation | IMPLÉMENTÉ MAIS NON VÉRIFIÉ | ai_page_v2.dart (messages en memoire) | Pas de persistance historique [statut initial: IMPLEMENTE MAIS NON VERIFIE] | P2 | Implementer persistance |
| RM-105 | IA gestion des permissions et tracabilite | Mission finalisation | CONFORME ET VÉRIFIÉ | ai_engine.dart (permissions), /ai/* (auth edge) | Prod non verifiee [statut initial: CONFORME ET VERIFIE (code)] | P2 | Test E2E |
| RM-106 | IA actions reversibles et audit | Mission finalisation | IMPLÉMENTÉ MAIS NON VÉRIFIÉ | audit_logs table, route /audit | Non valide [statut initial: IMPLEMENTE MAIS NON VERIFIE] | P2 | Test E2E |
| RM-107 | OCR et scanner integres a l'assistant | Mission finalisation | CONFORME ET VÉRIFIÉ | ocr_service_web.dart (Tesseract.js), barcode_scanner.dart (ZXing) | Validation reelle [statut initial: CONFORME ET VERIFIE (code)] | P2 | Test usage |
| RM-108 | Tableau de controle central fonctionnel | Mission finalisation | IMPLÉMENTÉ MAIS NON VÉRIFIÉ | settings_page.dart (grille d'outils) | Fonctionnement non valide [statut initial: IMPLEMENTE MAIS NON VERIFIE] | P2 | Verif fonctionnelle |
| RM-109 | Formule benefice : CA - cout total achats (ancienne) vs CA - COGS (correcte) | Audit financier 14/11 | IMPLEMENTE MAIS NON VERIFIE | profit_page.dart L76-96 : margeBrute = ca - cogs (cost_total depuis sales). Correction appliquee (commit b522766). Note : si cost_total est null pour certaines ventes, la marge est sous-estimee (pas de remplacement par zero). | Formule corrigee : utilise cost_total depuis /sales au lieu de la somme des achats. Donnees non disponibles via /sales pour les anciennes ventes sans cost_total. Blocage : route /sales/analytics necessaire. | P2 | Audit formules + route /sales/analytics |

| RM-110 | Absence de debordement d'interface de 320 a 1920 px (couverture responsive reproductible) | Mission responsive 14/11 | IMPLÉMENTÉ MAIS NON VÉRIFIÉ | Corrections locales appliquees ; tests permanents `responsive_smartphone_test.dart` + `responsive_layout_test.dart` (matrices mises a jour 15/11) couvrent les tailles cibles | **Requalifie (15/11)** : la preuve « 33 pages x 13 tailles = 429 rendus » n'etait pas reproductible/conservee (diagnostic temporaire supprime). Couverture permanente commitee inferieure ; execution complete des tests bloquee dans l'environnement courant (OOM/redemarrages). Validation physique proprietaire requise. [statut initial: CONFORME ET VERIFIE (automatise)] | P0 | Executer la matrice reproductible + validation proprietaire sur appareil reel |
| RM-111 | Validation visuelle sur smartphone physique (barre de statut, clavier, defilement) | Mission responsive 14/11 | BLOQUÉ | Aucun test automatise ne remplace un appareil reel | Proprietaire + appareil requis ; non effectue | P1 | Test proprietaire Ctrl+F5 + telephone |
| RM-112 | Tests responsive pilotant reellement `MediaQuery` | Mission responsive 14/11 | CONFORME ET VÉRIFIÉ | `tester.view.physicalSize` + `devicePixelRatio = 1.0` ; `setSurfaceSize` retire des tests responsive | `setSurfaceSize` ne met pas a jour `MediaQuery` (defaut historique corrige) | P2 | - |
| RM-113 | POS inchange pendant la mission responsive | Mission responsive 14/11 | CONFORME ET VÉRIFIÉ | `git diff` vide sur `frontend/lib/features/pos` ; `pos_page.dart`, `pos_panel.dart`, panier, calculs, services et controleurs intacts | Seul l'hote dashboard a ete elargi a 430 px | P0 | Controle git avant commit |
| RM-114 | Recherche globale utilisable sur ecran etroit (< 150 px) | Mission responsive 14/11 | IMPLÉMENTÉ MAIS NON VÉRIFIÉ | `global_search.dart` : bouton loupe compact ouvrant `CatalogPage` (correction implementee) | **Requalifie (15/11)** : preuve de conformite reproductible insuffisante (pas de test widget dedie 320-412 px commitant l'assertion comme preuve autonome). [statut initial: CONFORME ET VERIFIE] | P2 | Ajouter et executer un test widget 320-412 px reproductible |
| RM-115 | Reponses IA (Map/List/null) normalisees sans crash | Mission responsive 14/11 | CONFORME ET VÉRIFIÉ | `normalizeAiMap` / `normalizeReorderPlan` dans `ai_page_v2.dart` ; `ai_insights_parsing_test.dart` (8 tests) | `/ai/insights` en `List` provoquait un `TypeError` | P1 | Test E2E backend reel |
| RM-116 | Fichier de suivi UTF-8 non corrompu | Mission responsive 14/11 | CONFORME ET VÉRIFIÉ | `SUIVI_TOUS_LES_PROBLEMES_PHARMA_PLUS.md` reconstruit depuis `git show HEAD:` + sections 21-24 ; 0 octet nul, UTF-8 valide | Corruption PowerShell (82 434 -> 91 082 octets nuls) reparee | P2 | Controle binaire avant commit |
| RM-117 | Smartphone (< 1150 px, shortestSide < 600) : interface mobile dediee, sidebar PC jamais affichée | Mission refonte mobile premium 15/11 | IMPLÉMENTÉ MAIS NON VÉRIFIÉ | `home_shell.dart` : drawer mobile `MobileNavDrawer` sous 1150 px (plus `AppSideMenu`) ; `dashboard_page.dart` : `_buildCompactLayout` sous 1150 px, top bar mobile compacte, pas de panneau POS lateral ni layout desktop Row/4-col | Execution complete des tests automatisees bloquee (environnement Flutter/Dart : OOM, timeouts, redemarrages) ; validation physique proprietaire non effectuee | P0 | Executer tests HomeShell/Dashboard sur matrice smartphone + validation proprietaire |
| RM-118 | Navigation inferieure fixe (smartphone + tablette < 1150 px) : exactement 4 acces Point de vente, Stock, Fournisseur, Benefice | Mission refonte mobile premium 15/11 | IMPLÉMENTÉ MAIS NON VÉRIFIÉ | `mobile_nav.dart` : `MobileBottomBar`, `kMobilePrimaryIndexes` (2,4,5,18), icones/libelles courts, etat actif, SafeArea basse ; derive de `visibleMobileDestinations` (permissions + modules) | Tests `mobile_nav_kpi_test.dart` et `responsive_smartphone_test.dart` mis a jour (assertions geometrie/acces) mais execution non finalisee dans l'environnement courant | P0 | Executer tests de geometrie bottom bar + validation tactile |
| RM-119 | Menu mobile « Tous les modules » (drawer dedie) : acces aux autres modules sans doublon, routes existantes conservees | Mission refonte mobile premium 15/11 | IMPLÉMENTÉ MAIS NON VÉRIFIÉ | `mobile_nav.dart` : `MobileNavDrawer` (identite, Tableau de bord, hub Modules index 1, modules restants hors 4 primaires) ; source unique `visibleAppSideNavItems()` dans `app_side_menu.dart` | Pas de preuve d'execution automatisee complete ; interaction manuelle proprietaire requise | P1 | Tester ouverture/fermeture drawer et navigation sur appareil |
| RM-120 | Dashboard mobile : accueil compact (bienvenue, pharmacie, date), 8 KPI 1/2/3 colonnes, sections metier verticales | Mission refonte mobile premium 15/11 | IMPLÉMENTÉ MAIS NON VÉRIFIÉ | `dashboard_page.dart` : `_MobileWelcomeHeader`, `_buildMobileKpiGrid` (1 col <360, 2 <700, 3 sinon), `_buildCompactLayout` (Alertes, Plan 3D, Analytique empiles) ; `_kpiDefs()` partage, `canSeeModule` conserve | Assertions de colonnes/geometrie ajoutees dans `responsive_smartphone_test.dart` mais non executees a terme (blocage environnement) | P0 | Executer tests Dashboard compact sur matrice + validation visuelle |
| RM-121 | Illustrations et Plan 3D adaptes sur mobile (conserves, non remplaces arbitrairement), consultation agrandie disponible | Mission refonte mobile premium 15/11 | IMPLÉMENTÉ MAIS NON VÉRIFIÉ | Assets KPI/Plan 3D existants conserves ; `_Plan3DPanel` recoit `phone` pour scene plus lisible, actions Vue 3D/Plein ecran conservees (`openPlanFullScreen`, `PharmacyPlanPage`) ; cartes KPI et images inchangees dans leur logique | Verification visuelle/recadrage fin requise sur appareils reels | P1 | Validation proprietaire (illustrations non coupees, Plan 3D lisible) |
| RM-122 | Tablettes (600-1149 px) : comportement adapte (bottom nav, pas de sidebar imposee, KPI 2-3 colonnes) | Phase 4 | CONFORME ET VÉRIFIÉ | `responsive_smartphone_test.dart` + `sales_intelligence_pages_test.dart` (768x1024) : 24 tests ciblés PASS, suite complète 278 PASS | Automatisme vérifié ; validation visuelle physique reste RM-111 | P1 | — |
| RM-123 | Desktop >= 1150 px : apparence et fonctionnalites preservees (sidebar, top bar, KPI 4 colonnes, Alertes+Plan3D, POS lateral) | Phase 4 | CONFORME ET VÉRIFIÉ | Suite complète `flutter test` 278 PASS / 9 skip ; captures shell PC 1440x900 dans `captures_phase4/` ; `pos_page_protection_test.dart` PASS | `dart analyze lib test` : 0 erreur | P0 | — |
| RM-124 | Tests geometriques et matrice requise (14 resolutions + paysage smartphone), reproductibles depuis le depot | Phase 4 | CONFORME ET VÉRIFIÉ | `flutter test test/responsive_smartphone_test.dart test/mobile_nav_kpi_test.dart test/stock_table_ui_test.dart test/dashboard_kpi_test.dart` → 24 PASS ; matrice 320x568..1920x1080 + paysages exécutée | Suite complète 278 PASS / 9 skip | P0 | — |
| RM-125 | POS et Supabase intacts (aucune modification metier/donnees/schema/API sans autorisation) | Mission refonte mobile premium 15/11 | CONFORME ET VÉRIFIÉ (code local) | Aucun fichier sous `frontend/lib/features/pos/` modifie dans cette mission ; aucune migration SQL, donnee, Auth, Storage, RLS, Edge Function ou appel API modifie ; changements limites a shell/dashboard/navigation mobile et tests/docs | Defaut preexistant connu inchange : `pos_panel.dart:1548` (5.4 px), `pos_page_render_test.dart` factice | P0 | Controle git avant tout commit |
| RM-126 | Permissions, roles, modules et donnees preservees (pas de fausses donnees, pas de fonctionnalite supprimee) | Mission refonte mobile premium 15/11 | IMPLÉMENTÉ MAIS NON VÉRIFIÉ | Filtrage conserve via `AuthStore.hasPermission` + `AuthStore.canSeeModule` ; `visibleAppSideNavItems()` source unique pour sidebar PC et menu mobile ; bottom bar filtree (permission `sales:view` pour POS, modules stock/suppliers/profit) ; `ModulesPage` inchange | Tests croises de roles/permissions non executes dans cette session | P1 | Tests avec profils a permissions restreintes |
| RM-127 | Analyse statique des fichiers modifies (lib + tests modifies) | Mission refonte mobile premium 15/11 | IMPLÉMENTÉ MAIS NON VÉRIFIÉ | `dart analyze` cible sur `mobile_nav.dart`, `home_shell.dart`, `app_side_menu.dart`, `dashboard_page.dart` : 0 erreur, 4 infos `prefer_const_constructors` sur lignes preexistantes ; analyse etendue incluant tests modifies interrompue/timeout dans l'environnement | Pas de `flutter analyze`/`dart analyze` global complet consigne avec succes | P2 | Executer `dart analyze lib` et `dart analyze test` complet |
| RM-128 | Execution complete `flutter test`, `flutter build web --release` | Phase 4 | CONFORME ET VÉRIFIÉ | `flutter test` → `02:49 +278 ~9: All tests passed!` ; `flutter build web --release --no-wasm-dry-run` → `√ Built build\web` (172,9 s) | Blocage OOM levé dans l'environnement courant | P0 | — |
| RM-129 | Validation physique smartphone/tablette par le proprietaire | Mission refonte mobile premium 15/11 | BLOQUÉ | Non effectuee (interdite a declarer sans test reel) | Acces appareil et validation humaine requis | P1 | Test proprietaire sur appareils reels (portrait/paysage) |
| RM-130 | Documentation mission (RM, SUIVI, rapport final) mise a jour sans perte d'historique | Mission refonte mobile premium 15/11 | IMPLÉMENTÉ MAIS NON VÉRIFIÉ | RM : RM-110/RM-114 requalifies, RM-117..RM-130 ajoutes, resume/historique mis a jour ; SUIVI : section §26 ajoutee (historique preserve) ; rapport final fourni dans la reponse | Coherence finale a relire apres execution des tests en environnement stable | P2 | Relecture croisee RM/SUIVI/rapport apres resultats de tests |

## RÉSUMÉ STATISTIQUE

| Statut | Nombre |
|---|---|
| CONFORME ET VÉRIFIÉ | 56 |
| IMPLÉMENTÉ MAIS NON VÉRIFIÉ | 58 |
| PARTIEL | 3 |
| ABSENT | 12 |
| DÉFAILLANT | 0 |
| BLOQUÉ | 1 |
| NON DOCUMENTÉ | 0 |
| **TOTAL** | **130** |

Notes :
- 109 exigences d'origine (RM-001 à RM-109) + 7 nouvelles (RM-110 à RM-116) = 116. Le résumé précédent (51/42/3/12 = 108 pour 109 lignes) était arithmétiquement incohérent : recomptage réel des 109 lignes d'origine = 52 CONFORME ET VÉRIFIÉ, 41 IMPLÉMENTÉ MAIS NON VÉRIFIÉ + 1 variante sans accents, 3 PARTIEL, 12 ABSENT. Les variantes qualifiées restent normalisées en statuts standards sans perte d'information (colonne Écart).
- **Mise à jour 15/11/2026 (refonte mobile premium)** : RM-110 et RM-114 requalifiés (CONFORME ET VÉRIFIÉ → IMPLÉMENTÉ MAIS NON VÉRIFIÉ, preuves non reproductibles/conservées). Ajout des exigences RM-117 à RM-130 (14 nouvelles) documentant l'architecture mobile/tablette, les tests de géométrie et la préservation PC/POS/Supabase. Totaux ajustés : 56 + 58 + 3 + 12 + 0 + 1 + 0 = 130.

---

## HISTORIQUE DE MISE À JOUR

| Date | Action | Fichiers | Référence |
|---|---|---|---|
| 08/11/2026 | Création inventaire initial (37 domaines) | `SUIVI_TOUS_LES_PROBLEMES_PHARMA_PLUS.md` | Commit 5fed106 |
| 11/11/2026 | Thème marbre gris argenté + CI verte | Suivi §14.14-14.15 | Commit 97a32d8 |
| 12/11/2026 | KPI clairs détourés + mini POS marbre + plan 3D | Suivi §14.17 | Commit 97a32d8 |
| 12/11/2026 | Fond sombre image pharmacie + tokens adaptatifs | Suivi §14.18 | Commit 94e3e5e |
| 12/11/2026 | Fond dashboard = image pharmacie | Suivi §14.18 (suite) | Commit 2fedf30 |
| 12/11/2026 | Illustration employé v6 (fondu réduit) | Suivi §14.18 (suite) | Commit 8873cb1 |
| 12/11/2026 | Annulation lightScale (débordement) | Suivi §14.18 (suite) | Commit d542b98 |
| 12/11/2026 | Illustration employé réduite (0.50/0.85) | Suivi §14.18 (suite) | Commit d62f03b |
| 12/11/2026 | Ombre KPI réduite sur smartphone | Suivi §14.18 (suite) | Commit e2f85a4 |
| 13/11/2026 | Audit global (lecture seule) | `RAPPORT_AUDIT_GLOBAL_PHARMA_PLUS.md` | — |
| 13/11/2026 | Vérification nouveau menu/fournisseurs/IA | `RAPPORT_VERIFICATION_NOUVEAU_MENU_FOURNISSEURS_IA_PHARMA_PLUS.md` | — |
| 13/11/2026 | Consolidation RM-PHARMA+ | `RM_PHARMA_PLUS_REGISTRE_MAITRE.md` (ce fichier) | - |
| 14/11/2026 | Mission responsive reelle (33 pages x 13 tailles, 10 debordements corriges) | Suivi §25 ; 10 fichiers `lib` + 3 tests | Non commité (HEAD b522766) |
| 14/11/2026 | Registre : RM-110 a RM-116 + correction du resume statistique | `RM_PHARMA_PLUS_REGISTRE_MAITRE.md` (ce fichier) | Non commité |
| 15/11/2026 | Requalification preuves non reproductibles | RM-110, RM-114 requalifies (preuve « 429 rendus » non conservee) ; resume recalcule | Non commité (HEAD b522766) |
| 15/11/2026 | Refonte mobile premium (shell + dashboard) | `mobile_nav.dart` (nouveau), `home_shell.dart`, `app_side_menu.dart`, `dashboard_page.dart` ; tests `responsive_smartphone_test.dart`, `mobile_nav_kpi_test.dart` mis a jour | Non commité (HEAD b522766) ; POS/Supabase intacts |
| 15/11/2026 | Registre : RM-117 a RM-130 + documentation SUIVI §26 | `RM_PHARMA_PLUS_REGISTRE_MAITRE.md`, `SUIVI_TOUS_LES_PROBLEMES_PHARMA_PLUS.md` | Non commité ; execution tests/build bloquee (environnement) |

---

## BLOCAGES DE VALIDATION (distincts des statuts d'exigence)

Les blocages suivants empêchent la validation complète de certaines exigences, mais ne changent pas leur statut d'implémentation :

| Blocage | Exigences concernées | Accès/autorisation nécessaire |
|---|---|---|
| Accès Supabase production (pas de CLI/credentials) | RM-009, RM-023, RM-027, RM-030, RM-033, RM-035, RM-036, RM-038, RM-042, RM-043, RM-046, RM-048, RM-053, RM-054, RM-055, RM-056, RM-057, RM-058, RM-059, RM-061, RM-063, RM-064, RM-079, RM-080 | Accès lecture seule Supabase |
| Données utilisateur réelles manquantes | RM-021 (incident Fournisseurs) | Reproduction contrôlée + logs /auth/me |
| DATABASE_URL indisponible | Tests backend (37 fichiers) | Base PostgreSQL accessible |
| Validation visuelle Ctrl+F5 non effectuée | RM-012, RM-013, RM-014, RM-015, RM-071, RM-072 | Propriétaire |
| Accès GitHub Actions détaillé (rate limit) | Vérification CI fine | Token GitHub authentifié |
| Scanner HID matériel absent | RM-026 | Scanner USB physique |
| deno CLI non confirmé | Edge Function check | Installation deno |
| Validation visuelle sur smartphone physique non effectuee (tests automatises uniquement) | RM-111 | Proprietaire + appareil reel |
## SOURCES MANQUANTES

- **RM-PHARMA+ — Registre maître des exigences, décisions et preuves** : absent du dépôt. Reconstitué à partir du suivi + rapports.
- **RM-PHARMA+ — Mémoire de continuité et rappel du Prompt Mega OpenCode** : absent du dépôt.
- **Texte intégral des anciens prompts** (05/10/2026, 30/10/2026) : non retrouvé. Traces disponibles via git log et suivi.

---

## DÉCISIONS NÉCESSAIRES DE L'UTILISATEUR

1. Valider visuellement en production (Ctrl+F5) le thème PHARMA+ final.
2. Décider si les endpoints IA manquants (`/ai/suppliers/*`, `/ai/customers/*`, `/ai/hr/analyze`) doivent être implémentés ou retirés du frontend.
3. Décider si les connexions fournisseurs temps réel doivent être développées (config manuelle requise).
4. Clarifier le contrat `visible_modules` (null vs []) côté backend.
5. Reproduire l'incident Fournisseurs avec données utilisateur réelles.
6. Décider de l'architecture backend de référence (Node vs Edge Function).
7. Valider le portail patient et les préparations pharmaceutiques (absents) pour une mission future.
---

## Mise a jour registre - 15/11/2026 (mission restauration smartphone, audit historique)

- **Contexte** : mission de restauration de l'interface smartphone d'origine (Splash, Connexion, Dashboard/8 KPI, Menu/navigation) basee sur historique Git. Aucune modification applicative effectuee ; aucun commit/push/deploiement ; POS et Supabase intacts.
- **RM-117 a RM-130 (refonte mobile locale existante, non commitee)** : statuts maintenus **IMPLEMENTE MAIS NON VERIFIE** (implementation locale presente dans l'arbre de travail, mais aucune validation automatisee complete ni capture reelle produite en environnement contraint).
- **Nouveau constat (RM note)** : reference historique unique "fonctionnelle smartphone" **NON PROUVEE** par le depot (absence de captures/version visuelle archivee exploitable, evolution multi-etapes). Exigences explicites actuelles (barre 4 acces POS/Stock/Fournisseur/Benefice, splash HTML barre 0-100% sans cercle, pas de 2e splash Flutter, pas de panneau POS lateral en compact) : **PARTIELLEMENT ALIGNEES EN CODE (etat local)** mais **NON VERIFIEES** visuellement/en execution.
- **Preuves** : rapport RESTAURATION_INTERFACE_SMARTPHONE_ORIGINALE_PHARMA_PLUS.md (cree), entree SUIVI section 28, audit Git (logs/follow/show). Tests/captures/build/analyze execution : **NON EXECUTES** (OOM/VirtualAlloc 1455/threads DartWorker/ressources insuffisantes).
- **Blocages** : validation visuelle multi-dimensions, tests fonctionnels/runtime, identification definitive de la reference historique, stabilisation environnement Windows pour Flutter/Dart.


---

## Mise a jour registre - 15/11/2026 (mission adaptation responsive smartphone/tablette, themes clair/sombre)

- **Phase 0** : audit realise (themes `AppTheme` clair/sombre + `colors.dart`, tokens paralleles `design_tokens.dart`, `AuthStore.themeMode` system/light/dark, `main.dart` ; responsive heterogene `responsive.dart` 600/1200/1920 + breakpoints ad hoc 760/1150/980/1300 ; shell local mobile `<1150` avec 4 acces primaires + drawer "Tous les modules" ; couleurs codees en dur nombreuses ; etat Git/local preserve).
- **Correctif applique** : `frontend/lib/features/auth/login_page.dart` `_ThemeToggle` ne assimile plus `ThemeMode.system` au mode sombre (luminosite effective). Statut : **IMPLEMENTE MAIS NON VERIFIE** (runtime).
- **Phases 1-6, 9-10** : adaptation responsive centralisee, couverture exhaustive modules/tablettes/paysage/RTL, harmonisation themes, tests/captures/analyze/build **NON REALISES / BLOQUES** (environnement Flutter/Dart non executable : OOM, VirtualAlloc 1455, threads DartWorker). Statut : **PARTIEL/ABSENT/BLOQUE** selon items (voir `RAPPORT_ADAPTATION_RESPONSIVE_SMARTPHONE_TABLETTE_PHARMA_PLUS.md`).
- **Phases 7-8 (protections)** : **CONFORME ET VERIFIE (session)** â€” aucun fichier POS modifie, aucune modification Supabase/Auth/RLS/tables/Storage/Edge Functions/API/donnees/migrations/commandes.
- **Livrables** : `RAPPORT_ADAPTATION_RESPONSIVE_SMARTPHONE_TABLETTE_PHARMA_PLUS.md`, SUIVI section 29.
- **Conclusion registre** : mission responsive/themes **NON TERMINEE AU SENS VERIFIEE** ; autorisation distincte requise avant poursuite/commit/push/deploiement.


---

## Mise a jour registre - 15/11/2026 (reprise implementation responsive complete, continuation)

- **Etat initial controle** : HEAD `b5227663d39e397762c0fe9576b866686ce88670`, 19 modifies suivis / nombreux non suivis (travail local preserve). POS diff/cache/status : vides.
- **Phase 1** : `responsive.dart` etendu additivement (repere 320-359/360-430/431-599/600-767/768-1023/1024-1149/>=1150, orientation, SafeArea/clavier, helpers largeur/padding/gaps, compat API existante). Statut : **IMPLEMEMENTE PARTIELLEMENT** (adoption globale widgets/modules non faite).
- **Phases 2-7** : correctif `ThemeMode.system` conserve ; adaptations themes/splash/connexion/dashboard/navigation/modules/RTL restees partielles ou non exhaustives. Statuts : **PARTIEL / ABSENT** selon exigences.
- **Phase 10 (partiel)** : `dart format` execute sur fichiers touches avec succes ("Formatted 2 files (1 changed) in 0.24 seconds"). `dart format --set-exit-if-changed lib`, `dart analyze lib`, `flutter test`, `flutter build web --release` : **NON EXECUTES** (blocage environnement). Statut validation : **BLOQUE**.
- **Phases 7-8 protections** : **CONFORME ET VERIFIE (session)** â€” POS et Supabase/backend intacts.
- **Preuves** : SUIVI section 30, controles git POS, rapport `RAPPORT_ADAPTATION_RESPONSIVE_SMARTPHONE_TABLETTE_PHARMA_PLUS.md` (a completer pour detail exhaustif par module/test si poursuite). Mission **NON TERMINEE AU SENS VERIFIEE**.


---

## Mise Ã  jour registre - 15/11/2026 (Mission NÂ°5 â€” audit/finalisation smartphone, continuation)

- **Audit initial** : HEAD `b522766`, branche `main` vÃ©rifiÃ© ; travail local prÃ©existant conservÃ© (suivis modifiÃ©s + non suivis, formatage global appliquÃ© en session) ; `frontend/lib/features/pos/**` sans diff/statut ; aucune modification Supabase/backend/Auth/RLS/donnÃ©es/migrations/API/config ; aucun commit/push/dÃ©ploiement/commande destructive.
- **Corrections rÃ©alisÃ©es** : `catalog_page.dart` (en-tÃªte compact hauteur `<520`, filtres scroll horizontal) â€” test ciblÃ© `responsive_smartphone_test` Â« Catalogue : cartes <600 px ou hauteur <520, tableau sinon Â» **CONFORME ET VÃ‰RIFIÃ‰** (`00:16 +1`) ; `users_management_page.dart` (filtres statut scroll horizontal, formulaire nom/prÃ©nom adaptatif `<420`) ; `role_management_page.dart` (dialogue matrice permissions adaptatif Ã©cran/clavier, scroll, actions `Wrap`) â€” **IMPLÃ‰MENTÃ‰ MAIS NON VÃ‰RIFIÃ‰** (runtime).
- **Ã‰tat smartphone global** : navigation 4 accÃ¨s + Â« Tous les modules Â» prÃ©sente cÃ´tÃ© code ; adaptations partielles sur plusieurs modules (dashboard/stock/fournisseurs/achats/bÃ©nÃ©fice/clients/employÃ©s/catalogue, etc.) ; rapports/paramÃ¨tres/notifications/super-admin/utilisateurs-rÃ´les et modules secondaires/admin **PARTIELS ou NON VÃ‰RIFIÃ‰S** Ã©cran par Ã©cran ; Splash/chargement dÃ©diÃ© non identifiÃ© comme page sÃ©parÃ©e (flux app) ; POS mobile dÃ©pend de `frontend/lib/features/pos/**` **protÃ©gÃ©** (adaptations nÃ©cessitant cette zone **BLOQUÃ‰ES**).
- **QualitÃ© (connu)** : `dart format lib` exÃ©cutÃ© (reformatage large) ; `dart analyze lib` ~393 issues (0 error, 79 warning, 314 info observÃ©s) ; `flutter test` complet dernier connu `+222 ~9 -1`, build web dernier connu OK avec avertissements â€” validations complÃ¨tes finales (`format --set-exit-if-changed`, analyze/test/build verts) et preuves runtime/captures/matrices/thÃ¨mes/RTL **NON TERMINÃ‰ES** (contraintes environnement).
- **Statut** : mission affichage smartphone **PARTIELLE / NON TERMINÃ‰E AU SENS VÃ‰RIFIÃ‰** ; `SUIVI_TOUS_LES_PROBLEMES_PHARMA_PLUS.md` section 35 ajoutÃ©. Validation finale utilisateur requise.


---

## Mise Ã  jour registre - 15/11/2026 (Mission NÂ°5 â€” corrections directes complÃ©mentaires, validations partielles)

- **Corrections** : rapports (filtre dates compact <420), notifications (action app bar compacte <430), paramÃ¨tres (grille cartes 1 col <360 + ratio adaptÃ©), dialogues formulaire client/employÃ©/commande (insets + hauteur max mobile), en complÃ©ment des correctifs prÃ©cÃ©dents (catalogue 568Ã—320 vÃ©rifiÃ©, users/roles).
- **Validations** : `dart format lib` + `dart format --output=none --set-exit-if-changed lib` **OK** (exit 0) ; test ciblÃ© catalogue responsive **OK** ; `dart analyze lib` **400 issues** (exit 2, majoritairement infos/lints) ; `flutter test` complet et `flutter build web --release` **non exÃ©cutÃ©s Ã  terme** (contraintes environnement).
- **Reste non vÃ©rifiÃ©** : matrices/rÃ©solutions complÃ¨tes + runtime/captures, tous modules/actions/formulaires/dialogues/clavier, KPI/navigation sans blocage, mini-POS PC, thÃ¨mes clair/sombre/systÃ¨me, RTL fr/ar/en, fluiditÃ©, qualitÃ© au vert complet.
- **BloquÃ©** : modifications requÃ©rant `frontend/lib/features/pos/**`.
- **Protections** : POS/Supabase/backend intacts ; aucun commit/push/dÃ©ploiement. Statut global : **PARTIEL / NON TERMINÃ‰ AU SENS VÃ‰RIFIÃ‰** (validation finale utilisateur requise).


---

## Mise Ã  jour registre - 15/11/2026 (Mission finale â€” derniÃ¨res corrections directes smartphone)

- **Corrections** : `settings_page.dart` (_PharmacyEditDialog et _AddUserDialog : insetPadding clavier) ; complÃ¨tent les correctifs prÃ©cÃ©dents (catalogue 568Ã—320 vÃ©rifiÃ©, rapports, notifications, paramÃ¨tres, utilisateurs/rÃ´les, dialogues clients/employÃ©s/achats/fournisseurs).
- **Validations** : `dart format` fichiers modifiÃ©s OK ; test ciblÃ© catalogue responsive OK ; `dart format --output=none --set-exit-if-changed lib` non vert uniquement Ã  cause de `pos/pos_page.dart` (zone protÃ©gÃ©e, non modifiÃ©e) ; `dart analyze lib` timeout (env.) ; `flutter test` complet et `flutter build web --release` non rÃ©-exÃ©cutÃ©s Ã  terme (timeouts).
- **Protections** : POS intact (git status/diff vides vs HEAD) ; aucun changement backend/Supabase ; aucun commit/push/dÃ©ploiement. Travail local/non suivis prÃ©servÃ©s.
- **Statut global** : smartphone **partiellement corrigÃ© et testÃ© ciblÃ©ment** ; **non terminÃ© au sens vÃ©rifiÃ©** (quality gate complet, preuves runtime, matrices rÃ©solutions, thÃ¨mes/RTL Ã©cran par Ã©cran, mini-POS PC non atteints). Validation finale utilisateur requise.
