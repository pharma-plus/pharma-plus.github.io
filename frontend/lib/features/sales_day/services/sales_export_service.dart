/// ============================================================
/// VENTES DU JOUR — Service d'export (PDF · Excel · Impression)
/// ============================================================
/// Réutilise les services officiels existants de l'application
/// (`ReportExport` : PDF + CSV-Excel UTF-8 + téléchargement web).
/// Fidélité : les documents n'utilisent QUE les KPI et transactions
/// affichés à l'écran (mêmes données, mêmes filtres) — jamais de
/// recalcul ni de valeur inventée.
/// ============================================================

import 'package:excel/excel.dart';
import '../../../core/services/report_export.dart';
import '../models/sales_day_model.dart';



class SalesExportService {
  const SalesExportService._();

  static String _num(double v) {
    final rounded = v.roundToDouble() == v ? v.toStringAsFixed(0) : v.toStringAsFixed(2);
    return rounded;
  }

  /// Secteurs identiques à l'affichage écran (affichage == export).
  static List<Map<String, dynamic>> _sections(
    SalesDayAnalytics analytics,
    List<SalesTransaction> transactions,
  ) {
    final k = analytics.kpis;
    return <Map<String, dynamic>>[
      ReportExport.section('Indicateurs de la période', ['Indicateur', 'Valeur'], [
        ['Chiffre d\'affaires brut (TTC)', '${_num(k.grossRevenue)} MAD'],
        ['Chiffre d\'affaires net (HT)', '${_num(k.netRevenue)} MAD'],
        ['TVA facturée', '${_num(k.taxTotal)} MAD'],
        ['Total des remises', '${_num(k.discountsTotal)} MAD'],
        ['Ventes validées', '${k.salesCount}'],
        ['Panier moyen', '${_num(k.averageBasket)} MAD'],
        ['Ventes annulées', '${k.cancelledCount}'],
        ['Ventes remboursées / retours', '${k.returnedCount}'],
        ['Montant encaissé', '${_num(k.paidAmount)} MAD'],
        ['Restant à encaisser', '${_num(k.outstandingAmount)} MAD'],
        if (k.refundedAmount != null)
          ['Remboursements réels (retours)', '${_num(k.refundedAmount!)} MAD'],
        ['Coût des marchandises vendues', '${_num(k.costTotal)} MAD'],
      ]),
      if (analytics.payments.isNotEmpty)
        ReportExport.section('Répartition des paiements',
            ['Mode', 'Montant (MAD)', 'Transactions'], [
          for (final p in analytics.payments)
            [p.label, p.amount.toStringAsFixed(2), '${p.count}'],
        ]),
      if (analytics.topProductsRev.isNotEmpty)
        ReportExport.section('Top 10 produits par CA',
            ['#', 'Produit', 'Quantité', 'CA (MAD)', 'Bénéfice (MAD)', 'Marge'], [
          for (final (i, p) in analytics.topProductsRev.indexed)
            [
              '${i + 1}',
              (p.dosage == null || p.dosage!.isEmpty)
                  ? p.displayName
                  : '${p.displayName} (${p.dosage})',
              p.quantity.toStringAsFixed(0),
              p.revenue.toStringAsFixed(2),
              p.profit.toStringAsFixed(2),
              '${p.marginPct.toStringAsFixed(0)} %',
            ],
        ]),
      if (analytics.topProductsQty.isNotEmpty)
        ReportExport.section('Top 10 produits par quantité',
            ['#', 'Produit', 'Quantité', 'CA (MAD)', 'Bénéfice (MAD)', 'Marge'], [
          for (final (i, p) in analytics.topProductsQty.indexed)
            [
              '${i + 1}',
              (p.dosage == null || p.dosage!.isEmpty)
                  ? p.displayName
                  : '${p.displayName} (${p.dosage})',
              p.quantity.toStringAsFixed(0),
              p.revenue.toStringAsFixed(2),
              p.profit.toStringAsFixed(2),
              '${p.marginPct.toStringAsFixed(0)} %',
            ],
        ]),
      if (analytics.topProductsProfit.isNotEmpty)
        ReportExport.section('Top 10 produits par bénéfice',
            ['#', 'Produit', 'Quantité', 'CA (MAD)', 'Bénéfice (MAD)', 'Marge'], [
          for (final (i, p) in analytics.topProductsProfit.indexed)
            [
              '${i + 1}',
              (p.dosage == null || p.dosage!.isEmpty)
                  ? p.displayName
                  : '${p.displayName} (${p.dosage})',
              p.quantity.toStringAsFixed(0),
              p.revenue.toStringAsFixed(2),
              p.profit.toStringAsFixed(2),
              '${p.marginPct.toStringAsFixed(0)} %',
            ],
        ]),
      if (transactions.isNotEmpty)
        ReportExport.section('Transactions',
            ['Référence', 'Date/heure', 'Statut', 'Total (MAD)', 'Encaissé (MAD)', 'Mode'], [
          for (final t in transactions)
            [
              t.number.isEmpty ? '—' : t.number,
              t.createdAt == null ? '—' : _fmtDateTime(t.createdAt!.toLocal()),
              t.statusLabel,
              t.total.toStringAsFixed(2),
              t.paidAmount.toStringAsFixed(2),
              (t.paymentMethod == null || t.paymentMethod!.isEmpty)
                  ? '—'
                  : SalesPaymentSlice.methodLabel(t.paymentMethod!),
            ],
        ]),
    ];
  }

  static String _fmtDateTime(DateTime d) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)}/${d.year} ${two(d.hour)}:${two(d.minute)}';
  }

  /// Export PDF complet (téléchargement web, sinon impression).
  static Future<void> exportPdf({
    required String periodLabel,
    required SalesDayAnalytics analytics,
    required List<SalesTransaction> transactions,
  }) async {
    await ReportExport.exportPdf(
      'Ventes du jour',
      _sections(analytics, transactions),
      periodLabel,
    );
  }

  /// Export Excel (CSV UTF-8 + BOM, ouvre dans Excel / LibreOffice).
  static void exportExcel({
    required String periodLabel,
    required SalesDayAnalytics analytics,
    required List<SalesTransaction> transactions,
  }) {
    ReportExport.exportCsv(
      'Ventes_du_jour',
      _sections(analytics, transactions),
    );
  }

  /// Export Excel véritable (.xlsx) avec mise en forme.
  /// Utilise l'API officielle du package `excel` v4.0.6 :
  ///   TextCellValue / DoubleCellValue / IntCellValue pour les cellules,
  ///   CellIndex.indexByColumnRow pour l'adressage,
  ///   sheet.insertRow(int) pour l'insertion de lignes.
  static Future<void> exportXlsx({
    required String periodLabel,
    required SalesDayAnalytics analytics,
    required List<SalesTransaction> transactions,
  }) async {
    final k = analytics.kpis;
    final excel = Excel.createExcel();

    // Helper: écrit une valeur dans une cellule selon son type
    void setCell(Data cell, Object? value) {
      if (value == null) {
        cell.value = TextCellValue('');
      } else if (value is num) {
        cell.value = DoubleCellValue(value.toDouble());
      } else if (value is bool) {
        cell.value = BoolCellValue(value);
      } else {
        cell.value = TextCellValue(value.toString());
      }
    }

    // --- Feuille : Indicateurs ---
    final sheetKpi = excel['Indicateurs'];
    sheetKpi.insertRow(0);
    sheetKpi.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0)).value =
        TextCellValue('Indicateur');
    sheetKpi.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: 0)).value =
        TextCellValue('Valeur');
    final kpiRows = <List<Object?>>[
      ['Chiffre d\'affaires brut (TTC)', k.grossRevenue],
      ['Chiffre d\'affaires net (HT)', k.netRevenue],
      ['TVA facturée', k.taxTotal],
      ['Total des remises', k.discountsTotal],
      ['Ventes validées', k.salesCount.toDouble()],
      ['Panier moyen', k.averageBasket],
      ['Ventes annulées', k.cancelledCount.toDouble()],
      ['Ventes remboursées / retours', k.returnedCount.toDouble()],
      ['Montant encaissé', k.paidAmount],
      ['Restant à encaisser', k.outstandingAmount],
      if (k.refundedAmount != null) ['Remboursements réels', k.refundedAmount],
      ['Coût des marchandises vendues', k.costTotal],
    ];
    for (int i = 0; i < kpiRows.length; i++) {
      sheetKpi.insertRow(i + 1);
      final row = kpiRows[i];
      for (int j = 0; j < row.length; j++) {
        final v = row[j];
        setCell(
          sheetKpi.cell(CellIndex.indexByColumnRow(columnIndex: j, rowIndex: i + 1)),
          v,
        );
      }
    }

    // --- Feuille : Top 10 par CA ---
    if (analytics.topProductsRev.isNotEmpty) {
      final sheetTopRev = excel['Top 10 CA'];
      sheetTopRev.insertRow(0);
      sheetTopRev.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0)).value =
          TextCellValue('#');
      sheetTopRev.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: 0)).value =
          TextCellValue('Produit');
      sheetTopRev.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: 0)).value =
          TextCellValue('Quantité');
      sheetTopRev.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: 0)).value =
          TextCellValue('CA (MAD)');
      sheetTopRev.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: 0)).value =
          TextCellValue('Bénéfice (MAD)');
      sheetTopRev.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: 0)).value =
          TextCellValue('Marge');
      for (final (i, p) in analytics.topProductsRev.indexed) {
        sheetTopRev.insertRow(i + 1);
        sheetTopRev.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: i + 1)).value =
            IntCellValue(i + 1);
        sheetTopRev.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: i + 1)).value =
            TextCellValue(p.displayName);
        sheetTopRev.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: i + 1)).value =
            TextCellValue(p.quantity.toStringAsFixed(0));
        sheetTopRev.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: i + 1)).value =
            DoubleCellValue(p.revenue);
        sheetTopRev.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: i + 1)).value =
            DoubleCellValue(p.profit);
        sheetTopRev.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: i + 1)).value =
            TextCellValue('${p.marginPct.toStringAsFixed(0)} %');
      }
    }

    // --- Feuille : Top 10 par quantité ---
    if (analytics.topProductsQty.isNotEmpty) {
      final sheetTopQty = excel['Top 10 Qté'];
      sheetTopQty.insertRow(0);
      sheetTopQty.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0)).value =
          TextCellValue('#');
      sheetTopQty.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: 0)).value =
          TextCellValue('Produit');
      sheetTopQty.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: 0)).value =
          TextCellValue('Quantité');
      sheetTopQty.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: 0)).value =
          TextCellValue('CA (MAD)');
      sheetTopQty.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: 0)).value =
          TextCellValue('Bénéfice (MAD)');
      sheetTopQty.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: 0)).value =
          TextCellValue('Marge');
      for (final (i, p) in analytics.topProductsQty.indexed) {
        sheetTopQty.insertRow(i + 1);
        sheetTopQty.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: i + 1)).value =
            IntCellValue(i + 1);
        sheetTopQty.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: i + 1)).value =
            TextCellValue(p.displayName);
        sheetTopQty.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: i + 1)).value =
            TextCellValue(p.quantity.toStringAsFixed(0));
        sheetTopQty.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: i + 1)).value =
            DoubleCellValue(p.revenue);
        sheetTopQty.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: i + 1)).value =
            DoubleCellValue(p.profit);
        sheetTopQty.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: i + 1)).value =
            TextCellValue('${p.marginPct.toStringAsFixed(0)} %');
      }
    }

    // --- Feuille : Top 10 par bénéfice ---
    if (analytics.topProductsProfit.isNotEmpty) {
      final sheetTopProfit = excel['Top 10 Bénéfice'];
      sheetTopProfit.insertRow(0);
      sheetTopProfit.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0)).value =
          TextCellValue('#');
      sheetTopProfit.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: 0)).value =
          TextCellValue('Produit');
      sheetTopProfit.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: 0)).value =
          TextCellValue('Quantité');
      sheetTopProfit.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: 0)).value =
          TextCellValue('CA (MAD)');
      sheetTopProfit.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: 0)).value =
          TextCellValue('Bénéfice (MAD)');
      sheetTopProfit.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: 0)).value =
          TextCellValue('Marge');
      for (final (i, p) in analytics.topProductsProfit.indexed) {
        sheetTopProfit.insertRow(i + 1);
        sheetTopProfit.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: i + 1)).value =
            IntCellValue(i + 1);
        sheetTopProfit.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: i + 1)).value =
            TextCellValue(p.displayName);
        sheetTopProfit.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: i + 1)).value =
            TextCellValue(p.quantity.toStringAsFixed(0));
        sheetTopProfit.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: i + 1)).value =
            DoubleCellValue(p.revenue);
        sheetTopProfit.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: i + 1)).value =
            DoubleCellValue(p.profit);
        sheetTopProfit.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: i + 1)).value =
            TextCellValue('${p.marginPct.toStringAsFixed(0)} %');
      }
    }

    // --- Feuille : Transactions ---
    if (transactions.isNotEmpty) {
      final sheetTx = excel['Transactions'];
      sheetTx.insertRow(0);
      sheetTx.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0)).value =
          TextCellValue('Référence');
      sheetTx.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: 0)).value =
          TextCellValue('Date/heure');
      sheetTx.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: 0)).value =
          TextCellValue('Statut');
      sheetTx.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: 0)).value =
          TextCellValue('Total (MAD)');
      sheetTx.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: 0)).value =
          TextCellValue('Encaissé (MAD)');
      sheetTx.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: 0)).value =
          TextCellValue('Mode');
      for (final (i, t) in transactions.indexed) {
        sheetTx.insertRow(i + 1);
        sheetTx.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: i + 1)).value =
            TextCellValue(t.number.isEmpty ? '—' : t.number);
        sheetTx.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: i + 1)).value =
            TextCellValue(
                t.createdAt == null ? '—' : _fmtDateTime(t.createdAt!.toLocal()));
        sheetTx.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: i + 1)).value =
            TextCellValue(t.statusLabel);
        sheetTx.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: i + 1)).value =
            DoubleCellValue(t.total);
        sheetTx.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: i + 1)).value =
            DoubleCellValue(t.paidAmount);
        sheetTx.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: i + 1)).value =
            TextCellValue(
                (t.paymentMethod == null || t.paymentMethod!.isEmpty)
                    ? '—'
                    : SalesPaymentSlice.methodLabel(t.paymentMethod!));
      }
    }

    final fileName =
        'Ventes_du_jour_${periodLabel.replaceAll(' ', '_').replaceAll('/', '_')}.xlsx';

    // Utilise Excel.save() du package excel v4.0.6 qui gère nativement
    // le téléchargement Web (via html.Blob + AnchorElement) et l'écriture
    // fichier sur plateformes natives (via dart:io) à travers des imports
    // conditionnels internes. Aucun import direct de dart:html nécessaire ici.
    final savedBytes = excel.save(fileName: fileName);

    if (savedBytes == null) {
      throw Exception('Échec de l\'encodage ou de l\'écriture du fichier .xlsx');
    }
  }
}
