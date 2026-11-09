import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart' as http_testing;
import 'package:shared_preferences/shared_preferences.dart';

import '../lib/core/services/api_client.dart';
import '../lib/features/sales/sales_day_repository.dart';

/// Tests unitaires du repository Ventes du jour (sans POS).
/// Vérifie le mapping d'erreurs HTTP, le retry sur NETWORK_ERROR (1 fois) et
/// l'absence de retry sur 401/403/500.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ApiClient.setClientForTesting(http_testing.MockClient((r) async {
      throw http.ClientException('Failed to fetch');
    }));
  });

  tearDown(() {
    ApiClient.resetClientForTesting();
  });

  group('SalesDayRepository._mapError (via loadPage)', () {
    test('401 → sessionExpired', () async {
      ApiClient.setClientForTesting(http_testing.MockClient((r) async {
        return http.Response(
          jsonEncode({
            'error': {'code': 'UNAUTHORIZED', 'message': 'JWT invalide'},
          }),
          401,
        );
      }));
      final res = await SalesDayRepository.instance.loadPage(
          fromIso: '2026-11-09T00:00:00+01:00',
          toIso: '2026-11-10T00:00:00+01:00',
          page: 1,
          limit: 10);
      expect(res.error?.kind, SalesDayErrorKind.sessionExpired);
      expect(res.error?.technical, contains('HTTP 401'));
      ApiClient.resetClientForTesting();
    });

    test('403 → forbidden', () async {
      ApiClient.setClientForTesting(http_testing.MockClient((r) async {
        return http.Response(
          jsonEncode({
            'error': {'code': 'FORBIDDEN', 'message': 'sales:view requise'},
          }),
          403,
        );
      }));
      final res = await SalesDayRepository.instance.loadPage(
          fromIso: '2026-11-09T00:00:00+01:00',
          toIso: '2026-11-10T00:00:00+01:00',
          page: 1,
          limit: 10);
      expect(res.error?.kind, SalesDayErrorKind.forbidden);
      ApiClient.resetClientForTesting();
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
      final res = await SalesDayRepository.instance.loadPage(
          fromIso: '2026-11-09T00:00:00+01:00',
          toIso: '2026-11-10T00:00:00+01:00',
          page: 1,
          limit: 10);
      expect(res.error?.kind, SalesDayErrorKind.serverError);
      ApiClient.resetClientForTesting();
    });

    test('NETWORK_ERROR retenté exactement 1 fois puis exposé', () async {
      int calls = 0;
      ApiClient.setClientForTesting(http_testing.MockClient((r) async {
        calls++;
        throw http.ClientException('Failed to fetch');
      }));
      final res = await SalesDayRepository.instance.loadPage(
          fromIso: '2026-11-09T00:00:00+01:00',
          toIso: '2026-11-10T00:00:00+01:00',
          page: 1,
          limit: 10);
      expect(calls, 2, reason: '1 essai initial + 1 retry sur NETWORK_ERROR');
      expect(res.error?.kind, SalesDayErrorKind.network);
      expect(res.error?.technical, contains('NETWORK_ERROR'));
      ApiClient.resetClientForTesting();
    });

    test('401 n\'est PAS réessayé (1 seul appel)', () async {
      int calls = 0;
      ApiClient.setClientForTesting(http_testing.MockClient((r) async {
        calls++;
        return http.Response(
          jsonEncode({
            'error': {'code': 'UNAUTHORIZED', 'message': 'JWT invalide'},
          }),
          401,
        );
      }));
      final res = await SalesDayRepository.instance.loadPage(
          fromIso: '2026-11-09T00:00:00+01:00',
          toIso: '2026-11-10T00:00:00+01:00',
          page: 1,
          limit: 10);
      expect(calls, 1);
      expect(res.error?.kind, SalesDayErrorKind.sessionExpired);
      ApiClient.resetClientForTesting();
    });
  });

  group('SalesDayRepository.aggregate', () {
    test('calcule CA, nombre et panier moyen sur les completed uniquement', () {
      final agg = SalesDayRepository.instance.aggregate(
        [
          {'id': '1', 'total': 15.6, 'status': 'completed', 'created_at': '2026-11-09T10:00:00Z'},
          {'id': '2', 'total': 7.8, 'status': 'completed', 'created_at': '2026-11-09T11:00:00Z'},
          {'id': '3', 'total': 99.0, 'status': 'voided', 'created_at': '2026-11-09T12:00:00Z'},
        ],
        totalServer: 3,
        byHour: true,
      );
      expect(agg.revenue, closeTo(23.4, 0.001));
      expect(agg.count, 2);
      expect(agg.average, closeTo(11.7, 0.001));
    });

    test('lignes vides → revenu 0, moyenne 0, sans exception', () {
      final agg = SalesDayRepository.instance.aggregate(
        [],
        totalServer: 0,
        byHour: true,
      );
      expect(agg.revenue, 0);
      expect(agg.count, 0);
      expect(agg.average, 0);
      expect(agg.hourly, isEmpty);
    });
  });
}
