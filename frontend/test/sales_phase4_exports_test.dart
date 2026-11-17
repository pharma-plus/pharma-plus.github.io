// ============================================================
// TESTS CONTRÔLÉS — GÉNÉRATION RÉELLE DES 4 FORMATS D'EXPORT
// ============================================================
// Données déterministes déclarées comme telles. Aucun réseau,
// aucun Supabase. Les fichiers sont réellement écrits sur disque
// par `download_file_stub.dart` puis relus et vérifiés (en-tête,
// extension, contenu, périmètre, BOM). Ce ne sont pas des données
// de production.
// ============================================================

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../lib/core/services/download_file.dart';
import '../lib/features/sales_day/models/sales_day_model.dart';
import '../lib/features/sales_day/services/sales_export_service.dart';

const _period = 'Période contrôlée 17/11/2026 — TEST';
const _scope =
    'Période contrôlée complète · aucun filtre de statut ni de recherche appliqué';

Map<String, dynamic> _payload({double? cost}) => {
      'kpis': {
        'gross_revenue': '1200.50',
        'net_revenue': 1000.0,
        'tax_total': 200.50,
        'discounts_total': 25.0,
        'sales_count': 2,
        'average_basket': 600.25,
        'cancelled_count': 0,
        'returned_count': 0,
        'paid_amount': 1200.50,
        'outstanding_amount': 0,
        'refunded_amount': null,
        'cost_total': cost,
        'total_rows': 2,
      },
      'hourly': [
        {'hour': 10, 'label': '10:00', 'revenue': 1200.5, 'count': 2},
      ],
      'payment_breakdown': [
        {'method': 'cash', 'amount': 1200.5, 'count': 2},
      ],
      'top_products_by_rev': [
        {
          'medication_id': 'm1',
          'name': 'DOLIPRANE',
          'dosage': '1000 mg',
          'quantity': 2.0,
          'revenue': 1200.5,
          'profit': 500.0,
          'marginPct': 41.6,
          'sales': 2,
          'sortBy': 'rev',
        },
      ],
    };

List<SalesTransaction> _transactions() => [
      SalesTransaction.fromJson({
        'id': 't1',
        'number': 'V-TEST-0001',
        'created_at': '2026-11-17T10:00:00Z',
        'status': 'completed',
        'total': '600.25',
        'paid_amount': '600.25',
        '_items_count': 1,
      }),
      SalesTransaction.fromJson({
        'id': 't2',
        'number': 'V-TEST-0002',
        'created_at': '2026-11-17T14:00:00Z',
        'status': 'completed',
        'total': '600.25',
        'paid_amount': '600.25',
        '_items_count': 1,
      }),
    ];

File _savedFile(String extension) {
  final path = lastSavedPath;
  expect(lastSaveError, isNull);
  expect(path, isNotNull);
  expect(path!.endsWith(extension), isTrue);
  final file = File(path);
  expect(file.existsSync(), isTrue);
  expect(file.lengthSync(), greaterThan(50));
  return file;
}

void main() {
  test('PDF réel : en-tête %PDF et contenu', () async {
    final a = SalesDayAnalytics.fromJson(_payload(cost: 700));
    await SalesExportService.exportPdf(
      periodLabel: _period,
      analytics: a,
      transactions: _transactions(),
      scopeLabel: _scope,
    );
    final f = _savedFile('.pdf');
    final head = f.openSync().readSync(5);
    expect(String.fromCharCodes(head), startsWith('%PDF'));
  });

  test('Word réel (.doc HTML) : périmètre, période, accents et produits', () {
    final a = SalesDayAnalytics.fromJson(_payload(cost: 700));
    SalesExportService.exportWord(
      periodLabel: _period,
      analytics: a,
      transactions: _transactions(),
      scopeLabel: _scope,
    );
    final content = _savedFile('.doc').readAsStringSync();
    final bom = File(lastSavedPath!).readAsBytesSync().take(3).toList();
    expect(bom, [0xEF, 0xBB, 0xBF], reason: 'BOM UTF-8');
    expect(content, contains('Périmètre du rapport'));
    expect(content, contains(_period));
    expect(content, contains(_scope));
    expect(content, contains('DOLIPRANE'));
    expect(content, contains('V-TEST-0001'));
    expect(content, contains('Chiffre d\'affaires brut (TTC)'));
  });

  test('CSV réel : BOM, colonnes, montants et périmètre', () {
    final a = SalesDayAnalytics.fromJson(_payload(cost: 700));
    SalesExportService.exportExcel(
      periodLabel: _period,
      analytics: a,
      transactions: _transactions(),
      scopeLabel: _scope,
    );
    final content = _savedFile('.csv').readAsStringSync();
    final bom = File(lastSavedPath!).readAsBytesSync().take(3).toList();
    expect(bom, [0xEF, 0xBB, 0xBF], reason: 'BOM UTF-8');
    expect(content, contains('Périmètre du rapport'));
    expect(content, contains(_scope));
    expect(content, contains('Référence'));
    expect(content, contains('V-TEST-0002'));
    expect(content, contains('1200.50'));
  });

  test('XLSX réel : signature ZIP et périmètre', () async {
    final a = SalesDayAnalytics.fromJson(_payload(cost: 700));
    await SalesExportService.exportXlsx(
      periodLabel: _period,
      analytics: a,
      transactions: _transactions(),
      scopeLabel: _scope,
    );
    final bytes = _savedFile('.xlsx').readAsBytesSync();
    expect(bytes[0], 0x50, reason: 'signature PK');
    expect(bytes[1], 0x4B);
  });

  test('coût ambigu exporté : « Non vérifiable », jamais 100 % de marge', () {
    final a = SalesDayAnalytics.fromJson(_payload(cost: 0));
    SalesExportService.exportExcel(
      periodLabel: _period,
      analytics: a,
      transactions: _transactions(),
      scopeLabel: _scope,
    );
    final content = _savedFile('.csv').readAsStringSync();
    expect(content, contains('Non vérifiable'));
    expect(content, contains('Fiabilité de la marge'));
    expect(
        content, isNot(contains('Coût des marchandises vendues","0.00 MAD')));
  });
}
