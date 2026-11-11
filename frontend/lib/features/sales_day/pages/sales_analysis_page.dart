/// ============================================================
/// SOUS-PAGE 2 : ANALYSE DES VENTES
/// ============================================================
import 'package:flutter/material.dart';

import '../../../core/theme/colors.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/glass_card.dart';
import '../controllers/sales_day_controller.dart';
import '../models/sales_day_model.dart';
import '../services/sales_analytics_service.dart';
import '../widgets/sales_date_filter.dart';
import '../widgets/sales_hourly_chart.dart';

class SalesAnalysisPage extends StatefulWidget {
  final SalesDayController analytics;
  const SalesAnalysisPage({super.key, required this.analytics});

  @override
  State<SalesAnalysisPage> createState() => _SalesAnalysisPageState();
}

class _SalesAnalysisPageState extends State<SalesAnalysisPage> {
  late final VoidCallback _listener;

  @override
  void initState() {
    super.initState();
    _listener = () {
      if (mounted) setState(() {});
    };
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
    final a = c.analytics;
    final k = a?.kpis;
    final hourly = a?.hourly ?? const <SalesHourBucket>[];

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
        // KPI principaux
        if (k != null)
          GlassCard(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Indicateurs principaux',
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
                          'CA brut (TTC)',
                          Fmt.number(k.grossRevenue, decimals: 2),
                          AppColors.sageGreenInk,
                          'MAD',
                        ),
                      ),
                      Expanded(
                        child: _kpiItem(
                          'CA net (HT)',
                          Fmt.number(k.netRevenue, decimals: 2),
                          AppColors.sageGreenInk,
                          'MAD',
                        ),
                      ),
                      Expanded(
                        child: _kpiItem(
                          'TVA facturée',
                          Fmt.number(k.taxTotal, decimals: 2),
                          AppColors.sageGreenInk,
                          'MAD',
                        ),
                      ),
                      Expanded(
                        child: _kpiItem(
                          'Total remises',
                          Fmt.number(k.discountsTotal, decimals: 2),
                          AppColors.pharmaMuted,
                          'MAD',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _kpiItem(
                          'Ventes validées',
                          '${k.salesCount}',
                          AppColors.sageGreenInk,
                          'ventes',
                        ),
                      ),
                      Expanded(
                        child: _kpiItem(
                          'Panier moyen',
                          Fmt.number(k.averageBasket, decimals: 2),
                          AppColors.sageGreenInk,
                          'MAD',
                        ),
                      ),
                      Expanded(
                        child: _kpiItem(
                          'Montant encaissé',
                          Fmt.number(k.paidAmount, decimals: 2),
                          AppColors.sageGreenInk,
                          'MAD',
                        ),
                      ),
                      Expanded(
                        child: _kpiItem(
                          'Restant à encaisser',
                          Fmt.number(k.outstandingAmount, decimals: 2),
                          k.outstandingAmount > 0
                              ? AppColors.pharmaWarning
                              : AppColors.sageGreenInk,
                          'MAD',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 16),
        // Graphique horaire
        if (hourly.isNotEmpty)
          GlassCard(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Répartition horaire',
                    style: TextStyle(
                      color: AppColors.inkDark,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 200,
                    child: SalesHourlyChart(hourly: hourly),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 16),
        // Note de couverture
        if (c.coverageNote.isNotEmpty)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              c.coverageNote,
              style: const TextStyle(
                color: AppColors.pharmaMuted,
                fontSize: 10.5,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
      ],
    );
  }

  Widget _kpiItem(
    String label,
    String value,
    Color color,
    String unit, {
    bool isDelta = false,
  }) {
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
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              unit,
              style: const TextStyle(
                color: AppColors.pharmaMuted,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
