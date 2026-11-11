/// ============================================================
/// SOUS-PAGE 4 : PRODUITS VENDUS
/// ============================================================
import 'package:flutter/material.dart';

import '../../../core/theme/colors.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/glass_card.dart';
import '../controllers/sales_day_controller.dart';
import '../models/sales_day_model.dart';
import '../services/sales_analytics_service.dart';
import '../widgets/sales_date_filter.dart';
import '../widgets/sales_product_ranking.dart';

class SalesProductsPage extends StatefulWidget {
  final SalesDayController analytics;
  const SalesProductsPage({super.key, required this.analytics});

  @override
  State<SalesProductsPage> createState() => _SalesProductsPageState();
}

class _SalesProductsPageState extends State<SalesProductsPage> {
  @override
  void initState() {
    super.initState();
    widget.analytics.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    widget.analytics.removeListener(() {});
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.analytics;
    final topQty = c.analytics?.topProductsQty ?? const <SalesProductRank>[];
    final topRev = c.analytics?.topProductsRev ?? const <SalesProductRank>[];
    final topProfit = c.analytics?.topProductsProfit ?? const <SalesProductRank>[];

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 30),
      children: [
        SalesDateFilter(
          period: c.period,
          customRange: c.custom,
          periodLabel: c.periodLabelText,
          onSelect: (p) => c.setPeriod(p),
          onCustomRange: (r) => c.setCustomRange(r),
        ),
        const SizedBox(height: 14),
        const Text(
          'Top 10 produits par chiffre d\'affaires',
          style: TextStyle(
            color: AppColors.pharmaText,
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 8),
        SalesProductRanking(
          title: 'Top 10 par CA',
          products: topRev,
          sortBy: 'rev',
        ),
        const SizedBox(height: 16),
        SalesProductRanking(
          title: 'Top 10 par quantité',
          products: topQty,
          sortBy: 'qty',
        ),
        const SizedBox(height: 16),
        SalesProductRanking(
          title: 'Top 10 par bénéfice',
          products: topProfit,
          sortBy: 'profit',
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.pharmaSurface.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.goldBorder, width: 1),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Top 10 par quantité et par bénéfice',
                style: TextStyle(
                  color: AppColors.pharmaText,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Le top par quantité est toujours disponible. Le top par bénéfice utilise le coût d\'achat (sale_items.cost_price) ; si celui-ci est à 0, le bénéfice égale le CA.',
                style: TextStyle(
                  color: AppColors.pharmaMuted,
                  fontSize: 11.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}