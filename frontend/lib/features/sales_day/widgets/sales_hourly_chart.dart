/// ============================================================
/// VENTES DU JOUR — Graphique des ventes par heure (données réelles)
/// ============================================================
/// Une barre par heure de la journée (heure locale de la pharmacie).
/// Infobulle au toucher / survol ; les heures sans vente valent 0
/// (réel, affiché tel quel). Aucune estimation.
/// ============================================================

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/colors.dart';
import '../../../core/utils/format.dart';
import '../models/sales_day_model.dart';

class SalesHourlyChart extends StatelessWidget {
  final List<SalesHourBucket> hourly;
  final String title;

  const SalesHourlyChart({
    super.key,
    required this.hourly,
    this.title = 'Ventes par heure',
  });

  @override
  Widget build(BuildContext context) {
    final data = hourly;
    final busy = data.any((b) => b.revenue > 0 || b.count > 0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: AppColors.pharmaText,
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          'Heure locale de la pharmacie · montants TTC réels',
          style: const TextStyle(
            color: AppColors.pharmaMuted,
            fontSize: 10.5,
          ),
        ),
        const SizedBox(height: 14),
        if (!busy)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 34),
            child: Center(
              child: Text(
                'Aucune vente sur la période',
                style: TextStyle(
                  color: AppColors.pharmaMuted,
                  fontSize: 12,
                ),
              ),
            ),
          )
        else
          SizedBox(
            height: 190,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                gridData: const FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 1,
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 42,
                      interval: _yInterval(data),
                      getTitlesWidget: (v, m) => Text(
                        Fmt.number(v),
                        style: const TextStyle(
                          color: AppColors.pharmaMuted,
                          fontSize: 9,
                        ),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 18,
                      interval: 3,
                      getTitlesWidget: (v, m) {
                        final h = v.toInt();
                        if (h < 0 || h > 23) return const SizedBox.shrink();
                        return Text(
                          '${h.toString().padLeft(2, '0')}h',
                          style: const TextStyle(
                            color: AppColors.pharmaMuted,
                            fontSize: 9,
                          ),
                        );
                      },
                    ),
                  ),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipItem: (group, gi, rod, ri) {
                      final h = group.x.toInt();
                      SalesHourBucket? bucket;
                      for (final b in data) {
                        if (b.hour == h) {
                          bucket = b;
                          break;
                        }
                      }
                      return BarTooltipItem(
                        '${h.toString().padLeft(2, '0')}:00',
                        const TextStyle(
                          color: AppColors.pharmaText,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                        children: [
                          TextSpan(
                            text: '\n${Fmt.money(rod.toY)}',
                            style: const TextStyle(
                              color: AppColors.pharmaGoldLight,
                              fontSize: 11,
                            ),
                          ),
                          if (bucket != null)
                            TextSpan(
                              text: '\n${bucket.count} vente${bucket.count > 1 ? 's' : ''}',
                              style: const TextStyle(
                                color: AppColors.pharmaMuted,
                                fontSize: 10,
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ),
                barGroups: [
                  for (final b in data)
                    BarChartGroupData(
                      x: b.hour,
                      barRods: [
                        BarChartRodData(
                          toY: b.revenue,
                          width: data.length > 12 ? 10 : 18,
                          borderRadius: BorderRadius.circular(3),
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [
                              AppColors.emeraldDark.withValues(alpha: 0.95),
                              AppColors.emerald.withValues(alpha: 0.95),
                              AppColors.emeraldLight.withValues(alpha: 0.95),
                            ],
                          ),
                        ),
                      ],
                    ),
                ],
                extraLinesData: const ExtraLinesData(),
                minY: 0,
              ),
            ),
          ),
      ],
    );
  }

  static double _yInterval(List<SalesHourBucket> data) {
    if (data.isEmpty) return 1;
    double max = 0;
    for (final b in data) {
      if (b.revenue > max) max = b.revenue;
    }
    if (max <= 0) return 1;
    final steps = [1.0, 2.0, 5.0, 10.0, 20.0, 50.0, 100.0, 200.0, 500.0, 1000.0, 2000.0, 5000.0, 10000.0];
    for (final s in steps) {
      if (max / s <= 5) return s;
    }
    return 10000;
  }
}
