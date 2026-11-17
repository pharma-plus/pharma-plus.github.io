// ============================================================
// SOUS-PAGE 4 : PRODUITS VENDUS
// ============================================================
// Phase 2 : suppression de la carte redondante, classements dans
// des panneaux harmonisés, libellés/unités/périodes explicites.
// Les chiffres proviennent exclusivement de l'API (aucune donnée
// de démonstration, aucun recalcul côté client).
import 'package:flutter/material.dart';

import '../controllers/sales_day_controller.dart';
import '../models/sales_day_model.dart';
import '../services/sales_financials.dart';
import '../widgets/sales_date_filter.dart';
import '../widgets/sales_design_system.dart';
import '../widgets/sales_product_ranking.dart';

class SalesProductsPage extends StatefulWidget {
  final SalesDayController analytics;
  const SalesProductsPage({super.key, required this.analytics});

  @override
  State<SalesProductsPage> createState() => _SalesProductsPageState();
}

class _SalesProductsPageState extends State<SalesProductsPage> {
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
    final topQty = c.analytics?.topProductsQty ?? const <SalesProductRank>[];
    final topRev = c.analytics?.topProductsRev ?? const <SalesProductRank>[];
    final topProfit =
        c.analytics?.topProductsProfit ?? const <SalesProductRank>[];
    final costKnown = SalesFinancials.fromKpis(c.analytics?.kpis).hasCost;

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
          title: 'Produits vendus',
          subtitle:
              '${c.periodLabelText} · top 10 réels · montants MAD · bénéfice selon coût transmis par l\'API',
        ),
        const SizedBox(height: SalesDesign.spacingMD),
        SalesPanel(
          child: SalesProductRanking(
            title: 'Top 10 par CA',
            products: topRev,
            sortBy: 'rev',
          ),
        ),
        const SizedBox(height: SalesDesign.spacingMD),
        SalesPanel(
          child: SalesProductRanking(
            title: 'Top 10 par quantité',
            products: topQty,
            sortBy: 'qty',
          ),
        ),
        const SizedBox(height: SalesDesign.spacingMD),
        SalesPanel(
          child: SalesProductRanking(
            title: 'Top 10 par bénéfice',
            products: topProfit,
            sortBy: 'profit',
          ),
        ),
        const SizedBox(height: SalesDesign.spacingMD),
        SalesNotice(
          warning: costKnown,
          message: costKnown
              ? 'Le classement par bénéfice reflète le coût d\'achat transmis par l\'API pour la période.'
              : 'Coût d\'achat absent, nul ou ambigu : le classement « bénéfice » n\'est pas vérifiable et doit être interprété avec prudence. Aucun coût implicite n\'est appliqué côté interface.',
        ),
      ],
    );
  }
}
