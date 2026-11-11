/// ============================================================
/// SOUS-PAGE 8 : COMPARAISONS
/// ============================================================
import 'package:flutter/material.dart';

import '../../../core/theme/colors.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/glass_card.dart';
import '../controllers/sales_day_controller.dart';
import '../models/sales_day_model.dart';
import '../services/sales_analytics_service.dart';
import '../widgets/sales_date_filter.dart';

class SalesComparisonsPage extends StatefulWidget {
  final SalesDayController analytics;
  const SalesComparisonsPage({super.key, required this.analytics});

  @override
  State<SalesComparisonsPage> createState() => _SalesComparisonsPageState();
}

class _SalesComparisonsPageState extends State<SalesComparisonsPage> {
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
    final k = c.analytics?.kpis;
    final prev = c.previousKpis;
    final grossDelta = c.grossDelta.pct;
    final countDelta = c.countDelta.pct;

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
          'Comparaison avec la période précédente',
          style: TextStyle(
            color: AppColors.inkDark,
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Même durée, période immédiatement précédente. Les pourcentages ne sont affichés que si une comparaison réelle est disponible.',
          style: TextStyle(
            color: AppColors.pharmaMuted,
            fontSize: 11,
          ),
        ),
        const SizedBox(height: 16),
        GlassCard(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ...[
                  _comparisonRow(
                    'Chiffre d\'affaires TTC',
                    Fmt.number(k?.grossRevenue ?? 0, decimals: 2),
                    prev?.grossRevenue != null
                        ? Fmt.number(prev!.grossRevenue, decimals: 2)
                        : '—',
                    grossDelta != null
                        ? '${grossDelta >= 0 ? '+' : ''}${grossDelta.toStringAsFixed(1)} %'
                        : '—',
                    grossDelta != null && grossDelta >= 0
                        ? AppColors.sageGreenInk
                        : grossDelta != null
                        ? AppColors.pharmaDanger
                        : AppColors.pharmaMuted,
                  ),
                  _comparisonRow(
                    'Ventes validées',
                    '${k?.salesCount ?? 0}',
                    prev?.salesCount != null
                        ? '${prev!.salesCount}'
                        : '—',
                    countDelta != null
                        ? '${countDelta >= 0 ? '+' : ''}${countDelta.toStringAsFixed(1)} %'
                        : '—',
                    countDelta != null && countDelta >= 0
                        ? AppColors.sageGreenInk
                        : countDelta != null
                        ? AppColors.pharmaDanger
                        : AppColors.pharmaMuted,
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        if (prev == null)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.pharmaSurface.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.goldBorder, width: 1),
            ),
            child: const Text(
              'Les données de la période précédente sont indisponibles (échec de chargement best-effort).',
              style: TextStyle(
                color: AppColors.pharmaMuted,
                fontSize: 11.5,
              ),
            ),
          ),
      ],
    );
  }

  Widget _comparisonRow(
    String label,
    String current,
    String previous,
    String delta,
    Color deltaColor,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: AppColors.inkDark,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'Actuel · Précédent',
                  style: const TextStyle(
                    color: AppColors.pharmaMuted,
                    fontSize: 9.5,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  current,
                  style: const TextStyle(
                    color: AppColors.champagneInkLight,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  previous,
                  style: const TextStyle(
                    color: AppColors.pharmaMuted,
                    fontSize: 10.5,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              delta,
              style: TextStyle(
                color: deltaColor,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}