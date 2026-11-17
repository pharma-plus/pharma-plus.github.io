// ============================================================
// CAPTURES PHASE 4 — SHELL COMPLET + PAGES (données contrôlées)
// ============================================================
// Génère des goldens reproductibles dans captures_phase4/.
// Le shell complet est capturé (barre, sidebar, fond émeraude),
// pas seulement une page isolée. Données HTTP factices, jamais
// de production, jamais de validation physique simulée.
// ============================================================

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart' as http_testing;
import 'package:shared_preferences/shared_preferences.dart';

import '../lib/core/services/api_client.dart';
import '../lib/features/sales_day/controllers/sales_day_controller.dart';
import '../lib/features/sales_day/pages/sales_alerts_page.dart';
import '../lib/features/sales_day/pages/sales_comparisons_page.dart';
import '../lib/features/sales_day/pages/sales_employees_page.dart';
import '../lib/features/sales_day/pages/sales_intelligence_shell.dart';
import '../lib/features/sales_day/pages/sales_payments_page.dart';
import '../lib/features/sales_day/pages/sales_profits_page.dart';
import '../lib/features/sales_day/pages/sales_products_page.dart';
import '../lib/features/sales_day/pages/sales_reports_page.dart';
import '../lib/features/sales_day/pages/sales_returns_page.dart';

const _analytics = {
  'data': {
    'kpis': {
      'gross_revenue': '12850.50',
      'net_revenue': 10650.0,
      'tax_total': 2200.50,
      'discounts_total': 850.30,
      'sales_count': 243,
      'average_basket': 52.88,
      'cancelled_count': 18,
      'returned_count': 4,
      'paid_amount': 11625.0,
      'outstanding_amount': 1225.60,
      'refunded_amount': 420.75,
      'cost_total': 7330.30,
      'total_rows': 265,
    },
    'hourly': [
      {'hour': 8, 'label': '08:00', 'revenue': 1100, 'count': 12},
      {'hour': 12, 'label': '12:00', 'revenue': 2850, 'count': 48},
      {'hour': 16, 'label': '16:00', 'revenue': 1800, 'count': 31},
      {'hour': 20, 'label': '20:00', 'revenue': 1100, 'count': 15},
    ],
    'payment_breakdown': [
      {'method': 'cash', 'amount': 5800.0, 'count': 120},
      {'method': 'card', 'amount': 4970.0, 'count': 88},
      {'method': 'credit', 'amount': 2080.5, 'count': 35},
    ],
    'top_products_by_rev': [_top],
    'top_products_by_qty': [_top],
    'top_products_by_profit': [_top],
  },
};

const _top = {
  'medication_id': 'm1',
  'name': 'DOLIPRANE',
  'dosage': '1000 mg',
  'quantity': 124.0,
  'revenue': 3670.0,
  'profit': 1450.0,
  'marginPct': 39.5,
  'sales': 96,
  'sortBy': 'rev',
};

List<Map<String, dynamic>> _tx() => List.generate(
    8,
    (i) => {
          'id': 't$i',
          'number': 'VTE-000$i',
          'created_at':
              '2026-11-17T${(9 + i).toString().padLeft(2, '0')}:15:00Z',
          'status': i == 6 ? 'voided' : 'completed',
          'total': '${120.0 + i * 13.5}',
          'subtotal': '${100.0 + i * 11.25}',
          'discount_total': '0',
          'paid_amount': '${120.0 + i * 13.5}',
          '_items_count': 1 + (i % 3),
          '_user': i.isEven ? 'Pharmacien A' : 'Pharmacien B',
        });

void setUpFakeApi() {
  ApiClient.setClientForTesting(http_testing.MockClient((req) async {
    final path = req.url.path;
    if (path.endsWith('/sales/day/transactions')) {
      final rows = _tx();
      return http.Response(
        jsonEncode({
          'data': rows,
          'meta': {'page': 1, 'limit': 200, 'total': rows.length},
        }),
        200,
      );
    }
    if (path.endsWith('/sales/day')) {
      return http.Response(jsonEncode(_analytics), 200);
    }
    return http.Response(
        jsonEncode({
          'data': [],
          'meta': {'total': 0}
        }),
        200);
  }));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ApiClient.resetClientForTesting();
    setUpFakeApi();
  });
  tearDown(() => ApiClient.resetClientForTesting());

  // 1. Shell complet : prouve le fond émeraude et la navigation réelle.
  for (final (name, w, h) in const [
    ('pc', 1440.0, 900.0),
    ('tablette', 768.0, 1024.0),
    ('smartphone', 390.0, 844.0),
  ]) {
    testWidgets('shell complet $name', (tester) async {
      tester.view.physicalSize = Size(w, h);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      await tester
          .pumpWidget(const MaterialApp(home: SalesIntelligenceShell()));
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('../captures_phase4/shell_$name.png'),
      );
    });
  }

  // 2. Pages (rendu détaillé) — données contrôlées.
  final pages = <(String, Widget Function(SalesDayController))>[
    ('01_vue_generale', (c) => SalesDayOverviewPage(analytics: c)),
    ('02_analyse', (c) => SalesAnalysisPage(analytics: c)),
    ('03_benefices', (c) => SalesProfitsPage(analytics: c)),
    ('04_produits', (c) => SalesProductsPage(analytics: c)),
    ('05_employes', (c) => SalesEmployeesPage(analytics: c)),
    ('06_paiements', (c) => SalesPaymentsPage(analytics: c)),
    ('07_retours', (c) => SalesReturnsPage(analytics: c)),
    ('08_comparaisons', (c) => SalesComparisonsPage(analytics: c)),
    ('09_rapports', (c) => SalesReportsPage(analytics: c)),
    ('10_alertes', (c) => SalesAlertsPage(analytics: c)),
  ];
  for (final (name, builder) in pages) {
    for (final (size, w, h) in const [
      ('pc', 1440.0, 900.0),
      ('smartphone', 390.0, 844.0),
    ]) {
      testWidgets('page $name $size', (tester) async {
        tester.view.physicalSize = Size(w, h);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });
        final c = SalesDayController();
        addTearDown(c.dispose);
        await c.initialLoad();
        await tester.pumpWidget(MaterialApp(home: Scaffold(body: builder(c))));
        await tester.pumpAndSettle();
        await expectLater(
          find.byType(Scaffold),
          matchesGoldenFile('../captures_phase4/${name}_$size.png'),
        );
      });
    }
  }
}
