/// ============================================================
/// VENTES DU JOUR — Classement des produits vendus (réels)
/// ============================================================
/// Top produits réels issus de sale_items × medications (API).
/// Supporte trois classements indépendants :
///   · 'qty'  : par quantités nettes vendues
///   · 'rev'  : par chiffre d'affaires net
///   · 'profit': par bénéfice brut réel
/// Graphique horizontal interactif avec accès au détail des ventes.
/// ============================================================

import 'package:flutter/material.dart';

import '../../../core/theme/colors.dart';
import '../../../core/utils/format.dart';
import '../models/sales_day_model.dart';

/// Un classement des 10 premiers produits.
class SalesProductRanking extends StatelessWidget {
  final String title;
  final List<SalesProductRank> products;
  final String sortBy;
  final ValueCallback<SalesProductRank>? onProductTap;

  const SalesProductRanking({
    super.key,
    required this.title,
    required this.products,
    required this.sortBy,
    this.onProductTap,
  });

  static const List<Color> _medals = [
    AppColors.champagneInkLight, // 1 (or)
    AppColors.pharmaMuted,     // 2 (argent)
    Color(0xFFCD7F32),         // 3 (bronze)
  ];

  /// Couleur de la barre selon le critère de classement.
  Color _barColor(String sortBy) {
    switch (sortBy) {
      case 'qty':
        return AppColors.sageGreenInk;
      case 'rev':
        return AppColors.champagneInk;
      case 'profit':
        return AppColors.cardBlue;
      default:
        return AppColors.sageGreenInk;
    }
  }

  /// Valeur de référence pour le graphique (max du critère).
  double _maxValue(List<SalesProductRank> list, String s) {
    if (list.isEmpty) return 1;
    double max = 0;
    for (final p in list) {
      final v = s == 'qty' ? p.quantity : (s == 'rev' ? p.revenue : p.profit);
      if (v > max) max = v;
    }
    return max <= 0 ? 1 : max;
  }

  @override
  Widget build(BuildContext context) {
    final barColor = _barColor(sortBy);
    final maxVal = _maxValue(products, sortBy);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Titre + critère
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: AppColors.inkDark,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Classement par ${sortBy == 'qty' ? 'quantités' : sortBy == 'rev' ? 'chiffre d\'affaires' : 'bénéfice brut'}',
                    style: const TextStyle(
                      color: AppColors.pharmaMuted,
                      fontSize: 10.5,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: barColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: barColor.withValues(alpha: 0.5), width: 1),
              ),
              child: Text(
                'Top 10 · ${sortBy == 'qty' ? 'Qté' : sortBy == 'rev' ? 'CA' : 'Bénéfice'}',
                style: TextStyle(
                  color: barColor,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (products.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: SizedBox(
              width: double.infinity,
              child: Text(
                'Aucun produit vendu sur la période',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.pharmaMuted, fontSize: 12),
              ),
            ),
          )
        else
          ...[
            for (final (i, p) in products.indexed)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: _rankingRow(
                  context: context,
                  rank: i + 1,
                  product: p,
                  barColor: barColor,
                  maxVal: maxVal,
                  sortBy: sortBy,
                  onTap: onProductTap != null ? () => onProductTap!(p) : null,
                ),
              ),
          ],
      ],
    );
  }

  Widget _rankingRow({
    required BuildContext context,
    required int rank,
    required SalesProductRank product,
    required Color barColor,
    required double maxVal,
    required String sortBy,
    VoidCallback? onTap,
  }) {
    final value = sortBy == 'qty'
        ? product.quantity
        : (sortBy == 'rev' ? product.revenue : product.profit);
    final pct = (value / maxVal).clamp(0.0, 1.0);
    final isMedal = rank <= 3;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.pharmaSurface.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.goldBorder, width: 1),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Ligne 1 : rang + nom + valeur
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 24,
                      child: Text(
                        '$rank',
                        style: TextStyle(
                          color: isMedal
                              ? _medals[rank - 1]
                              : AppColors.pharmaMuted,
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            product.displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.inkDark,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (product.dosage != null &&
                              product.dosage!.isNotEmpty)
                            Text(
                              product.dosage!,
                              style: const TextStyle(
                                color: AppColors.pharmaMuted,
                                fontSize: 10,
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Valeur principale selon le critère
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          sortBy == 'qty'
                              ? '${product.quantity.toStringAsFixed(0)} u.'
                              : Fmt.money(
                                  sortBy == 'rev'
                                      ? product.revenue
                                      : product.profit),
                          style: const TextStyle(
                            color: AppColors.champagneInkLight,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          sortBy == 'qty'
                              ? 'Qté'
                              : (sortBy == 'rev' ? 'CA' : 'Bénéfice'),
                          style: const TextStyle(
                            color: AppColors.pharmaMuted,
                            fontSize: 9,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 7),
                // Graphique horizontal
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: pct,
                    minHeight: 6,
                    color: barColor,
                    backgroundColor:
                        AppColors.pharmaSurface2.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(height: 3),
                // Métriques secondaires : quantité / CA / bénéfice + marge
                Row(
                  children: [
                    Expanded(
                      child: _metricChip(
                        'Qté',
                        '${product.quantity.toStringAsFixed(0)}',
                        AppColors.pharmaMuted,
                      ),
                    ),
                    Expanded(
                      child: _metricChip(
                        'CA',
                        Fmt.money(product.revenue),
                        AppColors.champagneInkLight,
                      ),
                    ),
                    Expanded(
                      child: _metricChip(
                        'Bénéf.',
                        Fmt.money(product.profit),
                        AppColors.cardBlue,
                      ),
                    ),
                    if (product.revenue > 0)
                      Expanded(
                        child: _metricChip(
                          'Marge',
                          '${product.marginPct.toStringAsFixed(0)} %',
                          product.marginPct >= 0
                              ? AppColors.sageGreenInk
                              : AppColors.pharmaDanger,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _metricChip(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 1),
        Text(
          label,
          style: const TextStyle(
            color: AppColors.pharmaMuted,
            fontSize: 8,
          ),
        ),
      ],
    );
  }
}

/// Callback typé pour le tap sur un produit du classement.
typedef ValueCallback<T> = void Function(T t);
