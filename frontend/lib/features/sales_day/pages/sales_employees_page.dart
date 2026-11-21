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

/// Regroupe les transactions par employé pour le classement.
///
/// La clé d'agrégation est L'IDENTIFIANT SERVEUR (`user_id`) lorsque disponible :
/// deux employés homonymes (même `user_name`) ne doivent JAMAIS être fusionnés
/// en une seule ligne, ce qui fausserait le classement par chiffre d'affaires.
/// En repli (identifiant absent), le nom est utilisé, puis 'Non identifié'.
/// Fonction pure (sans widget) pour être testable unitairement.
Map<String, List<SalesTransaction>> groupTransactionsByEmployee(
    List<SalesTransaction> rows) {
  final byEmployee = <String, List<SalesTransaction>>{};
  for (final t in rows) {
    final id = t.userId;
    final key = (id != null && id.isNotEmpty)
        ? id
        : (t.userName ?? 'Non identifié');
    byEmployee.putIfAbsent(key, () => <SalesTransaction>[]).add(t);
  }
  return byEmployee;
}

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

    final byEmployee = groupTransactionsByEmployee(c.fullRows);
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
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SalesSectionHeader(
                title: 'Classement par chiffre d\'affaires',
                subtitle: 'Barres réelles calculées sur les ventes terminées',
              ),
              const SizedBox(height: SalesDesign.spacingSM),
              SalesPanel(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                child: _buildEmployeeChart(entries),
              ),
              const SizedBox(height: SalesDesign.spacingMD),
              for (final e in entries) _buildEmployeeRow(e),
            ],
          ),
      ],
    );
  }

  /// Libellé d'affichage d'un employé : nom connu, sinon l'identifiant
  /// serveur (jamais une valeur inventée).
  String _employeeLabel(MapEntry<String, List<SalesTransaction>> e) {
    for (final t in e.value) {
      final name = t.userName;
      if (name != null && name.isNotEmpty) return name;
    }
    return e.key;
  }

  /// Barres de classement des employés par CA réel (jeu complet chargé).
  Widget _buildEmployeeChart(
      List<MapEntry<String, List<SalesTransaction>>> entries) {
    final values = <(String, String, double)>[
      for (final e in entries)
        (
          e.key,
          _employeeLabel(e),
          e.value
              .where((t) => t.isCompleted)
              .fold<double>(0, (s, t) => s + t.total),
        ),
    ];
    var max = 0.0;
    for (final v in values) {
      if (v.$3 > max) max = v.$3;
    }
    if (max <= 0) max = 1;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final v in values)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                SizedBox(
                  width: 92,
                  child: Text(
                    v.$2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: SalesDesign.onDarkMuted, fontSize: 10),
                  ),
                ),
                Expanded(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 5,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: (v.$3 / max).clamp(0.0, 1.0),
                        minHeight: 8,
                        color: AppColors.sageGreenInk,
                        backgroundColor:
                            AppColors.pharmaSurface2.withValues(alpha: 0.6),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 78,
                  child: Text(
                    Fmt.number(v.$3, decimals: 2),
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                        color: SalesDesign.onDark, fontSize: 10),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildEmployeeRow(MapEntry<String, List<SalesTransaction>> e) {
    final empSales = e.value;
    final completed = empSales.where((t) => t.isCompleted).toList();
    final grossRevenue = completed.fold<double>(0, (s, t) => s + t.total);
    // CA HT aligné sur le KPI officiel (SalesDayKpis.netRevenue) :
    // Σ (total − tax_total), TVA extraite du TTC après remise.
    // Ne pas utiliser subtotal − discount_total (TTC net) sous le libellé
    // « CA net » : ce serait une grandeur différente du KPI.
    final netRevenue =
        completed.fold<double>(0, (s, t) => s + (t.total - t.taxTotal));
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
                    _employeeLabel(e),
                    style: const TextStyle(
                      color: SalesDesign.onDark,
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
                    'CA HT', Fmt.money(netRevenue), AppColors.champagneInk),
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
            style:
                const TextStyle(color: SalesDesign.onDarkMuted, fontSize: 8.5),
          ),
        ],
      ),
    );
  }
}
