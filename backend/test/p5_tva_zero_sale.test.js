import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";

/* P5 — FIX POS « Payer » (13/10/2026)
   Cause racine : defaultTvaFor retournait 20 pour tva_rate=0
   (`Number(fallback ?? 20) || 20` → 0||20 = 20) → total serveur +20 %
   vs total client (TVA 0) → paiement incohérent.
   Ces tests verrouillent le correctif contre toute regression. */

const edge = readFileSync(
  new URL("../../supabase/functions/pharma-api/index.ts", import.meta.url),
  "utf8",
);
/* Code effectif sans les commentaires (le commentaire du fix cite
   volontairement l'ancien pattern défectueux à titre documentaire). */
const edgeCode = edge
  .replace(/\/\*[\s\S]*?\*\//g, "")
  .replace(/^\s*\/\/.*$/gm, "");
const posPage = readFileSync(
  new URL("../../frontend/lib/features/pos/pos_page.dart", import.meta.url),
  "utf8",
);
const posPanel = readFileSync(
  new URL(
    "../../frontend/lib/features/dashboard/pos_panel.dart",
    import.meta.url,
  ),
  "utf8",
);
const paymentSheet = readFileSync(
  new URL(
    "../../frontend/lib/features/dashboard/payment_sheet.dart",
    import.meta.url,
  ),
  "utf8",
);

test("Edge : l'ancien pattern défectueux `Number(fallback ?? 20) || 20` est absent du code", () => {
  assert.ok(
    !/Number\(fallback \?\? 20\) \|\| 20/.test(edgeCode),
    "le fallback || 20 (0||20=20) ne doit plus exister dans le code actif",
  );
});

test("Edge : defaultTvaFor accepte tva_rate=0 (comparaison >= 0)", () => {
  assert.ok(
    /if \(Number\.isFinite\(t\) && t >= 0\) return t;/.test(edge),
    "tva_rate=0 est une valeur valide, pas un 'manquant'",
  );
  assert.ok(
    /return Number\.isFinite\(fallback\) && fallback >= 0 \? fallback : 0;/.test(
      edge,
    ),
    "dernier recours = 0 (aligné règles TVA médicaments), jamais 20",
  );
});

test("Edge : plus aucun défaut `?? 20` sur les taux de TVA ligne (achats/retours)", () => {
  assert.ok(
    !/tva_rate \?\? it\.tax_rate \?\? 20/.test(edge),
    "le défaut ?? 20 sur tva_rate des lignes est interdit",
  );
  assert.ok(
    /tva_rate \?\? it\.tax_rate \?\? 0/.test(edge),
    "défaut de ligne = 0 (cohérent médicaments TVA 0)",
  );
});

test("Edge : le contrôle de cohérence TVA compare Edge vs DB (gardre vivant)", () => {
  assert.ok(
    /TVA_DIVERGENCE/.test(edge),
    "le garde-fou de divergence Edge/DB doit rester actif",
  );
});

test("Flutter POS complet : message explicite si montant reçu insuffisant", () => {
  assert.ok(
    /Montant reçu insuffisant/.test(posPage),
    "_confirmPayment doit signaler le sous-montant, jamais de return muet",
  );
});

test("Flutter POS panneau : message explicite si montant reçu insuffisant", () => {
  assert.ok(
    /Montant reçu insuffisant/.test(posPanel),
    "_pay doit signaler le sous-montant, jamais de return muet",
  );
});

test("Flutter feuille de paiement : message explicite si montant reçu insuffisant", () => {
  assert.ok(
    /Montant reçu insuffisant/.test(paymentSheet),
    "_validate espèces doit signaler le sous-montant",
  );
});

test("Edge : idempotence clientSaleId conservée (anti double-vente)", () => {
  assert.ok(
    /client_sale_id/.test(edge) && /duplicate: true/.test(edge),
    "la relecture idempotente par client_sale_id doit rester en place",
  );
});
