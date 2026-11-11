/// ============================================================
/// SOUS-PAGE 7 : ANNULATIONS ET RETOURS
/// ============================================================
import 'package:flutter/material.dart';

import '../../../core/theme/colors.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/glass_card.dart';
import '../controllers/sales_day_controller.dart';
import '../models/sales_day_model.dart';
import '../services/sales_analytics_service.dart';
import '../widgets/sales_date_filter.dart';

class SalesReturnsPage extends StatefulWidget {
  final SalesDayController analytics;
  const SalesReturnsPage({super.key, required this.analytics});

  @override
  State<SalesReturnsPage> createState() => _SalesReturnsPageState();
}

class _SalesReturnsPageState extends State<SalesReturnsPage> {
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
    final k = c.analytics?.kpis;
    final tx = c.txRows;
    final cancelled = tx.where((t) =>
        t.status == 'voided' || t.status == 'cancelled').toList();
    final returned = tx.where((t) =>
        t.status == 'returned' || t.status == 'refunded').toList();

    // Construire les lignes de transactions détaillées
    final returnRows = <Widget>[];
    if (cancelled.isEmpty && returned.isEmpty) {
      returnRows.add(const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Aucune annulation ou retour sur la période',
            style: TextStyle(color: AppColors.pharmaMuted),
          ),
        ),
      ));
    } else {
      for (final t in [...cancelled, ...returned]) {
        returnRows.add(_buildTransactionRow(t));
      }
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
        GlassCard(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Annulations et retours',
                  style: TextStyle(
                    color: AppColors.pharmaText,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _kpiItem(
                        'Annulées', '${k?.cancelledCount ?? 0}',
                        AppColors.pharmaDanger,
                      ),
                    ),
                    Expanded(
                      child: _kpiItem(
                        'Retours / remboursés',
                        '${k?.returnedCount ?? 0}',
                        AppColors.pharmaDanger,
                      ),
                    ),
                    Expanded(
                      child: _kpiItem(
                        'Problèmes',
                        '${cancelled.length + returned.length}',
                        AppColors.pharmaWarning,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text(
                  'Détails des transactions annulées / retournées',
                  style: TextStyle(
                    color: AppColors.pharmaText,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                ...returnRows,
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTransactionRow(SalesTransaction t) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.pharmaSurface.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.goldBorder, width: 1),
        ),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t.number.isEmpty ? '—' : t.number,
                      style: const TextStyle(
                        color: AppColors.pharmaText,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${t.statusLabel} · ${t.createdAt == null ? '—' : SalesAnalyticsService.hourMinute(t.createdAt)}',
                      style: const TextStyle(
                        color: AppColors.pharmaMuted,
                        fontSize: 10.5,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                Fmt.number(t.total, decimals: 2),
                style: const TextStyle(
                  color: AppColors.pharmaDanger,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
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