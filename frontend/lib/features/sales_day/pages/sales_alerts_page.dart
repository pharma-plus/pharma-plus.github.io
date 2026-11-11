/// ============================================================
/// SOUS-PAGE 10 : ALERTES INTELLIGENTES
/// ============================================================
import 'package:flutter/material.dart';

import '../../../core/theme/colors.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/glass_card.dart';
import '../controllers/sales_day_controller.dart';
import '../models/sales_day_model.dart';
import '../services/sales_analytics_service.dart';
import '../widgets/sales_date_filter.dart';

class SalesAlertsPage extends StatefulWidget {
  final SalesDayController analytics;
  const SalesAlertsPage({super.key, required this.analytics});

  @override
  State<SalesAlertsPage> createState() => _SalesAlertsPageState();
}

class _SalesAlertsPageState extends State<SalesAlertsPage> {
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
    final tx = c.txRows;
    final gross = k?.grossRevenue ?? 0;
    final cost = k?.costTotal ?? 0;
    final grossProfit = gross - cost;
    final discounts = k?.discountsTotal ?? 0;
    final cancelled = k?.cancelledCount ?? 0;
    final returned = k?.returnedCount ?? 0;
    final outstanding = k?.outstandingAmount ?? 0;

    final alerts = <_Alert>[];

    if (gross > 0 && grossProfit < 0) {
      alerts.add(_Alert(
        'Marge brute négative',
        'Le coût des marchandises (${Fmt.number(cost, decimals: 2)} MAD) dépasse le chiffre d\'affaires (${Fmt.number(gross, decimals: 2)} MAD).',
        'high',
        AppColors.pharmaDanger,
      ));
    }

    if (prev != null && gross > 0) {
      final prevGross = prev.grossRevenue;
      if (prevGross > 0 && gross < prevGross * 0.8) {
        final drop = ((1 - gross / prevGross) * 100).toStringAsFixed(0);
        alerts.add(_Alert(
          'Baisse inhabituelle du CA',
          'Le CA TTC a baissé de $drop % par rapport à la période précédente.',
          'medium',
          AppColors.pharmaWarning,
        ));
      }
    }

    if (gross > 0 && discounts / gross > 0.2) {
      final pct = ((discounts / gross) * 100).toStringAsFixed(0);
      alerts.add(_Alert(
        'Remises anormales',
        'Les remises représentent ${pct}% du CA TTC, seuil de vigilance : 20%.',
        'medium',
        AppColors.pharmaWarning,
      ));
    }

    final totalTx = (k?.salesCount ?? 0) + cancelled + returned;
    if (totalTx > 0 && (cancelled + returned) / totalTx > 0.15) {
      final pct = (((cancelled + returned) / totalTx) * 100).toStringAsFixed(0);
      alerts.add(_Alert(
        'Taux d\'annulation élevé',
        '$pct % des transactions sont annulées ou retournées.',
        'medium',
        AppColors.pharmaDanger,
      ));
    }

    if (outstanding > gross * 0.3 && gross > 0) {
      final pct = ((outstanding / gross) * 100).toStringAsFixed(0);
      alerts.add(_Alert(
        'Écart de caisse / créances',
        '$pct % du CA TTC reste à encaisser (${Fmt.number(outstanding, decimals: 2)} MAD).',
        'medium',
        AppColors.pharmaWarning,
      ));
    }

    if (alerts.isEmpty) {
      alerts.add(_Alert(
        'Aucune anomalie détectée',
        'Tous les indicateurs sont dans les normes pour la période sélectionnée.',
        'low',
        AppColors.emerald,
      ));
    }

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
          'Alertes intelligentes',
          style: TextStyle(
            color: AppColors.pharmaText,
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Les alertes sont générées à partir des données réelles de la période. Aucune anomalie n\'est inventée.',
          style: TextStyle(
            color: AppColors.pharmaMuted,
            fontSize: 11,
          ),
        ),
        const SizedBox(height: 20),
        ...alerts.map((alert) => _alertCard(alert)),
      ],
    );
  }

  Widget _alertCard(_Alert alert) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.pharmaSurface.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: alert.color.withValues(alpha: 0.45),
            width: 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: alert.color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  alert.level == 'high'
                      ? Icons.error_outline
                      : alert.level == 'medium'
                      ? Icons.warning_outlined
                      : Icons.check_circle_outline,
                  color: alert.color,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      alert.title,
                      style: TextStyle(
                        color: AppColors.pharmaText,
                        fontWeight: FontWeight.w700,
                        fontSize: 13.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      alert.message,
                      style: TextStyle(
                        color: AppColors.pharmaMuted,
                        fontSize: 11.5,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Alert {
  final String title;
  final String message;
  final String level; // 'high', 'medium', 'low'
  final Color color;

  _Alert(this.title, this.message, this.level, this.color);
}