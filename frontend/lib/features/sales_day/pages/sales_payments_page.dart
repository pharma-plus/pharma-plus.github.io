// ============================================================
// SOUS-PAGE 6 : PAIEMENTS ET CAISSE
// ============================================================
// Phase 2 : contrôleurs de saisie créés une seule fois et disposés
// (plus de TextEditingController dans build), écart de caisse
// calculé uniquement lorsque les deux valeurs sont renseignées,
// panneaux et KPI harmonisés.
import 'package:flutter/material.dart';

import '../../../core/theme/colors.dart';
import '../../../core/utils/format.dart';
import '../controllers/sales_day_controller.dart';
import '../models/sales_day_model.dart';
import '../widgets/sales_date_filter.dart';
import '../widgets/sales_design_system.dart';
import '../widgets/sales_payment_chart.dart';

class SalesPaymentsPage extends StatefulWidget {
  final SalesDayController analytics;
  const SalesPaymentsPage({super.key, required this.analytics});

  @override
  State<SalesPaymentsPage> createState() => _SalesPaymentsPageState();
}

class _SalesPaymentsPageState extends State<SalesPaymentsPage> {
  late final VoidCallback _listener;

  // Saisie manuelle de la clôture : valeur locale à la session, non
  // persistée, distincte des KPI financiers calculés par l'API.
  final TextEditingController _theoreticalController = TextEditingController();
  final TextEditingController _countedController = TextEditingController();
  double? _theoreticalCash;
  double? _countedCash;

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
    _theoreticalController.dispose();
    _countedController.dispose();
    super.dispose();
  }

  void _clearCashInputs() {
    _theoreticalController.clear();
    _countedController.clear();
    setState(() {
      _theoreticalCash = null;
      _countedCash = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.analytics;
    final k = c.analytics?.kpis;
    final slices = c.analytics?.payments ?? const <SalesPaymentSlice>[];
    final totalPaid = k?.paidAmount ?? 0;
    final outstanding = k?.outstandingAmount ?? 0;

    // L'écart n'a de sens que si les deux montants sont saisis.
    final cashGap = (_theoreticalCash != null && _countedCash != null)
        ? _countedCash! - _theoreticalCash!
        : null;

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
          title: 'Paiements et caisse',
          subtitle: '${c.periodLabelText} · montants MAD · données réelles API',
        ),
        const SizedBox(height: SalesDesign.spacingSM),
        SalesPanel(
          child: Wrap(
            spacing: SalesDesign.spacingLG,
            runSpacing: SalesDesign.spacingSM,
            children: [
              SalesMetric(
                  label: 'Encaissé',
                  value: Fmt.number(totalPaid, decimals: 2),
                  unit: 'MAD',
                  color: AppColors.sageGreenInk),
              SalesMetric(
                  label: 'Reste à encaisser',
                  value: Fmt.number(outstanding, decimals: 2),
                  unit: 'MAD',
                  color: outstanding > 0
                      ? AppColors.pharmaWarning
                      : AppColors.sageGreenInk),
              SalesMetric(
                  label: 'Moyens détectés',
                  value: '${slices.length}',
                  color: AppColors.cardBlue),
            ],
          ),
        ),
        const SizedBox(height: SalesDesign.spacingLG),
        SalesPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SalesSectionHeader(
                title: 'Clôture de caisse (saisie manuelle)',
                subtitle:
                    'Valeur locale à la session · non persistée · hors KPI financiers',
              ),
              const SizedBox(height: SalesDesign.spacingSM),
              LayoutBuilder(builder: (context, box) {
                final inputs = <Widget>[
                  _cashInput(
                    'Caisse théorique (MAD)',
                    _theoreticalController,
                    AppColors.champagneInk,
                    (v) => setState(
                        () => _theoreticalCash = double.tryParse(v.trim())),
                  ),
                  _cashInput(
                    'Caisse comptée (MAD)',
                    _countedController,
                    AppColors.sageGreenInk,
                    (v) => setState(
                        () => _countedCash = double.tryParse(v.trim())),
                  ),
                ];
                if (box.maxWidth >= 520) {
                  return Row(children: [
                    Expanded(child: inputs[0]),
                    const SizedBox(width: SalesDesign.spacingSM),
                    Expanded(child: inputs[1]),
                  ]);
                }
                return Column(
                  children: [
                    inputs[0],
                    const SizedBox(height: SalesDesign.spacingSM),
                    inputs[1],
                  ],
                );
              }),
              if (cashGap != null) ...[
                const SizedBox(height: SalesDesign.spacingSM),
                Row(
                  children: [
                    const Text(
                      'Écart de caisse : ',
                      style: TextStyle(
                        color: AppColors.inkDark,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      '${cashGap >= 0 ? '+' : ''}${Fmt.money(cashGap)}',
                      style: TextStyle(
                        color: cashGap >= 0
                            ? AppColors.sageGreenInk
                            : AppColors.pharmaDanger,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: SalesDesign.spacingXS),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: _clearCashInputs,
                  icon: const Icon(Icons.clear, size: 14),
                  label: const Text('Effacer la saisie'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: SalesDesign.spacingLG),
        SalesSectionHeader(
          title: 'Répartition des moyens de paiement',
          subtitle:
              'Montants TTC réels par mode · période ${c.periodLabelText}',
        ),
        const SizedBox(height: SalesDesign.spacingSM),
        if (slices.isEmpty)
          const SalesEmptyState(
              message: 'Aucun paiement enregistré sur la période')
        else
          SalesPanel(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
            child: SalesPaymentChart(slices: slices),
          ),
        if (outstanding > 0) ...[
          const SizedBox(height: SalesDesign.spacingMD),
          const SalesNotice(
            message:
                'Des ventes ont un montant restant à encaisser. Vérifiez les paiements partiels et les ventes à crédit.',
          ),
        ],
      ],
    );
  }

  Widget _cashInput(
    String label,
    TextEditingController controller,
    Color color,
    ValueChanged<String> onChanged,
  ) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: color, fontSize: 11),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(SalesDesign.radiusInner),
          borderSide: BorderSide(color: color.withValues(alpha: 0.5)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(SalesDesign.radiusInner),
          borderSide: BorderSide(color: color.withValues(alpha: 0.5)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(SalesDesign.radiusInner),
          borderSide: BorderSide(color: color, width: 1.5),
        ),
      ),
      style: const TextStyle(color: AppColors.inkDark, fontSize: 12),
      onChanged: onChanged,
    );
  }
}
