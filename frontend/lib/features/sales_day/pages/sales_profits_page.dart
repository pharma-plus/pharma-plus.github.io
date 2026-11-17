// ============================================================
// SOUS-PAGE 3 : BÉNÉFICES ET MARGES
// ============================================================
// Règle financière (Phase 2) : un coût non fourni par l'API est
// « N/D » — jamais 0. Aucun bénéfice ni taux de marge n'est calculé
// quand le coût est indisponible (plus de marge trompeuse à ~100 %).
import 'package:flutter/material.dart';

import '../../../core/theme/colors.dart';
import '../../../core/utils/format.dart';
import '../controllers/sales_day_controller.dart';
import '../services/sales_financials.dart';
import '../widgets/sales_date_filter.dart';
import '../widgets/sales_design_system.dart';

class SalesProfitsPage extends StatefulWidget {
  final SalesDayController analytics;
  const SalesProfitsPage({super.key, required this.analytics});

  @override
  State<SalesProfitsPage> createState() => _SalesProfitsPageState();
}

class _SalesProfitsPageState extends State<SalesProfitsPage> {
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
    final f = SalesFinancials.fromKpis(k);
    final gross = f.grossRevenue;
    final net = f.netRevenue;
    final cost = f.costTotal;
    final hasCost = f.hasCost;
    final grossProfit = f.grossProfit;
    final marginPct = f.grossMarginPct;
    final htShare = f.htSharePct;

    String unavailable = f.costUnavailableLabel;
    String money(num? v) =>
        v == null ? unavailable : Fmt.number(v, decimals: 2);
    String pct(num? v) => v == null ? unavailable : '${v.toStringAsFixed(1)} %';

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
        SalesPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SalesSectionHeader(
                title: 'Bénéfices et marges',
                subtitle:
                    '${c.periodLabelText} · montants en MAD · TTC sauf mention HT',
              ),
              const SizedBox(height: SalesDesign.spacingMD),
              LayoutBuilder(builder: (context, box) {
                final wide = box.maxWidth >= 620;
                final metrics = <Widget>[
                  SalesMetric(
                      label: 'CA TTC',
                      value: money(gross),
                      unit: 'MAD',
                      color: AppColors.sageGreenInk),
                  SalesMetric(
                      label: 'Coût d\'achat',
                      value: money(cost),
                      unit: hasCost ? 'MAD' : null,
                      color: hasCost
                          ? AppColors.pharmaDanger
                          : AppColors.pharmaMuted,
                      hint: hasCost ? null : f.costExplanation),
                  SalesMetric(
                      label: 'Bénéfice brut',
                      value: money(grossProfit),
                      unit: hasCost ? 'MAD' : null,
                      color: grossProfit == null
                          ? AppColors.pharmaMuted
                          : (grossProfit >= 0
                              ? AppColors.sageGreenInk
                              : AppColors.pharmaDanger)),
                  SalesMetric(
                      label: 'Taux de marge brute',
                      value: pct(marginPct),
                      color: marginPct == null
                          ? AppColors.pharmaMuted
                          : (marginPct >= 0
                              ? AppColors.sageGreenInk
                              : AppColors.pharmaDanger),
                      hint: hasCost ? 'bénéfice brut / CA TTC' : null),
                  SalesMetric(
                      label: 'CA HT net',
                      value: money(net),
                      unit: 'MAD',
                      color: AppColors.champagneInk,
                      hint: 'après remises, hors TVA'),
                  SalesMetric(
                      label: 'Part HT du CA TTC',
                      value: pct(htShare),
                      color: AppColors.cardBlue,
                      hint: 'ratio HT/TTC — pas une marge'),
                ];
                if (wide) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (var i = 0; i < metrics.length; i++) ...[
                        if (i > 0) const SizedBox(width: SalesDesign.spacingMD),
                        Expanded(child: metrics[i]),
                      ],
                    ],
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var i = 0; i < metrics.length; i++) ...[
                      if (i > 0) const SizedBox(height: SalesDesign.spacingSM),
                      metrics[i],
                    ],
                  ],
                );
              }),
              if (!hasCost) ...[
                const SizedBox(height: SalesDesign.spacingMD),
                SalesNotice(message: f.costExplanation),
              ],
            ],
          ),
        ),
        const SizedBox(height: SalesDesign.spacingLG),
        const Center(
          child: Text(
            'Le détail du bénéfice par produit et par catégorie nécessite le coût d\'achat par article (sale_items.cost_price), actuellement non exposé par l\'API.',
            style: TextStyle(
              color: AppColors.pharmaMuted,
              fontSize: 11.5,
              fontStyle: FontStyle.italic,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}
