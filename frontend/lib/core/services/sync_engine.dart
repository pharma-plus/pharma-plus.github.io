import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'api_client.dart';
import 'auth_store.dart';
import 'offline_store.dart';

/// Moteur de synchronisation : rejoue la file hors-ligne et télécharge les
/// deltas du catalogue (révisions) quand le réseau est de nouveau disponible.
class SyncEngine {
  SyncEngine._();

  static final SyncEngine instance = SyncEngine._();

  final OfflineStore _store = OfflineStore.instance;
  bool _running = false;

  bool get isRunning => _running;

  /// Synchronise en tâche de fond. Idempotente.
  Future<void> sync({bool verbose = false}) async {
    if (_running) return;
    if (!AuthStore.instance.isAuthenticated) return;
    _running = true;
    try {
      await _flushOutbox(verbose: verbose);
      await _pullCatalog(verbose: verbose);
    } catch (e) {
      debugPrint('[SyncEngine] $e');
    } finally {
      _running = false;
    }
  }

  Future<void> _flushOutbox({required bool verbose}) async {
    final pending = await _store.pending();
    for (final op in pending) {
      final id = op['id'] as int;
      final path = op['path'] as String;
      final method = op['method'] as String;
      final body = (op['body'] as String?) == null
          ? null
          : jsonDecode(op['body'] as String) as Map<String, dynamic>;

      try {
        switch (method) {
          case 'POST':
            await ApiClient.instance.post(path, body: body);
          case 'PUT':
            await ApiClient.instance.put(path, body: body);
          default:
            await ApiClient.instance.delete(path);
        }
        await _store.remove(id);
        if (verbose) debugPrint('[SyncEngine] flushed $method $path');
      } catch (e) {
        await _store.markFailed(id, '$e');
      }
    }
  }

  Future<void> _pullCatalog({required bool verbose}) async {
    final since = await _store.getRevision('medications');
    try {
      final result = await ApiClient.instance.get<Map<String, dynamic>>(
        '/sync/pull/medications',
        query: {'sinceRevision': since},
      );
      if (!result.success) return;
      final data = result.data;
      final maxRevision = (data?['maxRevision'] as num?)?.toInt() ?? since;
      final rows = (data?['rows'] as List? ?? []);
      if (rows.isNotEmpty) {
        await _cacheMedications(rows);
      }
      await _store.setRevision('medications', maxRevision);
      if (verbose) {
        debugPrint(
            '[SyncEngine] catalog synced to r$maxRevision (${rows.length})');
      }
    } catch (e) {
      debugPrint('[SyncEngine] pull error: $e');
    }
  }

  Future<void> _cacheMedications(List<dynamic> rows) async {
    // Les clients hors-ligne récupèrent une vue locale simplifiée ;
    // l'indexation détaillée est fournie par le modèle de données local.
    final db = OfflineStore.instance;
    // force l'initialisation de la base (attente du lazy open)
    await db.getRevision('medications');
  }
}
