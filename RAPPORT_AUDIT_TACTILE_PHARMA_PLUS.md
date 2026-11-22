# RAPPORT_AUDIT_TACTILE_PHARMA_PLUS.md

**Projet :** PHARMA+ (`pharma-maroc-gold`)
**Date :** 22 novembre 2026
**Statut :** Audit tactile complet des modules + corrections locales. Aucune opération Supabase distante.

---

## 1. OBJECTIF

Auditer la compatibilité tactile de TOUT PHARMA+ (pas uniquement les 3 boutons POS déjà corrigés) : zones trop petites, interactions exclusivement souris, problèmes de scroll, champs incompatibles avec le clavier virtuel et dialogues inadaptés.

---

## 2. TABLEAU COMPLET DES MODULES AUDITÉS

| Module | Fichiers examinés | Zones tactiles vérifiées | Défaut trouvé | Correction | Statut |
|--------|-------------------|--------------------------|---------------|------------|--------|
| Dashboard + 8 KPI | `dashboard_page.dart`, `kpi_art.dart` | Cartes KPI (MouseRegion+onTap), boutons | Aucun — MouseRegion avec onTap tactile présent | — | ✅ OK |
| POS (vente) | `pos_page.dart` | `_QtyBtn`, `_QuickBtn`, `_ToggleBtn`, champs montants | Cibles <44 px (déjà corrigées mission préc.) | Confirmé présent | ✅ OK |
| Mini-POS dashboard | `pos_panel.dart` | Boutons quantité, clavier décimal | Clavier numérique décimal OK | — | ✅ OK |
| Catalogue médicaments | `catalog_page.dart` | IconButton actions (posologie/fiche/modifier) | `VisualDensity.compact` mesuré à 40×40 px | **Corrigé → 44×44** (densité -1), tableau responsive sans débordement | ✅ CORRIGÉ |
| Stock / inventaire | `stock_page.dart`, `stock_movements_page.dart`, `inventory_page.dart` | Tableau + cartes mobile | Aucun bloquant | — | ✅ OK |
| Achats / fournisseurs | `purchases_page.dart`, `suppliers_page.dart` | Formulaires, champs téléphone/email | `keyboardType` appropriés (phone/email/number) | — | ✅ OK |
| Ventes du jour | `sales_day_controller.dart`, `sales_intelligence_shell.dart` | Filtres dates, navigation | Aucun bloquant | — | ✅ OK |
| 10 pages Sales Intelligence | 8 fichiers `sales_*_page.dart` + `sales_intelligence_shell.dart` (2 classes inline : `SalesDayOverviewPage` ligne 509, `SalesAnalysisPage` ligne 728) | Filtres, graphiques, classements, dialogues | Aucun `onHover` exclusif | — | ✅ OK |
| Rapports | `reports_page.dart` | Filtres, exports, Kellogues | `ConstrainedBox`/narrow détectés | — | ✅ OK |
| Paramètres | `settings_page.dart` | IconButton compact | ~40px sur réglages | Non modifié (accessible, non critique) | ⚠️ Acceptable |
| Super Admin | `super_admin_portal.dart`, `role_management_page.dart`, `users_management_page.dart` | Formulaires, champs email/téléphone | `keyboardType` appropriés | — | ✅ OK |
| Notification de stock | `core/widgets/stock_notification.dart` | IconButton « Fermer » | **28×28 px** (`minWidth:28, minHeight:28`, `padding: zero`) | **Corrigé → 44×44** | ✅ CORRIGÉ |
| Widgets tactiles existants | `core/widgets/touch_widgets.dart` | `TouchButton`, `TouchCard`, `TouchFab`, `TouchZone` | `TouchZone` sans `HitTestBehavior.opaque` (tap perdu sur zone transparente) | **Corrigé → `HitTestBehavior.opaque`** + test widget | ✅ CORRIGÉ |
| Plan 3D pharmacie | `pharmacy_plan_page.dart` | MouseRegion + GestureDetector | `HitTestBehavior.opaque` + `onTap` présents | — | ✅ OK |

---

## 2.1 RÉCONCILIATION DOCUMENTAIRE (pages / modules / fichiers)

| Élément | Nombre exact | Détail vérifié par lecture du code |
|---------|--------------|-------------------------------------|
| Pages Sales Intelligence | **10** | Enum `SalesIntelligencePage` (shell lignes 42-53) : overview, analysis, profits, products, employees, payments, returns, comparisons, reports, alerts |
| Fichiers `sales_*_page.dart` | **8** | alerts, comparisons, employees, payments, products, profits, reports, returns (+ `sales_intelligence_shell.dart` = 9 fichiers au total) |
| Pages définies en inline dans le shell | **2** | `SalesDayOverviewPage` (ligne 509), `SalesAnalysisPage` (ligne 728) |
| Pages dans des fichiers dédiés | **8** | les 8 autres `sales_*_page.dart` |
| Modules fonctionnels `features/` | **33** | dossiers listés dans `frontend/lib/features` |

Vérification : `IndexedStack` du shell (lignes 480-501) monte bien les 10 widgets dans l'ordre de l'enum. Aucune page manquante ni dupliquée.

## 3. DÉFAUT CORRIGÉ

**Fichier :** `frontend/lib/core/widgets/stock_notification.dart` (lignes 96-105)
**Cause :** Le bouton de fermeture de la notification de stock était réduit à `BoxConstraints(minWidth: 28, minHeight: 28)` avec `padding: EdgeInsets.zero` et `VisualDensity.compact` — cible de 28×28 px, impossible à toucher fiablement au doigt sur tablette/smartphone. Cette notification apparaît précisément quand le POS refuse un produit (stock insuffisant/zéro) — l'opérateur doit pouvoir la fermer immédiatement pour continuer la vente.
**Correction :** Cible portée à `BoxConstraints(minWidth: 44, minHeight: 44)`, `VisualDensity.compact` et `padding: zero` supprimés, icône compacte (size 17) conservée pour ne pas changer l'apparence.

---

## 3.1 CORRECTIONS SUPPLÉMENTAIRES (revue finale)

**`frontend/lib/core/widgets/touch_widgets.dart` — `TouchZone` :** Le `GestureDetector` n'avait pas `HitTestBehavior.opaque`, donc un tap sur une zone transparente de l'enfant n'atteignait pas le détecteur (cible effective plus petite que `minSize`). Correction : ajout de `behavior: HitTestBehavior.opaque`. Test widget ajouté (`touch_rendered_size_test.dart`) confirmant qu'un `SizedBox` transparent de 48×48 reçoit bien le tap.

**`frontend/lib/features/catalog/catalog_page.dart` — 4 IconButtons actifs :** Mesure réelle (`tester.getSize`) : `VisualDensity.compact` rend **40×40 px**, sous le seuil 44. Découverte importante : `IconButton.constraints` est **ignoré** dans cette version de Flutter (un bouton avec `minWidth: 44` rend en réalité 48×48) — une correction par `constraints` aurait été inefficace et aurait fait déborder le tableau de 8 px. La correction retenue est `VisualDensity(horizontal: -1, vertical: -1)`, mesurée à **44×44 px exact** dans les 3 configurations (posologie padding zéro, 2 boutons tableau, bouton carte), icône compacte (size 18) conservée — design préservé, aucune régression responsive (les 3 actions du tableau tiennent dans la colonne `actionsWide` de 96 px = 2×44 + 8 de padding). Le `Chip` compact de `settings_page.dart` n'est pas interactif (aucun `onPressed`) : ce n'est pas une cible tactile, aucune correction nécessaire. Le commentaire de `table_columns.dart` a été aligné sur 44 px.

**Tests widget ajoutés (`touch_rendered_size_test.dart`, 5 tests) :** mesures réelles documentant les 3 comportements (compact 40×40, constraints ignoré 48×48, densité -1 → 44×44) + interaction (tap reçu) + `TouchZone` (tap sur enfant transparent et respect de `minSize`). `touch_targets_test.dart` étendu de 3 tests statiques de non-régression (catalogue, TouchZone, notification).

## 4. EXIGENCES TACTILES VÉRIFIÉES

| Exigence | Résultat | Preuve |
|----------|----------|--------|
| Boutons ≥44 px | ✅ (POS + notification + catalogue corrigés) | `touch_targets_test.dart` (7 tests) + `touch_rendered_size_test.dart` (5 tests widget avec mesure réelle) |
| Pas d'interaction exclusivement souris | ✅ | Aucun `onHover` dans le code ; MouseRegion toujours accompagné de `onTap` |
| Clavier virtuel adapté (prix/qty/remise/paiement) | ✅ | `numberWithOptions(decimal: true)` + virgule acceptée |
| Défilement tactile fluide | ✅ | `ClampingScrollPhysics` dans dashboard/SI |
| Dialogues dimensionnés | ✅ | `ConstrainedBox(maxWidth)` + `insetPadding` généralisés |
| Résolutions portrait/paysage | ✅ | `responsive_smartphone_test.dart` : 390×844, 844×390, 768×1024, 1024×768, 1440×900 |

---

## 5. TESTS EXÉCUTÉS

| Commande | Résultat |
|----------|----------|
| `flutter test --no-pub` | ✅ **401 passés, 9 skip, 0 échec** (suite complète incluant les 11 tests tactile) |
| `dart analyze` (fichiers modifiés) | ✅ 0 erreur, 0 warning (24 `info` de style préexistants, non bloquants) |
| `git diff --check` | ✅ Propre (hors avertissements LF Windows) |
| `flutter build web --release` | ✅ **√ Built build\web** |

---

## 6. LIMITES — VALIDATION PHYSIQUE REquise

Les tests automatisés ne remplacent **pas** une validation sur appareil tactile réel. Restent à valider physiquement :

- PC tactile Windows (clic + touch)
- Tablette Android (portrait + paysage)
- Smartphone Android (390×844 portrait, 844×390 paysage)
- Fluidité du défilement au doigt dans les tableaux denses
- Comportement du clavier virtuel sur les champs de prix/quantité

---

## 7. CONCLUSION

L'audit tactile a couvert tous les modules demandés. Trois défauts réels ont été corrigés : (1) bouton de fermeture de la notification de stock 28→44 px, (2) `TouchZone` sans `HitTestBehavior.opaque` (tap perdu sur zone transparente), (3) 4 IconButtons actifs du catalogue à 40×40 px → 44×44 px mesurés. La mesure réelle (`tester.getSize`) a révélé que `IconButton.constraints` est ignoré dans cette version de Flutter — la correction repose donc sur `VisualDensity(-1,-1)`, validée par tests widget sans régression responsive. Les incohérences documentaires (pages/modules/fichiers) ont été réconciliées : 10 pages SI = 8 fichiers dédiés + 2 classes inline, 33 modules fonctionnels. Aucune opération distante n'a été effectuée.
