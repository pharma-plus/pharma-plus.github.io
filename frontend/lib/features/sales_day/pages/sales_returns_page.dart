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
    final tx = c.txRows;
    final cancelled = tx.where((t) =>
        t.status == 'voided' || t.status == 'cancelled').toList();
    final returned = tx.where((t) =>
        t.status == 'returned' || t.status == 'refunded').toList();

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
                        'Remboursées / Retours',
                        '${k?.returnedCount ?? 0}',
                        AppColors.pharmaMuted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ...returnRows,
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
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
              '',
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

  Widget _buildTransactionRow(SalesTransaction t) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        title: Text(
          t.number.isEmpty ? '—' : t.number,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          t.createdAt == null
              ? '—'
              : '${t.createdAt!.day}/${t.createdAt!.month}/${t.createdAt!.year}',
          style: const TextStyle(fontSize: 12),
        ),
        trailing: Text(
          t.statusLabel,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
        ),
      ),
    );
  }
}