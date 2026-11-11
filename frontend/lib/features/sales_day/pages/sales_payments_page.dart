/// ============================================================
/// SOUS-PAGE 6 : PAIEMENTS ET CAISSE
/// ============================================================
import 'package:flutter/material.dart';

import '../../../core/theme/colors.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/glass_card.dart';
import '../controllers/sales_day_controller.dart';
import '../models/sales_day_model.dart';
import '../services/sales_analytics_service.dart';
import '../widgets/sales_date_filter.dart';
import '../widgets/sales_payment_chart.dart';

class SalesPaymentsPage extends StatefulWidget {
  final SalesDayController analytics;
  const SalesPaymentsPage({super.key, required this.analytics});

  @override
  State<SalesPaymentsPage> createState() => _SalesPaymentsPageState();
}

class _SalesPaymentsPageState extends State<SalesPaymentsPage> {
  // Saisie manuelle de la clôture de caisse (non stockée côté backend,
  // affichage local uniquement pour la session courante)
  double? _theoreticalCash;
  double? _countedCash;

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
    final slices = c.analytics?.payments ?? const <SalesPaymentSlice>[];
    final totalPaid = k?.paidAmount ?? 0;
    final outstanding = k?.outstandingAmount ?? 0;

    // Calcul de l'écart de caisse si les deux saisis sont présents
    double? cashGap;
    if (_countedCash != null && _theoreticalCash != null) {
      cashGap = _countedCash! - _theoreticalCash!;
    } else if (_countedCash != null) {
      cashGap = _countedCash! - totalPaid;
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
                  'Paiements et caisse',
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
                        'Encaissé', Fmt.number(totalPaid, decimals: 2),
                        AppColors.emerald,
                      ),
                    ),
                    Expanded(
                      child: _kpiItem(
                        'Reste à encaisser', Fmt.number(outstanding, decimals: 2),
                        outstanding > 0 ? AppColors.pharmaWarning : AppColors.emerald,
                      ),
                    ),
                    Expanded(
                      child: _kpiItem(
                        'Moyens détectés', '${slices.length}',
                        AppColors.cardBlue,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                // Saisie manuelle de la clôture de caisse
                const Text(
                  'Clôture de caisse (saisie manuelle)',
                  style: TextStyle(
                    color: AppColors.pharmaText,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _cashInput(
                        'CAISSE THÉORIQUE',
                        _theoreticalCash?.toStringAsFixed(2),
                        AppColors.pharmaGold,
                        (v) => setState(() => _theoreticalCash =
                            double.tryParse(v)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _cashInput(
                        'CAISSE COMPTÉE',
                        _countedCash?.toStringAsFixed(2),
                        AppColors.emerald,
                        (v) => setState(() => _countedCash =
                            double.tryParse(v)),
                      ),
                    ),
                  ],
                ),
                if (cashGap != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Row(
                      children: [
                        const Text(
                          'Écart de caisse : ',
                          style: TextStyle(
                            color: AppColors.pharmaText,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          '${cashGap >= 0 ? '+' : ''}${Fmt.money(cashGap)}',
                          style: TextStyle(
                            color: cashGap >= 0
                                ? AppColors.emerald
                                : AppColors.pharmaDanger,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        if (slices.isNotEmpty)
          SalesPaymentChart(slices: slices)
        else
          const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Aucun paiement enregistré sur la période',
                style: TextStyle(color: AppColors.pharmaMuted),
              ),
            ),
          ),
        const SizedBox(height: 12),
        if (outstanding > 0)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.pharmaWarning.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: AppColors.pharmaWarning.withValues(alpha: 0.45),
                width: 1,
              ),
            ),
            child: const Text(
              'Des ventes ont un montant restant à encaisser. Vérifiez les paiements partiels et les ventes à crédit.',
              style: TextStyle(
                color: AppColors.pharmaWarning,
                fontSize: 11,
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

  Widget _cashInput(String label, String? initialValue, Color color,
      ValueChanged<String> onChanged) {
    return TextField(
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: color, fontSize: 11),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: color.withValues(alpha: 0.5)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: color.withValues(alpha: 0.5)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: color, width: 1.5),
        ),
      ),
      style: const TextStyle(color: AppColors.pharmaText, fontSize: 12),
      controller: TextEditingController(text: initialValue),
      onChanged: (v) {
        onChanged(v);
      },
    );
  }
}