import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pharma_maroc_gold/core/services/offline_store.dart';

// File d'attente hors-ligne : couvre enqueue/pending/remove/markFailed
// (chemin critique des ventes non perdues) + pendingSales + révisions.
// Valide le back-end SharedPreferences (web/mobile) qui a remplacé sqflite.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    OfflineStore.instance.resetForTest();
  });

  test('enqueue -> pending expose id int, body JSON string, puis remove', () async {
    final store = OfflineStore.instance;
    await store.enqueue(
      method: 'POST',
      path: '/sales',
      body: {'client_sale_id': 'abc', 'total': 10},
    );
    final pending = await store.pending();
    expect(pending, hasLength(1));
    final op = pending.first;
    expect(op['id'], isA<int>());
    expect(op['method'], 'POST');
    expect(op['path'], '/sales');
    // body est une String JSON (décodée par SyncEngine via jsonDecode).
    expect(op['body'], isA<String>());
    expect((op['body'] as String).contains('client_sale_id'), isTrue);

    await store.remove(op['id'] as int);
    expect(await store.pending(), isEmpty);
  });

  test('markFailed incrmente attempts et enregistre last_error', () async {
    final store = OfflineStore.instance;
    await store.enqueue(method: 'POST', path: '/sales', body: {'x': 1});
    final op = (await store.pending()).first;
    await store.markFailed(op['id'] as int, 'NETWORK_ERROR');
    final after = (await store.pending()).first;
    expect(after['attempts'], 1);
    expect(after['last_error'], 'NETWORK_ERROR');
    await store.remove(op['id'] as int);
  });

  test('enqueue sans body -> body null (pas de string vide)', () async {
    final store = OfflineStore.instance;
    await store.enqueue(method: 'DELETE', path: '/x/1');
    final op = (await store.pending()).first;
    expect(op['body'], isNull);
    await store.remove(op['id'] as int);
  });

  test('savePendingSale -> pendingSales (synced=0) -> markSaleSynced', () async {
    final store = OfflineStore.instance;
    await store.savePendingSale('sale-1', {'total': 42});
    final pending = await store.pendingSales();
    expect(pending, hasLength(1));
    expect(pending.first['id'], 'sale-1');
    expect(pending.first['synced'], 0);

    await store.markSaleSynced('sale-1');
    expect(await store.pendingSales(), isEmpty);
  });

  test('getRevision/setRevision persiste la révision par entité', () async {
    final store = OfflineStore.instance;
    expect(await store.getRevision('medications'), 0);
    await store.setRevision('medications', 7);
    expect(await store.getRevision('medications'), 7);
    expect(await store.getRevision('autre'), 0);
  });

  group('cache catalogue hors-ligne', () {
    final rows = [
      {'id': 'm1', 'name': 'Doliprane 1000mg', 'laboratory_name': 'Sanofi',
       'barcode_ean13': '3400936055412', 'form': 'Comprimé', 'price_sale': 12.5},
      {'id': 'm2', 'name': 'Efferalgan 500mg', 'laboratory_name': 'Sanofi',
       'barcode_ean13': '3400933077190', 'form': 'Comprimé effervescent', 'price_sale': 8.0},
      {'id': 'm3', 'name': 'Bepanthen', 'laboratory_name': 'Sothema',
       'barcode_ean13': null, 'form': 'Pommade', 'price_sale': 45.0},
    ];

    // Recherche locale : reprend la logique de POS._offlineSearch
    // (nom / labo / EAN + filtre forme).
    List<Map<String, dynamic>> search(
        List<Map<String, dynamic>> cat, String q, String? form) {
      final ql = q.toLowerCase();
      return cat.where((r) {
        final name = (r['name'] ?? '').toString().toLowerCase();
        final lab = (r['laboratory_name'] ?? '').toString().toLowerCase();
        final ean = (r['barcode_ean13'] ?? '').toString();
        final mq = ql.isEmpty ||
            name.contains(ql) ||
            lab.contains(ql) ||
            ean.contains(q);
        final mf = form == null ||
            form.isEmpty ||
            (r['form'] ?? '').toString() == form;
        return mq && mf;
      }).toList();
    }

    test('cache vide : cachedCatalog vide, syncedAt null, count 0', () async {
      final store = OfflineStore.instance;
      expect(await store.cachedCatalog(), isEmpty);
      expect(await store.cachedCatalogCount(), 0);
      expect(await store.catalogSyncedAt(), isNull);
    });

    test('cache rempli : upsert par id, count, syncedAt renseigné', () async {
      final store = OfflineStore.instance;
      await store.saveCatalogRows(rows);
      final cat = await store.cachedCatalog();
      expect(cat, hasLength(3));
      expect(await store.cachedCatalogCount(), 3);
      expect(await store.catalogSyncedAt(), isNotNull);

      // Re-upsert avec le même id m1 modifié : pas de doublon.
      await store.saveCatalogRows([
        {'id': 'm1', 'name': 'Doliprane 1000mg CORRIGE', 'form': 'Comprimé'}
      ]);
      final after = await store.cachedCatalog();
      expect(after, hasLength(3)); // toujours 3, m1 remplacé
      expect(after.firstWhere((r) => r['id'] == 'm1')['name'],
          'Doliprane 1000mg CORRIGE');
    });

    test('recherche hors-ligne par nom, labo, EAN et forme', () async {
      final store = OfflineStore.instance;
      await store.saveCatalogRows(rows);
      final cat = await store.cachedCatalog();

      expect(search(cat, 'doli', null), hasLength(1));
      expect(search(cat, 'sothema', null), hasLength(1)); // par labo
      expect(search(cat, '3400933077190', null), hasLength(1)); // par EAN
      expect(search(cat, '', 'Pommade'), hasLength(1)); // par forme
      expect(search(cat, 'inexistant', null), isEmpty);
      // Cas limite EAN null : ne doit pas lever d'exception.
      expect(search(cat, 'bepanthen', null), hasLength(1));
    });

    test('saveCatalogRows([]) ne touche pas au cache existant', () async {
      final store = OfflineStore.instance;
      await store.saveCatalogRows(rows);
      await store.saveCatalogRows([]);
      expect(await store.cachedCatalogCount(), 3);
    });

    test('reconnexion : le cache online remplace/étend le cache offline',
        () async {
      final store = OfflineStore.instance;
      // Session offline : seuls 2 produits vus.
      await store.saveCatalogRows(rows.take(2).toList());
      expect(await store.cachedCatalogCount(), 2);
      // Reconnexion : le serveur renvoie le 3e + une correction du 1er.
      await store.saveCatalogRows(rows);
      final cat = await store.cachedCatalog();
      expect(cat, hasLength(3)); // upsert, pas de doublon
    });

    test('données périmées : syncedAt reflète la dernière écriture', () async {
      final store = OfflineStore.instance;
      expect(await store.catalogSyncedAt(), isNull); // jamais synchro
      await store.saveCatalogRows(rows);
      final t1 = await store.catalogSyncedAt();
      await Future<void>.delayed(const Duration(milliseconds: 5));
      await store.saveCatalogRows([rows.first]);
      final t2 = await store.catalogSyncedAt();
      expect(t2!.isAfter(t1!), isTrue); // fraîcheur mise à jour
    });

    test('erreur de stockage / JSON corrompu : retourne vide sans crash',
        () async {
      SharedPreferences.setMockInitialValues({
        'pmg_catalog': '{corrompu-json-invalid',
        'pmg_catalog_synced_at': 'pas-une-date',
      });
      OfflineStore.instance.resetForTest();
      final store = OfflineStore.instance;
      expect(await store.cachedCatalog(), isEmpty); // corruption -> vide
      expect(await store.cachedCatalogCount(), 0);
      expect(await store.catalogSyncedAt(), isNull); // date invalide -> null
    });

    test('changement de pharmacie : clearCatalog purge (pas de fuite)',
        () async {
      final store = OfflineStore.instance;
      await store.saveCatalogRows(rows);
      expect(await store.cachedCatalogCount(), 3);
      // Changement de pharmacie -> purge (appelée par AuthStore.saveSession).
      await store.clearCatalog();
      expect(await store.cachedCatalog(), isEmpty);
      expect(await store.catalogSyncedAt(), isNull);
      // La nouvelle pharmacie repart d'un cache vide.
      await store.saveCatalogRows([{'id': 'x1', 'name': 'Prod B'}]);
      final cat = await store.cachedCatalog();
      expect(cat, hasLength(1));
      expect(cat.first['id'], 'x1'); // aucun résidu de l'ancienne pharmacie
    });

    test('logout : clearCatalog ne laisse aucune donnée produit', () async {
      final store = OfflineStore.instance;
      await store.saveCatalogRows(rows);
      await store.clearCatalog(); // appelée par AuthStore.signOut
      expect(await store.cachedCatalog(), isEmpty);
    });
  });
}
