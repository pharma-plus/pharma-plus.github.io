// ============================================================
// VENTES DU JOUR — Graphique des ventes par heure (données réelles)
// ============================================================
// Une courbe par heure de la journée (heure locale de la pharmacie) —
// orientation « évolution » imposée par le cahier des charges de la
// refonte : courbe (et non histogramme) pour une lecture d'évolution.
// Infobulle au toucher / survol ; les heures sans vente valent 0
// (réel, affiché tel quel). Aucune estimation.
// ============================================================

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/colors.dart';
import '../../../core/utils/format.dart';
import '../models/sales_day_model.dart';
import 'sales_design_system.dart';

class SalesHourlyChart extends StatelessWidget {
  final List<SalesHourBucket> hourly;
  final String title;

  /// Hauteur du graphique (courbe). Compacte par défaut pour une densité
  /// visuelle maîtrisée.
  final double height;

  /// État de chargement / d'erreur : permet de distinguer « aucune vente »
  /// d'un échec de récupération des données.
  final bool loading;
  final String? errorMessage;

  const SalesHourlyChart({
    super.key,
    required this.hourly,
    this.title = 'Ventes par heure',
    this.height = 168,
    this.loading = false,
    this.errorMessage,
  });

  @override
  Widget build(BuildContext context) {
    final data = hourly;
    final busy = data.any((b) => b.revenue > 0 || b.count > 0);

    double maxY = 0;
    for (final b in data) {
      if (b.revenue > maxY) maxY = b.revenue;
    }
    if (maxY <= 0) maxY = _yInterval(data);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: SalesDesign.onDark,
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 2),
        const Text(
          'Heure locale de la pharmacie · montants TTC réels',
          style: TextStyle(
            color: SalesDesign.onDarkMuted,
            fontSize: 10.5,
          ),
        ),
        const SizedBox(height: 14),
        if (loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 34),
            child: Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                    color: AppColors.champagne, strokeWidth: 2),
              ),
            ),
          )
        else if (errorMessage != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 26),
            child: SalesNotice(
              message: 'Graphique indisponible : $errorMessage',
            ),
          )
        else if (!busy)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 34),
            child: Center(
              child: Text(
                'Aucune vente sur la période',
                style: TextStyle(
                  color: SalesDesign.onDarkMuted,
                  fontSize: 12,
                ),
              ),
            ),
          )
        else
          SizedBox(
            height: height,
            child: LineChart(
              LineChartData(
                minY: 0,
                maxY: maxY,
                lineBarsData: [
                  LineChartBarData(
                    spots: [
                      for (final b in data)
                        FlSpot(b.hour.toDouble(), b.revenue),
                    ],
                    isCurved: true,
                    barWidth: 3,
                    // Alignement maquette : courbe or, points et aire dégradée.
                    color: AppColors.champagneInkLight,
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          AppColors.champagneInkLight.withValues(alpha: 0.32),
                          AppColors.champagneInkLight.withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, bar, index) =>
                          FlDotCirclePainter(
                        color: AppColors.champagneInkLight,
                        radius: 3,
                        strokeColor: AppColors.pharmaSurface,
                        strokeWidth: 1,
                      ),
                    ),
                  ),
                ],
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: _yInterval(data),
                  getDrawingHorizontalLine: (value) => const FlLine(
                    color: Color(0x26C6A76B),
                    strokeWidth: 1,
                  ),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 42,
                      interval: _yInterval(data),
                      getTitlesWidget: (v, m) => Text(
                        Fmt.number(v),
                        style: const TextStyle(
                          color: SalesDesign.onDarkSoft,
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
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                ),
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    tooltipRoundedRadius: SalesDesign.radiusInner,
                    tooltipBorder: const BorderSide(
                      color: AppColors.goldBorder,
                      width: SalesDesign.borderWidth,
                    ),
                    fitInsideHorizontally: true,
                    fitInsideVertically: true,
                    getTooltipColor: (_) => AppColors.pharmaSurface,
                    getTooltipItems: (spots) => spots.map((s) {
                      final hour = s.x.round();
                      final bucket = data.cast<SalesHourBucket?>().firstWhere(
                            (b) => b?.hour == hour,
                            orElse: () => null,
                          );
                      final count = bucket?.count ?? 0;
                      return LineTooltipItem(
                        '${hour.toString().padLeft(2, '0')}h · ${Fmt.money(s.y)}'
                        '${count > 0 ? ' · ${Fmt.number(count)} vente(s)' : ''}',
                        const TextStyle(
                          color: SalesDesign.onDark,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      );
                    }).toList(),
                  ),
                ),
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
    final steps = [
      1.0,
      2.0,
      5.0,
      10.0,
      20.0,
      50.0,
      100.0,
      200.0,
      500.0,
      1000.0,
      2000.0,
      5000.0,
      10000.0
    ];
    for (final s in steps) {
      if (max / s <= 5) return s;
    }
    return 10000;
  }
}
