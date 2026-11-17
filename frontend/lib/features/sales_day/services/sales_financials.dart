// ============================================================
// VENTES DU JOUR — Calculs financiers honnêtes (Phase 4)
// ============================================================
// La source `cost_total` ne permet PAS de distinguer un coût
// réellement nul d'un coût par défaut à 0 (cf. local_backend/server.js
// L202-211 : `costTotal += med ? qty * price_purchase : 0`).
// Un coût absent OU nul est donc traité comme NON FIABLE :
// aucun bénéfice ni marge n'est calculé ni présenté comme réel.
// ============================================================

import '../models/sales_day_model.dart';

/// Fiabilité du coût transmis par la source.
enum SalesCostReliability {
  /// Coût strictement positif : exploitable.
  available,

  /// Champ absent / null : information non disponible.
  absent,

  /// Coût nul ou négatif : ambigu (0 utilisé comme défaut par la source).
  zeroAmbiguous,
}

class SalesFinancials {
  final double grossRevenue;
  final double netRevenue;
  final double? costTotal;

  const SalesFinancials({
    required this.grossRevenue,
    required this.netRevenue,
    required this.costTotal,
  });

  factory SalesFinancials.fromKpis(SalesDayKpis? k) => SalesFinancials(
        grossRevenue: k?.grossRevenue ?? 0,
        netRevenue: k?.netRevenue ?? 0,
        costTotal: k?.costTotal,
      );

  SalesCostReliability get costReliability {
    final c = costTotal;
    if (c == null) return SalesCostReliability.absent;
    if (c <= 0) return SalesCostReliability.zeroAmbiguous;
    return SalesCostReliability.available;
  }

  /// Compatibilité : vrai uniquement si le coût est réellement fiable.
  bool get hasCost => costReliability == SalesCostReliability.available;

  /// Libellé à afficher à la place d'un montant de coût non fiable.
  String get costUnavailableLabel => switch (costReliability) {
        SalesCostReliability.absent => 'Non disponible',
        SalesCostReliability.zeroAmbiguous => 'Non vérifiable',
        SalesCostReliability.available => '',
      };

  /// Explication courte de la non-fiabilité du coût.
  String get costExplanation => switch (costReliability) {
        SalesCostReliability.absent =>
          'Coût d\'achat absent de l\'API : bénéfice et marge non calculables.',
        SalesCostReliability.zeroAmbiguous =>
          'Coût d\'achat nul ou négatif : la source utilise 0 comme valeur par défaut, '
              'impossible de distinguer un vrai coût nul. Bénéfice et marge non vérifiables.',
        SalesCostReliability.available => '',
      };

  /// Bénéfice brut = CA TTC − coût. null si coût non fiable.
  double? get grossProfit => hasCost ? grossRevenue - costTotal! : null;

  /// Marge brute = bénéfice brut / CA TTC. null si coût non fiable
  /// ou si CA nul (jamais de division par zéro).
  double? get grossMarginPct {
    final profit = grossProfit;
    if (profit == null || grossRevenue <= 0) return null;
    return (profit / grossRevenue) * 100;
  }

  /// Part du CA HT dans le CA TTC : information de TVA/remises.
  /// Ce n'est PAS une marge commerciale.
  double? get htSharePct =>
      grossRevenue > 0 ? (netRevenue / grossRevenue) * 100 : null;
}
