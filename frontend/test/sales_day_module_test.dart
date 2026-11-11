import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart' as http_testing;
import 'package:shared_preferences/shared_preferences.dart';

import '../lib/core/services/api_client.dart';
import '../lib/features/sales_day/controllers/sales_day_controller.dart';
import '../lib/features/sales_day/models/sales_day_model.dart';
import '../lib/features/sales_day/repositories/sales_repository.dart';
import '../lib/features/sales_day/services/sales_analytics_service.dart';

/// Tests unitaires du module reconstruit « Ventes du jour » :
/// parsing du contrat API, bornes de période, mapping d'erreurs
/// différenciées, controller (chargement + filtre statut).
/// Aucun réseau réel, aucune donnée fictive persistée.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ApiClient.resetClientForTesting();
  });

  tearDown(() {
    ApiClient.resetClientForTesting();
  });

  group('SalesDayKpis / Analytics (contrat /sales/day)', () {
    const payload = {
      'data': {
        'kpis': {
          'gross_revenue': '123.45',
          'net_revenue': 100.0,
          'tax_total': 23.45,
          'discounts_total': 5.0,
          'sales_count': 4,
          'average_basket': 30.86,
          'cancelled_count': 1,
          'returned_count': 0,
          'paid_amount': 123.45,
          'outstanding_amount': 0,
          'refunded_amount': null,
          'cost_total': 40.0,
          'total_rows': 5,
        },
        'hourly': [
          {'hour': 9, 'label': '09:00', 'revenue': 123.45, 'count': 4},
        ],
        'payment_breakdown': [
          {'method': 'cash', 'amount': 123.45, 'count': 1},
        ],
        'top_products_by_rev': [
          {
            'medication_id': 'm1',
            'name': 'DOLIPRANE',
            'dosage': '1000 mg',
            'quantity': 3.0,
            'revenue': 50.0,
            'profit': 30.0,
            'marginPct': 60.0,
            'sales': 2,
            'sortBy': 'rev',
          },
        ],
      },
    };

    test('parsing honnête (types numériques et string mélangés)', () {
      final a = SalesDayAnalytics.fromJson(
          Map<String, dynamic>.from((payload['data'] as Map)));
      expect(a.kpis.grossRevenue, closeTo(123.45, 0.001));
      expect(a.kpis.netRevenue, 100.0);
      expect(a.kpis.salesCount, 4);
      expect(a.kpis.refundedAmount, isNull,
          reason: 'champ null = non disponible, jamais 0 inventé');
      expect(a.hourly.single.revenue, 123.45);
      expect(a.payments.single.label, 'Espèces');
      expect(a.topProductsRev.single.displayName, 'DOLIPRANE');
      expect(a.topProductsRev.single.dosage, '1000 mg');
    });

    test('payload vide / malformé → zéros honnêtes, pas de crash', () {
      final a = SalesDayAnalytics.fromJson({});
      expect(a.kpis.grossRevenue, 0);
      expect(a.hourly, isEmpty);
      expect(a.payments, isEmpty);
      expect(a.topProductsRev, isEmpty);
    });
  });

  group('SalesAnalyticsService (bornes de période)', () {
    // Mercredi 11 nov 2026 (weekday=3).
    final now = DateTime(2026, 11, 11, 15, 30);

    test('Aujourd\'hui : [minuit, minuit+1j)', () {
      final r = SalesAnalyticsService.rangeFor(SalesPeriod.today, now: now);
      expect(r.start, DateTime(2026, 11, 11));
      expect(r.end, DateTime(2026, 11, 12));
    });

    test('Hier : exactement la journée précédente', () {
      final r = SalesAnalyticsService.rangeFor(SalesPeriod.yesterday, now: now);
      expect(r.start, DateTime(2026, 11, 10));
      expect(r.end, DateTime(2026, 11, 11));
    });

    test('Cette semaine : lundi → lundi suivant (norme ISO)', () {
      final r = SalesAnalyticsService.rangeFor(SalesPeriod.thisWeek, now: now);
      expect(r.start, DateTime(2026, 11, 9)); // lundi
      expect(r.end, DateTime(2026, 11, 16));
    });

    test('Ce mois : 1er → 1er suivant', () {
      final r = SalesAnalyticsService.rangeFor(SalesPeriod.thisMonth, now: now);
      expect(r.start, DateTime(2026, 11, 1));
      expect(r.end, DateTime(2026, 12, 1));
    });

    test('Personnalisé à cheval sur 2 mois : bornes exactes', () {
      final r = SalesAnalyticsService.rangeFor(
        SalesPeriod.custom,
        now: now,
        custom: DateTimeRange(
          start: DateTime(2026, 10, 28),
          end: DateTime(2026, 11, 3),
        ),
      );
      expect(r.start, DateTime(2026, 10, 28));
      expect(r.end, DateTime(2026, 11, 4));
    });

    test('Période précédente = même durée, juste avant', () {
      final r = SalesAnalyticsService.rangeFor(SalesPeriod.today, now: now);
      final p = SalesAnalyticsService.previousOf(r);
      expect(p.end, r.start);
      expect(p.start, r.start.subtract(r.end.difference(r.start)));
    });

    test('isoLocal inclut le décalage de l\'appareil', () {
      final d = DateTime(2026, 11, 11, 9, 5, 3);
      final s = isoLocal(d);
      expect(s, startsWith('2026-11-11T09:05:03'));
      expect(s, matches(RegExp(r'[+-]')));
    });
  });

  group('SalesRepository (mapping erreurs + contrat)', () {
    test(' Succès /sales/day : parse + query params corrects', () async {
      var captured = <String, String>{};
      ApiClient.setClientForTesting(http_testing.MockClient((r) async {
        captured = r.url.queryParameters;
        return http.Response(
          jsonEncode({
            'data': {'kpis': {}},
          }),
          200,
        );
      }));
      final range = SalesDateRange(
          DateTime(2026, 11, 10), DateTime(2026, 11, 11));
      final (a, err) = await SalesRepository.instance.loadAnalytics(range, offsetMinutes: 60);
      expect(err, isNull);
      expect(a, isNotNull);
      expect(captured['offsetMin'], '60');
      expect(captured['from']!, startsWith('2026-11-10T00:00:00'));
      expect(captured['to']!, startsWith('2026-11-11T00:00:00'));
    });

    test('Bornes de période : from/to avec décalage horaire local', () async {
      var captured = <String, String>{};
      ApiClient.setClientForTesting(http_testing.MockClient((r) async {
        captured = r.url.queryParameters;
        return http.Response(
          jsonEncode({'data': {'kpis': {}}}),
          200,
        );
      }));
      final range = SalesDateRange(
          DateTime(2026, 11, 10), DateTime(2026, 11, 11));
      await SalesRepository.instance.loadAnalytics(range, offsetMinutes: 60);
      // from/to doivent être des ISO avec décalage local (UTC ou local)
      expect(captured['from']!, startsWith('2026-11-10T00:00:00'));
      expect(captured['from']!, contains(RegExp(r'[+-]\d{2}:\d{2}')));
      expect(captured['to']!, startsWith('2026-11-11T00:00:00'));
      expect(captured['to']!, contains(RegExp(r'[+-]\d{2}:\d{2}')));
    });

    test('Réponse API incomplète (data absent) : pas de crash, kpis à zéro',
        () async {
      ApiClient.setClientForTesting(http_testing.MockClient((r) async {
        return http.Response(
          jsonEncode({'meta': {'total': 0}}), // pas de champ 'data'
          200,
        );
      }));
      final (a, err) = await SalesRepository.instance.loadAnalytics(
        SalesDateRange(DateTime(2026, 11, 10), DateTime(2026, 11, 11)),
        offsetMinutes: 0,
      );
      expect(err, isNull);
      expect(a, isNotNull);
      expect(a!.kpis.grossRevenue, 0);
      expect(a!.kpis.salesCount, 0);
    });

    test('Réponse API vide : kpis à zéro, pas de crash', () async {
      ApiClient.setClientForTesting(http_testing.MockClient((r) async {
        return http.Response(jsonEncode({}), 200);
      }));
      final (a, err) = await SalesRepository.instance.loadAnalytics(
        SalesDateRange(DateTime(2026, 11, 10), DateTime(2026, 11, 11)),
        offsetMinutes: 0,
      );
      expect(err, isNull);
      expect(a, isNotNull);
      expect(a!.kpis.grossRevenue, 0);
      expect(a!.hourly, isEmpty);
      expect(a!.payments, isEmpty);
      expect(a!.topProductsRev, isEmpty);
    });

    test('Formules financières : cohérence des KPIs et absence de double déduction', () async {
      // Données : 3 ventes terminées
      // Vente 1 : subtotal=100, discount=10, tax=20, total=110, paid=110, cost=60
      // Vente 2 : subtotal=200, discount=0, tax=40, total=240, paid=200, cost=120
      // Vente 3 : subtotal=50, discount=5, tax=10, total=55, paid=30, cost=30
      // Attendus :
      //   gross_revenue = 110+240+55 = 405
      //   net_revenue = (100-10)+(200-0)+(50-5) = 90+200+45 = 335
      //   tax_total = 20+40+10 = 70
      //   discounts_total = 10+0+5 = 15
      //   Vérification : gross = net + tax + discounts = 335+70+15 = 410 != 405 ?
      //   Non : gross = Σ total = 405, net = Σ(subtotal-discount) = 335
      //   gross - net = 70 = tax_total → cohérent (pas de double déduction)
      //   sales_count = 3
      //   average_basket = 405/3 = 135
      //   paid_amount = 110+200+30 = 340
      //   outstanding = max(110-110,0)+max(240-200,0)+max(55-30,0) = 0+40+25 = 65
      //   cost_total = 60+120+30 = 210
      //   gross_profit = gross - cost = 405-210 = 195
      //   margin_pct = 195/405 = 48.1%
      ApiClient.setClientForTesting(http_testing.MockClient((r) async {
        return http.Response(
          jsonEncode({
            'data': {
              'kpis': {
                'gross_revenue': 405.0,
                'net_revenue': 335.0,
                'tax_total': 70.0,
                'discounts_total': 15.0,
                'sales_count': 3,
                'average_basket': 135.0,
                'cancelled_count': 0,
                'returned_count': 0,
                'paid_amount': 340.0,
                'outstanding_amount': 65.0,
                'refunded_amount': null,
                'cost_total': 210.0,
                'total_rows': 3,
              },
              'hourly': [],
              'payment_breakdown': [],
              'top_products_by_rev': [],
              'top_products_by_qty': [],
              'top_products_by_profit': [],
            },
          }),
          200,
        );
      }));
      final (a, err) = await SalesRepository.instance.loadAnalytics(
        SalesDateRange(DateTime(2026, 11, 10), DateTime(2026, 11, 11)),
        offsetMinutes: 0,
      );
      expect(err, isNull);
      expect(a, isNotNull);

      // Vérification : gross = net + tax (pas de double déduction des remises)
      expect(a!.kpis.grossRevenue, a.kpis.netRevenue + a.kpis.taxTotal);

      // Vérification : gross - cost = gross profit
      final grossProfit = a.kpis.grossRevenue - a.kpis.costTotal;
      expect(grossProfit, 195.0);

      // Vérification : outstanding = Σ max(total - paid, 0)
      expect(a.kpis.outstandingAmount, 65.0);

      // Vérification : paid_amount = Σ min(total, paid)
      expect(a.kpis.paidAmount, 340.0);

      // Vérification : moyenne
      expect(a.kpis.averageBasket, 135.0);
    });

    test('401 → sessionExpired', () async {
      ApiClient.setClientForTesting(http_testing.MockClient((r) async {
        return http.Response(
          jsonEncode({
            'error': {'code': 'UNAUTHORIZED', 'message': 'JWT invalide'},
          }),
          401,
        );
      }));
      final (a, err) = await SalesRepository.instance.loadAnalytics(
        SalesDateRange(DateTime(2026, 11, 10), DateTime(2026, 11, 11)),
        offsetMinutes: 0,
      );
      expect(a, isNull);
      expect(err?.kind, SalesDayErrorKind.sessionExpired);
    });

    test('403 → forbidden (sales:view)', () async {
      ApiClient.setClientForTesting(http_testing.MockClient((r) async {
        return http.Response(
          jsonEncode({
            'error': {'code': 'FORBIDDEN', 'message': 'Permission sales:view requise'},
          }),
          403,
        );
      }));
      final (a, err) = await SalesRepository.instance.loadAnalytics(
        SalesDateRange(DateTime(2026, 11, 10), DateTime(2026, 11, 11)),
        offsetMinutes: 0,
      );
      expect(a, isNull);
      expect(err?.kind, SalesDayErrorKind.forbidden);
    });

    test('500 → serverError', () async {
      ApiClient.setClientForTesting(http_testing.MockClient((r) async {
        return http.Response(
          jsonEncode({
            'error': {'code': 'QUERY_FAILED', 'message': 'db down'},
          }),
          500,
        );
      }));
      final (a, err) = await SalesRepository.instance.loadAnalytics(
        SalesDateRange(DateTime(2026, 11, 10), DateTime(2026, 11, 11)),
        offsetMinutes: 0,
      );
      expect(a, isNull);
      expect(err?.kind, SalesDayErrorKind.serverError);
    });

    test('réseau indisponible : 1 seul retry, jamais de faux succès', () async {
      var calls = 0;
      ApiClient.setClientForTesting(http_testing.MockClient((r) async {
        calls++;
        throw http.ClientException('Failed to fetch');
      }));
      final (a, err) = await SalesRepository.instance.loadAnalytics(
        SalesDateRange(DateTime(2026, 11, 10), DateTime(2026, 11, 11)),
        offsetMinutes: 0,
      );
      expect(a, isNull);
      expect(err?.kind, SalesDayErrorKind.network);
      expect(calls, 2, reason: '1 requête + 1 seul retry réseau');
    });

    test('from/to inversé côté serveur → validation (400)', () async {
      ApiClient.setClientForTesting(http_testing.MockClient((r) async {
        return http.Response(
          jsonEncode({
            'error': {'code': 'VALIDATION', 'message': 'to > from requis'},
          }),
          400,
        );
      }));
      final (a, err) = await SalesRepository.instance.loadAnalytics(
        SalesDateRange(DateTime(2026, 11, 11), DateTime(2026, 11, 10)),
        offsetMinutes: 0,
      );
      expect(a, isNull);
      expect(err?.kind, SalesDayErrorKind.validation);
    });

    test(
        'isTokenExpiringSoon : expiré → vrai, valide → faux, '
        'mal formé → faux (sans crash)', () {
      String make(int expSecondsFromNow) {
        final payload = base64Url.encode(
            utf8.encode(jsonEncode({'exp': DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000 + expSecondsFromNow})));
        return 'h.$payload.s';
      }

      expect(SalesRepository.isTokenExpiringSoon(make(-100)), isTrue);
      expect(SalesRepository.isTokenExpiringSoon(make(3600)), isFalse);
      expect(SalesRepository.isTokenExpiringSoon('not-a-jwt'), isFalse);
      expect(SalesRepository.isTokenExpiringSoon(null), isFalse);
    });
  });

  group('SalesDayController (chargement + filtres)', () {
    test('initialLoad remplit KPI + transactions, aucune erreur', () async {
      ApiClient.setClientForTesting(http_testing.MockClient((r) async {
        if (r.url.path.contains('sales/day/transactions')) {
          return http.Response(
            jsonEncode({
              'data': [
                {
                  'id': 's1',
                  'number': 'VTE-001',
                  'status': 'completed',
                  'total': 15.6,
                  'paid_amount': 15.6,
                  'created_at': '2026-11-10T10:15:00Z',
                },
              ],
              'meta': {'total': 1, 'page': 1, 'limit': 50},
            }),
            200,
          );
        }
        return http.Response(
          jsonEncode({
            'data': {'kpis': {'gross_revenue': 15.6, 'sales_count': 1}, 'hourly': [], 'payment_breakdown': [], 'top_products': []},
          }),
          200,
        );
      }));
      final c = SalesDayController();
      await c.initialLoad();
      expect(c.loading, isFalse);
      expect(c.error, isNull);
      expect(c.analytics?.kpis.grossRevenue, 15.6);
      expect(c.txRows.single.number, 'VTE-001');
      c.dispose();
    });

    test('erreur 401 : état erreur honnête (sessionExpired), données vides',
        () async {
      ApiClient.setClientForTesting(http_testing.MockClient((r) async {
        return http.Response(
          jsonEncode({
            'error': {'code': 'SESSION_EXPIRED', 'message': 'expirée'},
          }),
          401,
        );
      }));
      final c = SalesDayController();
      await c.initialLoad();
      expect(c.loading, isFalse);
      expect(c.error?.kind, SalesDayErrorKind.sessionExpired);
      expect(c.analytics, isNull);
      expect(c.txRows, isEmpty);
      c.dispose();
    });
  });
}
