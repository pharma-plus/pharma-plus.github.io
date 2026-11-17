# PHASE 4 — CORRECTIONS CIBLÉES ET VALIDATION FINALE : SALLE INTELLIGENTE

Date : 17/11/2026 · Branche : `main` · Commit initial : `b650f259bd6a45ea3a58087c8a743841abf4bf1e`

## 1. Commit initial et état Git

- Branche vérifiée : `main` ; `git rev-parse HEAD` → `b650f259bd6a45ea3a58087c8a743841abf4bf1e`.
- `git status --short` initial : 15 fichiers `sales_day` déjà modifiés (Phase 2, non committés), deux logs `runs_latest*.json` et de nombreux fichiers non suivis préexistants. **Toutes ces modifications préexistantes ont été préservées.**
- Périmètre autorisé appliqué : uniquement `frontend/lib/features/sales_day/**`, tests associés, `RM_PHARMA_PLUS_REGISTRE_MAITRE.md` et le présent rapport/captures.
- Contrôle final : aucun fichier `frontend/lib/features/pos/**`, `pharma_background.dart`, `marble_texture.dart`, backend, Supabase, Auth, RLS ou migration modifié (`git diff --name-only` sur ces chemins : vide).
- **Aucun commit, push, merge, déploiement ni contact Supabase.**

## 2. Fichiers modifiés et justification

### Nouveaux fichiers
| Fichier | Justification |
|---|---|
| `lib/features/sales_day/services/sales_financials.dart` | Tri-état de fiabilité du coût (positif / absent / nul ambigu) — P0 |
| `lib/features/sales_day/services/sales_alerts_service.dart` | Règles pures, aucune alerte chiffrée sur coût non fiable — P0 |
| `lib/features/sales_day/widgets/sales_design_system.dart` | Design system commun (Phase 2, inchangé en Phase 4) |
| `test/sales_phase2_test.dart` | 13 tests contrôlés (finances 4 cas, alertes, pagination 250/450, isol. filtres) |
| `test/sales_phase4_exports_test.dart` | 5 tests : génération réelle et relecture des 4 formats |
| `test/sales_phase4_ranking_test.dart` | 2 tests : absence d'affordance interactive sans cible |
| `test/sales_phase4_capture_test.dart` | 23 goldens : shell complet + 10 pages, PC/tablette/smartphone |
| `captures_phase4/*.png` | 23 captures datées du 17/11/2026, commit testé `b650f25` + arbre Phase 4 |
| `RAPPORT_PHASE4_SALES_INTELLIGENCE.md` | Présent rapport |

### Fichiers existants modifiés
| Fichier | Correction |
|---|---|
| `sales_day_model.dart` | `costTotal` nullable (Phase 2, conservé) ; `null` = absent |
| `sales_financials.dart` | Coût nul/négatif = `zeroAmbiguous` → « Non vérifiable », aucun bénéfice/marge |
| `sales_profits_page.dart` | Affiche « Non disponible » / « Non vérifiable » ; plus jamais 100 % sur coût ambigu |
| `sales_alerts_service.dart` | Règle marge désactivée si coût non fiable ; message explicite |
| `sales_comparisons_page.dart` | Coût comparé uniquement si fiable des deux côtés ; avis sinon |
| `sales_products_page.dart` | Avertissement coût ambigu affiché |
| `sales_export_service.dart` | Périmètre exporté explicite, coût ambigu tracé, **écriture réelle du XLSX** (`downloadBytes`) |
| `sales_day_controller.dart` | `fullRows` isolé des filtres `txStatus`/`_search` ; clé de cache = période seule ; `fullScopeLabel` |
| `sales_repository.dart` | Parcours complet de pagination (Phase 2, conservé) |
| `sales_employees_page.dart`, `sales_returns_page.dart`, `sales_reports_page.dart`, `sales_intelligence_shell.dart` | Périmètre explicite affiché ; cartes d'export désactivées visuellement |
| `sales_product_ranking.dart` | `InkWell` uniquement si un callback existe ; sinon présentation non interactive |
| `sales_hourly_chart.dart` | Alignement maquette : courbe or, points, aire dégradée (tooltip conservé) |
| `RM_PHARMA_PLUS_REGISTRE_MAITRE.md` | 9 lignes mises à jour avec preuves |

## 3. Corrections effectuées

### P0 — Fiabilité financière
- Origine tracée : `local_backend/server.js` L202–211 calcule `costTotal += med ? qty * price_purchase : 0`. Le `0` est donc **un défaut de la source**, indistinguable d'un coût réellement nul.
- Décision appliquée : `cost > 0` seul est fiable ; `null` → « Non disponible » ; `0`/négatif → « Non vérifiable ». Aucun bénéfice ni marge n'est calculé dans ces deux derniers cas.
- Alertes : aucune alerte chiffrée de marge si coût non fiable ; alerte informative « Marge brute non vérifiable ».
- Exports : ligne « Fiabilité de la marge » ajoutée quand le coût n'est pas fiable.

### P0 — Isolation des filtres
- `txStatus` et `_search` restent dans le tableau de la vue générale ; le jeu complet est désormais chargé avec `status:''`, `search:''` et une clé de cache basée sur la période seule.
- Employés, retours, analyse « Quantités » et les 4 exports partagent le même périmètre explicite, affiché à l'écran (`fullScopeLabel`) et inséré dans chaque fichier.
- Si la pagination échoue ou dépasse la limite, `fullComplete = false` : les exports et agrégations sont refusés, jamais présentés comme complets.

### P1 — Classements
- Aucune fiche produit n'existe dans le module : l'`InkWell` sans action a été supprimé. Le widget reste réutilisable avec un vrai callback (testé).

### P1 — Exports
- Défaut réel découvert et corrigé : `excel.save()` du package `excel` 4.0.6 **renvoie les octets mais n'écrit pas de fichier sur desktop/mobile** (`SavingHelper.client_save_excel.dart`). `downloadBytes()` est désormais appelé.
- Les 4 formats sont réellement générés puis relus par les tests : PDF (`%PDF`), Word/CSV (BOM + contenu), XLSX (`PK`). Le périmètre et la période figurent dans chaque fichier.

### P1 — Maquette
- Corrections non ambiguës appliquées : courbe or avec points et aire dégradée (captures `shell_*` et `01_vue_generale_*`).
- Classement des autres écarts : voir §9 (arbitrage propriétaire requis).

## 4. Tests — commandes et sorties exactes

| Commande | Sortie |
|---|---|
| `dart analyze lib test` | **0 erreur**, 69 warnings (préexistants : super_admin, doublon `sales_analysis_page.dart`, 3 `!` superflus dans `sales_day_module_test.dart`) |
| `flutter test test/sales_phase2_test.dart` | `00:00 +13: All tests passed!` |
| `flutter test test/sales_phase4_exports_test.dart` | `00:01 +5: All tests passed!` |
| `flutter test test/sales_phase4_ranking_test.dart` | `00:01 +2: All tests passed!` |
| `flutter test test/sales_phase4_capture_test.dart` | `00:11 +23: All tests passed!` |
| `flutter test test/sales_intelligence_pages_test.dart` | `00:07 +30: All tests passed!` |
| `flutter test test/sales_day_module_test.dart` | `00:01 +22: All tests passed!` |
| `flutter test test/sales_day_repository_test.dart` | `00:01 +11: All tests passed!` |
| `flutter test test/dashboard_kpi_test.dart` | `00:07 +2: All tests passed!` |
| `flutter test test/pos_page_protection_test.dart` | `00:00 +5: All tests passed!` |
| `flutter test test/responsive_smartphone_test.dart test/mobile_nav_kpi_test.dart test/stock_table_ui_test.dart test/dashboard_kpi_test.dart` | `01:10 +24: All tests passed!` |
| **Suite complète** `flutter test` | **`03:17 +301 ~9: All tests passed!`** |

Tous les jeux de données sont contrôlés (`MockClient`, pas de réseau réel, pas de production).

## 5. Build

`flutter build web --release --no-wasm-dry-run` → `√ Built build\web` (172,9 s). Aucun déploiement effectué.

## 6. Tests échoués / non exécutables

- Aucun test automatisé en échec. Deux échecs initiaux du nouveau test d'export ont été diagnostiqués et corrigés dans le code autorisé (BOM lu comme chaîne → vérification octets ; XLSX non écrit → `downloadBytes`).
- Non exécutés par restriction : validation sur smartphone physique (RM-111), accès Supabase/production, ouverture manuelle d'un fichier dans Microsoft Excel/Word (les fichiers sont générés et vérifiés par octets/contenu, pas ouverts dans une application bureau).

## 7. Tableau RM

| RM | Exigence | Statut Phase 4 | Preuve |
|---|---|---|---|
| RM-011 | KPI Vente du jour → Salle intelligente | CONFORME ET VÉRIFIÉ | `dashboard_kpi_test` (2 PASS), entrée inchangée |
| RM-053 | 10 pages Sales Intelligence | CONFORME ET VÉRIFIÉ | 30 tests widget + suite 301 PASS ; arbitrage visuel mineur documenté |
| RM-054 | Bénéfice brut / coût réel | CONFORME ET VÉRIFIÉ | `sales_financials.dart`, 4 cas de coût testés (13 tests) |
| RM-055 | Marges, retours, paiements | CONFORME ET VÉRIFIÉ | tests contrôlés ; clôture manuelle non persistée (documentée) |
| RM-056 | Exports PDF/Word/Excel/CSV | CONFORME ET VÉRIFIÉ | 5 tests de génération réelle + relecture des fichiers |
| RM-083 | fl_chart vs CustomPainter | CONFORME ET VÉRIFIÉ | Module actif `LineChart`/`PieChart`; ancien module orphelin intact |
| RM-111 | Validation smartphone physique | BLOQUÉ | Aucun appareil réel / propriétaire requis |
| RM-122 | Tablettes | CONFORME ET VÉRIFIÉ | Matrice + 768×1024 testés (24 PASS) |
| RM-123 | Desktop | CONFORME ET VÉRIFIÉ | Suite 301 PASS, captures shell 1440×900 |
| RM-124 | Matrice 14 résolutions + paysage | CONFORME ET VÉRIFIÉ | 24 tests ciblés PASS + suite complète |
| RM-128 | Suite complète + build | CONFORME ET VÉRIFIÉ | `+301 ~9 All tests passed!`, `√ Built build\web` |

## 8. Comparaison Phase 3 → Phase 4

| Réserve Phase 3 | Phase 4 |
|---|---|
| `cost_total = 0` → marge 100 % | Corrigé : « Non vérifiable », tests dédiés |
| Filtres de vue générale polluant agrégations/exports | Corrigé : périmètre période seule, explicite, testé |
| `InkWell(onTap: null)` sur classements | Corrigé : plus d'affordance sans action |
| Exports réels non vérifiés | 4 fichiers réels générés et relus ; bug XLSX corrigé |
| Courbe maquette (or/points/aire) | Appliqué |
| RM-124/128 bloqués | Levés : 301 PASS + build OK |
| Captures isolées du shell | 3 captures shell complet ajoutées (fond émeraude visible) |
| RM-111 | Toujours BLOQUÉ |

## 9. Réserves restantes et arbitrages propriétaire

- **RM-111** : validation physique (barre de statut, clavier, défilement réel) — bloquée.
- **Arbitrage maquette** (non implémenté pour ne pas inventer la décision) :
  - donut avec total central : option recommandée = ajouter le total au centre ;
  - illustration gélule et style des barres du Top 10 : option recommandée = conserver le style actuel (déjà lisible et testé) ;
  - panneau « Alertes & Infos » en barre latérale : option recommandée = conserver la page dédiée (déjà accessible) ;
  - bascule Jour/Semaine/Mois : fonction équivalente assurée par le filtre de période global ; à confirmer par le propriétaire.
- Clôture de caisse : saisie locale non persistée, explicitement documentée dans l'UI.
- Anciens modules orphelins (`features/sales/sales_of_day_page.dart`, `sales_analysis_page.dart`) conservés : aucune suppression sans autorisation spécifique.
- Captures : le harnais Flutter substitue les polices (texte en blocs) ; elles prouvent la structure et le fond émeraude, pas la typographie finale ni un rendu physique.
- Aucune donnée de production n'a été consultée ni validée.

## 10. Contrôles exigeant le propriétaire, un appareil ou un accès externe

1. Test sur smartphone physique (RM-111).
2. Ouverture manuelle des fichiers exportés dans un lecteur bureau (PDF/Word/Excel) et contrôle visuel des accents.
3. Validation sur données réelles Supabase (lecture seule autorisée par le propriétaire) — aucun contact effectué ici.
4. Décision sur les quatre écarts de maquette listés en §9.
5. Commit/push/déploiement — explicitement non effectués, en attente de l'accord final.
