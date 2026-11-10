/// ============================================================
/// VENTES DU JOUR — Classement des produits vendus (réels)
/// ============================================================
/// Top produits réels issus de sale_items × medications (API).
/// ============================================================

import 'package:flutter/material.dart';

import '../../../core/theme/colors.dart';
import '../../../core/utils/format.dart';
import '../models/sales_day_model.dart';

class SalesProductRanking extends StatelessWidget {
  final List<SalesProductRank> products;

  const SalesProductRanking({super.key, required this.products});

  static const List<Color> _medals = [
    AppColors.pharmaGoldLight, // 1
    AppColors.pharmaMuted,     // 2
    Color(0xFFCD7F32),         // 3 (bronze)
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Produits les plus vendus',
          style: TextStyle(
            color: AppColors.pharmaText,
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 2),
        const Text(
          'Prix TTC réels · quantité de lignes de vente terminées',
          style: TextStyle(color: AppColors.pharmaMuted, fontSize: 10.5),
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
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.pharmaSurface.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.goldBorder, width: 1),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 8),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 24,
                          child: Text(
                            '${i + 1}',
                            style: TextStyle(
                              color: i < _medals.length
                                  ? _medals[i]
                                  : AppColors.pharmaMuted,
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                p.displayName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: AppColors.pharmaText,
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (p.dosage != null && p.dosage!.isNotEmpty)
                                Text(
                                  p.dosage!,
                                  style: const TextStyle(
                                    color: AppColors.pharmaMuted,
                                    fontSize: 10,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${Fmt.number(p.quantity, decimals: 0)} u.',
                          style: const TextStyle(
                            color: AppColors.pharmaMuted,
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          Fmt.money(p.revenue),
                          style: const TextStyle(
                            color: AppColors.pharmaGoldLight,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
      ],
    );
  }
}
