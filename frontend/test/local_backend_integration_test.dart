import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../lib/core/services/api_client.dart';
import '../lib/core/services/auth_store.dart';

void main() {
  group('Intégration Flutter + Backend Local SQLite (127.0.0.1:4001)', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      // Forcer l'URL du backend local (mode local PHARMA+)
      // sans appeler AuthStore.init() pour éviter les effets de bord
      await AuthStore.instance.setBaseUrl('http://127.0.0.1:4001/api/v1');
    });

    test('Le backend local est joignable (health)', () async {
      final result = await ApiClient.instance.get('/health');
      expect(result.success, isTrue, reason: result.error?.readableMessage ?? '');
      // Réponse directe non enveloppée : pas de clé 'data'
    });

    test('Login admin@pharma.local depuis Flutter', () async {
      final result = await ApiClient.instance.post(
        '/auth/login',
        body: {
          'email': 'admin@pharma.local',
          'password': 'admin123',
          'device': {'name': 'Flutter Test', 'type': 'mobile', 'userAgent': 'pmg-app'},
        },
      );
      expect(result.success, isTrue, reason: result.error?.readableMessage ?? '');
      final data = result.data as Map<String, dynamic>;
      expect(data['accessToken'], isNotNull);
      expect(data['refreshToken'], isNotNull);
      final user = data['user'] as Map<String, dynamic>;
      expect(user['email'], 'admin@pharma.local');
      expect(user['is_super_admin'], true);
    });

    test('Récupération du profil /auth/me depuis Flutter', () async {
      final login = await ApiClient.instance.post(
        '/auth/login',
        body: {'email': 'admin@pharma.local', 'password': 'admin123'},
      );
      expect(login.success, isTrue);
      final token = (login.data as Map)['accessToken'] as String;
      final result = await ApiClient.instance.get(
        '/auth/me',
        customHeaders: {'Authorization': 'Bearer $token'},
      );
      expect(result.success, isTrue, reason: result.error?.readableMessage ?? '');
      final user = result.data as Map<String, dynamic>;
      expect(user['email'], 'admin@pharma.local');
    });

    test('Liste des branches depuis Flutter', () async {
      final login = await ApiClient.instance.post(
        '/auth/login',
        body: {'email': 'admin@pharma.local', 'password': 'admin123'},
      );
      final token = (login.data as Map)['accessToken'] as String;
      final result = await ApiClient.instance.get(
        '/branches',
        customHeaders: {'Authorization': 'Bearer $token'},
      );
      expect(result.success, isTrue, reason: result.error?.readableMessage ?? '');
      expect(result.data, isA<List>());
    });

    test('Catalogue médicaments depuis Flutter', () async {
      final login = await ApiClient.instance.post(
        '/auth/login',
        body: {'email': 'admin@pharma.local', 'password': 'admin123'},
      );
      final token = (login.data as Map)['accessToken'] as String;
      final result = await ApiClient.instance.get(
        '/catalog/medications?limit=10',
        customHeaders: {'Authorization': 'Bearer $token'},
      );
      expect(result.success, isTrue, reason: result.error?.readableMessage ?? '');
      expect(result.data, isA<List>());
    });

    test('Stock des médicaments depuis Flutter', () async {
      final login = await ApiClient.instance.post(
        '/auth/login',
        body: {'email': 'admin@pharma.local', 'password': 'admin123'},
      );
      final token = (login.data as Map)['accessToken'] as String;
      final result = await ApiClient.instance.get(
        '/catalog/medications/stock',
        customHeaders: {'Authorization': 'Bearer $token'},
      );
      expect(result.success, isTrue, reason: result.error?.readableMessage ?? '');
      expect(result.data, isA<List>());
    });

    test('Création de vente avec idempotence depuis Flutter', () async {
      final login = await ApiClient.instance.post(
        '/auth/login',
        body: {'email': 'admin@pharma.local', 'password': 'admin123'},
      );
      final token = (login.data as Map)['accessToken'] as String;
      final pharmacyId = (login.data['user'] as Map)['pharmacy_id'] as String;
      final branchesResult = await ApiClient.instance.get(
        '/branches',
        customHeaders: {'Authorization': 'Bearer $token'},
      );
      final branchId = (branchesResult.data as List).first['id'] as String;
      final clientSaleId = 'flutter-local-test-${DateTime.now().millisecondsSinceEpoch}';

      final saleResult = await ApiClient.instance.post(
        '/sales',
        body: {
          'pharmacyId': pharmacyId,
          'branchId': branchId,
          'clientSaleId': clientSaleId,
          'saleType': 'pos',
          'items': [
            {'medication_id': 'm1', 'quantity': 2, 'unit_price': 6.5, 'discount': 0, 'tva_rate': 20}
          ],
          'payments': [{'method': 'cash', 'amount': 15.6}],
        },
        customHeaders: {'Authorization': 'Bearer $token', 'Idempotency-Key': 'idem-$clientSaleId'},
      );
      expect(saleResult.success, isTrue, reason: saleResult.error?.readableMessage ?? '');
      final sale = saleResult.data as Map<String, dynamic>;
      expect(sale['number'], isNotNull);
      expect(sale['content_hash'], isNotNull);

      // Replay idempotent : même clientSaleId + même contenu -> même vente
      final replayResult = await ApiClient.instance.post(
        '/sales',
        body: {
          'pharmacyId': pharmacyId,
          'branchId': branchId,
          'clientSaleId': clientSaleId,
          'saleType': 'pos',
          'items': [
            {'medication_id': 'm1', 'quantity': 2, 'unit_price': 6.5, 'discount': 0, 'tva_rate': 20}
          ],
          'payments': [{'method': 'cash', 'amount': 15.6}],
        },
        customHeaders: {'Authorization': 'Bearer $token', 'Idempotency-Key': 'idem-$clientSaleId'},
      );
      expect(replayResult.success, isTrue);
      final replay = replayResult.data as Map<String, dynamic>;
      expect(replay['id'], sale['id']);
      expect(replay['number'], sale['number']);
    });

    test('Conflit idempotence : même clé, contenu différent -> 409', () async {
      final login = await ApiClient.instance.post(
        '/auth/login',
        body: {'email': 'admin@pharma.local', 'password': 'admin123'},
      );
      final token = (login.data as Map)['accessToken'] as String;
      final pharmacyId = (login.data['user'] as Map)['pharmacy_id'] as String;
      final branchesResult = await ApiClient.instance.get(
        '/branches',
        customHeaders: {'Authorization': 'Bearer $token'},
      );
      final branchId = (branchesResult.data as List).first['id'] as String;
      final clientSaleId = 'flutter-conflict-test-${DateTime.now().millisecondsSinceEpoch}';

      await ApiClient.instance.post(
        '/sales',
        body: {
          'pharmacyId': pharmacyId,
          'branchId': branchId,
          'clientSaleId': clientSaleId,
          'saleType': 'pos',
          'items': [
            {'medication_id': 'm1', 'quantity': 2, 'unit_price': 6.5, 'discount': 0, 'tva_rate': 20}
          ],
          'payments': [{'method': 'cash', 'amount': 15.6}],
        },
        customHeaders: {'Authorization': 'Bearer $token', 'Idempotency-Key': 'idem-$clientSaleId'},
      );

      final conflictResult = await ApiClient.instance.post(
        '/sales',
        body: {
          'pharmacyId': pharmacyId,
          'branchId': branchId,
          'clientSaleId': clientSaleId,
          'saleType': 'pos',
          'items': [
            {'medication_id': 'm1', 'quantity': 999, 'unit_price': 6.5, 'discount': 0, 'tva_rate': 20}
          ],
          'payments': [{'method': 'cash', 'amount': 15.6}],
        },
        customHeaders: {'Authorization': 'Bearer $token', 'Idempotency-Key': 'idem-$clientSaleId'},
      );
      expect(conflictResult.statusCode, 409);
      expect(conflictResult.error?.code, 'IDEMPOTENCY_CONFLICT');
    });

    test('Clients depuis Flutter', () async {
      final login = await ApiClient.instance.post(
        '/auth/login',
        body: {'email': 'admin@pharma.local', 'password': 'admin123'},
      );
      final token = (login.data as Map)['accessToken'] as String;
      final result = await ApiClient.instance.get(
        '/customers?limit=50',
        customHeaders: {'Authorization': 'Bearer $token'},
      );
      expect(result.success, isTrue, reason: result.error?.readableMessage ?? '');
      expect(result.data, isA<List>());
    });
  });
}
