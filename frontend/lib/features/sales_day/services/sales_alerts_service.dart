// ============================================================
// VENTES DU JOUR — Règles d'alertes intelligentes (Phase 2)
// ============================================================
// Évaluation pure (testable) sur les KPI réels de la période et
// de la période précédente. Aucune règle n'est évaluée avec un
// intrant manquant : l'information est signalée comme non
// vérifiable plutôt que de produire un faux négatif/positif.
// ============================================================

import 'package:flutter/material.dart';

import '../../../core/theme/colors.dart';
import '../models/sales_day_model.dart';
import 'sales_financials.dart';

class SalesAlert {
  final String title;
  final String message;
  final String level; // 'high' | 'medium' | 'info' | 'low'
  final Color color;

  const SalesAlert(this.title, this.message, this.level, this.color);
}

class SalesAlertsService {
  SalesAlertsService._();

  static String _n(double v) => v.toStringAsFixed(2);

  static List<SalesAlert> evaluate({
    required SalesDayKpis? kpis,
    required SalesDayKpis? previous,
  }) {
    final alerts = <SalesAlert>[];
    final gross = kpis?.grossRevenue ?? 0;
    final cost = kpis?.costTotal;
    final discounts = kpis?.discountsTotal ?? 0;
    final cancelled = kpis?.cancelledCount ?? 0;
    final returned = kpis?.returnedCount ?? 0;
    final outstanding = kpis?.outstandingAmount ?? 0;

    final financials = SalesFinancials.fromKpis(kpis);
    if (financials.hasCost) {
      final grossProfit = gross - cost!;
      if (gross > 0 && grossProfit < 0) {
        alerts.add(SalesAlert(
          'Marge brute négative',
          'Le coût des marchandises (${_n(cost)} MAD) dépasse le chiffre d\'affaires (${_n(gross)} MAD).',
          'high',
          AppColors.pharmaDanger,
        ));
      }
    } else {
      // Aucun chiffre de marge n'est produit : le coût est absent ou nul
      // ambigu (0 utilisé comme défaut par la source).
      alerts.add(SalesAlert(
        'Marge brute non vérifiable',
        financials.costExplanation +
            ' La règle « marge négative » n\'a pas pu être vérifiée : aucun montant chiffré n\'est affiché.',
        'info',
        AppColors.cardBlue,
      ));
    }

    final prevGross = previous?.grossRevenue;
    if (prevGross != null && prevGross > 0 && gross > 0) {
      if (gross < prevGross * 0.8) {
        final drop = ((1 - gross / prevGross) * 100).toStringAsFixed(0);
        alerts.add(SalesAlert(
          'Baisse inhabituelle du CA',
          'Le CA TTC a baissé de $drop % par rapport à la période précédente.',
          'medium',
          AppColors.pharmaWarning,
        ));
      }
    }

    if (gross > 0 && discounts / gross > 0.2) {
      final pct = ((discounts / gross) * 100).toStringAsFixed(0);
      alerts.add(SalesAlert(
        'Remises anormales',
        'Les remises représentent $pct % du CA TTC, seuil de vigilance : 20 %.',
        'medium',
        AppColors.pharmaWarning,
      ));
    }

    final totalTx = (kpis?.salesCount ?? 0) + cancelled + returned;
    if (totalTx > 0 && (cancelled + returned) / totalTx > 0.15) {
      final pct = (((cancelled + returned) / totalTx) * 100).toStringAsFixed(0);
      alerts.add(SalesAlert(
        'Taux d\'annulation élevé',
        '$pct % des transactions sont annulées ou retournées.',
        'medium',
        AppColors.pharmaDanger,
      ));
    }

    if (gross > 0 && outstanding > gross * 0.3) {
      final pct = ((outstanding / gross) * 100).toStringAsFixed(0);
      alerts.add(SalesAlert(
        'Écart de caisse / créances',
        '$pct % du CA TTC reste à encaisser (${_n(outstanding)} MAD).',
        'medium',
        AppColors.pharmaWarning,
      ));
    }

    final onlyInfo =
        alerts.isNotEmpty && alerts.every((a) => a.level == 'info');
    if (alerts.isEmpty || onlyInfo) {
      alerts.add(const SalesAlert(
        'Aucune anomalie détectée',
        'Tous les indicateurs évaluables sont dans les normes pour la période sélectionnée.',
        'low',
        AppColors.sageGreenInk,
      ));
    }
    return alerts;
  }
}
