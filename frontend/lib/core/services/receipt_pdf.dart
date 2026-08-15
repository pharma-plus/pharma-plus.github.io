import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../l10n/strings.dart';
import '../utils/format.dart';

/// Génération de tickets / factures PDF PHARMA+ avec le logo embarqué.
class ReceiptPdf {
  ReceiptPdf._();

  static Future<pw.MemoryImage> _loadLogo() async {
    final data = await rootBundle.load('assets/logo/pharma_plus_mark.png');
    return pw.MemoryImage(data.buffer.asUint8List());
  }

  /// Construit les octets du ticket de caisse à partir du panier.
  static Future<Uint8List> buildSaleReceiptBytes({
    required List<CartLineLike> lines,
    required String pharmacyName,
    required String locale,
    double globalDiscountPercent = 0,
  }) async {
    final logo = await _loadLogo();
    const fmt = PdfPageFormat.roll80;

    final subtotal =
        lines.fold<double>(0, (s, l) => s + l.unitPrice * l.quantity);
    final tva =
        lines.fold<double>(0, (s, l) => s + l.unitPrice * l.quantity * (l.tvaRate / 100));
    final discount = subtotal * (globalDiscountPercent / 100);
    final total = subtotal + tva - discount;

    final doc = pw.Document(title: 'PHARMA+ — Ticket de caisse');
    doc.addPage(
      pw.Page(
        pageFormat: fmt,
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.Image(logo, width: 46),
            pw.SizedBox(height: 4),
            pw.Text('PHARMA+',
                style:
                    pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
            pw.Text('LOGICIEL DE PHARMACIE',
                style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey)),
            pw.SizedBox(height: 6),
            pw.Text(pharmacyName,
                style: const pw.TextStyle(fontSize: 9),
                textAlign: pw.TextAlign.center),
            pw.SizedBox(height: 2),
            pw.Text(_now(),
                style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey)),
            pw.SizedBox(height: 10),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Expanded(
                    child: pw.Text(S.t('product', locale),
                        style: const pw.TextStyle(fontSize: 8))),
                pw.Text(S.t('qty', locale),
                    style: const pw.TextStyle(fontSize: 8)),
                pw.Text(S.t('total', locale),
                    style: const pw.TextStyle(fontSize: 8)),
              ],
            ),
            pw.Divider(height: 6),
            for (final l in lines)
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(vertical: 2),
                child: pw.Row(
                  children: [
                    pw.Expanded(
                        child: pw.Text(l.name,
                            style: const pw.TextStyle(fontSize: 8))),
                    pw.Text(l.quantity.toStringAsFixed(0),
                        style: const pw.TextStyle(fontSize: 8)),
                    pw.Text(Fmt.money(l.unitPrice * l.quantity),
                        style: const pw.TextStyle(fontSize: 8)),
                  ],
                ),
              ),
            pw.SizedBox(height: 10),
            _totalRow(S.t('subtotal', locale), Fmt.money(subtotal)),
            _totalRow(S.t('tva', locale), Fmt.money(tva)),
            if (globalDiscountPercent > 0)
              _totalRow('${S.t('discount', locale)} ($globalDiscountPercent%)',
                  '- ${Fmt.money(discount)}'),
            _totalRow(S.t('total', locale), Fmt.money(total), bold: true),
            pw.SizedBox(height: 10),
            pw.Text(S.t('thankYou', locale),
                style: const pw.TextStyle(fontSize: 8),
                textAlign: pw.TextAlign.center),
            pw.Text('PHARMA+ — v2.0.0',
                style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey)),
          ],
        ),
      ),
    );
    return doc.save();
  }

  /// Ouvre la boîte d'impression / partage du ticket.
  static Future<void> printSaleReceipt({
    required List<CartLineLike> lines,
    required String pharmacyName,
    required String locale,
    double globalDiscountPercent = 0,
  }) =>
      Printing.layoutPdf(
        format: PdfPageFormat.roll80,
        onLayout: (_) => buildSaleReceiptBytes(
          lines: lines,
          pharmacyName: pharmacyName,
          locale: locale,
          globalDiscountPercent: globalDiscountPercent,
        ),
      );

  static String _now() {
    final d = DateTime.now();
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year} '
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  static pw.Widget _totalRow(String label, String value, {bool bold = false}) =>
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 1),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(label,
                style: pw.TextStyle(
                    fontSize: bold ? 10 : 8,
                    fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
            pw.Text(value,
                style: pw.TextStyle(
                    fontSize: bold ? 11 : 8,
                    fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
          ],
        ),
      );
}

/// Vue minimale d'une ligne de vente pour l'impression (évite le couplage
/// avec le modèle interne du POS).
class CartLineLike {
  final String name;
  final double quantity;
  final double unitPrice;
  final double tvaRate;
  const CartLineLike({
    required this.name,
    required this.quantity,
    required this.unitPrice,
    this.tvaRate = 0,
  });
}
