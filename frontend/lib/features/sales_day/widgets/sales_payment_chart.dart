/// ============================================================
/// VENTES DU JOUR — Répartition des paiements (données réelles)
/// ============================================================
/// Secteurs alimentés par le détail payments JSONB, sinon payment_method
/// (montant encaissé réel par vente) — mention explicite sous le titre.
/// ============================================================

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/colors.dart';
import '../../../core/utils/format.dart';
import '../models/sales_day_model.dart';

class SalesPaymentChart extends StatelessWidget {
  final List<SalesPaymentSlice> slices;
  final String title;

  const SalesPaymentChart({
    super.key,
    required this.slices,
    this.title = 'Répartition des paiements',
  });

  static const List<Color> _palette = [
    AppColors.sageGreenInk,
    AppColors.champagneInk,
    AppColors.cardBlue,
    AppColors.cardPurple,
    AppColors.cardAmber,
    AppColors.sageGreenInk,
  ];

  @override
  Widget build(BuildContext context) {
    final total = slices.fold(0.0, (s, p) => s + p.amount);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: AppColors.inkDark,
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 2),
        const Text(
          'Détail réel des paiements de la période (décaissé, hors monnaie rendue)',
          style: TextStyle(color: AppColors.pharmaMuted, fontSize: 10.5),
        ),
        const SizedBox(height: 14),
        if (slices.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 28),
            child: Center(
              child: Text(
                'Aucun paiement enregistré sur la période',
                style: TextStyle(color: AppColors.pharmaMuted, fontSize: 12),
              ),
            ),
          )
        else
          Column(
            children: [
              SizedBox(
                height: 150,
                child: PieChart(
                  PieChartData(
                    centerSpaceRadius: 34,
                    sectionsSpace: 1.5,
                    pieTouchData: PieTouchData(enabled: false),
                    sections: [
                      for (final (i, p) in slices.indexed)
                        PieChartSectionData(
                          value: p.amount <= 0 ? 0.0001 : p.amount,
                          color: _palette[i % _palette.length],
                          radius: 52,
                          showTitle: false,
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              for (final (i, p) in slices.indexed)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: _palette[i % _palette.length],
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          p.label,
                          style: const TextStyle(
                            color: AppColors.inkDark,
                            fontSize: 11.5,
                          ),
                        ),
                      ),
                      Text(
                        '${Fmt.number(p.amount, decimals: 2)} MAD · '
                        '${total > 0 ? ((p.amount / total) * 100).toStringAsFixed(1) : '0'} %',
                        style: const TextStyle(
                          color: AppColors.pharmaMuted,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
      ],
    );
  }
}
