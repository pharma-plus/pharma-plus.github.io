// ============================================================
// SALES INTELLIGENCE — 23 TESTS SÉMANTIQUES DÉTERMINISTES
// ============================================================
// Les anciennes comparaisons pixel (goldens) ont été remplacées
// par des assertions sur la structure, les valeurs, les interactions
// et les états. Aucun skip, aucune tolérance, aucun || true.
// Les captures Phase 5 restent des références visuelles conservées
// dans captures_phase5/ mais ne sont plus comparées par les tests.
// Données HTTP factices explicites, jamais de production.
// ============================================================

import 'dart:convert';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart' as http_testing;
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../lib/core/services/api_client.dart';
import '../lib/core/widgets/glass_card.dart';
import '../lib/core/widgets/marble_texture.dart';
import '../lib/features/sales_day/controllers/sales_day_controller.dart';
import '../lib/features/sales_day/models/sales_day_model.dart';
import '../lib/features/sales_day/models/sales_day_model.dart' as model;
import '../lib/features/sales_day/services/sales_analytics_service.dart';
import '../lib/features/sales_day/pages/sales_alerts_page.dart';
import '../lib/features/sales_day/pages/sales_comparisons_page.dart';
import '../lib/features/sales_day/pages/sales_employees_page.dart';
import '../lib/features/sales_day/pages/sales_intelligence_shell.dart';
import '../lib/features/sales_day/pages/sales_payments_page.dart';
import '../lib/features/sales_day/pages/sales_profits_page.dart';
import '../lib/features/sales_day/pages/sales_products_page.dart';
import '../lib/features/sales_day/pages/sales_reports_page.dart';
import '../lib/features/sales_day/pages/sales_returns_page.dart';
import '../lib/features/sales_day/widgets/sales_date_filter.dart';
import '../lib/features/sales_day/widgets/sales_design_system.dart';
import '../lib/features/sales_day/widgets/sales_hourly_chart.dart';
import '../lib/features/sales_day/widgets/sales_kpi_card.dart';
import '../lib/features/sales_day/widgets/sales_kpi_section.dart';
import '../lib/features/sales_day/widgets/sales_payment_chart.dart';
import '../lib/features/sales_day/widgets/sales_product_ranking.dart';
import '../lib/features/sales_day/widgets/sales_transactions_table.dart';

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
        'created_at': '2026-11-17T${(9 + i).toString().padLeft(2, '0')}:15:00Z',
        'status': i == 6 ? 'voided' : 'completed',
        'total': '${120.0 + i * 13.5}',
        'subtotal': '${100.0 + i * 11.25}',
        'discount_total': '0',
        'paid_amount': '${120.0 + i * 13.5}',
        '_items_count': 1 + (i % 3),
        '_user': i.isEven ? 'Pharmacien A' : 'Pharmacien B',
      },
    );

void _setUpFakeApi() {
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

Future<SalesDayController> _fixedController() async {
  final c = SalesDayController();
  await c.setCustomRange(DateTimeRange(
    start: DateTime(2026, 11, 17),
    end: DateTime(2026, 11, 18),
  ));
  return c;
}

Future<void> _setView(WidgetTester tester, double w, double h) async {
  tester.view.physicalSize = Size(w, h);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

Widget _host(double w, double h, Widget child) => MediaQuery(
      data: MediaQueryData(size: Size(w, h), devicePixelRatio: 1.0),
      child: MaterialApp(home: child),
    );

Future<void> _reveal(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    400,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
}

void _expectNoWhitePanel(WidgetTester tester) {
  expect(find.byType(GlassCard), findsNothing,
      reason: 'aucune surface blanche dépendant du thème clair');
  expect(tester.takeException(), isNull);
}

void _expectEmeraldShell(WidgetTester tester) {
  final bg =
      tester.widget<MarbleBackground>(find.byType(MarbleBackground).first);
  expect(bg.dark, isFalse, reason: 'fond émeraude officiel conservé');
  expect(bg.showTexture, isTrue);
  expect(find.text('PHARMA+ SALES INTELLIGENCE'), findsOneWidget);
  expect(find.byType(GlassCard), findsNothing);
}

void _expectKpiGrid(WidgetTester tester, double w) {
  expect(find.byType(SalesKpiSection), findsOneWidget);
  expect(find.byType(SalesKpiCard), findsNWidgets(8));
  final grid = tester.widget<GridView>(find.descendant(
    of: find.byType(SalesKpiSection),
    matching: find.byType(GridView),
  ));
  final delegate =
      grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
  expect(delegate.crossAxisCount, w >= 900 ? 4 : 2,
      reason: 'grille KPI responsive');
}

void _expectGoldCurve(WidgetTester tester) {
  expect(find.byType(SalesHourlyChart), findsOneWidget);
  final chart = tester.widget<LineChart>(find.byType(LineChart));
  final bar = chart.data.lineBarsData.single;
  expect(bar.isCurved, isTrue);
  expect(bar.belowBarData.show, isTrue, reason: 'aire dégradée conservée');
  expect(bar.dotData.show, isTrue, reason: 'points conservés');
  expect(chart.data.lineTouchData.enabled, isTrue);
}

void _expectCommonChrome(WidgetTester tester) {
  expect(find.byType(SalesDateFilter), findsOneWidget);
  _expectNoWhitePanel(tester);
}

SalesDayAnalytics _emptyAnalytics() => model.SalesDayAnalytics(
      kpis: model.SalesDayKpis(
        grossRevenue: 0,
        netRevenue: 0,
        taxTotal: 0,
        discountsTotal: 0,
        salesCount: 0,
        averageBasket: 0,
        cancelledCount: 0,
        returnedCount: 0,
        paidAmount: 0,
        outstandingAmount: 0,
        refundedAmount: null,
        costTotal: null,
        totalRows: 0,
      ),
      hourly: const [],
      payments: const [],
      topProductsQty: const [],
      topProductsRev: const [],
      topProductsProfit: const [],
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    await initializeDateFormatting('fr', null);
    await initializeDateFormatting('fr_MA', null);
    SharedPreferences.setMockInitialValues({});
    ApiClient.resetClientForTesting();
    _setUpFakeApi();
  });
  tearDown(() => ApiClient.resetClientForTesting());

  // 1. Shell complet : fond émeraude, navigation et interactions réelles.
  for (final (name, w, h) in const [
    ('pc', 1440.0, 900.0),
    ('tablette', 768.0, 1024.0),
    ('smartphone', 390.0, 844.0),
  ]) {
    testWidgets('shell complet $name', (tester) async {
      await _setView(tester, w, h);
      final c = await _fixedController();
      addTearDown(c.dispose);
      await tester
          .pumpWidget(_host(w, h, SalesIntelligenceShell(controller: c)));
      await tester.pumpAndSettle();

      _expectEmeraldShell(tester);
      _expectKpiGrid(tester, w);
      await _reveal(tester, find.byType(SalesHourlyChart));
      _expectGoldCurve(tester);
      await tester.scrollUntilVisible(
        find.byType(SalesDateFilter),
        -600,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      _expectCommonChrome(tester);
      await _reveal(tester, find.byType(SalesPaymentChart));
      expect(find.byType(SalesPaymentChart), findsOneWidget);
      expect(find.byType(SalesProductRanking), findsWidgets);
      await _reveal(tester, find.byType(SalesTransactionsTable));
      expect(find.byType(SalesTransactionsTable), findsOneWidget);
      expect(c.analytics!.kpis.grossRevenue, 12850.5);
      expect(c.analytics!.hourly.length, 4);

      if (w >= 900) {
        for (final label in [
          'Retour',
          'Précédent',
          'Maison',
          'Dashboard',
          'Suivant'
        ]) {
          expect(find.text(label), findsOneWidget, reason: 'nav PC: $label');
        }
        // Interaction : changement de page réel.
        await tester.tap(find.text('Suivant'));
        await tester.pumpAndSettle();
        expect(find.text('Analyse des ventes'), findsWidgets,
            reason: 'Suivant ouvre la page Analyse');
        // Interaction : filtre de dates réel.
        await tester.tap(find.text('Hier'));
        await tester.pumpAndSettle();
        expect(c.period, SalesPeriod.yesterday);
      } else {
        for (final tip in [
          'Page précédente',
          'Vue générale SALES INTELLIGENCE',
          'Retour Dashboard PHARMA+',
          'Page suivante'
        ]) {
          expect(find.byTooltip(tip), findsOneWidget,
              reason: 'nav mobile: $tip');
        }
        await tester.tap(find.byTooltip('Page suivante'));
        await tester.pumpAndSettle();
        expect(find.text('Analyse des ventes'), findsWidgets,
            reason: 'navigation mobile fonctionnelle');
      }
    });
  }

  // 2. Pages : 20 scénarios avec assertions concrètes.
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
        await _setView(tester, w, h);
        final c = await _fixedController();
        addTearDown(c.dispose);
        await tester.pumpWidget(_host(w, h, Scaffold(body: builder(c))));
        await tester.pumpAndSettle();
        _expectCommonChrome(tester);

        switch (name) {
          case '01_vue_generale':
            expect(find.text('Vue générale'), findsOneWidget);
            _expectKpiGrid(tester, w);
            _expectGoldCurve(tester);
            await _reveal(tester, find.byType(SalesPaymentChart));
            expect(find.byType(SalesPaymentChart), findsOneWidget);
            expect(find.byType(SalesProductRanking), findsWidgets);
            await _reveal(tester, find.byType(SalesTransactionsTable));
            expect(find.byType(SalesTransactionsTable), findsOneWidget);
            await _reveal(tester, find.text('VTE-0007'));
            expect(find.text('VTE-0007'), findsOneWidget);
            break;
          case '02_analyse':
            expect(find.text('Analyse des ventes'), findsOneWidget);
            expect(find.text('Résumé analytique'), findsOneWidget);
            expect(find.byType(SalesMetric), findsNWidgets(6));
            await _reveal(tester, find.byType(SalesHourlyChart));
            _expectGoldCurve(tester);
            await _reveal(tester, find.text('Dernières transactions'));
            expect(find.text('Dernières transactions'), findsOneWidget);
            await _reveal(tester, find.text('VTE-0001'));
            expect(find.text('VTE-0001'), findsOneWidget);
            // États : chargement, erreur et absence de données.
            await tester.scrollUntilVisible(
              find.byType(SalesHourlyChart),
              -600,
              scrollable: find.byType(Scrollable).first,
            );
            await tester.pumpAndSettle();
            c.loading = true;
            c.notifyListeners();
            // Le CircularProgressIndicator anime indéfiniment : pump() suffit.
            await tester.pump();
            expect(find.byType(CircularProgressIndicator), findsWidgets,
                reason: 'état chargement');
            c.loading = false;
            c.error = SalesDayFailure(
                kind: SalesDayErrorKind.serverError,
                message: 'panne contrôlée',
                technical: 'TEST');
            c.notifyListeners();
            await tester.pump();
            expect(
                find.textContaining('Graphique indisponible'), findsOneWidget,
                reason: 'état erreur distinct');
            c.error = null;
            c.analytics = _emptyAnalytics();
            c.notifyListeners();
            await tester.pump();
            expect(find.text('Aucune vente · valeurs nulles'), findsOneWidget,
                reason: 'état vide distinct');
            break;
          case '03_benefices':
            expect(find.text('Bénéfices et marges'), findsOneWidget);
            expect(find.byType(SalesMetric), findsNWidgets(6));
            expect(find.text("Coût d'achat"), findsOneWidget);
            expect(find.text('Taux de marge brute'), findsOneWidget);
            expect(find.text('Part HT du CA TTC'), findsOneWidget);
            break;
          case '04_produits':
            expect(find.text('Produits vendus'), findsOneWidget);
            expect(find.byType(SalesProductRanking), findsNWidgets(3));
            expect(find.text('Top 10 par CA'), findsOneWidget);
            expect(find.text('DOLIPRANE'), findsWidgets);
            break;
          case '05_employes':
            expect(find.text('Performance employés'), findsOneWidget);
            // Le nom apparaît désormais aussi dans le bar chart de classement.
            expect(find.text('Pharmacien A'), findsWidgets);
            await _reveal(tester, find.text('Pharmacien B').last);
            expect(find.text('Pharmacien B'), findsWidgets);
            expect(find.text('Ventes'), findsWidgets);
            expect(find.text('CA HT'), findsWidgets);
            expect(c.fullRows.length, 8, reason: 'jeu complet agrégé');
            break;
          case '06_paiements':
            expect(find.text('Paiements et caisse'), findsOneWidget);
            expect(find.byType(SalesMetric), findsNWidgets(3));
            // La section de clôture persistée a grandi : on défile jusqu'au
            // graphique avant de l'assertion (ListView construit à la demande).
            await _reveal(tester, find.byType(SalesPaymentChart));
            expect(find.byType(SalesPaymentChart), findsOneWidget);
            expect(find.text('Caisse théorique (indicative, MAD)'),
                findsOneWidget);
            expect(find.text('Caisse comptée (MAD)'), findsOneWidget);
            await tester.enterText(find.byType(TextField).at(0), '1000');
            await tester.enterText(find.byType(TextField).at(1), '900');
            await tester.pumpAndSettle();
            expect(find.text('Écart de caisse : '), findsOneWidget,
                reason: 'calcul d’écart réel');
            break;
          case '07_retours':
            expect(find.text('Annulations et retours'), findsOneWidget);
            expect(find.text('Remboursements réels'), findsOneWidget);
            await _reveal(tester, find.text('VTE-0006'));
            expect(find.text('VTE-0006'), findsOneWidget,
                reason: 'transaction annulée listée');
            expect(find.byType(SalesMetric), findsNWidgets(3));
            break;
          case '08_comparaisons':
            expect(find.text('Comparaison avec la période précédente'),
                findsOneWidget);
            expect(find.text('Ventes validées'), findsOneWidget);
            expect(find.text('Encaissé'), findsOneWidget);
            await _reveal(tester, find.text("Coût d'achat"));
            expect(find.text("Coût d'achat"), findsOneWidget);
            break;
          case '09_rapports':
            expect(find.text('Rapports et exports'), findsOneWidget);
            await _reveal(tester, find.text('Imprimer'));
            for (final label in [
              'Export PDF',
              'Export Word (.doc)',
              'Export Excel (CSV)',
              'Export Excel (.xlsx)',
              'Imprimer'
            ]) {
              expect(find.text(label), findsOneWidget, reason: 'export $label');
            }
            expect(find.textContaining('transaction(s) incluse(s)'),
                findsOneWidget);
            expect(c.fullComplete, isTrue);
            break;
          case '10_alertes':
            expect(find.text('Alertes intelligentes'), findsOneWidget);
            expect(find.text('Aucune anomalie détectée'), findsOneWidget);
            expect(find.text('Marge brute non vérifiable'), findsNothing,
                reason: 'coût positif : aucune alerte trompeuse');
            break;
        }
      });
    }
  }
}
