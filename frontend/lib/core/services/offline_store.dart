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

  /// Cache entités générique (clé = pmg_entity_<nom>).
  static String _kEntity(String name) => 'pmg_entity_$name';

  /// Idempotence : clé client->serveur pour éviter les doublons de vente.
  static const _kIdempotencyKeys = 'pmg_idempotency_keys';

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

  // ════════════════════════════════════════════════════════════════════
  // CACHE D'ENTITÉS GÉNÉRIQUE (clients, fournisseurs, factures, stock…)
  // ════════════════════════════════════════════════════════════════════

  /// Lit une liste d'entités mise en cache (ex: clients, fournisseurs).
  Future<List<Map<String, dynamic>>> readEntityCache(String name) async =>
      _readList(_kEntity(name));

  /// Écrit une liste d'entités en cache (upsert par id si présent).
  Future<void> writeEntityCache(
    String name,
    List<Map<String, dynamic>> rows, {
    bool merge = true,
  }) async {
    final key = _kEntity(name);
    final existing = merge ? await _readList(key) : <Map<String, dynamic>>[];
    final byId = <String, Map<String, dynamic>>{};
    for (final r in existing) {
      final id = r['id']?.toString();
      if (id != null && id.isNotEmpty) byId[id] = r;
    }
    for (final r in rows) {
      final id = r['id']?.toString();
      if (id != null && id.isNotEmpty) byId[id] = Map<String, dynamic>.from(r);
    }
    await _writeList(key, byId.values.toList());
  }

  /// Supprime le cache d'une entité (logout, changement de pharmacie).
  Future<void> clearEntityCache(String name) async {
    final sp = await _sp;
    await sp.remove(_kEntity(name));
  }

  // ═════════════════════════════════════════════════════════════════════
  // IDEMPOTENCE — clés client→serveur pour éviter les doublons de vente
  // ═════════════════════════════════════════════════════════════════════

  /// Vérifie si une clé d'idempotence a déjà été envoyée au serveur.
  Future<bool> isIdempotencyKeyUsed(String key) async {
    final map = await _readMap(_kIdempotencyKeys);
    return map.containsKey(key);
  }

  /// Marque une clé d'idempotence comme utilisée (après succès serveur).
  Future<void> markIdempotencyKeyUsed(String key, String serverRef) async {
    final map = await _readMap(_kIdempotencyKeys);
    map[key] = {
      'serverRef': serverRef,
      'usedAt': DateTime.now().toIso8601String(),
    };
    await _writeMap(_kIdempotencyKeys, map);
  }

  /// Nettoie les anciennes clés d'idempotence (garde les 1000 plus récentes).
  Future<void> pruneIdempotencyKeys() async {
    final map = await _readMap(_kIdempotencyKeys);
    if (map.length <= 1000) return;
    final entries = map.entries.toList()
      ..sort((a, b) {
        final da = (a.value as Map?)?['usedAt'] ?? '';
        final db = (b.value as Map?)?['usedAt'] ?? '';
        return db.toString().compareTo(da.toString());
      });
    final pruned = <String, dynamic>{};
    for (var i = 0; i < 1000 && i < entries.length; i++) {
      pruned[entries[i].key] = entries[i].value;
    }
    await _writeMap(_kIdempotencyKeys, pruned);
  }

  // ═══════════════════════════════════════════════════════════════════════
  // SAUVEGARDE / RESTAURATION LOCALE (Phase 7)
  // ═══════════════════════════════════════════════════════════════════════

  /// Liste des clés stockées dans SharedPreferences pour une sauvegarde complète.
  static const List<String> _backupKeys = [
    _kOutbox,
    _kOutboxSeq,
    _kPendingSales,
    _kRevisions,
    _kCatalog,
    _kCatalogSyncedAt,
    _kIdempotencyKeys,
  ];

  /// Exporte toutes les données hors-ligne vers une Map sérialisable.
  /// Inclut : file d'attente, ventes en attente, révisions, cache catalogue,
  /// caches d'entités (clients, fournisseurs…), clés d'idempotence.
  Future<Map<String, dynamic>> exportBackup() async {
    final sp = await _sp;
    final backup = <String, dynamic>{};
    final exportedKeys = <String>[];

    for (final key in _backupKeys) {
      final raw = sp.getString(key);
      if (raw != null && raw.isNotEmpty) {
        try {
          backup[key] = jsonDecode(raw);
          exportedKeys.add(key);
        } catch (_) {
          backup[key] = raw; // garde la valeur brute si JSON invalide
          exportedKeys.add(key);
        }
      }
    }

    // Inclure aussi tous les caches d'entités générés (pmg_entity_*).
    final allKeys = sp.getKeys();
    for (final key in allKeys) {
      if (key.startsWith('pmg_entity_')) {
        final raw = sp.getString(key);
        if (raw != null && raw.isNotEmpty) {
          try {
            backup[key] = jsonDecode(raw);
          } catch (_) {
            backup[key] = raw;
          }
          exportedKeys.add(key);
        }
      }
    }

    return <String, dynamic>{
      'exportedAt': DateTime.now().toIso8601String(),
      'version': 1,
      'keys': exportedKeys,
      'data': backup,
    };
  }

  /// Restaure une sauvegarde depuis une Map (produite par [exportBackup]).
  /// Écrase les valeurs existantes pour les clés présentes dans la sauvegarde.
  /// Retourne le nombre de clés restaurées.
  Future<int> importBackup(Map<String, dynamic> backup) async {
    final sp = await _sp;
    final data = backup['data'] as Map? ?? <String, dynamic>{};
    int count = 0;

    for (final entry in data.entries) {
      final key = entry.key as String;
      final value = entry.value;
      try {
        final String stringValue =
            value is String ? value : const JsonCodec().encode(value);
        await sp.setString(key, stringValue);
        count++;
      } catch (_) {
        // Ignore les clés non restaurables.
      }
    }

    // Invalider l'instance cachée de SharedPreferences pour forcer la relecture.
    _prefs = null;
    return count;
  }

  /// Exporte toutes les données hors-ligne vers une chaîne JSON.
  /// Cette chaîne peut être enregistrée dans un fichier par l'utilisateur.
  Future<String> exportBackupJson() async {
    final backup = await exportBackup();
    return const JsonCodec().encode(backup);
  }

  /// Importe une sauvegarde depuis une chaîne JSON (produite par [exportBackupJson]).
  /// Retourne le nombre de clés restaurées.
  Future<int> importBackupJson(String jsonBackup) async {
    try {
      final decoded = jsonDecode(jsonBackup) as Map<String, dynamic>;
      return await importBackup(decoded);
    } catch (_) {
      return 0;
    }
  }

  /// Vérifie l'intégrité d'une chaîne JSON de sauvegarde sans l'appliquer.
  /// Retourne (valide, nombre de clés, message).
  Future<(bool, int, String)> validateBackupJson(String jsonBackup) async {
    try {
      final decoded = jsonDecode(jsonBackup);
      if (decoded is! Map) return (false, 0, 'Format invalide : pas un objet');
      final version = decoded['version'];
      if (version is! int && version is! num) {
        return (false, 0, 'Version de sauvegarde manquante');
      }
      final data = decoded['data'];
      if (data is! Map) return (false, 0, 'Données manquantes');
      return (true, data.length, 'Sauvegarde valide');
    } catch (e) {
      return (false, 0, 'JSON invalide : $e');
    }
  }

  static String _json(Map<String, dynamic> map) {
    try {
      return const JsonCodec().encode(map);
    } catch (_) {
      return '{}';
    }
  }
}
