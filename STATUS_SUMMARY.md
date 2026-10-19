# PHARMA+ Project Status Summary

## 1. Backend Status
- **_logAction calls**: 6 calls to the `_logAction` function in `supabase/functions/pharma-api/index.ts:266`
- **/stock/adjustments route**: Defined at line 856 (`/stock/adjustments`: `stock_movements`), used from `frontend/lib/features/stock/stock_page.dart:189`

## 2. Dart Analyze Status
- **Issues resolved**: 0 (analysis passes cleanly)
- **Remaining**: None - `_analyze.txt` confirms "No issues found! (ran in 126.3s)"
- Note: 40 packages are outdated (`flutter pub outdated`) but do not cause analysis failures

## 3. Flutter Test Status
- **63/63 tests passing** (dernier run validé 19/10)
- Test files: `widget_test.dart`, `shell_nav_test.dart`, `pos_page_render_test.dart`, `pos_models_test.dart`, `offline_store_test.dart`
- All core functionality tests pass (POS navigation, calculations, widget tree)

## 4. Deployment Status
- **Edge function**: `pharma-api` deployed via `deploy_func.bat`
- **Tag created**: `v-global-final-20261008` created and pushed via `tag_release.bat`
- Web deployment ready via `deploy_web.ps1` (requires `flutter build web --release`)

## 5. Final Report Status
- Project documented in `PROJECT_CONTEXT.md` (669 lines)
- Version: v2.0.0 (build 200) per `version.json`
- All requirements preserved: Supabase data, validated design, real API connections
- No destructive changes to backend or existing data

## 6. VALIDÉ 19/10 — Correction POS dashboard « Stock non vérifiable »

**Étape validée et enregistrée** : `flutter analyze` 0 · tests **63/63** · build 356 s · CI **2/2 succès** · CDN stamp **`202610190041`** (bundle HTTP 200, identique au local, 5 393 996 o) · arbre propre, poussé (HEAD = origin/main = `021de07`, fix `e905012`).

**Cause réelle** : `pos_panel.dart` (encart POS du **dashboard = PC**) lisait `Medication.stockQuantity`, mais `/catalog/medications` **ne retourne jamais** ce champ → toujours `null` → « Stock non vérifiable » à **chaque** ajout. Le POS complet `pos_page.dart` fetchait déjà le stock séparément → d'où « smartphone OK / PC KO ». (Détail complet : rapport `CLOTURE_SECURITE_SUPABASE_GITHUB.md` §14.1.)

### PIÈGES — À NE PAS RETOMBER LORS DES PROCHAINES CORRECTIONS

1. **`/catalog/medications` (TABLE_MAP → table `medications`) N'EXPOSE PAS `stock_quantity`.** Le stock vit dans `stock_balances`. Tout composant qui a besoin de stock doit appeler **`GET /catalog/medications/stock?ids=...`**. L'Edge complète les ids sans ligne par `quantity:0` (`index.ts:7174-7179`) → un id valide est TOUJOURS renseigné **si l'appel aboutit**. Ne JAMAIS faire confiance à `m.stockQuantity` / `Medication.stockQuantity` issu d'une réponse de catalogue (le champ existe dans le modèle Dart mais pas dans l'API).
2. **Un diagnostic UI n'est pas une cause racine.** « Stock non vérifiable » ≠ session/API morte : le même libellé masquait un champ manquant. AVANT d'attribuer un symptôme à la session/réseau, sonder la **shape réelle de la réponse API en live** puis lire le code qui consomme le champ. (Probe live = `stock_quantity présent: false` → cause tranchée en 1 appel.)
3. **POS = 2 composants distincts** : `pos_page.dart` (page POS complète, `_stock` + fetch dédié) et `pos_panel.dart` (encart dashboard). Un fix sur l'un **ne couvre pas** l'autre — vérifier les deux systématiquement.
4. **Routes Edge** : login/logout = `auth/login` / `auth/logout`. Un chemin nu `/login` tombe sur une route protégée et renvoie « JWT Supabase invalide ou expiré » — **faux signal** qui simule un mauvais mot de passe.
5. **Debug PC/mobile divergent** : le PC utilise le dashboard (`pos_panel.dart`), le téléphone la page POS (`pos_page.dart`). Tester le composant de la plateforme fautive, pas celui qui fonctionne.