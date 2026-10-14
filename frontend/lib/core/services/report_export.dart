import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'download_file.dart';

/// ============================================================
/// EXPORTS RAPPORTS PHARMA+ — PDF · Excel (CSV) · Word (.doc)
/// · PDF : rendu complet multi-sections, impression/lecture
/// · Excel : CSV UTF-8 avec BOM (ouvre proprement dans Excel)
/// · Word : HTML autonome enregistré en .doc (ouvrable dans Word)
/// ============================================================
class ReportExport {
  ReportExport._();

  static String _dateStamp() {
    final n = DateTime.now();
    String p(int v) => v.toString().padLeft(2, '0');
    return '${n.year}${p(n.month)}${p(n.day)}_${p(n.hour)}${p(n.minute)}';
  }

  static String _num(Object? v) {
    if (v == null) return '0';
    final d = double.tryParse('$v') ?? 0;
    return d == d.roundToDouble() ? '${d.round()}' : d.toStringAsFixed(2);
  }

  /// Formatage nombre pour export (alias public de _num).
  static String numStr(Object? v) => _num(v);

  // ------------------------------------------------------------------
  // PDF — rapport complet multi-sections
  // ------------------------------------------------------------------
  static Future<void> exportPdf(
    String title,
    List<Map<String, dynamic>> sections,
    String periodLabel,
  ) async {
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
            child: pw.Text(title,
                style: const pw.TextStyle(
                    fontSize: 15, fontWeight: pw.FontWeight.bold)),
          ),
          pw.Center(
              child: pw.Text(periodLabel,
                  style: const pw.TextStyle(fontSize: 10))),
          pw.SizedBox(height: 6),
          pw.Center(
              child: pw.Text(
                  'Généré le ${DateTime.now().toLocal().toString().split('.').first}',
                  style: const pw.TextStyle(
                      fontSize: 9, color: PdfColors.grey600))),
          pw.Divider(thickness: 1.2),
          pw.SizedBox(height: 8),
        ];
        for (final s in sections) {
          final rows = (s['rows'] as List?)?.toList() ?? const [];
          if (rows.isEmpty) continue;
          widgets.addAll([
            pw.Text('${s['title'] ?? ''}',
                style: const pw.TextStyle(
                    fontSize: 13, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 4),
            pw.TableHelper.fromTextArray(
              headers: (s['headers'] as List?)
                      ?.map((h) => '$h')
                      .toList() ??
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
            style:
                const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
      ),
    ));
    final bytes = await pdf.save();
    if (downloadSupported) {
      downloadBytes('PHARMA+_${title}_${_dateStamp()}.pdf'.replaceAll(' ', '_'), bytes, 'application/pdf');
    } else {
      await Printing.layoutPdf(onLayout: (_) => pdf.save());
    }
  }

  // ------------------------------------------------------------------
  // EXCEL (CSV) — sections séparées, UTF-8 + BOM
  // ------------------------------------------------------------------
  static void exportCsv(
    String title,
    List<Map<String, dynamic>> sections,
  ) {
    final buf = StringBuffer();
    for (final s in sections) {
      final rows = (s['rows'] as List?)?.toList() ?? const [];
      if (rows.isEmpty) continue;
      buf.writeln('"${s['title'] ?? ''}"');
      final headers = (s['headers'] as List?)
              ?.map((h) => '"$h"')
              .join(',') ??
          '';
      buf.writeln(headers);
      for (final r in rows) {
        final cells = (r as List).map((c) {
          final v = '$c'.replaceAll('"', '""');
          return '"$v"';
        }).join(',');
        buf.writeln(cells);
      }
      buf.writeln();
    }
    downloadText(
      'PHARMA+_${title}_${_dateStamp()}.csv'.replaceAll(' ', '_'),
      buf.toString(),
      'text/csv;charset=utf-8',
    );
  }

  // ------------------------------------------------------------------
  // WORD (.doc) — HTML autonome compatible Microsoft Word
  // ------------------------------------------------------------------
  static void exportDoc(
    String title,
    List<Map<String, dynamic>> sections,
    String periodLabel,
  ) {
    final b = StringBuffer()
      ..writeln('<html xmlns:o="urn:schemas-microsoft-com:office:office" '
          'xmlns:w="urn:schemas-microsoft-com:office:word" '
          'xmlns="http://www.w3.org/TR/REC-html40">')
      ..writeln('<head><meta charset="utf-8"><title>$title</title>')
      ..writeln('<style>')
      ..writeln('body{font-family:Calibri,Arial,sans-serif;font-size:11pt;}')
      ..writeln('h1{color:#006B43;text-align:center;font-size:20pt;}')
      ..writeln(
          'h2{color:#333;font-size:14pt;border-bottom:2px solid #00C96B;padding-bottom:3px;}')
      ..writeln(
          'table{border-collapse:collapse;width:100%;margin:8px 0 18px 0;}')
      ..writeln(
          'th{background:#006B43;color:#fff;padding:6px 8px;text-align:left;font-size:10pt;}')
      ..writeln('td{border:1px solid #ccc;padding:5px 8px;font-size:10pt;}')
      ..writeln('tr:nth-child(even) td{background:#f4f7f5;}')
      ..writeln('.meta{text-align:center;color:#666;font-size:9pt;}')
      ..writeln('</style></head><body>')
      ..writeln('<h1>PHARMA+</h1>')
      ..writeln('<p class="meta"><b>$title</b><br>$periodLabel<br>'
          'Généré le ${DateTime.now().toLocal().toString().split('.').first}</p>');

    for (final s in sections) {
      final rows = (s['rows'] as List?)?.toList() ?? const [];
      if (rows.isEmpty) continue;
      b.writeln('<h2>${s['title'] ?? ''}</h2>');
      b.writeln('<table><tr>');
      for (final h in (s['headers'] as List?) ?? const []) {
        b.writeln('<th>$h</th>');
      }
      b.writeln('</tr>');
      for (final r in rows) {
        b.writeln('<tr>');
        for (final c in (r as List)) {
          b.writeln('<td>${_htmlEscape('$c')}</td>');
        }
        b.writeln('</tr>');
      }
      b.writeln('</table>');
    }
    b.writeln('</body></html>');

    downloadText(
      'PHARMA+_${title}_${_dateStamp()}.doc'.replaceAll(' ', '_'),
      b.toString(),
      'application/msword',
    );
  }

  static String _htmlEscape(String v) => v
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;');

  // ------------------------------------------------------------------
  // Helpers de construction des sections (rapports)
  // ------------------------------------------------------------------
  static Map<String, dynamic> section(
    String title,
    List<String> headers,
    List<List<Object?>> rows,
  ) =>
      {
        'title': title,
        'headers': headers,
        'rows': rows,
      };
}
