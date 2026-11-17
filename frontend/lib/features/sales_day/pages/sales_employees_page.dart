// ============================================================
// SOUS-PAGE 5 : PERFORMANCE EMPLOYÉS
// ============================================================
// Phase 2 : agrégation sur TOUTES les transactions de la période
// (jeu complet chargé via la pagination serveur), plus sur les 50
// premières lignes. Les montants sont calculés sur les ventes
// terminées uniquement, comme les KPI officiels.
import 'package:flutter/material.dart';

import '../../../core/theme/colors.dart';
import '../../../core/utils/format.dart';
import '../controllers/sales_day_controller.dart';
import '../models/sales_day_model.dart';
import '../widgets/sales_date_filter.dart';
import '../widgets/sales_design_system.dart';

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

  void _requestFull() {
    final c = widget.analytics;
    if (c.analytics == null || c.fullLoading) return;
    if (c.fullRows.isNotEmpty || c.fullError != null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) c.ensureFullTransactions();
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.analytics;
    _requestFull();

    final byEmployee = <String, List<SalesTransaction>>{};
    for (final t in c.fullRows) {
      final key = t.userName ?? t.userId ?? 'Non identifié';
      byEmployee.putIfAbsent(key, () => <SalesTransaction>[]).add(t);
    }
    final entries = byEmployee.entries.toList()
      ..sort((a, b) {
        final caA = a.value
            .where((t) => t.isCompleted)
            .fold<double>(0, (s, t) => s + t.total);
        final caB = b.value
            .where((t) => t.isCompleted)
            .fold<double>(0, (s, t) => s + t.total);
        return caB.compareTo(caA);
      });

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
          title: 'Performance employés',
          subtitle:
              '${c.fullScopeLabel} · ${c.fullRows.length} transaction(s) · ventes terminées',
        ),
        const SizedBox(height: SalesDesign.spacingSM),
        if (c.fullLoading)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(
                child:
                    CircularProgressIndicator(color: AppColors.sageGreenInk)),
          )
        else if (c.fullError != null)
          SalesNotice(
            message:
                'Agrégation indisponible : ${c.fullError!.userMessage}. Réessayez.',
          )
        else if (!c.fullComplete)
          const SalesNotice(
            message:
                'Jeu de transactions tronqué : l\'agrégation par employé serait inexacte. Elle est masquée plutôt que de produire un résultat partiel.',
          )
        else if (entries.isEmpty)
          const SalesEmptyState(message: 'Aucune transaction sur la période')
        else
          for (final e in entries) _buildEmployeeRow(e),
      ],
    );
  }

  Widget _buildEmployeeRow(MapEntry<String, List<SalesTransaction>> e) {
    final empSales = e.value;
    final completed = empSales.where((t) => t.isCompleted).toList();
    final grossRevenue = completed.fold<double>(0, (s, t) => s + t.total);
    final netRevenue =
        completed.fold<double>(0, (s, t) => s + (t.subtotal - t.discountTotal));
    final discounts = completed.fold<double>(0, (s, t) => s + t.discountTotal);
    final paid = completed.fold<double>(0, (s, t) => s + t.paidAmount);
    final cancelled = empSales
        .where((t) => t.status == 'voided' || t.status == 'cancelled')
        .length;
    final returned = empSales
        .where((t) => t.status == 'returned' || t.status == 'refunded')
        .length;
    final basket = completed.isNotEmpty ? grossRevenue / completed.length : 0.0;

    return Padding(
      padding: const EdgeInsets.only(bottom: SalesDesign.spacingSM),
      child: SalesPanel(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    e.key,
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
            const SizedBox(height: SalesDesign.spacingSM),
            Wrap(
              spacing: SalesDesign.spacingLG,
              runSpacing: SalesDesign.spacingSM,
              children: [
                _empMetric(
                    'Ventes', '${completed.length}', AppColors.sageGreenInk),
                _empMetric(
                    'CA net', Fmt.money(netRevenue), AppColors.champagneInk),
                _empMetric(
                    'Panier moyen', Fmt.money(basket), AppColors.cardBlue),
                _empMetric(
                    'Remises', Fmt.money(discounts), AppColors.pharmaWarning),
                _empMetric('Encaissé', Fmt.money(paid), AppColors.sageGreenInk),
                _empMetric('Annulées', '$cancelled', AppColors.pharmaDanger),
                _empMetric('Retours', '$returned', AppColors.pharmaDanger),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _empMetric(String label, String value, Color color) {
    return SizedBox(
      width: 92,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            label,
            style: const TextStyle(color: AppColors.pharmaMuted, fontSize: 8.5),
          ),
        ],
      ),
    );
  }
}
