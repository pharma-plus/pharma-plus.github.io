/// ============================================================
/// SOUS-PAGE 3 : BÉNÉFICES ET MARGES
/// ============================================================
import 'package:flutter/material.dart';

import '../../../core/theme/colors.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/glass_card.dart';
import '../controllers/sales_day_controller.dart';
import '../models/sales_day_model.dart';
import '../services/sales_analytics_service.dart';
import '../widgets/sales_date_filter.dart';

class SalesProfitsPage extends StatefulWidget {
  final SalesDayController analytics;
  const SalesProfitsPage({super.key, required this.analytics});

  @override
  State<SalesProfitsPage> createState() => _SalesProfitsPageState();
}

class _SalesProfitsPageState extends State<SalesProfitsPage> {
  late final VoidCallback _listener;

  @override
  void initState() {
    super.initState();
    _listener = () {
      if (mounted) setState(() {});};
    widget.analytics.addListener(_listener);
  }

  @override
  void dispose() {
    widget.analytics.removeListener(_listener);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.analytics;
    final k = c.analytics?.kpis;
    final gross = k?.grossRevenue ?? 0;
    final cost = k?.costTotal ?? 0;
    final net = k?.netRevenue ?? 0;
    final grossProfit = gross - cost;
    final marginPct = gross > 0 ? (grossProfit / gross) * 100 : 0;
    final netMarginPct = gross > 0 ? (net / gross) * 100 : 0;

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
        GlassCard(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Bénéfices et marges',
                  style: TextStyle(
                    color: AppColors.inkDark,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _kpiItem(
                        'CA TTC', Fmt.number(gross, decimals: 2),
                        AppColors.sageGreenInk,
                      ),
                    ),
                    Expanded(
                      child: _kpiItem(
                        'Coût achats', Fmt.number(cost, decimals: 2),
                        AppColors.pharmaDanger,
                      ),
                    ),
                    Expanded(
                      child: _kpiItem(
                        'Bénéfice brut', Fmt.number(grossProfit, decimals: 2),
                        grossProfit >= 0 ? AppColors.sageGreenInk : AppColors.pharmaDanger,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _kpiItem(
                        'Taux marge brute', '${marginPct.toStringAsFixed(1)} %',
                        marginPct >= 0 ? AppColors.sageGreenInk : AppColors.pharmaDanger,
                      ),
                    ),
                    Expanded(
                      child: _kpiItem(
                        'CA net HT', Fmt.number(net, decimals: 2),
                        AppColors.champagneInk,
                      ),
                    ),
                    Expanded(
                      child: _kpiItem(
                        'Marge nette', '${netMarginPct.toStringAsFixed(1)} %',
                        netMarginPct >= 0 ? AppColors.sageGreenInk : AppColors.pharmaDanger,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (k?.costTotal == 0 || k?.costTotal == null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.pharmaWarning.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: AppColors.pharmaWarning.withValues(alpha: 0.45),
                        width: 1,
                      ),
                    ),
                    child: const Text(
                      'Le coût d\'achat (cost_total) est à 0 ou non renseigné pour certaines ventes. Le bénéfice brut peut être incomplet.',
                      style: TextStyle(
                        color: AppColors.pharmaWarning,
                        fontSize: 11,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        Center(
          child: Text(
            'Le détail du bénéfice par produit et par catégorie nécessite des données de coût d\'achat par article (sale_items.cost_price), actuellement non exposées par l\'API.',
            style: const TextStyle(
              color: AppColors.pharmaMuted,
              fontSize: 11.5,
              fontStyle: FontStyle.italic,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }

  Widget _kpiItem(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.pharmaMuted,
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}