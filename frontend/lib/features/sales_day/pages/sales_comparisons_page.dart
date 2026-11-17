// ============================================================
// SOUS-PAGE 8 : COMPARAISONS
// ============================================================
// Phase 2 : extension de la comparaison à tous les KPI comparables
// de la période précédente (même durée). Un écart n'est affiché
// que si la valeur précédente est réellement disponible et > 0.
import 'package:flutter/material.dart';

import '../../../core/theme/colors.dart';
import '../../../core/utils/format.dart';
import '../controllers/sales_day_controller.dart';
import '../services/sales_analytics_service.dart';
import '../services/sales_financials.dart';
import '../widgets/sales_date_filter.dart';
import '../widgets/sales_design_system.dart';

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

    final rows = <Widget>[
      _comparisonRow('CA TTC', k?.grossRevenue ?? 0, prev?.grossRevenue, 'MAD'),
      _comparisonRow('CA HT net', k?.netRevenue ?? 0, prev?.netRevenue, 'MAD'),
      _comparisonRow('TVA facturée', k?.taxTotal ?? 0, prev?.taxTotal, 'MAD'),
      _comparisonRow(
          'Remises', k?.discountsTotal ?? 0, prev?.discountsTotal, 'MAD'),
      _comparisonRow(
          'Panier moyen', k?.averageBasket ?? 0, prev?.averageBasket, 'MAD'),
      _comparisonRow('Ventes validées', (k?.salesCount ?? 0).toDouble(),
          prev?.salesCount.toDouble(), ''),
      _comparisonRow('Annulées', (k?.cancelledCount ?? 0).toDouble(),
          prev?.cancelledCount.toDouble(), ''),
      _comparisonRow(
          'Remboursées / retours',
          (k?.returnedCount ?? 0).toDouble(),
          prev?.returnedCount.toDouble(),
          ''),
      _comparisonRow('Encaissé', k?.paidAmount ?? 0, prev?.paidAmount, 'MAD'),
      _comparisonRow('Restant à encaisser', k?.outstandingAmount ?? 0,
          prev?.outstandingAmount, 'MAD'),
      if (SalesFinancials.fromKpis(k).hasCost &&
          SalesFinancials.fromKpis(prev).hasCost)
        _comparisonRow('Coût d\'achat', k!.costTotal!, prev!.costTotal, 'MAD'),
      if (k?.refundedAmount != null && prev?.refundedAmount != null)
        _comparisonRow('Remboursements réels', k!.refundedAmount!,
            prev!.refundedAmount, 'MAD'),
    ];

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
        const SizedBox(height: SalesDesign.spacingMD),
        SalesSectionHeader(
          title: 'Comparaison avec la période précédente',
          subtitle:
              '${c.periodLabelText} · même durée, période immédiatement antérieure · écarts réels uniquement',
        ),
        const SizedBox(height: SalesDesign.spacingMD),
        SalesPanel(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Column(children: rows),
        ),
        const SizedBox(height: SalesDesign.spacingMD),
        if (prev == null)
          const SalesNotice(
            warning: false,
            message:
                'Données de la période précédente indisponibles (chargement best-effort) : les écarts ne peuvent pas être calculés. Les valeurs actuelles restent affichées.',
          )
        else
          Column(
            children: [
              const SalesNotice(
                warning: false,
                message:
                    'Un écart n\'est affiché que si la valeur précédente est connue et strictement positive. Les lignes absentes concernent des données non exposées par l\'API.',
              ),
              if (!SalesFinancials.fromKpis(k).hasCost ||
                  !SalesFinancials.fromKpis(prev).hasCost) ...[
                const SizedBox(height: SalesDesign.spacingSM),
                const SalesNotice(
                  message:
                      'Coût d\'achat absent, nul ou ambigu : la comparaison de coût et de marge est masquée plutôt que de présenter un écart non vérifiable.',
                ),
              ],
            ],
          ),
      ],
    );
  }

  Widget _comparisonRow(
    String label,
    double current,
    double? previous,
    String unit,
  ) {
    final delta = SalesAnalyticsService.delta(current, previous);
    final pct = delta.pct;
    final color = pct == null
        ? AppColors.pharmaMuted
        : (pct >= 0 ? AppColors.sageGreenInk : AppColors.pharmaDanger);
    final currentText = unit.isEmpty
        ? Fmt.number(current)
        : '${Fmt.number(current, decimals: 2)} $unit';
    final previousText = previous == null
        ? '—'
        : (unit.isEmpty
            ? Fmt.number(previous)
            : '${Fmt.number(previous, decimals: 2)} $unit');

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: SalesDesign.spacingXS),
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
                const Text(
                  'Actuel · Précédent',
                  style: TextStyle(color: AppColors.pharmaMuted, fontSize: 9.5),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  currentText,
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    color: AppColors.champagneInkLight,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  previousText,
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                      color: AppColors.pharmaMuted, fontSize: 10.5),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              pct == null
                  ? '—'
                  : '${pct >= 0 ? '+' : ''}${pct.toStringAsFixed(1)} %',
              style: TextStyle(
                color: color,
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
