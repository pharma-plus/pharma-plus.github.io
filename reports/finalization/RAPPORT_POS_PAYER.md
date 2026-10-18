# RAPPORT — CORRECTION BOUTON « PAYER » POS (13/10/2026)

## Cause exacte (diagnostic, preuves)

**Bug racine — Edge `POST /sales`, fonction `defaultTvaFor` (ex-l.4353)** :
```ts
const t = Number(med?.tva_rate ?? 0);
if (t > 0) return t;                       // tva_rate=0 ignoré (« pas de taux »)
const fallback = ... settings.tva ...;
return Number(fallback ?? 20) || 20;       // 0 || 20 = 20  ← BUG
```
Depuis l'application de la **TVA 0 %** aux 4 976 médicaments (13/10) :
- `tva_rate = 0` n'est pas `> 0` → ignoré ;
- le fallback `settings.tva.medication = 0` est falsy → **`0 || 20 = 20`** ;
- **le serveur ajoutait 20 % de TVA** alors que le client Flutter affichait un total TVA 0 → total serveur ≠ total client, ticket/caisse incohérents, « le paiement ne se valide pas ».

**Preuves** :
1. Code live : `line_total` est une colonne **GENERATED** `net × (1 + tax_rate/100)` avec `tax_rate DEFAULT 20.00` (défaut de colonne) — l'Edge l'écrasait avec sa valeur fausse (20) ;
2. Les 5 dernières ventes (18/09, avant TVA 0) ont toutes `tax_total = 20 %` et une incohérence `paid ≠ total` (POS-2026-000071 : total 75,60 / paid 69,30) ;
3. **Aucune vente depuis le passage TVA 0** (dernière le 18/09) ;
4. Bug de code reproduit : `Number(0 ?? 20) || 20 → 20`.

**Bug secondaire (UX)** : `_confirmPayment` / `_pay` / `_validate` faisaient un **return silencieux** si montant reçu insuffisant → le bouton « Payer » semblait mort.

## Corrections

| Fichier | Correction |
|---|---|
| `supabase/functions/pharma-api/index.ts` | `defaultTvaFor` : **0 est une TVA valide** (`Number.isFinite(t) && t >= 0`), défaut pharmacie si taux absent, dernier recours **0** (jamais `|| 20`) ; version **2.4.1** ; défaut ligne achats `?? 20` → `?? 0` |
| `frontend/lib/features/pos/pos_page.dart` | SnackBar « Montant reçu insuffisant — reste X MAD » si sous-montant espèces |
| `frontend/lib/features/dashboard/pos_panel.dart` | idem |
| `frontend/lib/features/dashboard/payment_sheet.dart` | idem (onglet Espèces) |
| `backend/test/p5_tva_zero_sale.test.js` | **8 nouveaux tests** verrouillant le fix (pattern `|| 20` interdit, `t >= 0`, messages, idempotence) |
| `backend/test/p2_sale_compensation.test.js` | fenêtre élargie 16k→22k (le handler a grandi ; code de compensation inchangé) |
| `backend/test/p5_invoices_edge.test.js` + `postdeploy_verify.mjs` | pins de version → 2.4.1 |

## Tests exécutés (résultats exacts)

| Suite | Résultat |
|---|---|
| Backend complet (28 fichiers) | **157/157** (149 + 8 nouveaux) |
| Flutter | **37/37** |
| `deno check` Edge | **0 erreur** |
| Postdeploy live (pin 2.4.1) | **23/23** |
| **Vente réelle de bout en bout** (`_pos_e2e_sale.mjs` contre l'API publiée) | **16/17** (l'unique FAIL = check de version du script sans auth, couvert par postdeploy 23/23) |

## Vente réelle — preuve métier (API publiée, 13/10 16:4x)

Vente **POS-2026-000084** (Bepanthen Plus, TVA 0, 55,00 MAD, siège) :
- Total serveur **55,00** — ancien bug aurait donné **66,00** (+20 %) ;
- `tax_total = 0`, `sale_items.tax_rate = 0`, `line_total = 55,00` ;
- Payment completed 55,00, `paid = total` ;
- Stock 120 → **119**, exactement **1** mouvement de vente ;
- **Rejeu** (double clic simulé) : `duplicate = true`, **1 seule vente**, stock inchangé.

## Sécurité / intégrité

- Aucune table recréée, aucun secret modifié, isolation pharmacie intacte (pid forcé + JWT).
- Idempotence `client_sale_id` intacte (rejeu testé live).
- Compensation d'échec (`compensateSale`) inchangée et testée.
- La vente de test est traçable : `notes = "VENTE DE TEST correction POS TVA 0 (2.4.1)"`.

## Déploiement

- **Edge 2.4.1 LIVE** (`Deployed Functions` + postdeploy 23/23) ;
- Web publié : stamp `main.202610131645.dart.js` (GitHub Pages) ;
- Rollback Edge : `_validation_backup/edge_predeploy_2.3.0_20261013_111901.ts` (2.3.0) — le diff 2.4.0→2.4.1 est le fix TVA + UX messages.

## Blocages restants / actions manuelles

1. ~~**`sale_items.tax_rate DEFAULT 20.00`** et `sales.tva_rate`/médicaments DEFAULT 20~~ — **RÉSOLU (vérifié live le 18/10)** : `sale_items.tax_rate` = **aucun défaut (NULL)**, `medicaments.tva_rate` = **défaut 0**, et `sales` **n'a aucune colonne tva/tax** (le défaut historique a été retiré par la migration TVA du 16/10 ; l'artefact versionné `20261009150000` a été aligné le 18/10 sans `DEFAULT 20.00`). Plus aucun insert manuel hors API ne peut être piégé par un défaut 20.
2. Recette physique (scanner/imprimante) et test manuel sur poste pilote : à faire côté terrain.
3. Les ventes **antérieures** (sept., TVA 20 %) n'ont pas été modifiées (aucune réécriture d'historique — conforme).
