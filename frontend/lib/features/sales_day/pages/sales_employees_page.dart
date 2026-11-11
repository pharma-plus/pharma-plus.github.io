/// ============================================================
/// SOUS-PAGE 5 : PERFORMANCE EMPLOYÉS
/// ============================================================
import 'package:flutter/material.dart';

import '../../../core/theme/colors.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/glass_card.dart';
import '../controllers/sales_day_controller.dart';
import '../models/sales_day_model.dart';
import '../services/sales_analytics_service.dart';
import '../widgets/sales_date_filter.dart';

class SalesEmployeesPage extends StatefulWidget {
  final SalesDayController analytics;
  const SalesEmployeesPage({super.key, required this.analytics});

  @override
  State<SalesEmployeesPage> createState() => _SalesEmployeesPageState();
}

class _SalesEmployeesPageState extends State<SalesEmployeesPage> {
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
    final tx = c.txRows;

    final byEmployee = <String, List<SalesTransaction>>{};
    tx.forEach((t) {
      final key = (t.userName ?? t.userId ?? 'Non identifié');
      byEmployee.putIfAbsent(key, () => []).add(t);
    });
    final entries = byEmployee.entries.toList()
      ..sort((a, b) {
        final caA = a.value.fold<double>(0, (s, t) => s + t.total);
        final caB = b.value.fold<double>(0, (s, t) => s + t.total);
        return caB.compareTo(caA);
      });

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 30),
      children: [
        SalesDateFilter(
          period: widget.analytics.period,
          customRange: widget.analytics.custom,
          periodLabel: widget.analytics.periodLabelText,
          onSelect: (p) => widget.analytics.setPeriod(p),
          onCustomRange: (r) => widget.analytics.setCustomRange(r),
        ),
        const SizedBox(height: 14),
        if (entries.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Aucune transaction sur la période',
                style: TextStyle(color: AppColors.pharmaMuted),
              ),
            ),
          )
        else
          ...entries.map(_buildEmployeeRow),
      ],
    );
  }

  Widget _buildEmployeeRow(MapEntry<String, List<SalesTransaction>> e) {
    final empName = e.key;
    final empSales = e.value;
    final completed = empSales.where((t) => t.isCompleted).toList();
    final grossRevenue = empSales.fold<double>(0, (s, t) => s + t.total);
    final netRevenue = empSales.fold<double>(
        0, (s, t) => s + (t.subtotal - t.discountTotal));
    final discounts = empSales.fold<double>(0, (s, t) => s + t.discountTotal);
    final paid = empSales.fold<double>(0, (s, t) => s + t.paidAmount);
    final cancelled = empSales.where((t) =>
        t.status == 'voided' || t.status == 'cancelled').length;
    final returned = empSales.where((t) =>
        t.status == 'returned' || t.status == 'refunded').length;
    final basket = completed.isNotEmpty
        ? grossRevenue / completed.length
        : 0.0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.pharmaSurface.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.goldBorder, width: 1),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      empName,
                      style: const TextStyle(
                        color: AppColors.inkDark,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  Text(
                    Fmt.money(grossRevenue),
                    style: const TextStyle(
                      color: AppColors.champagneInkLight,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _empMetric('Ventes', '${completed.length}',
                        AppColors.sageGreenInk),
                  ),
                  Expanded(
                    child: _empMetric(
                        'CA net', Fmt.money(netRevenue), AppColors.champagneInk),
                  ),
                  Expanded(
                    child: _empMetric(
                        'Panier moyen', Fmt.money(basket), AppColors.cardBlue),
                  ),
                  Expanded(
                    child: _empMetric('Remises', Fmt.money(discounts),
                        AppColors.pharmaWarning),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _empMetric(
                        'Encaissé', Fmt.money(paid), AppColors.sageGreenInk),
                  ),
                  Expanded(
                    child: _empMetric(
                        'Annulées', '$cancelled', AppColors.pharmaDanger),
                  ),
                  Expanded(
                    child: _empMetric(
                        'Retours', '$returned', AppColors.pharmaDanger),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _empMetric(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 1),
        Text(
          label,
          style: const TextStyle(
            color: AppColors.pharmaMuted,
            fontSize: 8.5,
          ),
        ),
      ],
    );
  }
}