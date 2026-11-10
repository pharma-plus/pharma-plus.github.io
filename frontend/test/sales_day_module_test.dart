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
        'top_products': [
          {
            'medication_id': 'm1',
            'name': 'DOLIPRANE',
            'dosage': '1000 mg',
            'quantity': 3.0,
            'revenue': 50.0,
            'sales': 2,
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
      expect(a.topProducts.single.displayName, 'DOLIPRANE');
      expect(a.topProducts.single.dosage, '1000 mg');
    });

    test('payload vide / malformé → zéros honnêtes, pas de crash', () {
      final a = SalesDayAnalytics.fromJson({});
      expect(a.kpis.grossRevenue, 0);
      expect(a.hourly, isEmpty);
      expect(a.payments, isEmpty);
      expect(a.topProducts, isEmpty);
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
