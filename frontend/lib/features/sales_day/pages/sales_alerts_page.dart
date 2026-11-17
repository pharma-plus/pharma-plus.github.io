// ============================================================
// SOUS-PAGE 10 : ALERTES INTELLIGENTES
// ============================================================
// Les règles sont évaluées par SalesAlertsService (pur et testable)
// sur les KPI réels de la période. Une règle dont l'intrant est
// indisponible n'est pas évaluée et l'information le signale.
import 'package:flutter/material.dart';

import '../../../core/theme/colors.dart';
import '../controllers/sales_day_controller.dart';
import '../services/sales_alerts_service.dart';
import '../widgets/sales_date_filter.dart';
import '../widgets/sales_design_system.dart';

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
    final alerts = SalesAlertsService.evaluate(
      kpis: c.analytics?.kpis,
      previous: c.previousKpis,
    );

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
          title: 'Alertes intelligentes',
          subtitle:
              '${c.periodLabelText} · règles évaluées sur les données réelles · aucun seuil inventé',
        ),
        const SizedBox(height: SalesDesign.spacingMD),
        for (final alert in alerts) _alertCard(alert),
      ],
    );
  }

  Widget _alertCard(SalesAlert alert) {
    return Padding(
      padding: const EdgeInsets.only(bottom: SalesDesign.spacingSM),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.pharmaSurface.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(SalesDesign.radiusInner),
          border: Border.all(
            color: alert.color.withValues(alpha: 0.45),
            width: SalesDesign.borderWidth,
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
                  switch (alert.level) {
                    'high' => Icons.error_outline,
                    'medium' => Icons.warning_outlined,
                    'info' => Icons.info_outline,
                    _ => Icons.check_circle_outline,
                  },
                  color: alert.color,
                  size: 20,
                ),
              ),
              const SizedBox(width: SalesDesign.spacingSM),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      alert.title,
                      style: const TextStyle(
                        color: AppColors.inkDark,
                        fontWeight: FontWeight.w700,
                        fontSize: 13.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      alert.message,
                      style: const TextStyle(
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
