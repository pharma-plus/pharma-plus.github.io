/// ============================================================
/// VENTES DU JOUR — Service d'export (PDF · Excel · Impression)
/// ============================================================
/// Réutilise les services officiels existants de l'application
/// (`ReportExport` : PDF + CSV-Excel UTF-8 + téléchargement web).
/// Fidélité : les documents n'utilisent QUE les KPI et transactions
/// affichés à l'écran (mêmes données, mêmes filtres) — jamais de
/// recalcul ni de valeur inventée.
/// ============================================================

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

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
      if (analytics.topProducts.isNotEmpty)
        ReportExport.section('Top produits vendus',
            ['#', 'Produit', 'Quantité', 'CA (MAD)', 'Ventes'], [
          for (final (i, p) in analytics.topProducts.indexed)
            [
              '${i + 1}',
              (p.dosage == null || p.dosage!.isEmpty)
                  ? p.displayName
                  : '${p.displayName} (${p.dosage})',
              p.quantity.toStringAsFixed(0),
              p.revenue.toStringAsFixed(2),
              '${p.sales}',
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

  /// Impression directe : même contenu que le PDF exporté.
  static Future<void> printReport({
    required String periodLabel,
    required SalesDayAnalytics analytics,
    required List<SalesTransaction> transactions,
  }) async {
    final pdf = pw.Document();
    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(28),
      build: (context) {
        final widgets = <pw.Widget>[
          pw.Center(
            child: pw.Text('PHARMA+',
                style: const pw.TextStyle(
                    fontSize: 20,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.green800)),
          ),
          pw.Center(
            child: pw.Text('Ventes du jour — $periodLabel',
                style: const pw.TextStyle(
                    fontSize: 15, fontWeight: pw.FontWeight.bold)),
          ),
          pw.SizedBox(height: 6),
          pw.Center(
            child: pw.Text(
                'Généré le ${_fmtDateTime(DateTime.now().toLocal())}',
                style: const pw.TextStyle(
                    fontSize: 9, color: PdfColors.grey600)),
          ),
          pw.Divider(thickness: 1.2),
          pw.SizedBox(height: 8),
        ];
        for (final s in _sections(analytics, transactions)) {
          final rows = (s['rows'] as List?)?.toList() ?? const [];
          if (rows.isEmpty) continue;
          widgets.addAll([
            pw.Text('${s['title'] ?? ''}',
                style: const pw.TextStyle(
                    fontSize: 13, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 4),
            pw.TableHelper.fromTextArray(
              headers: (s['headers'] as List?)?.map((h) => '$h').toList() ??
                  const [],
              data: rows
                  .map((r) => (r as List).map((c) => '$c').toList())
                  .toList(),
              headerStyle: const pw.TextStyle(
                  fontWeight: pw.FontWeight.bold, fontSize: 9),
              cellStyle: const pw.TextStyle(fontSize: 9),
              headerDecoration:
                  const pw.BoxDecoration(color: PdfColors.grey300),
              cellAlignment: pw.Alignment.centerLeft,
              oddRowDecoration:
                  const pw.BoxDecoration(color: PdfColors.grey100),
            ),
            pw.SizedBox(height: 14),
          ]);
        }
        return widgets;
      },
      footer: (context) => pw.Center(
        child: pw.Text(
            'PHARMA+ — Rapport confidentiel · page ${context.pageNumber}/${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
      ),
    ));
    final bytes = await pdf.save();
    await Printing.layoutPdf(onLayout: (_) => Future.value(bytes));
  }
}
