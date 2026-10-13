import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// File d'attente hors-ligne (SharedPreferences / localStorage).
/// Fonctionne sur WEB et mobile — remplace sqflite, inutilisable sur le
/// build web déployé (cible Pages). Les opérations critiques (ventes) sont
/// mises en file quand le réseau tombe, puis rejouées par [SyncEngine].
/// API et types préservés (id int, body String?) pour les appelants.
class OfflineStore {
  OfflineStore._();

  static final OfflineStore instance = OfflineStore._();

  SharedPreferences? _prefs;
  Future<SharedPreferences> get _sp async =>
      _prefs ??= await SharedPreferences.getInstance();

  /// RAZ de l'instance cachée — à appeler dans setUp() de test après
  /// [SharedPreferences.setMockInitialValues] pour isoler chaque cas.
  @visibleForTesting
  void resetForTest() {
    _prefs = null;
  }

  static const _kOutbox = 'pmg_outbox';
  static const _kOutboxSeq = 'pmg_outbox_seq';
  static const _kPendingSales = 'pmg_pending_sales';
  static const _kRevisions = 'pmg_revisions';
  static const _kCatalog = 'pmg_catalog';
  static const _kCatalogSyncedAt = 'pmg_catalog_synced_at';

  Future<List<Map<String, dynamic>>> _readList(String key) async {
    final sp = await _sp;
    final raw = sp.getString(key);
    if (raw == null || raw.isEmpty) return <Map<String, dynamic>>[];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
    } catch (_) {}
    return <Map<String, dynamic>>[];
  }

  Future<void> _writeList(String key, List<Map<String, dynamic>> items) async {
    final sp = await _sp;
    await sp.setString(key, jsonEncode(items));
  }

  Future<Map<String, dynamic>> _readMap(String key) async {
    final sp = await _sp;
    final raw = sp.getString(key);
    if (raw == null || raw.isEmpty) return <String, dynamic>{};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {}
    return <String, dynamic>{};
  }

  Future<void> _writeMap(String key, Map<String, dynamic> map) async {
    final sp = await _sp;
    await sp.setString(key, jsonEncode(map));
  }

  /// Ajoute une opération différée.
  Future<void> enqueue({
    required String method,
    required String path,
    Map<String, dynamic>? body,
  }) async {
    final sp = await _sp;
    final seq = (sp.getInt(_kOutboxSeq) ?? 0) + 1;
    await sp.setInt(_kOutboxSeq, seq);
    final items = await _readList(_kOutbox);
    items.add(<String, dynamic>{
      'id': seq,
      'method': method,
      'path': path,
      'body': body == null ? null : _json(body),
      'created_at': DateTime.now().toIso8601String(),
      'attempts': 0,
      'last_error': null,
    });
    await _writeList(_kOutbox, items);
  }

  Future<List<Map<String, Object?>>> pending({int limit = 50}) async {
    final items = await _readList(_kOutbox);
    items.sort((a, b) => ((a['id'] as int?) ?? 0).compareTo((b['id'] as int?) ?? 0));
    final sliced = items.take(limit).toList();
    return sliced.map((e) => Map<String, Object?>.from(e)).toList();
  }

  Future<void> remove(int id) async {
    final items = await _readList(_kOutbox);
    items.removeWhere((e) => e['id'] == id);
    await _writeList(_kOutbox, items);
  }

  Future<void> markFailed(int id, String error) async {
    final items = await _readList(_kOutbox);
    for (final e in items) {
      if (e['id'] == id) {
        e['attempts'] = ((e['attempts'] as int?) ?? 0) + 1;
        e['last_error'] = error;
        break;
      }
    }
    await _writeList(_kOutbox, items);
  }

  Future<void> savePendingSale(String id, Map<String, dynamic> payload) async {
    final map = await _readMap(_kPendingSales);
    map[id] = <String, dynamic>{
      'payload': payload,
      'created_at': DateTime.now().toIso8601String(),
      'synced': 0,
    };
    await _writeMap(_kPendingSales, map);
  }

  Future<List<Map<String, Object?>>> pendingSales() async {
    final map = await _readMap(_kPendingSales);
    final out = <Map<String, Object?>>[];
    map.forEach((id, v) {
      if (v is Map && ((v['synced'] as num?) ?? 0) == 0) {
        out.add(<String, Object?>{
          'id': id,
          'payload': v['payload'],
          'created_at': v['created_at'],
          'synced': 0,
        });
      }
    });
    out.sort((a, b) => (a['created_at'] ?? '')
        .toString()
        .compareTo((b['created_at'] ?? '').toString()));
    return out;
  }

  Future<void> markSaleSynced(String id) async {
    final map = await _readMap(_kPendingSales);
    final v = map[id];
    if (v is Map) {
      v['synced'] = 1;
      await _writeMap(_kPendingSales, map);
    }
  }

  Future<int> getRevision(String entity) async {
    final map = await _readMap(_kRevisions);
    return (map[entity] as num?)?.toInt() ?? 0;
  }

  Future<void> setRevision(String entity, int revision) async {
    final map = await _readMap(_kRevisions);
    map[entity] = revision;
    await _writeMap(_kRevisions, map);
  }

  /// Accumule des lignes catalogue (upsert par id) pour la recherche offline.
  /// Alimenté à chaque recherche online réussie et par le pull de révision.
  /// Stamp la date de dernière synchro pour afficher la fraîcheur hors-ligne.
  Future<void> saveCatalogRows(List<Map<String, dynamic>> rows) async {
    if (rows.isEmpty) return;
    final map = await _readMap(_kCatalog);
    for (final r in rows) {
      final id = r['id']?.toString();
      if (id != null && id.isNotEmpty) map[id] = r;
    }
    await _writeMap(_kCatalog, map);
    final sp = await _sp;
    await sp.setString(_kCatalogSyncedAt, DateTime.now().toIso8601String());
  }

  /// Catalogue mis en cache (lignes brutes, même format que l'API) — source
  /// de la recherche lorsque le réseau est indisponible.
  Future<List<Map<String, dynamic>>> cachedCatalog() async {
    final map = await _readMap(_kCatalog);
    return map.values
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  /// Date de dernière synchro réussie du catalogue (null = jamais synchro).
  /// Permet d'afficher « données du … » quand on est hors-ligne (fraîcheur).
  Future<DateTime?> catalogSyncedAt() async {
    final sp = await _sp;
    final raw = sp.getString(_kCatalogSyncedAt);
    if (raw == null || raw.isEmpty) return null;
    return DateTime.tryParse(raw);
  }

  /// Nombre de produits en cache (bornage mémoire / diagnostics).
  Future<int> cachedCatalogCount() async =>
      (await cachedCatalog()).length;

  /// Supprime le cache catalogue + son horodatage. Appelé au logout et à tout
  /// changement de pharmacie pour empêcher toute fuite de données entre
  /// sessions/utilisateurs sur un poste partagé.
  Future<void> clearCatalog() async {
    final sp = await _sp;
    await sp.remove(_kCatalog);
    await sp.remove(_kCatalogSyncedAt);
  }

  static String _json(Map<String, dynamic> map) {
    try {
      return const JsonCodec().encode(map);
    } catch (_) {
      return '{}';
    }
  }
}
