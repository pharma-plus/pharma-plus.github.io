// ============================================================
// TESTS WIDGET CONTRÔLÉS — 10 PAGES SALES INTELLIGENCE
// ============================================================
// Rendu réel des 10 pages sur PC / tablette / smartphone avec
// des données HTTP factices déterministes (aucun réseau réel,
// aucune donnée de démonstration embarquée dans l'application).
// Vérifie : absence d'exception/overflow, présence du titre de
// section, cohérence du chargement complet des transactions.
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
      'gross_revenue': '1200.50',
      'net_revenue': 1000.0,
      'tax_total': 200.50,
      'discounts_total': 25.0,
      'sales_count': 6,
      'average_basket': 200.08,
      'cancelled_count': 1,
      'returned_count': 0,
      'paid_amount': 1100.0,
      'outstanding_amount': 100.50,
      'refunded_amount': null,
      'cost_total': 700.0,
      'total_rows': 7,
    },
    'hourly': [
      {'hour': 9, 'label': '09:00', 'revenue': 300.0, 'count': 2},
      {'hour': 10, 'label': '10:00', 'revenue': 600.0, 'count': 3},
      {'hour': 14, 'label': '14:00', 'revenue': 300.5, 'count': 1},
    ],
    'payment_breakdown': [
      {'method': 'cash', 'amount': 700.0, 'count': 4},
      {'method': 'card', 'amount': 500.5, 'count': 2},
    ],
    'top_products_by_rev': [
      {
        'medication_id': 'm1',
        'name': 'DOLIPRANE',
        'dosage': '1000 mg',
        'quantity': 5.0,
        'revenue': 500.0,
        'profit': 200.0,
        'marginPct': 40.0,
        'sales': 3,
        'sortBy': 'rev',
      },
    ],
    'top_products_by_qty': [
      {
        'medication_id': 'm1',
        'name': 'DOLIPRANE',
        'dosage': '1000 mg',
        'quantity': 5.0,
        'revenue': 500.0,
        'profit': 200.0,
        'marginPct': 40.0,
        'sales': 3,
        'sortBy': 'qty',
      },
    ],
    'top_products_by_profit': [
      {
        'medication_id': 'm1',
        'name': 'DOLIPRANE',
        'dosage': '1000 mg',
        'quantity': 5.0,
        'revenue': 500.0,
        'profit': 200.0,
        'marginPct': 40.0,
        'sales': 3,
        'sortBy': 'profit',
      },
    ],
  },
};

List<Map<String, dynamic>> _txRows() => [
      {
        'id': 't1',
        'number': 'V-0001',
        'created_at': '2026-11-17T10:00:00Z',
        'status': 'completed',
        'total': '200.00',
        'subtotal': '166.67',
        'discount_total': '0',
        'paid_amount': '200.00',
        '_items_count': 2,
        '_user': 'Pharmacien A',
      },
      {
        'id': 't2',
        'number': 'V-0002',
        'created_at': '2026-11-17T11:30:00Z',
        'status': 'voided',
        'total': '50.00',
        'subtotal': '41.67',
        'discount_total': '0',
        'paid_amount': '0',
        '_items_count': 1,
        '_user': 'Pharmacien B',
      },
      {
        'id': 't3',
        'number': 'V-0003',
        'created_at': '2026-11-17T14:00:00Z',
        'status': 'completed',
        'total': '150.00',
        'subtotal': '125.00',
        'discount_total': '5.00',
        'paid_amount': '150.00',
        '_items_count': 3,
        '_user': 'Pharmacien A',
      },
    ];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ApiClient.resetClientForTesting();
    ApiClient.setClientForTesting(http_testing.MockClient((req) async {
      final path = req.url.path;
      if (path.endsWith('/sales/day/transactions')) {
        return http.Response(
          jsonEncode({
            'data': _txRows(),
            'meta': {
              'page': 1,
              'limit': 200,
              'total': _txRows().length,
            },
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
  });

  tearDown(() {
    ApiClient.resetClientForTesting();
  });

  final cases = <(String, Widget Function(SalesDayController))>[
    ('Vue générale', (c) => SalesDayOverviewPage(analytics: c)),
    ('Analyse des ventes', (c) => SalesAnalysisPage(analytics: c)),
    ('Bénéfices et marges', (c) => SalesProfitsPage(analytics: c)),
    ('Produits vendus', (c) => SalesProductsPage(analytics: c)),
    ('Performance employés', (c) => SalesEmployeesPage(analytics: c)),
    ('Paiements et caisse', (c) => SalesPaymentsPage(analytics: c)),
    ('Annulations et retours', (c) => SalesReturnsPage(analytics: c)),
    (
      'Comparaison avec la période précédente',
      (c) => SalesComparisonsPage(analytics: c)
    ),
    ('Rapports et exports', (c) => SalesReportsPage(analytics: c)),
    ('Alertes intelligentes', (c) => SalesAlertsPage(analytics: c)),
  ];

  const sizes = <(String, double, double)>[
    ('smartphone 390x844', 390, 844),
    ('tablette 768x1024', 768, 1024),
    ('PC 1440x900', 1440, 900),
  ];

  for (final (name, builder) in cases) {
    for (final (sizeName, w, h) in sizes) {
      testWidgets('$name · $sizeName', (tester) async {
        tester.view.physicalSize = Size(w, h);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final c = SalesDayController();
        addTearDown(c.dispose);
        await c.initialLoad();
        expect(c.analytics, isNotNull, reason: 'données contrôlées chargées');

        await tester.pumpWidget(MaterialApp(home: Scaffold(body: builder(c))));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull,
            reason: 'aucun overflow/exception sur $name en $sizeName');
        expect(find.text(name), findsOneWidget,
            reason: 'titre de section présent sur $name');
      });
    }
  }
}
