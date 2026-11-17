// ============================================================
// TESTS CONTRÔLÉS — PHASE 2 SALES INTELLIGENCE
// ============================================================
// Données de test explicitement contrôlées (MockClient) : aucun
// appel réseau réel, aucune donnée de démonstration dans l'app.
// Couvre : coût manquant, marge honnête, règles d'alertes,
// chargement complet des transactions (exports/agrégations).
// ============================================================

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart' as http_testing;
import 'package:shared_preferences/shared_preferences.dart';

import '../lib/core/services/api_client.dart';
import '../lib/features/sales_day/controllers/sales_day_controller.dart';
import '../lib/features/sales_day/models/sales_day_model.dart';
import '../lib/features/sales_day/repositories/sales_repository.dart';
import '../lib/features/sales_day/services/sales_analytics_service.dart';
import '../lib/features/sales_day/services/sales_alerts_service.dart';
import '../lib/features/sales_day/services/sales_financials.dart';

SalesDayKpis kpisWith({
  required double gross,
  double? cost,
  double net = 0,
  double discounts = 0,
  int salesCount = 0,
  int cancelled = 0,
  int returned = 0,
  double outstanding = 0,
}) =>
    SalesDayKpis(
      grossRevenue: gross,
      netRevenue: net,
      taxTotal: 0,
      discountsTotal: discounts,
      salesCount: salesCount,
      averageBasket: 0,
      cancelledCount: cancelled,
      returnedCount: returned,
      paidAmount: 0,
      outstandingAmount: outstanding,
      refundedAmount: null,
      costTotal: cost,
      totalRows: 0,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ApiClient.resetClientForTesting();
  });

  tearDown(() {
    ApiClient.resetClientForTesting();
  });

  group('Finances honnêtes (coût manquant)', () {
    test('cost_total absent ou null → null (jamais 0)', () {
      final absent = SalesDayKpis.fromJson({'gross_revenue': '100'});
      final nil = SalesDayKpis.fromJson({
        'gross_revenue': '100',
        'cost_total': null,
      });
      expect(absent.costTotal, isNull);
      expect(nil.costTotal, isNull);
    });

    test('cost_total = 0 → conservé mais AMBIGU (jamais une marge fiable)', () {
      final zero = SalesDayKpis.fromJson({
        'gross_revenue': '100',
        'cost_total': 0,
      });
      expect(zero.costTotal, 0.0);
      final f = SalesFinancials.fromKpis(zero);
      expect(f.costReliability, SalesCostReliability.zeroAmbiguous);
      expect(f.hasCost, isFalse);
      expect(f.costUnavailableLabel, 'Non vérifiable');
      expect(f.grossProfit, isNull);
      expect(f.grossMarginPct, isNull,
          reason: 'un coût nul peut être un défaut de la source');
    });

    test('coût absent → « Non disponible », ni bénéfice ni marge', () {
      final f = SalesFinancials.fromKpis(kpisWith(gross: 1000, cost: null));
      expect(f.costReliability, SalesCostReliability.absent);
      expect(f.costUnavailableLabel, 'Non disponible');
      expect(f.hasCost, isFalse);
      expect(f.grossProfit, isNull);
      expect(f.grossMarginPct, isNull);
      expect(f.htSharePct, isNotNull);
    });

    test('coût positif → bénéfice et marge calculés', () {
      final f = SalesFinancials.fromKpis(kpisWith(gross: 1000, cost: 700));
      expect(f.costReliability, SalesCostReliability.available);
      expect(f.hasCost, isTrue);
      expect(f.grossProfit, 300);
      expect(f.grossMarginPct, closeTo(30, 0.001));
    });

    test('coût négatif → ambigu, aucune marge calculée', () {
      final f = SalesFinancials.fromKpis(kpisWith(gross: 1000, cost: -5));
      expect(f.costReliability, SalesCostReliability.zeroAmbiguous);
      expect(f.grossProfit, isNull);
    });
  });

  group('Règles d’alertes (contrôlées)', () {
    test('coût indisponible → règle marge NON évaluée, signalée info', () {
      final alerts = SalesAlertsService.evaluate(
        kpis: kpisWith(gross: 1000, cost: null),
        previous: null,
      );
      expect(
          alerts.map((a) => a.title), contains('Marge brute non vérifiable'));
      expect(
          alerts.map((a) => a.title), isNot(contains('Marge brute négative')));
    });

    test('coût nul ambigu → aucune alerte chiffrée de marge', () {
      final alerts = SalesAlertsService.evaluate(
        kpis: kpisWith(gross: 1000, cost: 0),
        previous: null,
      );
      expect(
          alerts.map((a) => a.title), contains('Marge brute non vérifiable'));
      expect(
          alerts.map((a) => a.title), isNot(contains('Marge brute négative')));
      expect(alerts.first.message, isNot(matches(RegExp(r'\d+ %'))));
    });

    test('coût > CA → alerte haute marge négative', () {
      final alerts = SalesAlertsService.evaluate(
        kpis: kpisWith(gross: 100, cost: 150),
        previous: null,
      );
      expect(alerts.map((a) => a.title), contains('Marge brute négative'));
      expect(alerts.first.level, 'high');
    });

    test('aucune anomalie → message explicite, pas de chiffre inventé', () {
      final alerts = SalesAlertsService.evaluate(
        kpis: kpisWith(
          gross: 1000,
          cost: 600,
          net: 800,
          salesCount: 10,
        ),
        previous: null,
      );
      expect(alerts.length, 1);
      expect(alerts.single.title, 'Aucune anomalie détectée');
    });
  });

  group('Jeu complet de transactions (exports / agrégations)', () {
    final range = SalesDateRange(
      DateTime(2026, 11, 17),
      DateTime(2026, 11, 18),
    );

    List<Map<String, dynamic>> rows(int start, int count) => List.generate(
          count,
          (i) => {
            'id': 't${start + i}',
            'number': 'V-${start + i}',
            'status': 'completed',
            'total': '10.00',
            'created_at': '2026-11-17T10:00:00Z',
          },
        );

    test('250 lignes → 2 pages parcourues, 250 lignes, complete=true',
        () async {
      final pages = <int>[];
      ApiClient.setClientForTesting(http_testing.MockClient((req) async {
        final p = int.tryParse(req.url.queryParameters['page'] ?? '1') ?? 1;
        expect(req.url.queryParameters['limit'], '200');
        pages.add(p);
        final start = (p - 1) * 200;
        final count = p == 1 ? 200 : 50;
        return http.Response(
          jsonEncode({
            'data': rows(start, count),
            'meta': {'page': p, 'limit': 200, 'total': 250},
          }),
          200,
        );
      }));

      final (result, err, complete) = await SalesRepository.instance
          .loadAllTransactions(range, offsetMinutes: 0);
      expect(err, isNull);
      expect(result, isNotNull);
      expect(result!.length, 250);
      expect(complete, isTrue);
      expect(pages, [1, 2]);
    });

    test('erreur en cours de pagination → échec signalé, jamais tronqué',
        () async {
      ApiClient.setClientForTesting(http_testing.MockClient((req) async {
        final p = int.tryParse(req.url.queryParameters['page'] ?? '1') ?? 1;
        if (p == 2) {
          return http.Response(
            jsonEncode({
              'error': {'code': 'SERVER', 'message': 'panic'}
            }),
            500,
          );
        }
        return http.Response(
          jsonEncode({
            'data': rows(0, 200),
            'meta': {'page': 1, 'limit': 200, 'total': 250},
          }),
          200,
        );
      }));

      final (result, err, complete) = await SalesRepository.instance
          .loadAllTransactions(range, offsetMinutes: 0);
      expect(result, isNull);
      expect(err, isNotNull);
      expect(complete, isFalse);
    });

    test('450 lignes → 3 pages, aucune troncature', () async {
      final pages = <int>[];
      ApiClient.setClientForTesting(http_testing.MockClient((req) async {
        final p = int.tryParse(req.url.queryParameters['page'] ?? '1') ?? 1;
        pages.add(p);
        final start = (p - 1) * 200;
        final count = p < 3 ? 200 : 50;
        return http.Response(
          jsonEncode({
            'data': rows(start, count),
            'meta': {'page': p, 'limit': 200, 'total': 450},
          }),
          200,
        );
      }));
      final (result, err, complete) = await SalesRepository.instance
          .loadAllTransactions(range, offsetMinutes: 0);
      expect(err, isNull);
      expect(result!.length, 450);
      expect(complete, isTrue);
      expect(pages, [1, 2, 3]);
    });

    test('filtres de la vue générale isolés du jeu complet', () async {
      final captured = <Map<String, String>>[];
      ApiClient.setClientForTesting(http_testing.MockClient((req) async {
        final q = Map<String, String>.from(req.url.queryParameters);
        captured.add(q);
        if (req.url.path.endsWith('/sales/day/transactions')) {
          return http.Response(
            jsonEncode({
              'data': rows(0, 2),
              'meta': {'page': 1, 'limit': q['limit'], 'total': 2},
            }),
            200,
          );
        }
        return http.Response(
            jsonEncode({
              'data': {'kpis': {}}
            }),
            200);
      }));
      final c = SalesDayController();
      addTearDown(c.dispose);
      await c.initialLoad();
      await c.setStatus(SalesTxFilter.problems);
      c.setSearch('RECHERCHE_QUI_NE_DOIT_PAS_FILTRER');

      await c.ensureFullTransactions();
      final fullCalls = captured.where((q) => q['limit'] == '200');
      expect(fullCalls, isNotEmpty);
      for (final q in fullCalls) {
        expect(q.containsKey('status'), isFalse,
            reason: 'statut du tableau isolé du jeu complet');
        expect(q.containsKey('search'), isFalse,
            reason: 'recherche du tableau isolée du jeu complet');
      }
      expect(c.fullRows.length, 2);
      expect(c.fullScopeLabel, contains('aucun filtre'));
    });
  });
}
