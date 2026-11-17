/// ============================================================
/// VENTES DU JOUR — Section des 8 KPI (grille responsive premium)
/// ============================================================
/// Grille 2 colonnes (smartphone) / 4 colonnes (tablette / PC).
/// Chiffre d'affaires et ventes affichent l'évolution réelle vs période
/// précédente quand elle est disponible — jamais de % inventé.
/// ============================================================

import 'package:flutter/material.dart';

import '../../../core/theme/colors.dart';
import '../../../core/utils/format.dart';
import '../models/sales_day_model.dart';
import 'sales_kpi_card.dart';

class SalesKpiSection extends StatelessWidget {
  final SalesDayKpis kpis;
  final double? grossDeltaPct;
  final double? countDeltaPct;

  const SalesKpiSection({
    super.key,
    required this.kpis,
    required this.grossDeltaPct,
    required this.countDeltaPct,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final cross = c.maxWidth >= 900 ? 4 : 2;
      final cards = <SalesKpiCard>[
        SalesKpiCard(
          title: 'CA BRUT (TTC)',
          value: _money(kpis.grossRevenue),
          unit: 'MAD',
          icon: Icons.storefront_outlined,
          accent: AppColors.sageGreenInk,
          deltaPct: grossDeltaPct,
        ),
        SalesKpiCard(
          title: 'CA NET (HT)',
          value: _money(kpis.netRevenue),
          unit: 'MAD',
          icon: Icons.paid_outlined,
          accent: AppColors.champagneInkLight,
        ),
        SalesKpiCard(
          title: 'VENTES VALIDÉES',
          value: '${kpis.salesCount}',
          unit: 'ventes',
          icon: Icons.receipt_long_outlined,
          accent: AppColors.sageGreenInk,
          deltaPct: countDeltaPct,
        ),
        SalesKpiCard(
          title: 'PANIER MOYEN',
          value: _money(kpis.averageBasket),
          unit: 'MAD',
          icon: Icons.shopping_bag_outlined,
          accent: AppColors.champagneInk,
        ),
        SalesKpiCard(
          title: 'TOTAL REMISES',
          value: _money(kpis.discountsTotal),
          unit: 'MAD',
          icon: Icons.local_offer_outlined,
          accent: AppColors.cardAmber,
        ),
        SalesKpiCard(
          title: 'VENTES ANNULÉES',
          value: '${kpis.cancelledCount + kpis.returnedCount}',
          unit: 'retours',
          icon: Icons.cancel_outlined,
          accent: AppColors.pharmaDanger,
        ),
        SalesKpiCard(
          title: 'MONTANT ENCAISSÉ',
          value: _money(kpis.paidAmount),
          unit: 'MAD',
          icon: Icons.account_balance_wallet_outlined,
          accent: AppColors.sageGreenInkRich,
        ),
        SalesKpiCard(
          title: 'RESTANT À ENCAISSER',
          value: _money(kpis.outstandingAmount),
          unit: 'MAD',
          icon: Icons.hourglass_bottom_outlined,
          accent: AppColors.cardPurple,
        ),
      ];

      const gap = 12.0;
      return GridView.builder(
        padding: EdgeInsets.zero,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: cross,
          mainAxisSpacing: gap,
          crossAxisSpacing: gap,
          childAspectRatio: _ratio(cross),
        ),
        itemCount: cards.length,
        itemBuilder: (_, i) => cards[i],
      );
    });
  }

  static double _ratio(int cross) => cross == 4 ? 2.55 : 1.5;

  static String _money(double v) => Fmt.number(v, decimals: 2);
}
