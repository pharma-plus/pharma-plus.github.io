import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/strings.dart';
import '../utils/format.dart';

/// ============================================================
/// IMPRESSION PHARMA+ — tickets de caisse & factures (réel)
/// · Formats tickets : 58 mm ET 80 mm (sélection persistée)
/// · TOTAL · MONTANT REÇU · MONNAIE imprimés sur le ticket
/// · Impression via la boîte d'impression système (Windows,
///   navigateur…) : toute imprimante installée avec son pilote
///   est utilisable, y compris thermiques 58/80 mm.
///   NB assumé (non masqué) : l'ESC/POS brut n'est pas possible
///   depuis le navigateur — limitation plateforme, pas du code.
/// · Test d'impression + RÉIMPRESSION du dernier ticket
/// ============================================================

/// Largeur de rouleau du ticket de caisse.
enum ReceiptWidth { mm58, mm80 }

/// Préférence persistée : largeur de ticket choisie (58 ou 80 mm).
class ReceiptPrefs {
  ReceiptPrefs._();
  static const _kKey = 'pmg_receipt_width';

  static Future<ReceiptWidth> load() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kKey) == '58'
        ? ReceiptWidth.mm58
        : ReceiptWidth.mm80;
  }

  static Future<void> save(ReceiptWidth w) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kKey, w == ReceiptWidth.mm58 ? '58' : '80');
  }

  /// Format PDF réel : rouleau 58/80 mm, hauteur infinie (découpe auto).
  static PdfPageFormat format(ReceiptWidth w) => PdfPageFormat(
        (w == ReceiptWidth.mm58 ? 58.0 : 80.0) * PdfPageFormat.mm,
        double.infinity,
        marginAll: w == ReceiptWidth.mm58 ? 4.0 : 5.0,
      );
}

/// Génération de tickets / factures PDF PHARMA+ avec le logo embarqué.
class ReceiptPdf {
  ReceiptPdf._();

  /// Dernier ticket généré : permet la RÉIMPRESSION sans relancer la vente.
  static Uint8List? _lastReceiptBytes;
  static PdfPageFormat _lastFormat =
      ReceiptPrefs.format(ReceiptWidth.mm80);
  static bool get hasLastReceipt => _lastReceiptBytes != null;

  static Future<pw.MemoryImage> _loadLogo() async {
    // Logo officiel complet (symbole + PHARMA+ + signature) : les textes
    // de marque sont deja dans l'asset, on ne les repete pas dans le ticket.
    final data = await rootBundle.load('assets/branding/pharma-logo-full.png');
    return pw.MemoryImage(data.buffer.asUint8List());
  }

  /// Construit les octets du ticket de caisse à partir du panier.
  /// [amountReceived] / [change] : montants RÉELS du paiement espèces,
  /// imprimés sous le total (MONTANT REÇU + MONNAIE rendue).
  /// [width] : format du rouleau (58 ou 80 mm).
  static Future<Uint8List> buildSaleReceiptBytes({
    required List<CartLineLike> lines,
    required String pharmacyName,
    required String locale,
    double globalDiscountPercent = 0,
    double amountReceived = 0,
    double change = 0,
    ReceiptWidth width = ReceiptWidth.mm80,
  }) async {
    final logo = await _loadLogo();
    final fmt = ReceiptPrefs.format(width);

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
            pw.Image(logo, width: 96),
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
            if (amountReceived > 0) ...[
              _totalRow('MONTANT REÇU', Fmt.money(amountReceived)),
              if (change > 0) _totalRow('MONNAIE', Fmt.money(change), bold: true),
            ],
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

  /// Ouvre la boîte d'impression système avec le ticket (format réellement
  /// sélectionné dans les paramètres) et mémorise les octets pour la
  /// réimpression. Toute imprimante installée avec son pilote est
  /// proposée par le système (thermiques 58/80 mm incluses).
  static Future<void> printSaleReceipt({
    required List<CartLineLike> lines,
    required String pharmacyName,
    required String locale,
    double globalDiscountPercent = 0,
    double amountReceived = 0,
    double change = 0,
  }) async {
    final width = await ReceiptPrefs.load();
    final bytes = await buildSaleReceiptBytes(
      lines: lines,
      pharmacyName: pharmacyName,
      locale: locale,
      globalDiscountPercent: globalDiscountPercent,
      amountReceived: amountReceived,
      change: change,
      width: width,
    );
    _lastReceiptBytes = bytes;
    _lastFormat = ReceiptPrefs.format(width);
    await Printing.layoutPdf(onLayout: (_) => bytes, format: _lastFormat);
  }

  /// RÉIMPRESSION du dernier ticket (même contenu, même format).
  /// Ne fait rien si aucun ticket n'a encore été imprimé — l'UI désactive
  /// le bouton via [hasLastReceipt].
  static Future<void> reprintLast() async {
    final bytes = _lastReceiptBytes;
    if (bytes == null) return;
    await Printing.layoutPdf(onLayout: (_) => bytes, format: _lastFormat);
  }

  /// Ticket de TEST : vérifie alignement, police et découpe sur
  /// l'imprimante réelle, au format sélectionné (58/80 mm).
  static Future<void> printTestTicket(String pharmacyName) async {
    final width = await ReceiptPrefs.load();
    final fmt = ReceiptPrefs.format(width);
    final logo = await _loadLogo();
    final doc = pw.Document(title: 'PHARMA+ — Ticket de test');
    doc.addPage(pw.Page(
      pageFormat: fmt,
      build: (context) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Image(logo, width: width == ReceiptWidth.mm58 ? 64.0 : 84.0),
          pw.SizedBox(height: 6),
          pw.Text(pharmacyName, style: const pw.TextStyle(fontSize: 9)),
          pw.Text(_now(),
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey)),
          pw.SizedBox(height: 8),
          pw.Text('TICKET DE TEST',
              style: const pw.TextStyle(
                  fontSize: 12, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 4),
          pw.Text('0123456789  EAN-13  Code128  QR',
              style: const pw.TextStyle(fontSize: 8)),
          pw.SizedBox(height: 8),
          pw.Text(
              'Si ce texte est lisible, complet et bien aligné,\n'
              'l\'impression fonctionne correctement.',
              textAlign: pw.TextAlign.center,
              style: const pw.TextStyle(fontSize: 8)),
        ],
      ),
    ));
    final bytes = await doc.save();
    _lastReceiptBytes = bytes;
    _lastFormat = fmt;
    await Printing.layoutPdf(onLayout: (_) => bytes, format: fmt);
  }

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
